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
  outputs = { self, nixpkgs, home-manager, sops-nix, ... }@inputs:
    let
      composer = import ./lib/composer.nix { inherit self nixpkgs home-manager inputs; };
      inherit (composer) systems forAllSystems pkgsFor homeConfigurations;
    in {
      inherit homeConfigurations;
    };
}