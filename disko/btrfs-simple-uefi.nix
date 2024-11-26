{
  device ? "/dev/vda",
  diskName ? "root",
  bootStart ? "1M",
  bootSize ? "1G",
  # btrfs opts
  extraDatasets ? {
    # allows overriding default subvolume layout
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
  ...
}:
let
  # btrfs filesystem inside luks container
  btrfs = {
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
    inherit device;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          type = "EF00";
          size = bootSize;
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        root = {
          size = "100%";
          content = btrfs;
        };
      };
    };
  };
}
