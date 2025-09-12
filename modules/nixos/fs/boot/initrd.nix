{ self, ... }:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkDefault flatten;
  opts = self.lib.options;
  cfg = config.provision.fs.boot.initrd;
  userKeyFiles = flatten (
    map (user: config.users.users.${user}.openssh.authorizedKeys.keyFiles) cfg.ssh.usersImportKeyFiles
  );
in
{

  options.provision.fs.boot.initrd = {
    enable = opts.enable "enable initrd configuration, adds initrd to supportedFilesystems";
    ssh = {
      enable = opts.enableTrue "enable SSH based auth";
      port = opts.int 9797 "SSH port sshd listens at during stage-1 boot";
      hostKeys = opts.stringList [ "/etc/initrd/ssh_host_ed25519_key" ] ''
        Caution: Host SSH private key used for sshd during stage-1 boot only.

        This key exists _unencrypted on the system's boot drive_. **Only use this key for this purpose!**
      '';
      authorizedKeyFiles = opts.stringList [ ] ''
        Authorized keys to access host during stage-1 boot.

        These pubkey files exist _unencrypted on the system's boot drive_.
      '';
      usersImportKeyFiles = opts.stringList [ ] ''
        Users to import keyfiles from to allow unlocking encrypted disk.

        Imports keys from `config.users.users.openssh.authorizedKeys.keyFiles`.

        NOTE: does not import from `keys` option.
      '';
    };
    postCommands = {
      enable = opts.enable' (!config.boot.initrd.systemd.enable) ''
        script used to decrypt system. this is not compatible with using systemd as an initrd.

        is enabled by default if systemd's initrd is not enabled
      '';
      command = opts.string "echo 'cryptsetup-askpass' >> /root/.profile" ''
        Command used to unlock root filesystem (and any others you may also want to unlock).

        This can be used with either grub or systemd-boot (but not with systemd-boot as an initrd).
      '';
    };
    network.vlan = opts.enable "add `8021q` driver to {network.modules}";
    network.bridge = opts.enable "add `bridge` driver to {network.modules}";
    network.modules =
      opts.stringList [ ] ''
        extra network modules to add to `boot.initrd.availableKernelModules`

        for network unlock you will likely need to add the kernel modules for
        your network cards you want to use in stage-1

        you can find out the kernel driver in use with `ethtool`:
        ```sh
        INTERFACE=enp1s0
        ethtool -i $INTERFACE | grep driver
        ```
      ''
      // {
        example = [
          "e1000e"
          "i40e"
          "igc"
          "8021q"
          "bridge"
          "r8169"
        ];
      };
  };

  config = mkIf cfg.enable {
    provision.fs.boot.initrd.network.modules =
      (lib.optional cfg.network.vlan "8021q") ++ (lib.optional cfg.network.bridge "bridge");
    boot.initrd.availableKernelModules = cfg.network.modules;
    boot.initrd.network = {
      enable = true;
      ssh = mkIf cfg.ssh.enable {
        enable = true;
        inherit (cfg.ssh) hostKeys;
        port = mkDefault cfg.ssh.port;
        authorizedKeyFiles = lib.unique (cfg.ssh.authorizedKeyFiles ++ userKeyFiles);
      };
      postCommands = lib.mkIf cfg.postCommands.enable cfg.postCommands.command;
    };
  };
}
