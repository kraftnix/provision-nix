{
  lib,
  profiles,
  inputs,
  ...
}:
{
  imports = with profiles.users; [
    test-operator
    test-deploy
    inputs.disko.nixosModules.disko
  ];

  provision = {
    fs = {
      boot.enable = true;
      boot.initrd.enable = true;
      boot.initrd.ssh.usersImportKeyFiles = [ "test-operator" ];
      bcachefs.enable = true; # enable extra tools etc.
      disko.devices.root = {
        device = "/dev/vda";
        profile = "bcachefs-encrypted-uefi";
      };
    };
    core.enable = true;
    nix.basic = true;
    networking.networkd.enable = true;
  };

  system.stateVersion = lib.mkDefault "23.05";
}
