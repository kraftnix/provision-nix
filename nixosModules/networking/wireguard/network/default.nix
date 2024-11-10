{self, ...}: {
  lib,
  config,
  pkgs,
  ...
}: let
  inherit
    (lib)
    attrValues
    filterAttrs
    flatten
    groupBy
    length
    mapAttrs
    mapAttrs'
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    nameValuePair
    pipe
    types
    ;
  cfg = config.provision.networking.wireguard.p2p;
  opts = self.lib.options;

  getGateways = peers:
    pipe peers [
      (filterAttrs (_: p: p.enable))
      (filterAttrs (_: p: p.gateway.enable))
    ];
  isGateway = peers:
    pipe peers [
      getGateways
      (gateways: lib.head (lib.attrValues gateways))
      (gateway: gateway.name == cfg.currHost.name)
    ];
  enabledNetworks = pipe cfg.networks [
    (filterAttrs (_: c: c.enable))
    (mapAttrs (_: c:
      c
      // {
        peers = filterAttrs (_: p: p.enable) c.peers;
      }))
  ];
in {
  imports = [
    (import ./agenix.nix self)
    (import ./firewall.nix self)
    (import ./hosts.nix self)
    ./systemd-networkd.nix
  ];
  options.provision.networking.wireguard.p2p = {
    enable = opts.enable "enable wireguard p2p between 2 peers";
    currHost = {
      name = opts.string config.networking.hostName "current host's user, looks host up in `networks`";
      networks = mkOption {
        type = types.attrsOf (types.submodule ({config, ...}: {
          options = {
            info = opts.raw {} "(read-only) core information";
            wgQuick = opts.raw {} "(read-only) wg-quick connection information";
            wgQuickFile = opts.string "" "(read-only) wg-quick connection information";
            netdev = opts.raw {} "(read-only) nixos netdev link";
            network = opts.raw {} "(read-only) nixos network";
            netdevUnit = opts.string "" "(read-only) nixos netdev unit file";
            networkUnit = opts.string "" "(read-only) nixos network unit file";
          };
        }));
        default = {};
        description = "(read-only) links to systemd network config and files";
      };
    };
    networks = mkOption {
      default = {};
      description = "wireguard networks to configure";
      type = types.attrsOf (types.submoduleWith {
        specialArgs = {
          inherit lib opts;
          host = cfg.currHost.name;
          interface = config.networking.nat.externalInterface;
        };
        modules = [./network.nix];
      });
    };
  };

  config = mkIf cfg.enable {
    assertions =
      flatten
      (
        (mapAttrsToList
          (
            _: network: (mapAttrsToList
              (_: host: {
                assertion = (network.enable && host.enable) -> host.ip != "";
                message = "IP must be set for host ${host.name} in network ${host.network}";
              })
              network.peers)
          )
          cfg.networks)
        ++ (mapAttrsToList
          (
            _: network: (mapAttrsToList
              (_: host: {
                assertion = (network.enable && host.enable) -> host.pubkey != "";
                message = "Pubkey must be set for host ${host.name} in network ${host.network}";
              })
              network.peers)
          )
          cfg.networks)
        ++ (mapAttrsToList
          (_: network: {
            assertion = network.enable -> network.privateKeyFile != "";
            message = "PrivateKeyFile must be non-null for current host, please set `provision.networking.wireguard.p2p.networks.${network.name}`";
          })
          cfg.networks)
        ++ [
          {
            assertion =
              (pipe cfg.networks [
                (filterAttrs (_: n: n.enable))
                attrValues
                (groupBy (el: toString el.listenPort))
                (filterAttrs (_: v: (length v) == 1))
              ])
              != {};
            message = ''
              Clashing listen ports between some networks
              ${pipe cfg.networks [
                (filterAttrs (_: n: n.enable))
                attrValues
                (groupBy (el: toString el.listenPort))
                (mapAttrs (_: map (v: v.name)))
                builtins.toJSON
              ]}
            '';
          }
        ]
        ++ (mapAttrsToList
          (_: network: {
            assertion = network.enable && network.mode == "hub-and-spoke" -> (getGateways network.peers) != {};
            message = ''
              If `hub-and-spoke` is enabled, a peer must be set as the gateway for: ${network.name}
              Please add a peer that has `subip` == `hubId`(${toString network.hubId}).
              Or add the gateway directly on the peer with:
                - `p2p.networks.${network.name}.peers.<mygatewaynode>.gateway.enable = true`
                - `p2p.hosts.<mygatewaynode>.networks.${network.name}.gateway.enable = true`
              depending on your usage.
            '';
          })
          cfg.networks)
      );

    networking.firewall = {
      allowedUDPPorts = pipe cfg.networks [
        (filterAttrs (_: n: n.enable && n.firewall.enable && (n.firewall.interface == null)))
        (mapAttrsToList (_: n: n.listenPort))
      ];
      interfaces = mkMerge (pipe cfg.networks [
        (filterAttrs (_: n: n.enable && n.firewall.enable && (n.firewall.interface != null)))
        (mapAttrsToList (_: n: {
          ${n.firewall.interface}.allowedUDPPorts = [n.listenPort];
        }))
      ]);
    };

    boot.kernel.sysctl = pipe enabledNetworks [
      (filterAttrs (_: n: n.mode == "hub-and-spoke"))
      (filterAttrs (_: n: isGateway n.peers))
      (mapAttrs' (
        _: network:
          nameValuePair "net.ipv4.conf.${network.name}.forwarding" true
      ))
    ];

    environment.systemPackages = [pkgs.wireguard-tools];
  };
}
