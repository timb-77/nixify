{ config, lib, ... }:
{
  imports = [
    ./git.nix
    ./tmux.nix
    ./bash.nix
    ./vim.nix
  ];
}
