{lib, ...}: {network, ...} @ config: let
  inherit (lib) optionals;
in {
  netdev = {
    netdevConfig = {
      Kind = "wireguard";
      MTUBytes = lib.trace network (builtins.toString network.mtu);
      Name = config.name;
    };
    wireguardConfig = {
      PrivateKeyFile = config.privateKeyFile;
      ListenPort = config.listenPort;
    };
    wireguardPeers = config.peers;
    # wireguardPeers = [
    #   { PublicKey = wireguard.publicKey;
    #     AllowedIPs = wireguard.allowedIPs;
    #     Endpoint = wireguard.endpoint;
    #   };
    # ];
  };

  network = {
    matchConfig.Name = config.name;
    address = network.addresses;
    # maybe this isnt needed
    # gateway = [ (stripMask network.gateway) ];
    # dns = [ (stripMask network.gateway) ] ++ (optional network.allowDNS upstreamDNS);
    dns = [network.dns];
    networkConfig = {
      # IPForward = "yes";
      DHCP = "no";
    };
    # NOTE: Might need inside container
    routes = optionals (network.gateway != null) [
      {
        Gateway = network.gateway;
        Destination = [network.route];
        GatewayOnLink = "yes";
      }
    ];
  };
}
