{
  config,
  lib,
  ...
}:
let
  wgOptions = import ./wireguardOptions.nix { inherit lib; };

  inherit (config._module.args)
    listenPort
    privateKeyFile
    hubId
    gateway
    mtu
    v4subnet
    ;

  inherit (lib)
    elemAt
    mapAttrsToList
    mkOption
    optionalAttrs
    splitString
    ;

  inherit (lib.types)
    attrsOf
    bool
    int
    listOf
    nullOr
    raw
    str
    submodule
    ;

  genIPv4 = subnet: id: "${subnet}.${toString id}";
in
{
  options = {
    enable = mkOption {
      type = bool;
      description = "Enable toggle for wireguard network, enabled by default if the network is defined.";
      default = true;
    };

    name = wgOptions.name config._module.args.name;
    id = wgOptions.id 1;
    persistentKeepAlive = wgOptions.persistentKeepAlive null;
    listenPort = wgOptions.listenPort listenPort;
    publicKey = wgOptions.publicKey "";
    privateKeyFile = wgOptions.privateKeyFile privateKeyFile;
    allowedIPs = wgOptions.allowedIPs [ ];
    endpointIP = wgOptions.endpointIP null;
    ipv4 = mkOption {
      description = "Wireguard interal IPv4 Address (for information purposes only).";
      default = genIPv4 config.network.v4subnet config.id;
      type = str;
    };
    ipv6 = mkOption {
      type = str;
      description = "Wireguard interal IPv6 Address (for information purposes only).";
      default = "";
    };

    network = {
      gateway = mkOption {
        type = nullOr str;
        description = "Internal Gateway for wireguard network.";
        default = gateway;
      };
      dns = mkOption {
        type = str;
        description = "Internal DNS for wireguard network.";
        default = if config.network.gateway != null then "" else config.network.gateway;
      };
      mtu = wgOptions.mtu mtu;
      v4subnet = wgOptions.subnet v4subnet;
      route = mkOption {
        type = str;
        description = "Wireguard network route, for routeConfig.";
        default = "";
        # default =
        #   let
        #     split = splitString [ "." ] config.gateway;
        #   in
        #   if config.gateway == null
        #   then ""
        #   else "${elemAt split 0}.${elemAt split 1}.${elemAt split 2}.0/${toString config.mask}";
      };
      mask = mkOption {
        default = 24;
        type = int;
        description = "Wireguard subnet netmask";
      };
      addresses = mkOption {
        type = listOf str;
        description = "Peer name";
        default = [ config.ipv4 ];
      };
    };

    __systemdNetwork = mkOption {
      default = { };
      description = "systemd units to configure wireguard";
      type = raw;
    };
  };
}
