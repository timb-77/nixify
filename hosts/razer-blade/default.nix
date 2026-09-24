# hosts/razer-blade/default.nix — the registry entry attrset (D-01/D-02/D-03)
# Machine identity is razer-blade (DMI product name), NOT the OS hostname pop-os (D-02).
{ inputs, ... }: {
  system = "x86_64-linux"; # OS default hostname is pop-os; machine identity is razer-blade (D-02)
  kind = "standalone"; # non-NixOS + standalone Home Manager (D-03)
  username = "timbernwald"; # same Unix username on every machine
  roles = [ ]; # D-12: composer built now, no roles until Phase 2
}
