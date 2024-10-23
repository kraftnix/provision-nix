{
  device ? "/dev/vda",
  diskName ? "nvme",
  rootName ? "root",
  # is somewhat for compat
  bootEnd ? "1G",
  luksSize ? "100%",
  encrypted ? true,
  compression ? "zstd",
  # set to empty to skip
  acl ? true,
  discard ? true,
  lib,
  ...
}: let
  bootStart = "1MiB";
in {
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
        root = {
          name = rootName;
          size = luksSize;
          content = {
            type = "filesystem";
            format = "bcachefs";
            extraArgs = lib.flatten [
              (lib.optionalString encrypted "--encrypted")
              (lib.optionalString (compression != "") "--compression=${compression}")
              (lib.optionalString acl "--acl")
              (lib.optionalString discard "--discard")
            ];
            mountpoint = "/";
          };
        };
      };
    };
  };
}
