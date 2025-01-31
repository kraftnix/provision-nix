# Systemd-Networkd Integration

This integration provides basic systemd-networkd setup:
  - enable `networkd`, `resolved`, `timesyncd`, `resolved`
  - shorthand for adding interfaces to wait for with `systemd-networkd-wait-online`
  - shorthand for setting ethernet devices to use DHCPv4

Module Options Reference for [`provision.networking.networkd`](../options/nixos-all-options.md#provisionnetworkingnetworkdenable)

## Basic

```nix
provision.networking.networkd = {
  enable = true;
  waitOnline = true;
  waitInteraces = [ "enp2s0" ];
  # ethernetUseDhcp = true; # enabled by default
};
```
