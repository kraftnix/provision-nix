# Disko Integration

[Disko](https://github.com/nix-community/disko) provides a declarative way to partition
and format disks with nix.

This module provides some pre-tested disko examples, which can be imported and re-used
across hosts.

The disko profiles only define root disk setups:

## Usage

You can use preconfigured disko profiles in your NixOS configurations:

> `bcachefs` is supported, but should definitely treated as experimental, I have
> had a few issues / errors with it, and have been able to recover so far, but
> I do not recommend storing any important data with it. Stick to ZFS for important data.

### Simple unencrypted btrfs

Unencrypted btrfs with GPT with ESP (UEFI support), vfat `/boot` partition.

[Uses `btrfs-simple-uefi`](#btrfs--uefi-btrfs-simple-uefi)
```nix
provision.fs = {
  btrfs.enable = true; # enable extra tools etc.
  disko.devices.root = {
    device = "/dev/nvme0n1"; # set device to install root on
    profile = "btrfs-simple-uefi";
    # `btrfs-simple-uefi` supports `extraDatasets` to extend profile's datasets
    args.extraDatasets = {
      "@lib" = {
        mountpoint = "/var/lib";
        mountOptions = ["compress=zstd"];
      };
    };
  };
};
```

### Native encrypted bcachefs root

Native encrypted bcachefs with GPT with ESP (UEFI support), unencrypted vfat `/boot`.

[Uses `bcachefs-encrypted-uefi`](#bcachefs--native-encryption--uefi-bcachefs-encrypted-uefi)
```nix
provision.fs = {
  btrfs.enable = true; # enable extra tools etc.
  disko.devices.nvme = {
    profile = "bcachefs-encrypted-uefi";
    device = "/dev/disk/by-id/nvme-Samsung_SSD_970_PRO_1TB_SERIAL_NUMBER";
    args.rootName = "bcachefs";
  };
};
```

### LUKS encrypted Ext4 root

Luks encrypted `/` Ext4 with GPT with ESP (UEFI support), unencrypted vfat `/boot`.

[Uses `ext4-luks-bios-uefi`](#ext4--luks--uefi--bios-ext4-luks-bios-uefi)
```nix
provision.fs.disko.devices.root = {
  device = "/dev/sda";
  profile = "ext4-luks-bios-uefi";
  args.bootEnd = "1G"; # args can be used to override arguments from the profile
  args.iter-time = 10000;
};
```

## Profiles

Below is a reference of the current disko profiles.

### Ext4 + UEFI: `ext4-simple-uefi`

- GPT partition table
- `/boot`: vfat (ESP)
- `/`: Ext4
```nix
# included from ../../disko/ext4-simple-uefi.nix
{{#include ../../disko/ext4-simple-uefi.nix}}
```

### Ext4 + UEFI + BIOS: `ext4-simple-bios-uefi`

- GPT partition table
- Grub MBR partition
- `/boot`: vfat (ESP)
- `/`: Ext4
```nix
# included from ../../disko/ext4-simple-bios-uefi.nix
{{#include ../../disko/ext4-simple-bios-uefi.nix}}
```

### Ext4 + LUKS + UEFI + BIOS: `ext4-luks-bios-uefi`

- GPT partition table
- Grub MBR partition
- `/boot`: vfat (ESP)
- `/`: LUKS encrypted Ext4
```nix
# included from ../../disko/ext4-luks-bios-uefi.nix
{{#include ../../disko/ext4-luks-bios-uefi.nix}}
```

### Bcachefs + native encryption + UEFI: `bcachefs-encrypted-uefi`

- GPT partition table
- `/boot`: vfat (ESP)
- `/`: Bcachefs (native encryption)
```nix
# included from ../../disko/bcachefs-encrypted-uefi.nix
{{#include ../../disko/bcachefs-encrypted-uefi.nix}}
```

### Bcachefs + LUKS + UEFI: `bcachefs-luks-uefi`

- GPT partition table
- `/boot`: vfat (ESP)
- `/`: LUKS encrypted bcachefs
```nix
# included from ../../disko/bcachefs-luks-uefi.nix
{{#include ../../disko/bcachefs-luks-uefi.nix}}
```

### ZFS mirror + LUKS: `zfs-mirror-luks`

- 2 disks
- not designed as root FS
- GPT partition tables
- `/<pool>`: LUKS with ZFS on mirrored drives
```nix
# included from ../../disko/zfs-mirror-luks.nix
{{#include ../../disko/zfs-mirror-luks.nix}}
```

### Btrfs + UEFI: `btrfs-simple-uefi`

- GPT partition table
- `/boot`: vfat (ESP)
- `/`: btrfs
```nix
# included from ../../disko/btrfs-simple-uefi.nix
{{#include ../../disko/btrfs-simple-uefi.nix}}
```

### Btrfs + LUKS + UEFI: `btrfs-luks-uefi`

- GPT partition table
- `/boot`: vfat (ESP)
- `/`: LUKS encrypted btrfs
```nix
# included from ../../disko/btrfs-luks-uefi.nix
{{#include ../../disko/btrfs-luks-uefi.nix}}
```

