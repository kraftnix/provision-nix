self: {
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (self.lib.provision.networking) stripMask ipToMac;
  dockerSubnet = "10.97.97";
  dockerCidr = "${dockerSubnet}.0/24";
  dockerGateway = "${dockerSubnet}.1/24";
  dockerHostIP = "${dockerSubnet}.2/24";
  netns = "docker";
  hostVeth = "veth-${netns}-ns";
  dockerNsVeth = "veth-${netns}-br";
  dockerBridge = "docker-br";
in
  lib.mkIf config.provision.virt.containers.legacy.netns {
    virtualisation.docker.daemon.settings = {
      bip = dockerHostIP;
      default-gateway = stripMask dockerGateway;
      fixed-cidr = "${dockerSubnet}.0/25";
    };
    systemd.services.docker = {
      bindsTo = ["netns@docker.service"];
      after = ["netns@docker.service"];
      serviceConfig.NetworkNamespacePath = "/var/run/netns/${netns}";
    };
    /*
       NOTE: you must add your own firewall rules
    networking.nftables.firewall = {
      zones.docker-in.interfaces = [ dockerBridge ];
      zones.docker-out.interfaces = [ dockerBridge config.networking.nat.externalInterface ];
      from.docker-in.to.docker-out.masquerade = true;
      from.docker-in.to.docker-out.policy = "accept";
    };
    */
    systemd.services."netns@docker" = {
      path = with pkgs; [iproute2 nftables];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = pkgs.writeShellScript "start-docker-netns" ''
          # add namespace
          ip netns add ${netns}

          # add bridge
          ip link add ${dockerBridge} type bridge

          # add veth pair connecting dockern namespace to the bridge
          ip link add ${hostVeth} type veth peer name ${dockerNsVeth}
          ip link set ${hostVeth} netns ${netns}
          ip link set ${dockerNsVeth} master ${dockerBridge}

          # set interfaces up
          ip -n ${netns} link set ${hostVeth} up
          ip link set ${dockerNsVeth} up

          # set bridge up
          ip link set ${dockerBridge} up

          ip -n ${netns} addr add ${dockerHostIP} dev ${hostVeth}
          ip addr add ${dockerGateway} dev ${dockerBridge}
          ip -n ${netns} route add default via ${stripMask dockerGateway} dev ${hostVeth}
        '';
        ExecStop = pkgs.writeShellScript "stop-docker-netns" ''
          ip link set ${dockerBridge} down
          ip -n ${netns} link set ${hostVeth} down
          ip link del ${hostVeth}
          ip link del ${dockerBridge}
          ip netns del ${netns}
        '';
      };
    };
  }
