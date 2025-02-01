{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    flatten
    mapAttrsToList
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.networking.nftables.gen.bridge;
in
{
  options.networking.nftables.gen.bridge = {
    enable = mkEnableOption "enable bridge filtering integration" // {
      default = cfg.interfaceMap != { };
    };
    enablePing = mkEnableOption "allow ping between bridge devices" // {
      default = true;
    };
    enableArp = mkEnableOption "allow arp between bridge devices" // {
      default = true;
    };
    defaultPolicy = mkOption {
      description = "default policy inside forward table";
      type = types.str;
      default = "drop";
    };
    table = mkOption {
      description = "inet nft table to apply NAT rules to";
      type = types.str;
      default = "br";
    };
    interfaceMap = mkOption {
      description = "set of bridge devices to set allow list for";
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              from = mkOption {
                description = "interface to expect ip from";
                default = name;
                type = types.str;
                example = "eth0";
              };
              to = mkOption {
                description = "list of interfaces to apply dnat from on host (optional)";
                type =
                  with types;
                  oneOf [
                    str
                    (listOf str)
                  ];
                default = [ ];
                example = "eth2";
                apply = t: flatten [ t ];
              };
            };
          }
        )
      );
      default = { };
      example = {
        eth0.to = "eth2";
        eth1.to = [
          "eth0"
          "eth2"
        ];
      };
    };
  };

  config = mkIf cfg.enable {
    networking.nftables.gen.tables.${cfg.table} = {
      __type = "bridge";
      mapsets.generated-allow-ifaces = mkIf (cfg.interfaceMap != { }) {
        lhsType = "iifname";
        rhsType = "oifname";
        verdict = "verdict";
        counter = true;
        elements = flatten (
          mapAttrsToList (
            _: m:
            map (t: {
              l = m.from;
              r = t;
              v = "accept";
            }) m.to
          ) cfg.interfaceMap
        );
      };
      forward = {
        __type.hook = "forward";
        __type.policy = cfg.defaultPolicy; # default drop traffic between bridge members
        __type.type = "filter";
        rules = {
          accept-all-arp = {
            enable = cfg.enableArp;
            n = 1;
            main = "ether type arp";
            verdict = "accept";
            comment = "accept all ARP";
          };
          ct-related-accept = { };
          ct-drop-invalid = { };
          arp-reply.enable = !cfg.enableArp;
          icmp-default.enable = cfg.enablePing;
          generated-allow-ifaces = {
            enable = cfg.interfaceMap != { };
            mapset = "generated-allow-ifaces";
            comment = "generated-allow-ifaces rule";
            verdict = "";
          };
        };
      };
    };
  };
}
