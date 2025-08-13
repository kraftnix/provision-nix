{
  config,
  lib,
  opts,
  name,
  host,
  interface,
  ...
}:
let
  inherit (lib)
    attrValues
    filterAttrs
    hasAttr
    head
    mapAttrs
    mkOption
    pipe
    types
    unique
    ;
  mkPeersP2P =
    host: peers:
    pipe peers [
      (filterAttrs (_: p: p.enable))
      # (filterAttrs (_: p: p.endpoint != ""))
    ];
  getGateways =
    host: peers:
    pipe peers [
      (filterAttrs (_: p: p.enable))
      (filterAttrs (_: p: p.gateway.enable))
    ];
  getSelfPeer = host: peers: peers.${host};
  isGateway =
    host: peers:
    pipe peers [
      (getGateways host)
      (gateways: head (attrValues gateways))
      (gateway: gateway.name == host)
    ];
  mkPeersHubAndSpoke =
    host: peers:
    if isGateway host peers then
      peers
    else
      # NOTE: potentially move this to a check inside peer config checking if mode == hub-and-spoke
      mapAttrs (
        _: p:
        p
        // {
          allowedIPs = unique ([ "${p.subnet}.0/${toString p.mask}" ] ++ config.peers.${host}.allowedIPs);
          extraAllowedIPs = unique (p.extraAllowedIPs ++ config.peers.${host}.extraAllowedIPs);
        }
      ) (getGateways host peers);
in
{
  options = {
    enable = opts.enable' (
      (filterAttrs (_: c: c.enable) config.peers) != { } && (hasAttr host config.peers)
    ) "enable wireguard network";
    name = opts.string name "wireguard network name";
    hubId = opts.int 1 "when `hub-and-spoke` is enabled, specifies the id of the gateway in the subnet";
    subnet = opts.string "" "wireguard subnet e.g. 10.97.23";
    listenPort = opts.int 51819 "wireguard listen port";
    firewall = {
      enable = opts.enable' (
        config.peers != { } && (getSelfPeer host config.peers).endpoint != ""
      ) "enable firewall";
      interface = mkOption {
        type = with types; nullOr str;
        default = interface;
        description = "optional interface to limit wireguard port listen to";
      };
      allowedHosts = mkOption {
        default = [ "__all" ];
        type = with types; listOf str;
        description = ''
          Used to set default `allowedHosts` per host.
          List of allowed hosts. If set to ["__all"] then allows all access, set to empty to disable.
        '';
      };
      extraRules = mkOption {
        default = [ ];
        type = with types; listOf str;
        description = ''
          Extra rules to add to `networking.nftables.firewall.objects.wg-<name>`
        '';
      };
    };
    mtu = opts.int 1420 "wireguard interface MTU bytes";
    allowAll = opts.enable' false "allow all IPs / forward all traffic (adds 0.0.0.0/0 to {extraAllowedIPs})";
    persistentKeepAlive = opts.int 0 "persistent keep alive";
    privateKeyFile = opts.string "" "private key file location, must be set";
    mask = opts.int 24 "subnet mask";
    destination = opts.string "${config.subnet}.0/${toString config.mask}" "destination for ip route creation";
    mode = mkOption {
      type = types.enum [
        "hub-and-spoke"
        "p2p"
      ];
      description = "Wireguard network name";
      default = "hub-and-spoke";
    };
    peers = mkOption {
      default = { };
      type = types.attrsOf (
        types.submoduleWith {
          specialArgs = {
            networkName = config.name;
            inherit lib opts;
            inherit (config)
              allowAll
              destination
              listenPort
              mask
              mtu
              persistentKeepAlive
              privateKeyFile
              subnet
              hubId
              mode
              firewall
              ;
          };
          modules = [ ./peer.nix ];
        }
      );
      description = "wireguard network module, contains peers";
    };
    __renderedPeers = mkOption {
      default = { };
      description = "wireguard network module, contains peers";
    };
    __allRendered = mkOption {
      default = { };
      description = "wireguard network module, contains peers";
    };
  };
  config = {
    __renderedPeers =
      if config.mode == "hub-and-spoke" then
        mkPeersHubAndSpoke host config.peers
      else if config.mode == "p2p" then
        mkPeersP2P host config.peers
      else
        throw "unimplemented wireguard mode set: ${config.mode}";
    __allRendered = mapAttrs (
      host: _:
      if config.mode == "hub-and-spoke" then
        mkPeersHubAndSpoke host config.peers
      else if config.mode == "p2p" then
        mkPeersP2P host config.peers
      else
        throw "unimplemented wireguard mode set: ${config.mode}"
    ) config.peers;
  };
}
