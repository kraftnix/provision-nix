{self, ...}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkMerge;
  opts = self.lib.options;
  cfg = config.provision.fs.smartd;
in {
  options.provision.fs.smartd = {
    enable = opts.enable "enable smartd (smartmontools) hard drive monitoring/testing";
    autodetect = {
      enable = opts.enableTrue "monitor all devices found on startup";
      defaultMatch = opts.string "-a -o on -s (S/../.././03|L/../../7/03)" ''
        See smartd.conf(5) man page for details about these options:
          + "-a": enable all checks
          + "-o VALUE": enable/disable automatic offline testing on device (on/off)
          + "-s REGEXP": do a short test every day at 3am and a long test every
                       sunday at 3am.
      '';
    };
    settings = opts.raw {} "extra settings to add to `services.smartd`";
  };

  config = lib.mkIf cfg.enable {
    services.smartd = mkMerge [
      {
        enable = true;
        autodetect = cfg.autodetect.enable;
        defaults.autodetected = cfg.autodetect.defaultMatch;
      }
      cfg.settings
    ];
  };
}
