{
  config,
  lib,
  ...
}:
lib.mkIf config.provision.fs.btrfs.legacy.btrbk-core-root {
  # Ensure btrbk has a directory to store snapshots in
  systemd.tmpfiles.rules = [
    "d /.snapshots 0750 btrbk btrbk"
  ];
}
