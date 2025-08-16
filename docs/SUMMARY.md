# Summary

- [Introduction](intro.md)
- [Installation](summary/installation.md)

---

# NixOS Modules

- [Core](nixos/core/intro.md)
  - [Nix Settings](nixos/core/nix.md)
- [Networking](nixos/networking/intro.md)
  - [systemd-networkd](nixos/networking/networkd.md)
  - [Wireguard Network Generation](nixos/networking/wireguard.md)
  - [Firewall (nftables)](nixos/networking/firewall/intro.md)
    - [Rules](nixos/networking/firewall/rules.md)
    - [Mapsets](nixos/networking/firewall/mapsets.md)
    - [Firewall Options Reference](options/nixos-nftables-options.md)
    <!-- - [Examples](networking/firewall/examples/intro.md) -->
    <!--   - [Desktop](networking/firewall/examples/desktop.md) -->
    <!--   - [Home Firewall](networking/firewall/examples/home-firewall.md) -->
- [Filesystems](nixos/filesystems/intro.md)
  - [Disko](nixos/filesystems/disko.md)
  - [initrd / boot](nixos/filesystems/initrd.md)
  - [ZFS](nixos/filesystems/zfs.md)
  - [Samba](nixos/filesystems/samba/intro.md)
    - [Server](nixos/filesystems/samba/server.md)
    - [Client](nixos/filesystems/samba/client.md)
    - [Samba Options Reference](options/nixos-samba-options.md)
  - [NFS](nixos/filesystems/nfs/intro.md)
    - [Server](nixos/filesystems/nfs/server.md)
    - [Client](nixos/filesystems/nfs/client.md)
    - [NFS Options Reference](options/nixos-nfs-options.md)
- [Virtualisation](nixos/virtualisation/intro.md)
  - [MicroVM.nix](nixos/virtualisation/microvm.md)
- [Roles](nixos/roles/intro.md)
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
