{
  config,
  lib,
  opts,
  name,
  networkName,
  allowAll,
  destination,
  listenPort,
  mask,
  mtu,
  persistentKeepAlive,
  privateKeyFile,
  subnet,
  mode,
  hubId,
  firewall,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkOption
    optionalString
    types
    ;
in
{
  options = {
    enable = opts.enable' (config.ip != "") "enable host";
    name = opts.string name "host name";
    network = opts.string networkName "wireguard network name";
    listenPort = opts.int listenPort "wireguard listen port";
    mtu = opts.int mtu "wireguard interface MTU bytes";
    mask = opts.int mask "subnet mask";
    allowAll = opts.enable' allowAll "allow all IPs / forward all traffic";
    pubkey = opts.string "" "wireguard public key";
    subnet = opts.string subnet "wireguard subnet";
    routes = mkOption {
      type = types.listOf types.raw;
      default = [ ];
      description = "list of systemd network routes";
    };
    gateway = {
      enable = opts.enable "use this host as single gateway for network";
      destination = opts.string destination "destination for ip route creation";
    };
    subip = mkOption {
      default = null;
      type = with types; nullOr int;
      description = "wireguard sub ip, combined with subnet, 300 if unused";
    };
    ip = opts.string (optionalString (
      config.subip != null
    ) "${config.subnet}.${toString config.subip}") "wireguard ip address";
    endpointIP = opts.string "" "optional endpoint ip address";
    endpoint = opts.string (optionalString (
      config.endpointIP != ""
    ) "${config.endpointIP}:${toString config.listenPort}") "optional endpoint + listen port combo";
    persistentKeepAlive = opts.int persistentKeepAlive "persistent keep alive";
    allowedIPs = opts.stringList ([ "${config.ip}/32" ] ++ config.extraAllowedIPs) "allowed IPs list";
    extraAllowedIPs = mkOption {
      default = [ ];
      type = with types; listOf str;
      description = ''
        extra allowed IPs
      '';
    };
    # allowedIPs = opts.stringList (
    #   if config.allowAll
    #     then ["0.0.0.0/0"]
    #   else if config.gateway.enable
    #     then ["${config.subnet}.0/${toString config.mask}"]
    #     else ["${config.ip}/32"]
    # ) "allowed IPs list";
    privateKeyFile = opts.string privateKeyFile "private key file location, not set if empty";
    firewall = {
      allowedHosts = mkOption {
        default = firewall.allowedHosts;
        type = with types; listOf str;
        description = ''
          List of allowed hosts. If set to ["__all"] then allows all access.
        '';
      };
    };
  };
  config.gateway.enable = mkDefault (mode == "hub-and-spoke" && hubId == config.subip);
}
