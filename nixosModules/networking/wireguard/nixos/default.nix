localFlake:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    filterAttrs
    listToAttrs
    mapAttrs
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    nameValuePair
    pipe
    types
    ;
  inherit (lib.types)
    attrsOf
    enum
    str
    submoduleWith
    ;

  opts = localFlake.self.lib.options;
  cfg = config.networking.wireguard;
  priority = toString cfg.__hostDebug.systemdUnitPriority;
in
{
  options.networking.wireguard = {
    generate = mkOption {
      description = "Whether to generate the host configuration.";
      type = enum [
        "none"
        "systemd"
      ];
      default = "none";
    };
    host = mkOption {
      description = "Which host configuration to generate.";
      type = str;
      default = config.networking.hostName;
    };
    networks = mkOption {
      description = "Wireguard Auto-Configured networks.";
      type = attrsOf (submoduleWith {
        modules = [ ./network.nix ];
      });
      default = { };
    };
    __hostDebug = {
      systemdUnitPriority = opts.int 40 "prefix for generated systemd units, i.e. '40-mynet.netdev'";
      networks = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              netdev = opts.raw { } "(read-only) nixos netdev link";
              network = opts.raw { } "(read-only) nixos network";
              netdevUnit = opts.string "" "(read-only) nixos netdev unit file";
              networkUnit = opts.string "" "(read-only) nixos network unit file";
            };
          }
        );
        default = { };
        description = "(read-only) links to systemd network config and files";
      };
    };
  };

  config = mkMerge [
    (mkIf (cfg.generate == "systemd") {
      environment.systemPackages = [ pkgs.wireguard-tools ];

      networking.firewall.allowedUDPPorts = mapAttrsToList (_: c: c.port) cfg.networks;

      boot.kernel.sysctl = lib.mapAttrs' (
        _: network: nameValuePair "net.ipv4.conf.${network.name}.forwarding" true
      ) (lib.filterAttrs (_: c: c.mode == "hub-and-spoke") cfg.networks);

      systemd.network.netdevs =
        if cfg.host == "" then
          { }
        # throw "you must define a host to generate the configuration for if you set `generate` to `systemd`"
        else
          listToAttrs (
            mapAttrsToList (
              name: network:
              nameValuePair "${priority}-${name}" network.__rendered.${cfg.host}.__systemdNetwork.netdev
            ) cfg.networks
          );

      systemd.network.networks =
        if cfg.host == "" then
          { }
        # throw "you must define a host to generate the configuration for if you set `generate` to `systemd`"
        else
          listToAttrs (
            mapAttrsToList (
              name: network:
              nameValuePair "${priority}-${name}" network.__rendered.${cfg.host}.__systemdNetwork.network
            ) cfg.networks
          );
    }
      # //
      # (lib.traceVal (lib.foldl' lib.recursiveUpdate {} (lib.attrValues cfg.networks)))
      # (mapAttrs (name: cfg: {}) cfg.networks) #cfg.__rendered.${cfg.host}.extraConfig) cfg.networks)
    )
    {
      networking.wireguard.__hostDebug.networks = pipe cfg.networks [
        (filterAttrs (_: n: n.enable))
        (filterAttrs (_: n: (filterAttrs (_: p: p.name == cfg.host) n.peers) != { }))
        (mapAttrs (
          _: w: {
            netdev = config.systemd.network.netdevs."${priority}-${w.name}";
            network = config.systemd.network.networks."${priority}-${w.name}";
            netdevUnit = config.systemd.network.units."${priority}-${w.name}.netdev".text;
            networkUnit = config.systemd.network.units."${priority}-${w.name}.network".text;
          }
        ))
      ];
    }
  ];
}
