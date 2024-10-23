{
  lib,
  profiles,
  ...
}: {
  imports = with profiles; [
    users.test-operator
    users.test-deploy
  ];

  networking.nftables.gen = {
    enable = true;
    tables.filter.mapsets.ssh_inbound = {
      lhsType = "daddr";
      elements = map (iface: {l = iface;}) ["10.11.1.1" "10.11.22.33"];
    };
    tables.filter.input.rules.testing = {
      log = true;
      counter = true;
      tcpDport = [22];
      mapset = "ssh_inbound";
    };
  };

  provision = {
    defaults.enable = true;
    fs = {
      boot = {
        enable = true;
        device = "/dev/vda1";
        grub.devices = ["/dev/vda"];
        configurationLimit = 10;
      };
      initrd = {
        enable = true;
        ssh.usersImportKeyFiles = ["test-operator"];
      };
      luks.devices.enc-root = "/dev/vda2";
      btrfs.enable = true;
      btrfs.gen.enc-root.subvolumes.root.isRoot = true;
    };
    core = {
      shell.enable = true;
      env.enable = true;
    };
    nix.basic = true;
    networking.networkd.enable = true;
  };

  system.stateVersion = lib.mkDefault "23.05";
}
