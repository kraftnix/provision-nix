# ZFS

This Nix module provides configuration options for setting up and managing ZFS on NixOS.
It enables ZFS support, configures kernel compatibility, encryption (native and on top of LUKS),
snapshot policies, and other ZFS-specific behaviors.

## Overview

This module allows you to:

- Enable ZFS support in the system.
- Select a compatible Linux kernel version for ZFS.
- Configure automatic data integrity checks (scrubbing) and TRIM support.
- Define snapshot policies for frequent, daily, weekly, and monthly backups.

Module Options Reference for [`provision.fs.zfs`](../../options/nixos-all-options.md#provisionfszfsenable)

## Example Configuration

When `enable` is set to `true`, the following actions are automatically applied:

- `zfs` is added to `boot.supportedFilesystems`.
- A compatible Linux kernel is selected and configured via `boot.kernelPackages` when `kernel.enable` is true.
- Native encryption is enabled if `nativeEncryption` is set to `true`, and the initrd is configured to unlock ZFS pools.
- ZFS services such as `trim`, `autoScrub`, and `autoSnapshot` are configured based on the specified policies.

```nix
provision.fs.zfs = {
  enable = true;
  # sets `networking.hostId`, required for ZFS on NixOS
  hostId = "deadbeef";
  kernel = {
    # set kernel to package specified below
    enable = true;
    # select a ZFS compatible kernel version
    latest = pkgs.linuxKernel.packages.linux_6_11;
  };
  # enables TRIM support to tell underlying devices of about blocks which are no longer allocated
  trim.enable = true;
  # enable periodic scrubbing of datasets
  scrub.auto = true;
  # sets initrd to request encryption credentials for ZFS on root
  nativeEncryption = true;
  # enable automatic snapshotting on a periodic basis
  snapshot = {
    auto = true;
    frequent = 10;
    daily = 3;
  };
}
```

## ZFS Pools backed by LUKS

Unlocking many LUKS datasets can take some time (especially in some setups or prior to systemd as an initrd with its parallel LUKS unlock).

An `provision.fs.zfs.luks.pools` provides a way to unlock many LUKS encrypted disks in parallel that are part of a ZFS pool.

This support importing disk configuration from a disko files or just by defining `device` and `label` for each device without defining them in `fileSystems` in NixOS.

```nix
provision.fs.zfs.luks.pools.enable = true;
provision.fs.zfs.luks.pools = {
  # import disk configuration from disko
  media = {
    mode = "keyfile";
    source = "/root/zpool-media-key";
    disko = ./path/to/disko/
  };

  # define zpool inline
  mirror-hdds = {
    mode = "keyfile";
    source = "/root/zpool-mirror-hdds-key";
    disks = [
      { device = "/dev/disk/by-id/XXX"; label = "mirror-hdds-1"; }
      { device = "/dev/disk/by-id/YYY"; label = "mirror-hdds-2"; }
    ];
  };
};
```

These pools are added to `boot.zfs.extraPools` to be auto-imported, the parallel unlock script is run before the `zfs-import-<pool>` service.

The disks are also added to `hardware.sensor.hddtemp.drives`.
