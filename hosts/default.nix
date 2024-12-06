{
  self,
  inputs,
  lib,
  ...
}:
{
  flake.hosts = {
    hostsDir = ./.;

    defaults.modules = self.auto-import.nixos.all;
    defaults.overlays = [
      self.overlays.lib
      self.overlays.lnav
      self.overlays.default
    ];

    # configs.basic.nixpkgs = "stable";
    # configs.basic.modules = [ ./basic.nix ];
    # configs.disko-manual.modules = [ ./disko-manual.nix ];
    configs = {
      rpi-image = {
        system = "aarch64-linux";
        modules = [
          (
            { lib, ... }:
            {
              provision.defaults.enable = true;
              services.openssh.enable = true;
              networking.firewall.allowedTCPPorts = [ 22 ];

              # grub not needed on RPi (uboot is used)
              boot.loader.grub.enable = false;
              # default label from upstream `sd-aarch64-installer`
              fileSystems."/" = {
                device = "/dev/disk/by-label/NIXOS_SD";
                fsType = "ext4";
              };
              system.stateVersion = lib.mkDefault "23.05";
            }
          )
        ];
      };
      testOverlays.modules = [
        ./basic.nix
        (
          { pkgs, ... }:
          {
            networking.firewall.enable = true;
            environment.systemPackages = [
              pkgs.btrfs-list
            ];
          }
        )
      ];
      bcachefs-iso.modules = [
        (
          {
            pkgs,
            lib,
            modulesPath,
            ...
          }:
          {
            imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix") ];
            boot.supportedFilesystems = [
              "btrfs"
              "bcachefs"
            ];
            networking.hostName = lib.mkForce "bcachefs-iso";
            networking.hostId = lib.mkOverride 123 "deadbeef";
            # disable fileSystem config for iso
            disko.enableConfig = false;
            environment.systemPackages = with pkgs; [
              iwd
              networkmanager
            ];
            provision.fs.bcachefs.enable = true;
            users.users.root.initialHashedPassword = lib.mkForce null;
          }
        )
      ] ++ self.nixosConfigurations.basic._module.args.modules;
      basic-iso.modules = [
        (
          {
            pkgs,
            lib,
            modulesPath,
            ...
          }:
          {
            imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
            boot.supportedFilesystems = [
              "zfs"
              "btrfs"
            ];
            networking.hostName = lib.mkForce "basic-iso";
            networking.hostId = lib.mkOverride 123 "deadbeef";
            # disable fileSystem config for iso
            disko.enableConfig = false;
            environment.systemPackages = with pkgs; [
              iwd
              networkmanager
            ];
          }
        )
      ] ++ self.nixosConfigurations.basic._module.args.modules;
    };

    colmena.targetPort = 22;
    colmena.targetUser = "admin";
    deploy-rs.sshUser = "admin";
  };

  # Comes from https://github.com/drduh/YubiKey-Guide#nixos
  flake.yubikey-installer-old = import ./__old-yubikey-installer.nix;
  # TODO: better way to enable
  # flake.yubikey-installer = inputs.drduh.nixosConfigurations.yubikeyLive.x86_64-linux.extendModules {
  #   modules = [
  #     ({
  #       pkgs,
  #       lib,
  #       ...
  #     }: {
  #       environment.systemPackages = with pkgs; [
  #         nushell
  #         vim
  #         tmux
  #       ];
  #       console.keyMap = "uk";
  #       i18n.defaultLocale = "en_GB.UTF-8";
  #       # asdasd
  #       users.users.nixos.hashedPassword = lib.mkDefault "$y$j9T$j4CTpbd4ynR0Mm7z6NfsO1$zNgB3Q7aih85ZgYswU8A5id.pwClX63lSZl.Q5FKCAC";
  #       # asdasd
  #       users.users.root.hashedPassword = lib.mkDefault "$y$j9T$j4CTpbd4ynR0Mm7z6NfsO1$zNgB3Q7aih85ZgYswU8A5id.pwClX63lSZl.Q5FKCAC";
  #     })
  #   ];
  # };
}
