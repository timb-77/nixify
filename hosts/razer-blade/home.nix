# hosts/razer-blade/home.nix — the shared home entrypoint (D-05/D-06)
# Consumed by the composer as the Host layer; NixOS-reusable in Phase 7.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  targets.genericLinux.enable = true; # D-05: mandatory standalone env baseline (XDG_DATA_DIRS, desktop files)
  home.packages = [ pkgs.hello ]; # D-05: marker proving activation installs
}
