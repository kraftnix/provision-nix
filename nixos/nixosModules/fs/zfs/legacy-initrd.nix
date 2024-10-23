{
  config,
  lib,
  ...
}:
lib.mkIf config.provision.fs.zfs.legacy.initrd {
  boot.initrd.network = {
    # This will use udhcp to get an ip address.
    # Make sure you have added the kernel module for your network driver to `boot.initrd.availableKernelModules`
    enable = true;
    ssh = {
      enable = true;
      # access boot ssh via `ssh root@ip -p 6924 -i /path/to/authorizedKey.pub`
      port = lib.mkDefault 6924;
      hostKeys = lib.mkDefault ["/etc/initrd/ssh_host_ed25519_key"];
      # NOTE: make sure to add your own authorizedKeys
      # authorizedKeys = [ "<add_your_key_here>" ];
    };
    postCommands = ''
      echo "zfs load-key -a; killall zfs" >> /root/.profile
    '';
  };
}
