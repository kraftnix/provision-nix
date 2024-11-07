# Filesystems

This set of submodules is provide ways to configure different filesystems for NixOS.

You can find the options at `provision.fs`, these can help with configuring:
  - disk + filesystems via [Disko](./disko.md)
  - basic enablement options for filesystems such as `btrfs`, `zfs`, `nfs`, `ntfs`, `bcachefs`
  - filesystem + disk tools such as `hddtemp`, `smartctl`/`smartd`, `automount`
  - [initrd / stage-1 boot](./initrd.md)
    - unlock LUKS/native encrypted disks over SSH
    - `grub`, `systemd-boot`, `systemd initrd` supported

Module Options Reference for [`provision.fs`](../options/nixos-all-options.md#provisionfsautomount)
