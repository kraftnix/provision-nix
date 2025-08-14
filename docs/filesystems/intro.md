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

## Smartd

Small wrapper around smartd service (smart daemon from `smartmontools`).

```nix
provision.fs.smartd = {
  enable = true;
  # autodetect is enabled by default to auto add drives to for monitoring
  autodetect.enable = true;
  # extra settings to add to `services.smartd`
  settings = {
    devices = [
      { "/dev/sda"; }
      { "/dev/sdb"; options = "-d sat"; }
    ];
  };
};
```

## hddtemp

Support HDD/SDD temperatur monitoring, includes defaults to add disks from disko to enabled disks.

```nix
provision.fs.hddtemp = {
  enable = true;
  # this is enabled by default, adds disks from `disko.disk.*.device`
  automapDisko = true;
  # add your own drives
  drives = [ "/dev/dissk/by-label/XXXXXXXXXXXXXX" ];
};
```

## Misc

```nix
# enable gvfs, udisks2 and devmon
provision.fs.automount = true;

# add ntfs3g to system packages
provision.fs.ntfs = true;

# shorthand to add LUKS devices
provision.fs.luks = {
  enable = true;
  devices.enc-root = "/dev/sda";
  # can then be referred to as `/dev/mapper/enc-root` elsewhere in config
};

# enable bcachefs as supported filesystem
provision.fs.bcachefs.enable = true;
```
