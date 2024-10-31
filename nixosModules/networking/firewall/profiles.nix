{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault mkIf;

  cfg = config.networking.nftables.gen;
  fCfg = config.networking.firewall;
in {
  config = mkIf cfg.enable {
    networking.nftables.gen.tables = mkIf (builtins.elem "default" cfg.profiles) {
      filter = {
        __type = "inet";
        all-input-handle.rules = {
          nixos-allowed-udp = {
            comment = "nixos `allowedUDPPorts` handling";
            enable = fCfg.allowedUDPPorts != [];
            udpDport = fCfg.allowedUDPPorts;
            counter = mkDefault true;
            verdict = "accept";
          };
          nixos-allowed-tcp = {
            comment = "nixos `allowedTCPPorts` handling";
            enable = fCfg.allowedTCPPorts != [];
            tcpDport = fCfg.allowedTCPPorts;
            counter = mkDefault true;
            verdict = "accept";
          };
        };
        input = {
          __type.hook = "input";
          __type.policy = mkDefault "drop";
          defaults.counter = true;
          defaults.verdict = "accept";
          rules = {
            accept-to-local = {};
            icmp-default = {};
            ct-related-accept = {};
            ct-dnat-trace = {};
            ct-drop-invalid = {};
            ipv6-accept-link-local-dhcp = {};

            all-input-handle = {
              n = 95;
              verdict = "jump all-input-handle";
            };
          };
          finalCounter = mkDefault true;
        };
        forward = {
          __type.hook = "forward";
          __type.policy = mkDefault "drop";
          defaults.counter = true;
          defaults.verdict = "accept";
          rules = {
            # { rule = "icmp-default"; } # allows ping across vlans
            ct-related-accept = {};
            ct-dnat-trace = {};
            ct-drop-invalid = {};

            all-input-handle = {
              n = 95;
              oifname = ["lo"];
              verdict = "jump all-input-handle";
            };
          };
          finalCounter = mkDefault true;
        };
      };
    };
  };
}
