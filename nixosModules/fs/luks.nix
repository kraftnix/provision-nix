{self, ...}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  opts = self.lib.options;
  cfg = config.provision.fs.luks;
in {
  options.provision.fs.luks = {
    enable = opts.enable' (cfg.devices != {}) "enable luks encryption, is read by `provision.fs.initrd` and `provision.fs.boot`";
    devices = opts.mk {
      default = {};
      description = "map of luks name -> device path to unlock";
      example = {
        enc-root = "/dev/vda1";
      };
      type = with lib.types; attrsOf str;
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.luks.devices =
      lib.mapAttrs
      (_: device: {
        inherit device;
        allowDiscards = lib.mkDefault true;
      })
      cfg.devices;
  };
}
