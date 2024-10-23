{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.provision.fs.btrfs.legacy.root-bios {
  boot.supportedFilesystems = ["btrfs"];
  boot.loader.grub = {
    enable = true;
    device = lib.mkDefault "/dev/vda";
    enableCryptodisk = lib.mkDefault true;
  };
  environment.systemPackages = with pkgs; [
    btrfs-progs
    btrfs-heatmap
    btdu
    btrfs-list
  ];
}
