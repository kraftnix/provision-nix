{
  self,
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
    roles.edge = {
      enable = true;
      initrdUnlockUsers = [ "test-operator" ];
      initrdNetModules = [ "virtio_net" ]; # normally already added with guestAgent enabled, but shows example usage
      nixTrustedUsers = [
        "test-deploy"
        "test-operator"
      ];
      bigMachine = true;
    };
    fs.bcachefs.enable = true; # enable extra tools etc.
    fs.disko.devices.root = {
      device = "/dev/vda";
      profile = "bcachefs-luks-uefi";
    };
  };

  system.stateVersion = lib.mkDefault "23.05";
}
