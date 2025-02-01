self:
let
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
        networking.nat.enable = true;
        ## nat example
        networking.nftables.gen.tables.filter = {
          ## nat example
          mapsets.forward-internet = {
            lhsType = "ip saddr";
            counter = true;
            elements = [
              { l = hostIps.host1; }
              { l = hostIps.host3; }
            ];
          };
          forward.rules.internet = {
            iifname = [ "br0" ];
            mapset = "forward-internet";
            verdict = "accept";
          };
          egress-snat.__type.hook = "postrouting";
          egress-snat.rules.egress = {
            iifname = [ "br0" ];
            mapset = "forward-internet";
            verdict = "masquerade";
          };
          ## use DNAT to expose
          # host1:80 at gateway:8888
          # host2:80 at gateway:9999
          # host3:80 at gateway:7777
          mapsets.dnats = {
            lhsType = "port";
            rhsType = "ip addr";
            verdictType = "tcp dport";
            type = "map";
            counter = true;
            elements = [
              {
                l = 8888;
                r = hostIps.host1;
                v = 80;
              }
              {
                l = 9999;
                r = hostIps.host2;
                v = 80;
              }
              {
                l = 7777;
                r = hostIps.host3;
                v = 80;
              }
            ];
          };
          egress-dnat.__type.hook = "prerouting";
          egress-dnat.rules.redir-to-hosts = {
            iifname = [ "internet" ];
            main = "dnat ip addr . port to tcp dport map @dnats";
          };
        };
        ## bridge filtering example
        networking.nftables.gen.tables.br0 = {
          __type = "bridge";
          mapsets.intra-bridge-http = {
            lhsType = "iifname";
            rhsType = "oifname";
            verdict = "verdict";
            counter = true;
            elements = [
              {
                l = "host1";
                r = "host2";
                v = "accept";
              }
              {
                l = "host3";
                r = "host2";
                v = "accept";
              }
            ];
          };
          forward = {
            __type.hook = "forward";
            __type.policy = "drop"; # default drop traffic between bridge members
            __type.type = "filter";
            # default fields in rules
            defaults.verdict = "accept";
            rules = {
              accept-all-arp = {
                n = 1;
                main = "ether type arp";
                comment = "accept all ARP";
              };
              ct-related-accept = { };
              ct-drop-invalid = { };
              arp-reply = { };
              icmp-default = { };
              limited-http = {
                counter = true;
                mapset = "intra-bridge-http";
                tcpDport = [ 80 ];
                comment = "limited http access inside bridge";
                verdict = "";
              };
            };
          };
        };
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
  test = {
    name = "nftables-nat-and-bridge-filter";
    hostPkgs = pkgs;
    node.specialArgs.pkgs = pkgs;
    inherit nodes;
    testScript = ''

      start_all()

      with subtest("Waiting for multi-user target"):
        gateway.wait_for_unit("nftables")
        gateway.wait_for_unit("sshd")
        gateway.wait_for_unit("systemd-networkd")
        host1.wait_for_unit("systemd-networkd")
        host1.wait_for_unit("sshd")
        host1.wait_for_unit("lighttpd")
        host1.wait_for_unit("nftables")
        host2.wait_for_unit("systemd-networkd")
        host2.wait_for_unit("lighttpd")
        host2.wait_for_unit("nftables")
        host3.wait_for_unit("systemd-networkd")
        host3.wait_for_unit("lighttpd")
        host3.wait_for_unit("nftables")

      with subtest("ping tests"):
        gateway.wait_until_succeeds("${ping} ${hostIps.host1}")
        gateway.wait_until_succeeds("${ping} ${hostIps.host2}")
        gateway.wait_until_succeeds("${ping} ${hostIps.host3}")
        gateway.wait_until_succeeds("${ping} ${hostIps.internet}")
        host1.succeed("${ping} ${hostIps.gateway}")
        host1.succeed("${ping} ${hostIps.host2}")
        host1.succeed("${ping} ${hostIps.host3}")
        host2.succeed("${ping} ${hostIps.gateway}")
        host2.succeed("${ping} ${hostIps.host1}")
        host2.succeed("${ping} ${hostIps.host3}")
        host3.succeed("${ping} ${hostIps.gateway}")
        host3.succeed("${ping} ${hostIps.host2}")
        host3.succeed("${ping} ${hostIps.host3}")

      with subtest("bridge filtering: test limited http access inside bridge"):
        gateway.succeed("${curlA "host1"}")
        gateway.succeed("${curlA "host2"}")
        gateway.succeed("${curlA "host3"}")
        gateway.succeed("${curlA "internet"}")
        host1.succeed("${curlA "host2"}")
        host1.fail("${curlA "host3"}")
        host2.fail("${curlA "host1"}")
        host2.fail("${curlA "host3"}")
        host3.succeed("${curlA "host2"}")
        host3.fail("${curlA "host1"}")

      with subtest("NAT tests"):
        host1.succeed("${curlA "internet"}")
        host2.fail("${curlA "internet"}")
        host3.succeed("${curlA "internet"}")

      with subtest("internet can't access internal br0"):
        internet.succeed("${ping} ${br1}.88")
        internet.fail("${ping} ${hostIps.host1}")
        internet.fail("${ping} ${hostIps.host2}")
        internet.fail("${ping} ${hostIps.host3}")

      with subtest("internet can access services through dnat"):
        internet.wait_until_succeeds("${curl} http://${br1}.88:7777 | grep 'ACCESS host3: OK'")
        internet.succeed("${curl} http://${br1}.88:8888 | grep 'ACCESS host1: OK'")
        internet.succeed("${curl} http://${br1}.88:9999 | grep 'ACCESS host2: OK'")
    '';
  };
in
nixos-lib.runTest test
