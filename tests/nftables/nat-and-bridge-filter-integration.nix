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
    name = "nftables-nat-and-bridge-filter-integration";
    hostPkgs = pkgs;
    nodes = shared.nodes // {
      gateway.imports = [
        shared.nodes.gateway
        (
          { lib, ... }:
          {
            nixpkgs.pkgs = pkgs;
            networking.nat.enable = true;
            networking.nat.externalInterface = lib.mkForce "internet";
            networking.nftables.gen.dnat.enable = true;
            networking.nftables.gen.dnat.gen = {
              host1 = {
                from = [ "internet" ];
                port = 8888;
                to = hostIps.host1;
                toPort = 80;
              };
              host2 = {
                from = [ "internet" ];
                port = 9999;
                to = hostIps.host2;
                toPort = 80;
              };
              host3 = {
                from = [ "internet" ];
                port = 7777;
                to = hostIps.host3;
                toPort = 80;
              };
            };
            networking.nftables.gen.snat.enable = true;
            networking.nftables.gen.snat.maps.br0.fromIP = [
              hostIps.host1
              hostIps.host3
            ];
            ## bridge filtering example
            networking.nftables.gen.bridge.enable = true;
            networking.nftables.gen.bridge.interfaceMap = {
              host1.to = "host2";
              host3.to = "host2";
            };
            # limit generated rules above
            networking.nftables.gen.tables.br.forward.rules.generated-allow-ifaces.tcpDport = [ 80 ];
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
        host1.wait_until_succeeds("${curlA "internet"}")
        host2.fail("${curlA "internet"}")
        host3.succeed("${curlA "internet"}")

      with subtest("internet can't access internal br0"):
        internet.succeed("${ping} ${br1}.88")
        internet.fail("${ping} ${hostIps.host1}")
        internet.fail("${ping} ${hostIps.host2}")
        internet.fail("${ping} ${hostIps.host3}")

      with subtest("internet can access services through dnat"):
        internet.succeed("${curl} http://${br1}.88:7777 | grep 'ACCESS host3: OK'")
        internet.succeed("${curl} http://${br1}.88:8888 | grep 'ACCESS host1: OK'")
        internet.succeed("${curl} http://${br1}.88:9999 | grep 'ACCESS host2: OK'")
    '';
  };
in
nixos-lib.runTest test
