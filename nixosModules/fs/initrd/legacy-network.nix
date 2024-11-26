{
  config,
  lib,
  ...
}:
lib.mkIf config.provision.fs.initrd.legacy.network {
  boot.initrd.network = {
    # This will use udhcp to get an ip address.
    # Make sure you have added the kernel module for your network driver to `boot.initrd.availableKernelModules`
    enable = true;
    ssh = {
      enable = true;
      # access boot ssh via `ssh root@ip -p 6924 -i /path/to/authorizedKey.pub`
      port = lib.mkDefault 6924;
      hostKeys = lib.mkDefault [ "/etc/initrd/ssh_host_ed25519_key" ];
      # NOTE: make sure to add your own authorizedKeys
      # authorizedKeys = [ "<add_your_key_here>" ];
    };
    # NOTE: you will likely need to add commands
    #       see ./btrfs/initrd.nix or ./zfs/initrd.nix for examples
    # postCommands = "";
  };
}
/*
   Notes
  - based on https://nixos.wiki/wiki/Remote_LUKS_Unlocking
  - combine with a filesystemd initrd config like ../btrfs/initrd.nix or ../zfs/initrd.nix
  - additionally you need to add your network driver to boot.initrd.availableKernelModules like
  - snippet
  ```nix
  boot.initrd.availableKernelModules = [ "atlantic" "igb" ];
  ```
  - in this case I have two ethernet kernel modules
  - you can find which kernel modules you need by running `lspci -vv | grep -i net -A 12` on
  your running system, the `Kernel modules: <module_name>` in the output (you might need to
  adjust the number of lines printed with the A parameter if it is cut short
*/
