{device ? "/dev/vda", ...}: let
  bootStart = "1M";
  bootEnd = "350M";
  luksEnd = "100%";

  root = {
    type = "filesystem";
    format = "ext4";
    mountpoint = "/";
  };

  # luks container in partition 2
  crypted-root = {
    type = "luks";
    name = "crypted-root";
    extraOpenArgs = ["--allow-discards"];
    # this is expected to be present at boot
    # settings.keyFile = "/tmp/root-luks.key";
    settings.allowDiscards = true;
    extraFormatArgs = [
      "--iter-time 3000"
      "--hash sha256"
      "--cipher aes-xts-plain64"
      "--key-size 512"
    ];
    # required using na-install script during nixos-anywhere installation
    # when using luks
    passwordFile = "/tmp/root-luks.key";
    content = root;
  };
in {
  ## GPT Bios Compatible
  disko.devices.disk.root = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        boot = {
          priority = 1;
          size = "1M";
          type = "EF02";
        };
        ESP = {
          priority = 2;
          size = bootEnd;
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        luks = {
          priority = 3;
          size = luksEnd;
          content = crypted-root;
        };
      };
    };
  };

  # ## UEFI
  # disko.devices.disk.root = {
  #   type = "disk";
  #   inherit device;
  #   content = {
  #     type = "table";
  #     format = "gpt";
  #     partitions = [
  #       {
  #         name = "ESP";
  #         start = bootStart;
  #         end = bootEnd;
  #         fs-type = "fat32";
  #         bootable = true;
  #         content = {
  #           type = "filesystem";
  #           format = "vfat";
  #           mountpoint = "/boot";
  #         };
  #       }
  #       {
  #         name = "luks";
  #         start = bootEnd;
  #         end = luksEnd;
  #         content = crypted-root;
  #       }
  #     ];
  #   };
  # };
}
