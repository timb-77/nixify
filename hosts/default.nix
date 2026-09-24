# hosts/default.nix — the host registry (NIX-04): one line per host, nothing else.
# Adding a host = hosts/<name>/ + one line here; flake.nix stays untouched.
{ inputs, ... }:
{
  razer-blade = import ./razer-blade { inherit inputs; };
}