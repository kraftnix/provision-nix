{
  self,
  lib,
  profiles,
  inputs,
  ...
}: {
  imports = [
    self.nixosModules'.virt.microvm.vm
    inputs.microvm.nixosModules.microvm
    profiles.users.test-operator
    profiles.users.test-deploy
  ];

  provision = {
    nix.trustedUsers = ["test-deploy" "test-operator"];
    nix.optimise.enable = lib.mkForce false;
    virt.microvm.vm = {
      enable = true;
      vcpu = 2;
      mem = 1000;
      store = {
        readwrite.enable = true;
        readwrite.size = 2000;
      };
      mounts = {
        etc.enable = true;
        persist = {
          enable = true;
          mountpoint = "/persist";
          volume.sizeGB = 1;
        };
        journal.enable = true;
        home.enable = true;
      };
      network = {
        base.enable = true;
        base.id = "vmch-testing";
      };
    };
  };

  system.stateVersion = lib.mkDefault "23.05";
}
