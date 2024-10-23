{
  lib,
  profiles,
  inputs,
  ...
}: {
  imports = with profiles.users; [
    test-operator
    test-deploy
    inputs.disko.nixosModules.disko
  ];

  provision = {
    defaults.enable = true;
    fs = {
      boot.enable = true;
      initrd.enable = true;
      initrd.ssh.usersImportKeyFiles = ["test-operator"];
      bcachefs.enable = true; # enable extra tools etc.
      disko.devices.root = {
        device = "/dev/vda";
        profile = "bcachefs-encrypted-uefi";
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
