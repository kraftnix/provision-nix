{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mapAttrs
    mapAttrsToList
    mkDefault
    flatten
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  dcfg = config.networking.nftables.gen.dnat;
  scfg = config.networking.nftables.gen.snat;
  enable = dcfg.enable || scfg.enable;
  dnatModule = (
    { name, config, ... }:
    {
      options = {
        comment = mkOption {
          description = "comment to add to firewall rule";
          type = types.str;
          example = "dnat for `name`";
        };
        counter = mkOption {
          description = "whether to add counter to forwards";
          type = types.bool;
          default = true;
        };
        from = mkOption {
          description = "list of interfaces to apply dnat from on host (optional)";
          type = with types; listOf str;
          default = [ ];
        };
        to = mkOption {
          description = "IP address to redirect to";
          type = types.str;
          example = "192.168.0.7";
        };
        port = mkOption {
          description = "port to DNAT from";
          type = types.port;
          example = 8080;
        };
        toPort = mkOption {
          description = "port to DNAT to";
          type = types.port;
          example = config.port;
        };
        protocols = mkOption {
          description = "protocols to DNAT";
          type =
            with types;
            listOf (enum [
              "tcp"
              "udp"
            ]);
          default = [ "tcp" ];
        };
      };
    }
  );
  snatModule = (
    { name, config, ... }:
    {
      options = {
        from = mkOption {
          description = "interface to expect ip from";
          default = name;
          type = types.str;
          example = "eth0";
        };
        fromIP = mkOption {
          description = "IP address to redirect to";
          type =
            with types;
            oneOf [
              str
              (listOf str)
            ];
          example = "192.168.0.0/24";
          apply = f: flatten [ f ];
        };
        to = mkOption {
          description = "list of interfaces to apply dnat from on host (optional)";
          type = with types; listOf str;
          default = scfg.defaultEgress;
        };
      };
    }
  );
in
{
  options.networking.nftables.gen = {
    dnat = {
      enable = mkEnableOption "enable Desination NAT integration" // {
        default = dcfg.gen != { };
      };
      inetTable = mkOption {
        description = "inet nft table to apply NAT rules to";
        type = types.str;
        default = "filter";
      };
      gen = mkOption {
        description = "generate redirect rules for ports on packets arriving at this host to other IPs";
        type =
          with types;
          attrsOf (submoduleWith {
            modules = [ dnatModule ];
          });
        default = { };
        example = {
          forward-to-host = {
            port = 8080;
            to = "127.0.0.1";
          };
          forward-tls = {
            port = 443;
            toPort = 8443;
            to = "127.0.0.1";
            protocls = [
              "udp"
              "tcp"
            ];
          };
        };
      };
    };
    snat = {
      enable = mkEnableOption "enable Source NAT integration" // {
        default = scfg.maps != { };
      };
      defaultEgress = mkOption {
        description = "default egress interfaces for snat interfaces";
        default = config.networking.nat.externalInterface or [ ];
        type =
          with types;
          oneOf [
            str
            (listOf str)
          ];
        apply = e: flatten [ e ];
      };
      maps = mkOption {
        description = "set of internal interfaces to do snat for";
        type = types.attrsOf (
          types.submoduleWith {
            modules = [ snatModule ];
          }
        );
        default = { };
        example = {
          eth0 = { };
          eth1.fromIP = "10.1.1.1";
        };
      };
    };
  };

  config = mkIf enable {
    networking.nat.enable = mkDefault true;
    networking.nftables.gen.tables.${dcfg.inetTable} = mkMerge [
      (mkIf dcfg.enable {
        ingress-dnat = {
          __type.hook = "prerouting";
          rules = mapAttrs (_: d: {
            tcpDport = if builtins.elem "tcp" d.protocols then [ d.port ] else [ ];
            udpDport = if builtins.elem "udp" d.protocols then [ d.port ] else [ ];
            iifname = d.from;
            main = "dnat ip to ${d.to}:${toString d.toPort}";
          }) dcfg.gen;
        };
      })
      (mkIf scfg.enable {
        mapsets.generated-egress = mkIf (scfg.maps != { }) {
          type = "set";
          lhsType = "iifname";
          rhsType = "ip saddr";
          verdictType = "oifname";
          counter = true;
          elements = flatten (
            mapAttrsToList (
              _: m:
              map (
                i:
                map (f: {
                  l = m.from;
                  r = f;
                  v = i;
                }) m.fromIP
              ) m.to
            ) scfg.maps
          );
        };
        egress-snat.__type.hook = "postrouting";
        egress-snat.rules.generated-egress = mkIf (scfg.maps != { }) {
          mapset = "generated-egress";
          verdict = "masquerade";
        };
        forward.rules.generated-egress = mkIf (scfg.maps != { }) {
          mapset = "generated-egress";
          verdict = "accept";
        };
      })
    ];
  };
}
