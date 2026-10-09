{ lib, pkgs, ... }:
let
  vimCore = import ../../lib/vim-core.nix { };
in
{
  programs.vim = {
    enable = true;
    packageConfigurable = pkgs.vim;
    plugins = lib.mkForce [ ];
    extraConfig = vimCore.coreRC;
  };
}
