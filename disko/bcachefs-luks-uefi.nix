{
  device ? "/dev/vda",
  diskName ? "nvme",
  rootName ? "crypted-root",
  # is somewhat for compat
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
  # bcachefs opts
  compression ? "zstd",
  # set to empty to skip
  acl ? true,
  discard ? true,
  lib,
  ...
}:
let
  inherit (lib) mkIf optional;
  bootStart = "1M";
  root = {
    type = "filesystem";
    format = "bcachefs";
    mountpoint = "/";
    extraArgs = lib.flatten [
      (lib.optionalString (compression != "") "--compression=${compression}")
      (lib.optionalString acl "--acl")
      (lib.optionalString discard "--discard")
    ];
  };
in
{
  ## GPT Bios Compatible UEFI
  disko.devices.disk.${diskName} = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        boot = {
          priority = 1;
          size = bootStart;
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
            ]
            ++ (optional useRandom "--use-random");
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
