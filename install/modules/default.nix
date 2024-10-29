{
  self,
  inputs,
  lib,
  ...
}: let
  inherit
    (lib)
    mkDefault
    mkForce
    mkOverride
    ;
in {
  flake.profiles.install = {
    # Base modules for nixos-anywhere installs
    nixosAnywhereBase = {modulesPath, ...}: {
      imports = [
        inputs.nixos-anywhere.inputs.disko.nixosModules.default
        (modulesPath + "/installer/scan/not-detected.nix")
        (modulesPath + "/profiles/qemu-guest.nix")
      ];
      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod" # standard laptop
        "ahci"
        "xhci_pci"
        "virtio_pci"
        "sr_mod"
        "virtio_blk"
        "virtio_net" # standard VM
      ];
      networking.hostName = mkDefault "baseNixosAnywhereInstall";
    };

    # (WIP) systemd-boot install
    uefiSystemdBoot = {config, ...}: {
      # systemd boot / UEFI
      boot.initrd.systemd.enable = true;
      boot.loader = {
        grub.enable = mkForce false;
        systemd-boot.enable = true;
        systemd-boot.configurationLimit = mkOverride 0 20;
        efi.canTouchEfiVariables = true;
      };
    };

    # enable initrd network unlock when using LUKS
    initrdNetwork = {config, ...}: {
      boot.initrd.network = {
        enable = true;
        ssh = {
          enable = true;
          inherit (self.internal) authorizedKeys;
          port = 9797;
          hostKeys = ["/etc/initrd/ssh_host_ed25519_key"];
        };
        # required for grub boot
        postCommands = lib.mkIf (!config.boot.initrd.systemd.enable) ''
          echo 'cryptsetup-askpass' >> /root/.profile
        '';
      };
    };

    # Sets a root user based on flake level settings in `flake.internal`
    testRootUser = {config, ...}: {
      users.users.root = {
        hashedPassword = self.internal.rootPasswordHash;
        openssh.authorizedKeys.keys = self.internal.authorizedKeys;
      };
    };

    ## Core base for nixos-anywhere installs
    nixosAnywhereInstall = {
      config,
      pkgs,
      ...
    }: {
      imports = [
        self.profiles.install.nixosAnywhereBase
        # add your own disk config
        # (import ./vps-disk.nix { device = "/dev/vda"; })
      ];

      networking.useDHCP = mkDefault true;
      networking.hostName = mkOverride 99 "nixosAnywhereInstall";
      networking.nameservers = [
        "9.9.9.9" # quad9
        "94.140.14.14" # adguard
      ];

      # Grub Default
      boot.loader.grub = {
        enable = mkDefault true;
        enableCryptodisk = mkDefault true;
      };

      services.openssh.enable = true;
      systemd.enableEmergencyMode = true;
      boot.initrd.systemd.emergencyAccess = true;

      environment.systemPackages = map lib.lowPrio [
        pkgs.curl
        pkgs.gitMinimal
        pkgs.vim
        pkgs.dig
      ];

      system.stateVersion = "23.11";
    };
  };
}
