# Summary

- [Introduction](intro.md)
- [Installation](summary/installation.md)

---

# NixOS Modules

- [Core](core/intro.md)
  - [Nix Settings](core/nix.md)
- [Networking](networking/intro.md)
  - [systemd-networkd](networking/networkd.md)
  - [Wireguard Network Generation](networking/wireguard.md)
  - [Firewall (nftables)](networking/firewall/intro.md)
    - [Rules](networking/firewall/rules.md)
    - [Mapsets](networking/firewall/mapsets.md)
    - [Firewall Options Reference](options/nixos-nftables-options.md)
    <!-- - [Examples](networking/firewall/examples/intro.md) -->
    <!--   - [Desktop](networking/firewall/examples/desktop.md) -->
    <!--   - [Home Firewall](networking/firewall/examples/home-firewall.md) -->
- [Filesystems](filesystems/intro.md)
  - [Disko](filesystems/disko.md)
  - [Stage 1 Boot / initrd](filesystems/initrd.md)
  - [ZFS](filesystems/zfs.md)
  - [Samba](filesystems/samba/intro.md)
    - [Server](filesystems/samba/server.md)
    - [Client](filesystems/samba/client.md)
    - [Samba Options Reference](options/nixos-samba-options.md)
- [Virtualisation](virtualisation/intro.md)
  - [MicroVM.nix](virtualisation/microvm.md)
- [Roles](roles/intro.md)
- [Full NixOS Options Reference](options/nixos-all-options.md)

---

# Flake Modules

- [Intro](flake/intro.md)
- [Hosts](flake/hosts.md)
- [Channels](flake/channels.md)
- [Documentation Generation](flake/docs.md)
  - [Nüscht Search Integration](flake/nuscht-search.md)
- [Full Flake Options Reference](options/flake-all-options.md)

---

# Scripts

- [Intro](scripts/intro.md)
  - [Options Reference: scripts](options/scripts-options.md)
  - [Flake Options Reference](options/scripts-flake-options.md)
  - [NixOS Options Reference](options/scripts-nixos-options.md)
  - [Home Options Reference](options/scripts-home-options.md)
