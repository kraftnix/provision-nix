{
  config,
  lib,
  utils,
  ...
}: let
  bridgeName = "libvirt-default";
  externalInterface = "enp1s0";
  subnet = "192.168.15";
in
  lib.mkIf config.provision.virt.libvirt.legacy.legacy-networking {
    networking.firewall.interfaces.${bridgeName} = {
      # open firewall for usbip to `libvirt-default`
      allowedTCPPorts = [3240];
      # allow DNS/DHCP
      allowedUDPPorts = [53 67];
    };
    networking.nat = {
      enable = true;
      internalInterfaces = [bridgeName];
      externalInterface = lib.mkDefault externalInterface;
    };

    # libvirt uses 192.168.122.0
    systemd.network.netdevs."15-${bridgeName}".netdevConfig = {
      Kind = "bridge";
      Name = bridgeName;
    };
    systemd.network.networks."15-${bridgeName}" = {
      matchConfig.Name = bridgeName;
      networkConfig = {
        # MulticastDNS = "yes";
        DHCP = "ipv4";
        DHCPServer = "yes";
        Address = "${subnet}.2/24";
        # Gateway = "${subnet}.1";
        # IPv6SendRA = "yes";
        # LinkLocalAddressing = mkDefault "ipv6";
        #DHCPServer = yesNo dhcp;
        #LLDP = "yes";
        #EmitLLDP = "customer-bridge";
        # IPv6AcceptRA = "no";
      };
      dhcpServerConfig = {
        EmitDNS = true;
        ServerAddress = "${subnet}.1/24";
        PoolOffset = 30;
      };
      # ipv6Prefixes = [ { ipv6PrefixConfig.Prefix = "fd12:3456:789a::/64"; } ];
      dhcpServerStaticLeases = [
        {
          # devVM 1
          Address = "${subnet}.3";
          MACAddress = "52:54:00:70:bc:0b";
        }
        {
          # devVM 2
          Address = "${subnet}.4";
          MACAddress = "52:54:00:07:ce:e0";
        }
      ];
    };

    systemd.services.libvirt-guests.after = [
      "systemd-networkd.service"
      "systemd-networkd-wait-online.service"
      "sys-subsystem-net-devices-${utils.escapeSystemdPath "libvirt-default"}.device"
    ];
  }
