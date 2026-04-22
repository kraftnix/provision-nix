{
  datasets ? [
    "pool/var"
    "pool/var/public"
    "pool/user-example"
  ],
}:
{ config, lib, ... }:
{
  networking.hostId = "deadbeef";
  boot.supportedFilesystems = [ "zfs" ];
  boot.initrd.kernelModules = [ "zfs" ];
  boot.initrd.systemd.extraBin = {
    zfs = "${config.boot.zfs.package}/bin/zfs";
    zpool = "${config.boot.zfs.package}/bin/zpool";
  };
  boot.initrd.systemd.services.init-zfs = {
    before = [ "initrd.target" ];
    wantedBy = [ "initrd.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -uo pipefail
      zpool create -O acltype=posixacl -O xattr=sa -O compression=lz4 pool /dev/vdb
      zfs set mountpoint=/pool pool
      ${lib.concatStringsSep "\n" (lib.map (d: "zfs create ${d}") datasets)}
    '';
  };
  boot.zfs.extraPools = [ "pool" ];
}
