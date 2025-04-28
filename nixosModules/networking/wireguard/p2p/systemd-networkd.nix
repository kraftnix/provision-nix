{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    filterAttrs
    hasAttr
    mapAttrs
    mapAttrsToList
    mkIf
    mkMerge
    pipe
    ;
  cfg = config.provision.networking.wireguard.p2p;

  enabledNetworks = pipe cfg.networks [
    (filterAttrs (_: c: c.enable))
    (mapAttrs (
      _: c:
      c
      // {
        peers = filterAttrs (_: p: p.enable) c.peers;
      }
    ))
  ];
in
{
  config = mkIf cfg.enable {
    provision.networking.wireguard.p2p.currHost.networks = mkMerge [
      (pipe enabledNetworks [
        (mapAttrs (
          _: network: rec {
            info = {
              host = network.peers.${cfg.currHost.name};
              peers = network.__renderedPeers;
            };
            wgQuick = {
              inherit (info.host) listenPort mtu privateKeyFile;
              address = "${info.host.ip}/${toString info.host.mask}";
              peers = mapAttrs (_: p: {
                publicKey = p.pubkey;
                inherit (p) endpoint allowedIPs persistentKeepAlive;
              }) info.peers;
            };
            wgQuickFile = ''
              [Interface]
              Address = ${wgQuick.address}
              PrivateKeyFile = ${wgQuick.privateKeyFile}
              MTU = ${toString wgQuick.mtu}

              ${builtins.concatStringsSep "\n" (
                mapAttrsToList (_: p: ''
                  [Peer]
                  PublicKey = ${p.pubkey}
                  AllowedIPs = ${builtins.concatStringsSep ", " p.allowedIPs}
                  ${lib.optionalString (p.endpoint != "") "Endpoint = ${p.endpoint}"}
                  PersistentKeepAlive = ${toString p.persistentKeepAlive}
                '') info.peers
              )}
            '';
          }
        ))
      ])
      (pipe enabledNetworks [
        (filterAttrs (_: n: hasAttr cfg.currHost.name n.peers))
        (mapAttrs (
          _: w: {
            netdev = config.systemd.network.netdevs."40-${w.name}";
            network = config.systemd.network.networks."40-${w.name}";
            netdevUnit = config.systemd.network.units."40-${w.name}.netdev".text;
            networkUnit = config.systemd.network.units."40-${w.name}.network".text;
          }
        ))
      ])
    ];

    systemd.network = {
      netdevs = pipe enabledNetworks [
        (filterAttrs (_: n: hasAttr cfg.currHost.name n.peers))
        (mapAttrsToList (
          _: w:
          let
            h = w.peers.${cfg.currHost.name};
          in
          {
            "40-${w.name}" = {
              netdevConfig = {
                Name = w.name;
                Kind = "wireguard";
                MTUBytes = toString h.mtu;
                Description = "Wireguard P2P Configuration. (${w.name})";
              };
              wireguardConfig = {
                ListenPort = h.listenPort;
                PrivateKeyFile = mkIf (h.privateKeyFile != "") h.privateKeyFile;
              };
              wireguardPeers = mapAttrsToList (_: p: {
                PublicKey = p.pubkey;
                AllowedIPs = p.allowedIPs;
                Endpoint = mkIf (p.endpoint != "") p.endpoint;
                PersistentKeepalive = mkIf (p.persistentKeepAlive > 1) p.persistentKeepAlive;
              }) w.__renderedPeers;
            };
          }
        ))
        mkMerge
      ];

      networks = pipe enabledNetworks [
        (filterAttrs (_: n: hasAttr cfg.currHost.name n.peers))
        (mapAttrsToList (
          _: w:
          let
            h = w.peers.${cfg.currHost.name};
          in
          {
            "40-${w.name}" = {
              matchConfig.Name = w.name;
              networkConfig = {
                IPv6AcceptRA = "no";
                DHCP = "no";
                Address = [ "${h.ip}/${toString h.mask}" ];
              };
              inherit (h) routes;
              # routes = let filtered = (filterAttrs (_: p: p.gateway.enable) w.peers); in
              #   if filtered != {}
              #   # WARN: might need to catch case where current host == gateway
              #   then (
              #     if (head (attrValues filtered)).name == cfg.currHost.name
              #       then []
              #       else [{
              #         Destination = (head (attrValues filtered)).gateway.destination;
              #         Gateway = (head (attrValues filtered)).ip;
              #         GatewayOnLink = true;
              #       }]
              #   )
              #   else [{
              #     Destination = "${w.subnet}.0/${toString w.mask}";
              #   }];
            };
          }
        ))
        mkMerge
      ];
    };
  };
}
