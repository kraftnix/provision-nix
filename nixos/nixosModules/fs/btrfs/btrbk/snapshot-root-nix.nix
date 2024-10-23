{
  config,
  lib,
  ...
}:
lib.mkIf config.provision.fs.btrfs.legacy.btrbk-snapshot-root {
  # snapshot root + home volume
  services.btrbk.instances.snapshot-root-nix.onCalendar = "hourly";
  services.btrbk.instances.snapshot-root-nix.settings = {
    transaction_syslog = "daemon";
    snapshot_preserve = "3h 3d 2w 3m";
    #snapshot_preserve_min = "2d";
    volume."/" = {
      snapshot_dir = ".snapshots";
      subvolume = {
        home.snapshot_create = "always";
        ".".snapshot_create = "always";
      };
    };
  };
}
