localFlake:
{
  self,
  lib,
  config,
  options,
  ...
}:
let
  inherit (lib)
    filterAttrs
    hasPrefix
    mapAttrs
    mapAttrs'
    mkIf
    nameValuePair
    pipe
    ;
  cfg = config.provision.networking.wireguard.p2p;
  opts = localFlake.lib.options;
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
  agenixEnabled = options ? age;
in
{
  options.provision.networking.wireguard.p2p.currHost = {
    addAgenixToHost = opts.enable ''
      Enable agenix integration for wireguard keys on current host.

      Automatically adds a `age.secrets.wg-<network>` arg for each wireguard network
      if the private key file location begins with `/run/agenix`.
    '';
  };

  config =
    if agenixEnabled then
      (mkIf (cfg.enable && cfg.currHost.addAgenixToHost) {
        age.secrets = mapAttrs' (
          network: wireguard:
          nameValuePair "wg-${network}" {
            file = "${self}/secrets/${cfg.currHost.name}/wg-${network}.age";
            owner = "systemd-network";
          }
        ) (filterAttrs (_: n: n.peers.${cfg.currHost.name}.addAgenixToHost) enabledNetworks);
      })
    else
      {
        assertions = [
          {
            assertion = cfg.enable -> !cfg.currHost.addAgenixToHost;
            message = ''
              You have enabled agenix integration in `provision.networking.wireguard.p2p`
              but there is no agenix module found.

              Please import the agenix nixosModule into the host.
            '';
          }
        ];
      };
}
