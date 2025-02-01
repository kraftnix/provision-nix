self: rec {
  pkgs = import self.inputs.nixpkgs {
    system = "x86_64-linux";
  };

  br0 = "10.0.0";
  br1 = "10.7.7";
  hostIps = {
    gateway = "${br0}.1";
    host1 = "${br0}.10";
    host2 = "${br0}.20";
    host3 = "${br0}.30";
    internet = "${br1}.80";
  };
  modules = [
    self.nixosModules.networking-firewall
    (
      { config, lib, ... }:
      {
        environment.systemPackages = [ pkgs.openssh ];
        systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";
        networking.useNetworkd = true;
        networking.useDHCP = false;
        services.openssh.enable = true;
        networking.nftables.gen.enable = true;
        networking.nftables.gen.overrideNixosNftables = true;
        networking.nftables.gen.profiles = [ "default" ];
        systemd.network = {
          enable = true;
          networks = lib.mkIf (config.networking.hostName != "gateway") {
            "30-eth" = {
              matchConfig.Name = "eth";
              address = [ "${hostIps.${config.networking.hostName}}/24" ];
              routes = [ { Gateway = hostIps.gateway; } ];
            };
          };
        };
        networking.nat.externalInterface = "eth2";
        services.lighttpd = {
          enable = true;
          port = 80;
          document-root = pkgs.runCommand "document-root" { host = config.networking.hostName; } ''
            mkdir -p "$out"
            echo "ACCESS $host: OK" > "$out/index.html"
          '';
        };
      }
    )
  ];

  nodes = {
    gateway =
      { config, lib, ... }:
      {
        imports = modules;
        virtualisation.interfaces = {
          host1.vlan = 10; # with host1
          host2.vlan = 20; # with host2
          host3.vlan = 30; # with host3
          internet.vlan = 88; # with fake "internet" host
        };
        services.openssh.openFirewall = true;
        systemd.network = {
          enable = true;
          netdevs = {
            "40-br0" = {
              netdevConfig = {
                Kind = "bridge";
                Name = "br0";
              };
            };
          };
          networks = {
            "30-host1" = {
              matchConfig.Name = "host1";
              networkConfig.Bridge = "br0";
            };
            "30-host2" = {
              matchConfig.Name = "host2";
              networkConfig.Bridge = "br0";
            };
            "30-host3" = {
              matchConfig.Name = "host3";
              networkConfig.Bridge = "br0";
            };
            "30-internet" = {
              matchConfig.Name = "internet";
              address = [ "${br1}.88/24" ];
            };
            "40-br0" = {
              matchConfig.Name = "br0";
              address = [ "${hostIps.${config.networking.hostName}}/24" ];
            };
          };
        };
      };
    host1 =
      { ... }:
      {
        imports = modules;
        virtualisation.interfaces.eth.vlan = 10;
        services.openssh.openFirewall = false;
        networking.nftables.gen.tables.filter = {
          input.rules.allow-http = {
            counter = true;
            log = true;
            iifname = [ "eth" ];
            tcpDport = [ 80 ];
            verdict = "accept";
            comment = "allow http access to httpd";
          };
        };
      };
    host2 =
      { ... }:
      {
        virtualisation.interfaces.eth.vlan = 20;
        imports = modules;
        services.openssh.openFirewall = false;
        networking.firewall.allowedTCPPorts = [
          22
          80
        ];
      };
    host3 =
      { ... }:
      {
        virtualisation.interfaces.eth.vlan = 30;
        imports = modules;
        services.openssh.openFirewall = false;
        networking.firewall.allowedTCPPorts = [
          22
          80
        ];
      };
    internet =
      { lib, ... }:
      {
        virtualisation.interfaces.eth.vlan = 88;
        imports = modules;
        networking.firewall.allowedTCPPorts = [
          22
          80
        ];
        systemd.network.networks."30-eth" = {
          # we set default gateway to the firewall
          # to test NAT failures more easily
          routes = lib.mkForce [ { Gateway = "10.7.7.88"; } ];
        };
      };
  };

  nixos-lib = import (self.inputs.nixpkgs + "/nixos/lib") { };
  ping = "ping -c 1 -w 3";
  curl = "curl --fail --connect-timeout 2";
  curlA = host: "${curl} http://${hostIps.${host}}/ | grep 'ACCESS ${host}: OK'";
}
