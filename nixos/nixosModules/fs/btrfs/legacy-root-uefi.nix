{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.provision.fs.btrfs.legacy.root-uefi {
  boot.supportedFilesystems = ["btrfs"];
  # Assumes you are using systemd-boot + uefi + BTRFS
  # with my core layout of datasets
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  environment.systemPackages = with pkgs; [
    btrfs-progs
    btrfs-heatmap
    btdu
    btrfs-list
  ];
}
