{
  config,
  lib,
  ...
}:
let
  wgOptions = import ./wireguardOptions.nix { inherit lib; };

  inherit (lib)
    attrValues
    head
    filterAttrs
    mapAttrs
    mapAttrsToList
    mkOption
    optionalAttrs
    ;
  inherit (lib.types)
    attrsOf
    bool
    enum
    str
    submodule
    submoduleWith
    ;

  genIPv4 = subnet: id: "${subnet}.${toString id}";

  # Generates expanded peer configuration for passed in peer
  hubSpokePeers =
    currPeer:
    if currPeer.id == config.hubId then # hub
      mapAttrs (
        name: peerCfg:
        let
          currIP = genIPv4 config.v4subnet currPeer.id;
          peerIP = genIPv4 config.v4subnet peerCfg.id;
        in
        {
          ip = peerIP;
          inherit (peerCfg) publicKey persistentKeepAlive;
          endpointIP = if (currIP != peerIP) then null else peerCfg.endpointIP;
          allowedIPs = peerCfg.extraAllowedIPs ++ [
            # "${config.v6ula}:${peerCfg.v6}/64"
            # "${config.v6gua}:${peerCfg.v6}/64"
            (if peerCfg.id == config.hubId then "${config.v4subnet}.0/24" else "${peerIP}/32")
          ];
        }
      ) config.peers
    else
      # spokes: each spoke only configure a single wireguard peer (the gateway)
      mapAttrs (name: peerCfg: {
        inherit (peerCfg) publicKey persistentKeepAlive endpointIP;
        ip = genIPv4 config.v4subnet peerCfg.id;
        allowedIPs = peerCfg.extraAllowedIPs ++ [
          "${config.v4subnet}.0/24"
        ];
      }) (filterAttrs (_: p: p.id == config.hubId) config.peers);

  # Generates expanded peer configuration for passed in peer
  p2pPeers =
    currPeer:
    if currPeer.id == config.hubId then # hub
      (mapAttrs (name: peerCfg: {
        inherit (peerCfg) publicKey persistentKeepAlive;
        endpointIP = null;
        ip = genIPv4 config.v4subnet peerCfg.id;
        # allowedIPs = peerCfg.extraAllowedIPs ++ [ "${genIPv4 config.v4subnet peerCfg.id}/32" ];
        # allowedIPs = peerCfg.extraAllowedIPs ++ [ "${config.v4subnet}.0/24" ];
        allowedIPs = peerCfg.extraAllowedIPs ++ [
          (
            if peerCfg.id == config.hubId then
              "${config.v4subnet}.0/24"
            else
              "${genIPv4 config.v4subnet peerCfg.id}/32"
          )
        ];
      }) config.peers)
    else
      (mapAttrs (name: peerCfg: {
        inherit (peerCfg) publicKey persistentKeepAlive;
        endpointIP = if peerCfg.id == config.hubId then peerCfg.endpointIP else null;
        ip = genIPv4 config.v4subnet peerCfg.id;
        allowedIPs = peerCfg.extraAllowedIPs ++ [ "${genIPv4 config.v4subnet peerCfg.id}/32" ];
      }) config.peers);

  # Renders the wireguard configuration based on `mode`
  renderedPeers = mapAttrs (
    _: peerCfg:
    let
      ip = genIPv4 config.v4subnet peerCfg.id;
      gateway = "${config.v4subnet}.1";
      p2pEnabled = config.mode == "p2p";
      noGateway = p2pEnabled || (ip == gateway);
    in
    {
      inherit (config) name;
      inherit (peerCfg)
        privateKeyFile
        publicKey
        network
        listenPort
        ;
      # listenPort = config.port;
      # network = {
      #   gateway = if noGateway then null else gateway;
      #   dns = gateway;
      #   addresses = if noGateway then [ "${ip}/24" ] else [ "${ip}/32" ];
      # };
      peers = if config.mode == "p2p" then p2pPeers peerCfg else hubSpokePeers peerCfg;
    }
  ) config.peers;

  gatewayPeers = filterAttrs (_: p: p.gateway) config.peers;
  gateway = if gatewayPeers == { } then null else (head (attrValues gatewayPeers)).ipv4;

  systemdNetwork =
    peer:
    import ./networkd-config.nix { inherit lib; } (
      peer
      // {
        peers = mapAttrsToList (
          name: cfg:
          {
            PublicKey = cfg.publicKey;
            AllowedIPs = cfg.allowedIPs;
          }
          // (optionalAttrs (cfg.endpointIP != null) {
            Endpoint = "${cfg.endpointIP}:${toString cfg.listenPort}";
          })
          // (optionalAttrs (cfg.persistentKeepAlive != null) {
            PersistentKeepalive = cfg.persistentKeepAlive;
          })
        ) config.peers;
      }
    );
in
{
  options = {
    enable = mkOption {
      type = bool;
      description = "Enable toggle for wireguard network, enabled by default if the network is defined.";
      default = true;
    };
    name = wgOptions.name config._module.args.name;
    mode = mkOption {
      type = enum [
        "hub-and-spoke"
        "p2p"
      ];
      description = "Wireguard network name";
      default = "hub-and-spoke";
    };

    hubId = wgOptions.id 1 // {
      description = "Peer id of the hub when `hub-and-spoke` is enabled.";
    };

    port = wgOptions.listenPort 28600;
    mtu = wgOptions.mtu 1420;

    v4subnet = wgOptions.subnet "";
    v6ula = wgOptions.ula "";
    v4gua = wgOptions.gua "";

    privateKeyFile = wgOptions.privateKeyFile "";
    persistentKeepAlive = wgOptions.persistentKeepAlive null;
    gateway = wgOptions.gateway "${config.v4subnet}.${toString config.hubId}";

    # peers = mkOption {
    #   default = {};
    #   description = "Peers (members) of the wireguard network.";
    #   type = attrsOf (submodule (args: {
    #
    #     options = {
    #       name = mkOption {
    #         default = args.config._module.args.name;
    #         description = "Peer name.";
    #         type = str;
    #       };
    #       id = wgOptions.id 1;
    #       extraAllowedIPs = wgOptions.allowedIPs [];
    #       endpointIP = wgOptions.endpointIP "";
    #       gateway = lib.mkEnableOption "use this peer as gateway for the network, required in `hub-and-spoke`" // {
    #         default = args.config.id == config.hubId;
    #       };
    #       publicKey = wgOptions.publicKey "";
    #       privateKeyFile = wgOptions.privateKeyFile config.privateKeyFile;
    #       persistentKeepAlive = wgOptions.persistentKeepAlive config.persistentKeepAlive;
    #     };
    #   }));
    # };

    peers = mkOption {
      type = attrsOf (submoduleWith {
        modules = [
          ./peer.nix
          {
            config._module.args = {
              inherit (config)
                mtu
                gateway
                hubId
                privateKeyFile
                v4subnet
                ;
              listenPort = config.port;
            };
          }
        ];
      });
      description = "Set of hosts with expanded configuration for wireguard network.";
      default = { };
    };

    __rendered = mkOption {
      default = { };
      description = "rendered peers with systemd network options";
    };
  };

  config = {
    __rendered = mapAttrs (
      _: p:
      p
      // {
        __systemdNetwork = systemdNetwork p;
      }
    ) renderedPeers;
  };
}
