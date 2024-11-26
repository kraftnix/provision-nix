{
  lib,
  profiles,
  ...
}:
{
  imports = with profiles.users; [
    test-operator
    test-deploy
  ];

  provision = {
    defaults.enable = true;
    fs = {
      boot.enable = true;
      initrd.enable = true;
      initrd.ssh.usersImportKeyFiles = [ "test-operator" ];
      zfs = {
        enable = true;
        nativeEncryption = true;
        hostId = "deafbeeb";
        kernel.enable = true;
        legacy.root-uefi = true;
      };
    };
    virt.containers.docker = {
      enable = true;
      zfs = true;
      zfsDataset = "zroot/root/docker";
    };
    core = {
      shell.enable = true;
      env.enable = true;
    };
    nix.basic = true;
    networking.static = {
      address = "192.168.0.187";
      interface = "ens8";
      gateway = "192.168.0.1";
      netmask = "255.255.254.0";
      prefixLength = 23;
    };
  };

  # ensure a datasets is mounted for docker
  fileSystems."/docker" = {
    device = "zroot/root/docker";
    fsType = "zfs";
  };

  system.stateVersion = lib.mkDefault "23.05";
}
