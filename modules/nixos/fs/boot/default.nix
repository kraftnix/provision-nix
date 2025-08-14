{ self, ... }@localFlake:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf genAttrs;
  opts = self.lib.options;
  cfg = config.provision.fs.boot;
in
{
  imports = [ (import ./initrd.nix localFlake) ];

  options.provision.fs.boot = {
    enable = opts.enable "enable boot configuration, adds boot to supportedFilesystems";
    device = opts.stringNull "set `/boot` to point to a vfat filesystem at device path";
    configurationLimit = opts.intNull "optionally set configuration limit";
    grub = {
      enable = opts.enable' (cfg.grub.devices != [ ]) "enable grub as bootloader";
      devices = opts.stringList [ ] "device to set for bootloader";
      luks = opts.enable' config.provision.fs.luks.enable "sets `enableCryptodisk`";
    };
    systemd = {
      enable = opts.enable' (
        !cfg.grub.enable
      ) "enable systemd-boot as bootloader (boot.loader.systemd-boot)";
      initrd.enable = opts.enable "enable systemd as initrd (boot.initrd.systemd)";
      initrd.emergencyAccess = opts.enable "enable emergency access in initrd, useful for debugging";
      network = {
        all = opts.enable ''
          import all links, netdevs and networks from the `systemd.network` into `boot.initrd.systemd.network`
        '';
        networks = opts.stringList [ ] "networks to import from `systemd.network.networks`";
        netdevs = opts.stringList [ ] "netdevs to import from `systemd.network.netdevs`";
        links = opts.stringList [ ] "links to import from `systemd.network.links`";
      };
    };
  };

  config = mkIf cfg.enable {
    fileSystems = mkIf (cfg.device != null) {
      "/boot" = {
        inherit (cfg) device;
        fsType = "vfat";
      };
    };

    boot.loader.grub = mkIf cfg.grub.enable {
      enable = true;
      devices = cfg.grub.devices;
      enableCryptodisk = cfg.grub.luks;
      configurationLimit = mkIf (cfg.configurationLimit != null) cfg.configurationLimit;
    };

    boot.loader.systemd-boot = mkIf cfg.systemd.enable {
      enable = true;
      configurationLimit = mkIf (cfg.configurationLimit != null) cfg.configurationLimit;
    };
    boot.loader.efi = mkIf cfg.systemd.enable {
      canTouchEfiVariables = true;
    };
    boot.initrd.systemd = mkIf cfg.systemd.initrd.enable {
      enable = true;
      inherit (cfg.systemd.initrd) emergencyAccess;
      network = lib.mkMerge [
        (mkIf cfg.systemd.network.importAll {
          inherit (config.systemd.network) networks netdevs links;
        })
        {
          links = genAttrs cfg.addLinks (link: config.systemd.network.links.${link});
          netdevs = genAttrs cfg.addNetdevs (netdev: config.systemd.network.netdevs.${netdev});
          networks = genAttrs cfg.addNetworks (network: config.systemd.network.networks.${network});
        }
      ];
    };
  };
}
