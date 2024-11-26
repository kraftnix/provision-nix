{ self, ... }:
{
  config,
  options,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mapAttrsToList;
  opts = self.lib.options;
  cfg = config.provision.fs;
  diskoDisks =
    if options ? disko then mapAttrsToList (name: cfg: cfg.device) config.disko.devices.disk else [ ];
  btrfsDisks = mapAttrsToList (name: cfg: cfg.devicePath) cfg.btrfs.gen;
in
{
  options.provision.fs = {
    automount = opts.enable "enable automount via devmon, udisks2 and gvfs";
    ntfs = opts.enable "enable ntfs3d driver";
    hddtemp = {
      enable = opts.enable "enable hddtemp monitoring";
      drives = opts.stringList [ ] "drives to monitor";
      automapDisko = opts.enableTrue "automatically add all disko defined drives to monitoring";
      automapBtrfs = opts.enable' cfg.btrfs.enable "automatically add all disko defined drives to monitoring";
    };
  };

  config = lib.mkMerge [
    (mkIf cfg.automount {
      services = {
        gvfs.enable = true;
        udisks2.enable = true;
        devmon.enable = true;
      };
    })
    (mkIf cfg.ntfs {
      environment.systemPackages = with pkgs; [ ntfs3g ];
    })
    (mkIf cfg.hddtemp.enable {
      hardware.sensor.hddtemp = {
        enable = true;
        drives = lib.unique (
          cfg.hddtemp.drives
          ++ (lib.optionals cfg.hddtemp.automapDisko diskoDisks)
          ++ (lib.optionals cfg.hddtemp.automapBtrfs btrfsDisks)
        );
      };
    })
  ];
}
