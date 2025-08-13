{
  config,
  lib,
  ...
}:
lib.mkIf config.provision.fs.zfs.legacy.root-uefi {
  # Assumes you are using systemd-boot + uefi + ZFS
  # with my core layout of datasets
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.zfs.requestEncryptionCredentials = true;

  # Default ZFS on Root Filesystem Layout
  fileSystems."/" = {
    device = "zroot/root/nixos";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "zroot/root/home";
    fsType = "zfs";
  };

  fileSystems."/tmp" = {
    device = "zroot/root/tmp";
    fsType = "zfs";
  };

  # TODO: needed for `nix flake check` command to not fail.
  networking.hostId = lib.mkOverride 900 "deadbeef";

  ### WARNING: Make sure to add this to your sys

  #fileSystems."/boot" = {
  #  device = "/dev/disk/by-uuid/35C7-7353";
  #  fsType = "vfat";
  #};
}
