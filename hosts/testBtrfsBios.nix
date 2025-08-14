{
  lib,
  profiles,
  ...
}:
{
  imports = with profiles; [
    users.test-operator
    users.test-deploy
    wireguard.testnet
  ];

  provision = {
    fs = {
      boot = {
        enable = true;
        device = "/dev/vda1";
        grub.devices = [ "/dev/vda" ];
        configurationLimit = 10;
        initrd = {
          enable = true;
          ssh.usersImportKeyFiles = [ "test-operator" ];
        };
      };
      luks.devices.enc-root = "/dev/vda2";
      btrfs.enable = true;
      btrfs.gen.enc-root.subvolumes.root.isRoot = true;
    };
    core.enable = true;
    nix.basic = true;
    networking.networkd.enable = true;
  };

  system.stateVersion = lib.mkDefault "23.05";
}
