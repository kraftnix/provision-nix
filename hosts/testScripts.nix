{
  lib,
  profiles,
  inputs,
  pkgs,
  self,
  ...
}:
{
  imports = [
    profiles.users.test-operator
    profiles.users.test-deploy
    inputs.disko.nixosModules.disko
  ];

  provision.scripts.enable = true;
  provision.scripts.defaultLibDirs = self.scripts.${pkgs.system}.defaultLibDirs;
  provision.scripts.scripts = self.scripts.${pkgs.system}.__exportableScripts // {
    testing.inputs = [ pkgs.afetch ];
    testing.text = ''
      # test function
      def main [ ] {
        ^afetch
      }
    '';
  };
  provision = {
    defaults.enable = true;
    fs = {
      boot.enable = true;
      boot.initrd.enable = true;
      boot.initrd.ssh.usersImportKeyFiles = [ "test-operator" ];
      btrfs.enable = true; # enable extra tools etc.
      disko.devices.root = {
        device = "/dev/vda";
        profile = "btrfs-simple-uefi";
        args.extraDatasets = {
          "@" = {
            # override root dataset name
            mountpoint = "/";
            name = "@root";
          };
        };
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
