{
  disks ? [
    "/dev/vda1"
    "/dev/vda2"
  ],
  ## LUKS options
  # LUKS password file
  passwordFile ? "/tmp/secret.key",
  # LUKS extra format arguments
  extraFormatArgs ? [
    "--iter-time 10000"
    "--hash sha512"
    "--cipher aes-xts-plain64"
    "--key-size 512"
  ],
  ## ZFS Options
  pool ? "mymirror",
  mountpoint ? "/${pool}",
  # ZFS options
  options ? {
    ashift = "13";
    autotrim = "on";
  },
  # ZFS root FS options
  rootFsOptions ? {
    compression = "zstd";
    "com.sun:auto-snapshot" = "false";
    recordsize = "1M";
    xattr = "sa";
    relatime = "on";
    acltype = "posixacl";
    dnodesize = "auto";
  },
  datasets ? {
    mydataset = {
      type = "zfs_fs";
      mountpoint = "/${pool}/mydataset";
    };
  },
  ...
}:
{
  disko.devices = {
    ## ZFS Pool Setup
    zpool.${pool} = {
      type = "zpool";
      mode = "mirror";
      inherit
        datasets
        mountpoint
        options
        rootFsOptions
        ;
    };

    ## Physical Disk Layout
    disk = {
      "${pool}-disk0" = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          inherit passwordFile extraFormatArgs;
          type = "luks";
          name = "${pool}-crypted0";
          content = {
            inherit pool;
            type = "zfs";
          };
        };
      };
      "${pool}-disk1" = {
        type = "disk";
        device = builtins.elemAt disks 1;
        content = {
          inherit passwordFile extraFormatArgs;
          type = "luks";
          name = "${pool}-crypted1";
          content = {
            inherit pool;
            type = "zfs";
          };
        };
      };
    };
  };
}
