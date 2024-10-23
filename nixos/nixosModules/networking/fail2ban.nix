{self, ...}: {
  lib,
  config,
  ...
}: let
  inherit
    (lib)
    mapAttrs
    mkIf
    mkEnableOption
    mkOverride
    ;
  cfg = config.provision.networking.fail2ban;
in {
  options.provision.networking.fail2ban = {
    enable = mkEnableOption "enable fail2ban defaults";
  };

  config = mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      jails = mapAttrs (_: mkOverride 900) {
        DEFAULT = {
          enabled = true;
          settings = {
            backend = "systemd";
            banaction = "iptables-multiport";
            banaction_allports = "iptables-allports";
            bantime = "10m";
            ignoreip = "127.0.0.1/8 ::1 ";
            maxretry = 3;
          };
        };
        sshd = {
          enabled = true;
          settings = {
            port = 22;
            maxretry = 10;
          };
        };

        # nginx-req-limit = ''
        #   enabled = ${boolToString (active "nginx")}
        #   filter = nginx-req-limit
        #   maxretry = 10
        #   action = iptables-multiport[name=ReqLimit, port="http,https", protocol=tcp]
        #   findtime = 600
        #   bantime = 7200
        # '';
      };
    };

    # environment.etc."fail2ban/filter.d/sshd-ddos.conf" = mkDefaults {
    #   enable = (active "openssh");
    #   text = ''
    #     [Definition]
    #     failregex = sshd(?:\[\d+\])?: Did not receive identification string from <HOST>$
    #     ignoreregex =
    #   '';
    # };
    #
    # environment.etc."fail2ban/filter.d/nginx-req-limit.conf" = mkDefaults {
    #   enable = (active "nginx");
    #   text = ''
    #     [Definition]
    #     failregex = limiting requests, excess:.* by zone.*client: <HOST>
    #   '';
    # };

    # Limit stack size to reduce memory usage
    systemd.services.fail2ban.serviceConfig.LimitSTACK = 256 * 1024;
  };
}
