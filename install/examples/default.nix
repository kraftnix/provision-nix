{
  self,
  inputs,
  lib,
  ...
}:
let
  inherit (lib)
    mapAttrs
    ;
in
{
  # For basic basic unencrypted installs
  flake.nixosConfigurations.vpsBasicInstall = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with self.profiles.install; [
      nixosAnywhereInstall
      testRootUser
      # (import ../../disko/ext4-simple-bios-uefi.nix)
      (import ./vps-disk.nix { device = "/dev/vda"; })
    ];
  };

  # Luks Encrypted with initrd
  flake.nixosConfigurations.vpsLuksInitrdInstall = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with self.profiles.install; [
      nixosAnywhereInstall
      testRootUser
      (import ./vps-disk.nix { device = "/dev/vda"; })
      initrdNetwork
    ];
  };

  # Luks Encrypted with initrd
  flake.nixosConfigurations.vpsLuksInitrdInstallBtrfs = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with self.profiles.install; [
      nixosAnywhereInstall
      uefiSystemdBoot
      testRootUser
      (import ../../disko/btrfs-luks-uefi.nix {
        device = "/dev/disk/by-id/nvme-Patriot_M.2_P300_128GB_P300EDBB23061702130";
        inherit lib;
      })
      initrdNetwork
      {
        boot.initrd.availableKernelModules = [
          "cdc_ncm"
          "mt7921e"
        ];
      }
    ];
  };

  # Hizakura example with static ip
  flake.nixosConfigurations.hizakuraStaticInstall = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with self.profiles.install; [
      nixosAnywhereInstall
      testRootUser
      (import ./vps-disk.nix { device = "/dev/vda"; })
      initrdNetwork
      (self.lib.initrdStaticIp {
        address = "45.133.117.40";
        interface = "enp3s0";
        gateway = "45.133.117.1";
        netmask = "255.255.255.0";
        prefixLength = 24;
      })
    ];
  };

  # Steam Deck example
  flake.nixosConfigurations.steamDeckBtrfs = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with self.profiles.install; [
      nixosAnywhereInstall
      uefiSystemdBoot
      testRootUser
      (import self.disko.btrfs-simple-uefi { device = "/dev/nvme0n1"; })
      {
        # boot.initrd.systemd.enable = lib.mkForce false;
        # boot.loader.systemd-boot.enable = lib.mkForce false;
        boot.initrd.availableKernelModules = [
          "nvme"
          "dwc3_pci"
          "xhci_pci"
          "usbhid"
          "sdhci_pci"
        ];
        boot.kernelModules = [ "kvm-amd" ];
        networking.useDHCP = true;
        hardware.cpu.amd.updateMicrocode = true;
      }
    ];
  };

  # Generate isos for hosts in `flake.internal.generateIsos`
  flake.isos = mapAttrs (host: cfg: cfg.config.formats.iso) self.internal.generateIsos;
}
