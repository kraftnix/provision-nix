{
  device ? "/dev/vda",
  diskName ? "root",
  rootName ? "crypted-root",
  bootStart ? "1M",
  bootEnd ? "1G",
  luksSize ? "100%",
  luksName ? "luks",
  # name of luks container
  # luks opts
  keyFile ? "",
  # if set, this key file is expected at boot i.g. "/tmp/root-luks.key"
  passwordFile ? "",
  # during nixos-anywhere install, this file on the installing host to use as a LUKS passphrase
  iterTime ? 10000,
  # 10s iter time
  hash ? "sha256",
  cipher ? "aes-xts-plain64",
  keySize ? 512,
  useRandom ? true,
  discard ? true,
  # btrfs opts
  extraDatasets ? {
    "@snapshots" = {
      mountpoint = "/snapshots";
      mountOptions = [
        "compress=zstd"
        "noatime"
      ];
    };
    "@containers" = {
      mountpoint = "/containers";
      mountOptions = [ "noatime" ];
    };
  },
  lib,
  ...
}:
let
  inherit (lib) mkIf optional;
  # btrfs filesystem inside luks container
  root = {
    type = "btrfs";
    extraArgs = [ "--label nixos" ];
    subvolumes = {
      "@" = {
        mountpoint = "/";
        mountOptions = [ "noatime" ];
      };
      "@nix" = {
        mountpoint = "/nix";
        mountOptions = [
          "compress=zstd"
          "noatime"
        ];
      };
      "@home" = {
        mountpoint = "/home";
        mountOptions = [
          "compress=zstd"
          "noatime"
        ];
      };
      "@log" = {
        mountpoint = "/var/log";
        mountOptions = [ "noatime" ];
      };
    } // extraDatasets;
  };
in
{
  disko.devices.disk.${diskName} = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 2;
          start = bootStart;
          end = bootEnd;
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        ${luksName} = {
          size = luksSize;
          content = {
            type = "luks";
            name = rootName;
            # extraOpenArgs = [ "--allow-discards" ];
            # this is expected to be present at boot
            settings.keyFile = mkIf (keyFile != "") keyFile;
            settings.allowDiscards = mkIf discard true;
            extraFormatArgs = [
              "--iter-time ${toString iterTime}"
              "--hash ${hash}"
              "--cipher ${cipher}"
              "--key-size ${toString keySize}"
            ] ++ (optional useRandom "--use-random");
            # required using na-install script during nixos-anywhere installation
            # when using luks
            passwordFile = mkIf (passwordFile != "") passwordFile;
            content = root;
          };
        };
      };
    };
  };
}
