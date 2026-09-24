# lib/composer.nix — shared composition helpers (pure Nix)
# The ONE place registry entries become Home Manager configurations.
# The same moduleList is reused by the NixOS home-manager module path in Phase 7
# (NIX-02: identical user config by construction).
{ self, nixpkgs, home-manager, ... }@inputs:
let
  systems = [ "x86_64-linux" "aarch64-linux" ];
  forAllSystems = nixpkgs.lib.genAttrs systems;
  pkgsFor = system: nixpkgs.legacyPackages.${system};
  hosts = import ../hosts/default.nix { inherit inputs; };
  # D-11: the ONE place Base → Roles → Host ordering is expressed.
  # Missing role dir fails fast at eval (D-11).
  moduleList = name: cfg:
    [ ../modules/base ]
    ++ map (role: ../modules/roles/${role}) cfg.roles
    ++ [ ../hosts/${name}/home.nix ];
in rec {
  inherit systems forAllSystems pkgsFor moduleList;
  composeHome = name: cfg: home-manager.lib.homeManagerConfiguration {
    pkgs = pkgsFor cfg.system;
    extraSpecialArgs = { inherit inputs; }; # matches official template
    modules = moduleList name cfg ++ [{
      home.username = cfg.username; # identity from registry, never the environment
      home.homeDirectory = "/home/${cfg.username}";
      home.stateVersion = "26.05"; # explicit; default would drift on HM release bump
    }];
  };
  # Phase 7 seam: NixOS entries (kind = "nixos") stay out of homeConfigurations.
  standaloneHosts = nixpkgs.lib.filterAttrs (name: cfg: cfg.kind == "standalone") hosts;
  homeConfigurations = nixpkgs.lib.mapAttrs composeHome standaloneHosts;
}