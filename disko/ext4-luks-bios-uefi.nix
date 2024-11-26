{
  device ? "/dev/vda",
  diskName ? "root",
  bootEnd ? "350M",
  luksEnd ? "100%",
  iter-time ? 3000, # in ms
  key-size ? 512,
  cipher ? "aes-xts-plain64",
  ...
}:
let
  root = {
    type = "filesystem";
    format = "ext4";
    mountpoint = "/";
  };

  # luks container in partition 2
  crypted-root = {
    type = "luks";
    name = "crypted-root";
    extraOpenArgs = [ "--allow-discards" ];
    # this is expected to be present at boot
    # settings.keyFile = "/tmp/root-luks.key";
    settings.allowDiscards = true;
    extraFormatArgs = [
      "--iter-time ${toString iter-time}"
      "--hash sha256"
      "--cipher ${cipher}"
      "--key-size ${toString key-size}"
    ];
    # required using na-install script during nixos-anywhere installation
    # when using luks
    passwordFile = "/tmp/root-luks.key";
    content = root;
  };
in
{
  ## GPT Bios Compatible
  disko.devices.disk.${diskName} = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        boot = {
          name = "boot";
          size = "1M";
          type = "EF02";
        };
        esp = {
          name = "ESP";
          size = bootEnd;
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        luks = {
          name = "luks";
          size = luksEnd;
          content = crypted-root;
        };
      };
    };
  };
}
