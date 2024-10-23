{self, ...}: {
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkDefault;
  opts = self.lib.options;
  cfg = config.provision.roles;
in {
  options.provision.roles.edge = {
    enable = opts.enable ''
      Enable edge node default configuration.

      Sets up:
        - base shell + env
        - garbage collected + optimised nix
        - systemd-networkd networking
        - boot integrated, systemd-boot by default but can be changed
        - initrd + SSH encrypted root unlock
    '';
    bigMachine = opts.enable ''
      When enabled, increases some base system limits.
    '';
    initrdUnlockUsers = opts.stringList [] "users to add SSH keys into initrd ssh network root disk unlock";
    initrdNetModules = opts.stringList [] "extra network modules to add to `boot.initrd.availableKernelModules`";
    nixTrustedUsers = opts.stringList [] "trusted nix users (needed for deploy user at least)";
  };

  config = mkIf cfg.edge.enable {
    provision = {
      defaults.enable = true;
      defaults.sysctl.inotifyLimitsMultiple = mkIf cfg.edge.bigMachine 10000;
      fs = {
        boot.enable = true;
        initrd.enable = true;
        initrd.ssh.usersImportKeyFiles = cfg.edge.initrdUnlockUsers;
        initrd.netModules = cfg.edge.initrdNetModules;
      };
      core = {
        shell.enable = true;
        env.enable = true;
      };
      nix = {
        basic = true;
        optimise.enable = true;
        optimise.gc = true;
        trustedUsers = cfg.edge.nixTrustedUsers;
      };
      networking = {
        networkd.enable = true;
        ssh.enable = true;
      };
    };
  };
}
