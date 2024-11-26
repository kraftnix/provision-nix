/*
   LUKS encrypted BTRFS root setup with some basic subvolumes on btrfs + ssh initrd luks unlock

  You could import this and change `provision.fs.boot.device` and
  `provision.luks.devices.enc-root` to your own, as well as adding
  your own ssh keyFiles at `provision.fs.initrd.ssh.keyFiles`
  or `provivision.fs.initrd.ssh.usersImportKeyFiles` to import keyFiles
  from a user.

  Expects:
  - vfat formatted boot partition at /dev/vda1
  - luks encrypted root partition at /dev/vda2
  - btrfs subvolumes
  - root: /
  - home: /home
  - nix: /nix
  - log: /var/log

  TODO: add example script of partition + disk setup
*/
{ lib, ... }:
{
  provision.fs = {
    boot.enable = true;
    boot.device = lib.mkDefault "/dev/vda1";
    initrd = {
      enable = true;
      ssh.usersImportKeyFiles = [ ]; # add your user here
    };
    luks = {
      enable = true;
      devices.enc-root = lib.mkDefault "/dev/vda2";
    };
    btrfs.enable = true;
    btrfs.gen.enc-root = {
      defaultOptions = [ "compress=zstd" ];
      subvolumes = {
        root.mnt = "/";
        home = { };
        nix.opts = [
          "compress=zstd"
          "noatime"
        ];
        log.mnt = "/var/log";
      };
    };
  };
}
