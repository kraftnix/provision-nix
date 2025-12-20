{
  lib,
  profiles,
  config,
  inputs,
  ...
}:
{
  imports = [
    profiles.users.test-operator
    profiles.users.test-deploy
  ];

  fileSystems."/" = lib.mkDefault { device = "/dev/disk/by-label/One"; };

  users.users.media.uid = 3000;
  users.users.media.group = "media";
  users.users.media.isSystemUser = true;
  users.groups.media.gid = 3000;

  provision.fs.boot = {
    enable = true;
    systemd.initrd.enable = true;
    initrd.enable = true;
    initrd.ssh.usersImportKeyFiles = [ "test-operator" ];
  };
  provision.fs.nfs.server = {
    enable = true;
    default.addToFilesystem = true;
    default.export.options = {
      rw = true;
      insecure = true;
      subtree_check = true;
      nohide = true;
      async = true;
    };
    subnets = {
      mydevices = {
        subnet = "10.77.1.0/24";
        exports = [
          "/media"
          "/pictures"
          "/documents"
          "/backups"
        ];
      };
      lan = {
        subnet = "192.168.1.0/24";
        exports = [ "/media" ];
      };
      phone = {
        subnet = "192.168.1.7/32";
        exports = [
          "/media"
          "/pictures"
          "/documents"
          "/backups"
        ];
      };
      thinclient = {
        subnet = "192.168.1.88/32";
        exports = [
          "/documents"
          "/backups"
        ];
      };
    };
    exports = {
      # Currently required to add root export
      "/" = {
        exportPath = "/export";
        export.options.fsid = 0;
        # allow to all hosts
        subnets."*" = { };
      };
      "/pictures".export.options = {
        anonuid = config.users.users.media.uid;
        anongid = config.users.users.media.uid;
      };
      "/media".export.options = {
        anonuid = config.users.users.media.uid;
        anongid = config.users.users.media.uid;
      };
      "/documents".export.options = {
        anonuid = 2000;
        anongid = 2000;
      };
    };
  };

  provision = {
    core.enable = true;
    nix.basic = true;
    networking.networkd.enable = true;
  };

  system.stateVersion = lib.mkDefault "23.05";
}
