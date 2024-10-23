{self, ...}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkIf
    optionalAttrs
    ;
  opts = self.lib.options;
  cfg = config.provision.networking.ssh;
in {
  imports = [./tor-ssh-daemon.nix];

  options.provision.networking.ssh = {
    enable = opts.enable "enable SSH";
    ports = opts.portList [22] "port for SSH (default: [22])";
    openFirewallAll = opts.enable' (!cfg.hardened) "opens firewall on all interfaces at specified ports (default: 22), is ignored if `allowedInterfaces` is set";
    allowedInterfaces = opts.stringList [] "opens firewall on allowed instances, overrides `openFirewallAll`";
    hardened = opts.enable "enable hardened SSH opts";
    gpgAgentForwarding = opts.enable "enable gpg agent forwarding over SSH";
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      openFirewall = false;
      inherit (cfg) ports;
      settings =
        {
          PermitRootLogin =
            if cfg.hardened
            then "no"
            else "prohibit-password";
        }
        // (optionalAttrs cfg.hardened {
          PasswordAuthentication = false;
          ClientAliveInterval = 300;
          X11Forwarding = false;
          X11UseLocalhost = false;
          MaxAuthTries = 6;
        });
      # Allow yubikey gpg socket forwarding
      extraConfig = mkIf cfg.gpgAgentForwarding ''
        StreamLocalBindUnlink yes
      '';
    };
    networking.firewall.allowedTCPPorts = mkIf (cfg.openFirewallAll && (cfg.allowedInterfaces != [])) cfg.ports;
    networking.firewall.interfaces = lib.genAttrs cfg.allowedInterfaces (name: {
      allowedTCPPorts = cfg.ports;
    });
  };
}
