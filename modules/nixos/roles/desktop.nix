{ self, ... }:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkDefault;
  opts = self.lib.options;
  cfg = config.provision.roles;
in
{
  options.provision.roles.desktop = {
    enable = opts.enable ''
      Enable desktop node default configuration.

      Sets up:
        - base shell + env
        - systemd-networkd networking
        - boot integrated, systemd-boot by default but can be changed
        - initrd + SSH encrypted root unlock
    '';
    nixTrustedUsers = opts.stringList [ ] "trusted nix users (needed for deploy user at least)";
    initrdUnlockUsers = opts.stringList [ ] "list of users to import SSH keyFiles from";
  };

  config = mkIf cfg.desktop.enable {
    provision = {
      defaults.enable = true;
      fs = {
        boot.enable = true;
        initrd.enable = false;
        initrd.ssh.usersImportKeyFiles = cfg.desktop.initrdUnlockUsers;
      };
      core = {
        shell.enable = true;
        env.enable = true;
      };
      nix = {
        basic = true;
        develop = true;
        builder = true;
        optimise.enable = true;
        trustWheel = mkDefault true;
        trustedUsers = cfg.desktop.nixTrustedUsers;
      };
      networking.ssh = {
        enable = true;
        hardened = true;
      };
    };
  };
}
