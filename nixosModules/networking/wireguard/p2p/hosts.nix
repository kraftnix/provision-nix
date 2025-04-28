self:
{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    filterAttrs
    flatten
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    pipe
    types
    ;
  cfg = config.provision.networking.wireguard.p2p;
  opts = self.lib.options;
in
{
  options.provision.networking.wireguard.p2p.hosts = mkOption {
    default = { };
    description = "wireguard networks to configure";
    type = types.attrsOf (
      types.submodule (
        {
          config,
          name,
          ...
        }:
        {
          options = {
            enable = opts.enable' (config.subip != 300) "enable host";
            name = opts.string name "host name";
            endpointIP = opts.string "" "optional endpoint ip";
            subip = opts.int 300 "subip";
            mtu = opts.int 1420 "mtu bytes";
            extraAllowedIPs = mkOption {
              default = [ ];
              type = with types; listOf str;
              description = ''
                extra allowed IPs
              '';
            };
            networks = mkOption {
              default = { };
              type = types.attrsOf (
                types.submodule (
                  n@{ name, ... }:
                  {
                    options = {
                      enable = opts.enable' (
                        n.config.pubkey != ""
                      ) "enable host in wireguard network, enabled if pubkey set";
                      name = opts.string name "network name";
                      pubkey = opts.string "" "public key for host";
                      subip = opts.int config.subip "subip";
                      mtu = opts.int config.mtu "mtu bytes";
                      gateway.enable = mkOption {
                        type = types.nullOr types.bool;
                        default = null;
                        description = "force set gateway option, if enabled";
                      };
                      endpointIP = opts.string config.endpointIP "optional endpoint ip";
                      extraAllowedIPs = mkOption {
                        default = config.extraAllowedIPs;
                        type = with types; listOf str;
                        description = ''
                          extra allowed IPs
                        '';
                      };
                    };
                  }
                )
              );
              description = "networks to attach host to";
            };
          };
        }
      )
    );
  };

  config = mkIf cfg.enable {
    provision.networking.wireguard.p2p.networks = pipe cfg.hosts [
      (filterAttrs (_: n: n.enable))
      (mapAttrsToList (
        _: host:
        mapAttrsToList (_: network: {
          ${network.name}.peers.${host.name} = {
            inherit (network)
              subip
              pubkey
              mtu
              endpointIP
              extraAllowedIPs
              ;
            gateway = lib.mkIf (network.gateway.enable != null) network.gateway;
          };
        }) (filterAttrs (_: n: n.enable) host.networks)
      ))
      flatten
      mkMerge
    ];
  };
}
