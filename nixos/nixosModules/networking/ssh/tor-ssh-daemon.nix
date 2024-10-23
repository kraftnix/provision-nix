{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.provision.networking.ssh.tor;
in {
  # find the hostname in `/var/lib/tor/onion/sshd/hostname`
  # access with: torsocks ssh xyzxyzxyz.onion -p 29420
  options.provision.networking.ssh.tor = {
    enable = mkEnableOption "enable onion service that connects to local sshd";
    listenPort = mkOption {
      default = 29420;
      type = types.port;
      description = "listen port on tor";
    };
    internalSshPort = mkOption {
      default = 22;
      type = types.port;
      description = "internal ssh listen port";
    };
    internalSshAddress = mkOption {
      default = "[::1]";
      type = types.str;
      description = "internal ssh listen address";
    };
  };

  config = mkIf (cfg.enable) {
    environment.systemPackages = [pkgs.torsocks];
    services.tor = {
      enable = true;
      enableGeoIP = false;
      relay.onionServices = {
        sshd = {
          version = 3;
          map = [
            {
              port = cfg.listenPort;
              target = {
                addr = cfg.internalSshAddress;
                port = cfg.internalSshPort;
              };
            }
          ];
        };
      };
      settings = {
        ClientUseIPv4 = false;
        ClientUseIPv6 = true;
        ClientPreferIPv6ORPort = true;
      };
    };
  };
}
