{self, ...}: {
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  opts = self.lib.options;
  cfg = config.provision.virt.qemu;
in {
  imports = [./smart-qemu.nix];

  options.provision.virt.qemu = {
    guestAgent = opts.enable ''
      Common configuration for virtual machines running under QEMU (using virtio).
    '';
    smart = {
      enable = opts.enable "enable smart-qemu quirks found somewhere online";
      arm = opts.enable "enable 32bit arm emulation";
      aarch64 = opts.enable "enable 64bit arm emulation";
      riscv64 = opts.enable "enable 64bit riscv emulation";
      supportedPlatforms = opts.stringList [] "extra platforms that nix will run binaries for";
    };
  };

  config = mkIf cfg.guestAgent {
    boot.initrd.availableKernelModules = ["virtio_net" "virtio_pci" "virtio_mmio" "virtio_blk" "virtio_scsi" "9p" "9pnet_virtio" "ahci" "xhci_pci" "sr_mod"];
    networking.interfaces.enp1s0.useDHCP = true;
    boot.initrd.kernelModules = ["virtio_balloon" "virtio_console" "virtio_rng"];

    boot.initrd.postDeviceCommands =
      lib.mkIf (!config.boot.initrd.systemd.enable)
      ''
        # Set the system time from the hardware clock to work around a
        # bug in qemu-kvm > 1.5.2 (where the VM clock is initialised
        # to the *boot time* of the host).
        hwclock -s
      '';
  };
}
