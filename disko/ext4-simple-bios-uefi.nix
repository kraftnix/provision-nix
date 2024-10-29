{
  device ? "/dev/mmcblk0",
  diskName ? "main",
  bootStart ? "1M",
  bootEnd ? "1G",
  luksSize ? "100%",
  ...
}: {
  disko.devices.disk.${diskName} = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        boot = {
          priority = 1;
          start = "0";
          end = bootStart;
          type = "EF02"; # for grub MBR
        };
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
          start = bootEnd;
          end = luksSize;
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
