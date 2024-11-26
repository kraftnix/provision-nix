{
  lib,
  profiles,
  inputs,
  ...
}:
{
  imports = [
    profiles.users.test-operator
    profiles.users.test-deploy
    profiles.wireguard.testnet-hosts
    inputs.disko.nixosModules.disko
  ];

  provision = {
    defaults = {
      enable = true;
      security = {
        doas.enable = true;
        doas.extraRules = [
          {
            users = [ "test-operator" ];
            noPass = true;
          }
        ];
        hardened_kernel.enable = true;
        namespacing.enable = true;
      };
    };
    fs = {
      boot.enable = true;
      boot.systemd.initrd.enable = true;
      initrd.enable = true;
      initrd.ssh.usersImportKeyFiles = [ "test-operator" ];
      btrfs.enable = true; # enable extra tools etc.
      disko.devices.root = {
        device = "/dev/vda";
        profile = "btrfs-simple-uefi";
      };
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
