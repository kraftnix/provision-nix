self:
let
  shared = import ./nat-shared.nix self;
  inherit (shared)
    pkgs
    br0
    br1
    hostIps
    nixos-lib
    ping
    curl
    curlA
    ;

  test = {
    name = "nftables-nat-and-bridge-filter";
    hostPkgs = pkgs;
    node.specialArgs.pkgs = pkgs;
    nodes = shared.nodes // {
      gateway.imports = [
        shared.nodes.gateway
        (
          { ... }:
          {
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
              ingress-dnat.__type.hook = "prerouting";
              ingress-dnat.rules.redir-to-hosts = {
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
          }
        )
      ];
    };
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
