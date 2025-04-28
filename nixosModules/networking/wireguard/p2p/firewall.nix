self:
{
  lib,
  config,
  options,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    elem
    filterAttrs
    flatten
    mkAfter
    mkMerge
    mkOption
    mapAttrs
    mapAttrs'
    mapAttrsToList
    mkIf
    nameValuePair
    optionalAttrs
    pipe
    types
    ;
  cfg = config.provision.networking.wireguard.p2p;
  opts = self.lib.options;
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
  nnfModuleEnabled = options.networking.nftables ? firewall;
  nnfEnabled = cfg.enable && cfg.currHost.firewall.enable && (cfg.currHost.firewall.type == "nnf");
  provisionModuleEnabled = options.networking.nftables ? gen;
  provisionEnabled =
    cfg.enable && cfg.currHost.firewall.enable && (cfg.currHost.firewall.type == "provision");
  generateFirewallRules =
    network:
    let
      ipMap = mapAttrs (_: p: p.ip) network.peers;
      ip = peer: ipMap.${peer};
    in
    pipe network.peers [
      (mapAttrsToList (
        _: p:
        if p.firewall.allowedHosts == [ ] then
          [ ]
        else if elem "__all" p.firewall.allowedHosts then
          "ip saddr ${ip p.name} counter accept \"allow access to all subnet for ${p.name}\""
        else
          "ip saddr ${ip p.name} ip daddr { ${concatStringsSep ", " p.firewall.allowedHosts} } counter accept \"allowed access for ${p.name}\""
      ))
      (rules: rules ++ network.firewall.extraRules)
      flatten
    ];
  provision = {
    networking.nftables.gen.tables.filter =
      {
        forward.rules = mapAttrs (_: n: {
          iifname = [ n.name ];
          verdict = "jump forward-${n.name}";
          comment = "handle ${n.name} rules";
        }) enabledNetworks;
      }
      // (mapAttrs' (
        _: n:
        let
          ipMap = mapAttrs (_: p: p.ip) n.peers;
          ip = peer: lib.trace n ipMap.${peer};
        in
        nameValuePair "forward-${n.name}" {
          rules = mapAttrs' (
            _: p:
            nameValuePair p.name (
              {
                saddr = [ (ip p.name) ];
                verdict = if p.firewall.allowedHosts == [ ] then "reject" else "accept";
                comment = "handle traffic from ${p.name}";
              }
              // (optionalAttrs (p.firewall.allowedHosts != [ ] && !(elem "__all" p.firewall.allowedHosts)) {
                daddr = map ip p.firewall.allowedHosts;
              })
            )
          ) n.peers;
        }
      ) enabledNetworks);
  };
in
{
  options.provision.networking.wireguard.p2p.currHost.firewall = {
    enable = opts.enable ''
      Enable nftables firewall integration via `nixos-nftables-firewall`.

      Normally used on gateway nodes only with a `hub-and-spoke` mode.
    '';
    type = mkOption {
      default = "provision";
      type = types.enum [
        "provision"
        "nnf"
      ];
      description = "which type of firewall to integrate with";
    };
    verdict = opts.string "reject" "default verdict for firewall";
  };

  config =
    if (!nnfModuleEnabled) then
      (mkMerge [
        {
          assertions = [
            {
              assertion = !nnfEnabled;
              message = ''
                You have enabled nnf integration in `provision.networking.wireguard.p2p`
                but there is no `nixos-nftables-firewall` module found.

                Please import the nixos-nftables-firewall nixosModule into the host.
              '';
            }
          ];
        }
        (mkIf provisionEnabled provision)
      ])
    else
      (mkMerge [
        (mkIf nnfEnabled {
          networking.nftables.firewall = {
            zones = mapAttrs (_: n: {
              interfaces = [ n.name ];
            }) enabledNetworks;
            objects = mapAttrs' (
              _: n:
              nameValuePair "wg-${n.name}" (
                mkAfter (flatten [
                  (generateFirewallRules n)
                  "counter ${cfg.currHost.firewall.verdict} # final policy"
                ])
              )
            ) enabledNetworks;
            from = mapAttrs (_: n: {
              ${n.name}.to.${n.name}.policy = "jump wg-${n.name}";
            }) enabledNetworks;
          };
        })
        (mkIf provisionEnabled provision)
      ]);
}
