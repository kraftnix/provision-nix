{
  config,
  lib,
  ...
}:
lib.mkIf config.provision.fs.btrfs.legacy.btrbk-snapshot-root {
  # snapshot nix subvolume based on `/` filesystem
  services.btrbk.instances.snapshot-root.onCalendar = "hourly";
  services.btrbk.instances.snapshot-root.settings = {
    transaction_syslog = "daemon";
    snapshot_preserve = "3h 3d 1w";
    #snapshot_preserve_min = "2d";
    volume."/" = {
      snapshot_dir = ".snapshots";
      subvolume.nix.snapshot_create = "always";
    };
  };
}
