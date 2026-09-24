{
  description = "nixify — one flake, all machines";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs"; # single nixpkgs node in lock (NIX-12)
    };
    sops-nix = {
      url = "github:Mic92/sops-nix"; # Phase 5; locks the single-nixpkgs topology now
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      sops-nix,
      ...
    }@inputs:
    let
      composer = import ./lib/composer.nix {
        inherit
          self
          nixpkgs
          home-manager
          inputs
          ;
      };
      inherit (composer)
        systems
        forAllSystems
        pkgsFor
        homeConfigurations
        ;
      hosts = import ./hosts/default.nix { inherit inputs; };
    in
    {
      inherit homeConfigurations;
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);
      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          # D-08 gate 1: build each host's activation package (config.home.activationPackage —
          # the `system` namespace does not exist on standalone HM release-26.05).
          hostChecks = nixpkgs.lib.mapAttrs' (
            name: cfg:
            nixpkgs.lib.nameValuePair "home-${name}"
              self.homeConfigurations.${name}.config.home.activationPackage
          ) (nixpkgs.lib.filterAttrs (name: cfg: cfg.system == system) hosts);
        in
        hostChecks
        // {
          # D-08 gate 2: fmt gate — treefmt --ci on a writable copy of the source
          # (nixfmt cannot run in the read-only store tree).
          fmt = pkgs.runCommand "fmt-check" { nativeBuildInputs = [ pkgs.nixfmt-tree ]; } ''
            cp -r --no-preserve=mode,timestamps ${./.} "$TMPDIR/src"
            chmod -R u+w "$TMPDIR/src"
            treefmt --ci --tree-root "$TMPDIR/src"
            touch $out
          '';
        }
      );
    };
}
