{self, ...}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkDefault mkIf mkOption;
  opts = self.lib.options;
  cfg = config.provision.fs.zfs;
in {
  imports = [
    ./legacy-initrd.nix
    ./legacy-root-uefi.nix
  ];

  options.provision.fs.zfs = {
    enable = opts.enable "enable zfs configuration, adds zfs to supportedFilesystems";
    hostId = opts.stringNull "optionally set `networking.hostId` here, not required";
    kernel = {
      enable = opts.enable "sets the kernel to the latest compatible with ZFS";
      latest = mkOption {
        default = pkgs.linuxKernel.packages.linux_6_10;
        description = "latest linux kernel version that works with zfs";
      };
    };
    trim = opts.enableTrue "enable trim";
    scrub = {
      auto = opts.enableTrue "enable autoscrub";
    };
    nativeEncryption = opts.enable ''
      sets zfs to request encryption credentials and
      sets initrd postCommand to unlock zfs pools with native encryption
    '';
    snapshot = {
      auto = opts.enableTrue "enable auto snapshot";
      frequent = opts.int 5 "keep this many 15minute snapshots";
      daily = opts.int 2 "keep this many daily snapshots";
      weekly = opts.int 1 "keep this many weekly snapshots";
      monthly = opts.int 1 "keep this many monthly snapshots";
    };

    legacy = {
      root-uefi = opts.enable "import the legacy profile for `root-uefi`, do not use unless already using";
      initrd = opts.enable "import the legacy profile for `initrd`, do not use unless already using";
    };
  };

  config = mkIf cfg.enable {
    networking.hostId = mkIf (cfg.hostId != null) cfg.hostId;

    boot.supportedFilesystems = ["zfs"];
    boot.kernelPackages = mkIf cfg.kernel.enable cfg.kernel.latest;

    boot.zfs.requestEncryptionCredentials = mkDefault cfg.nativeEncryption;
    provision.fs.initrd.postCommands = mkIf cfg.nativeEncryption {
      command = ''
        echo "zfs load-key -a; killall zfs" >> /root/.profile
      '';
    };

    services.zfs = {
      trim.enable = cfg.trim;
      autoScrub.enable = cfg.scrub.auto;
      autoSnapshot = mkIf cfg.snapshot.auto {
        enable = true;
        inherit
          (cfg.snapshot)
          frequent
          daily
          weekly
          monthly
          ;
      };
    };
  };
}
