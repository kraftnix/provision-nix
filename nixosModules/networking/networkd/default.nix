{self, ...}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    flatten
    mkDefault
    mkIf
    pipe
    unique
    ;
  opts = self.lib.options;
  cfg = config.provision.networking.networkd;
in {
  options.provision.networking.networkd = {
    enable = opts.enable "enable systemd-networkd";
    waitOnline = opts.enable "enable `systemd-networkd-wait-online`";
    waitInterfaces = opts.stringList [] "interfaces to wait online for with `systemd-networkd-wait-online`";
    ethernetUseDhcp = opts.enableTrue "add a basic unit which matches ethernet devices and enables DHCPv4";
  };

  config = mkIf cfg.enable {
    networking = {
      firewall.enable = mkDefault true;
      networkmanager.enable = lib.mkForce false;
      useNetworkd = true;
      useDHCP = false;
    };
    services = {
      timesyncd.enable = lib.mkOverride 99 true;
      resolved.enable = true;
    };
    systemd = {
      network.enable = true;
      network.wait-online = {
        enable = cfg.waitOnline;
        extraArgs = pipe cfg.waitInterfaces [
          unique
          (map (i: ["-i" i]))
          flatten
        ];
        # extraArgs = flatten (map (i: [ "-i" i ]) cfg.waitInterfaces);
      };
      network.networks = mkIf cfg.ethernetUseDhcp {
        "90-ethernet-default" = {
          matchConfig.Name = "enp*";
          networkConfig.DHCP = "ipv4";
        };
      };
    };
  };
}
