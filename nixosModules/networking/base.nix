{ self, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  opts = self.lib.options;
  cfg = config.provision.networking;
in
{
  options.provision.networking = {
    wifi = {
      enable = opts.enable "enable wifi";
      interface = opts.string "wlan0" "wireless interface name";
    };
    vpn = {
      mullvad-app = opts.enable "enable mullvad-vpn app";
      protonvpn = opts.enable "enable protonvpn (add cli)";
    };
    firewall = {
      iptables = {
        enable = opts.enable "enable iptables";
      };
    };
    # services = mkOption {
    #   default = {};
    #   type = with types; attrsOf int;
    #   description = "maps to `networking.services";
    # };
  };

  config = lib.mkMerge [
    # {networking = {inherit (cfg) services;};}
    (mkIf cfg.wifi.enable {
      networking = {
        wireless.iwd.enable = true;
        interfaces.${cfg.wifi.interface}.useDHCP = true;
      };
    })
    (mkIf cfg.vpn.protonvpn {
      environment.systemPackages = with pkgs; [
        protonvpn-cli
        wireguard-tools
      ];
    })
    (mkIf cfg.vpn.mullvad-app {
      services.mullvad-vpn.enable = true;
      environment.systemPackages = with pkgs; [
        mullvad-vpn
        wireguard-tools
      ];
      /*
        networking.nftables = {
          enable = false;
          ruleset = ''
            table inet customDnsServers {
                chain permitDnsTraffic {
                  type filter hook output priority -30; policy accept;
                   udp dport 53 ip daddr 192.168.1.1 ct mark set 0x00000f41;
                   tcp dport 53 ip daddr 192.168.1.1 ct mark set 0x00000f41;
                }
            }
          '';
        };
      */
    })
    (mkIf cfg.firewall.iptables.enable {
      networking.firewall = {
        enable = lib.mkOverride 1 true;
        # enable all logging
        logRefusedConnections = true;
        logRefusedPackets = true;
        logReversePathDrops = true;
      };
    })
  ];
}
