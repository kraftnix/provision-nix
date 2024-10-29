{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.provision.fs.btrfs.legacy.initrd {
  boot.initrd = {
    luks.devices."enc-root" = {
      #device = "/dev/disk/by-uuid/__TOPLEVEL_CONTAINER_UUID__";
      preLVM = true;
      allowDiscards = true;
    };
    network = {
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
        echo 'cryptsetup-askpass' >> /root/.profile
      '';
    };
  };
  environment.systemPackages = with pkgs; [
    btrfs-progs
    btrfs-heatmap
    btdu
    btrfs-list
  ];
}
