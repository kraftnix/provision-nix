{self, ...}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkDefault optionals;
  opts = self.lib.options;
  cfg = config.provision.networking.tools;
in {
  options.provision.networking.tools = {
    basic = {
      enable = opts.enable "enable basic tools";
      packages = opts.packageList [] "basic network debugging tools";
    };
    all = {
      enable = opts.enable "enable iptables";
      packages = opts.packageList [] "all network debugging tools";
    };
  };

  config = {
    provision.networking.tools = {
      basic.packages = with pkgs;
        mkDefault [
          conntrack-tools # CLI: conntrack
          dnsx # CLI: dns parse + scripting tool
          ethtool # CLI: ethtool
          glances # CLI: real-time monitoring
          iperf # CLI: internet performance measure
          ipmitool # CLI: handle ipmi for servers with BMC
          iproute2 # CLI: ip route checking tool
          iptraf-ng # TUI: network monitoring (all interfaces + traffic)
          iputils # CLI: ping, traceroute etc
          macchanger # CLI: change + view MAC addresses
          mtr # CLI: traceroute/ping combo
          mubeng # CLI: proxy rotator tool
          netproc # TUI: monitor traffic per process
          rustscan # CLI: better nmap
          speedtest-rs # CLI: quick speedtester
          sslscan # CLI: test SSL services
          tcpdump # CLI: dump TCP traffic
          tshark # TUI: terminal wireshark
          wireguard-tools # CLI: wireguard standard tools
          wuzz # TUI: inteactive http curl
        ];
      all.packages = with pkgs;
        mkDefault [
        ];
    };

    environment.systemPackages =
      []
      ++ (optionals cfg.basic.enable cfg.basic.packages)
      ++ (optionals cfg.all.enable cfg.all.packages);
  };
}
