{ self, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkDefault optionals;
  opts = self.lib.options;
  cfg = config.provision.networking.tools;
in
{
  options.provision.networking.tools = {
    basic = {
      enable = opts.enable "enable basic tools";
      packages = opts.packageList [ ] "basic network debugging tools";
    };
    all = {
      enable = opts.enable "enable all network debug tools";
      packages = opts.packageList [ ] "all network debugging tools";
    };
  };

  config = {
    provision.networking.tools = {
      basic.packages =
        with pkgs;
        mkDefault [
          conntrack-tools # CLI: conntrack
          self.packages.${pkgs.stdenv.hostPlatform.system}.dnsleaktest # CLI: test for leaking DNS
          ethtool # CLI: ethtool
          iperf # CLI: internet performance measure
          iproute2 # CLI: ip route checking tool
          iptraf-ng # TUI: network monitoring (all interfaces + traffic)
          iputils # CLI: ping, traceroute etc
          mtr # CLI: traceroute/ping combo
          netproc # TUI: monitor traffic per process
          rustscan # CLI: better nmap
          sslscan # CLI: test SSL services
          tcpdump # CLI: dump TCP traffic
          tshark # TUI: terminal wireshark
          wireguard-tools # CLI: wireguard standard tools
        ];
      all.packages =
        with pkgs;
        mkDefault [
          dnsx # CLI: dns parse + scripting tool
          ipmitool # CLI: handle ipmi for servers with BMC
          glances # CLI: real-time monitoring
          macchanger # CLI: change + view MAC addresses
          mubeng # CLI: proxy rotator tool
          speedtest-rs # CLI: quick speedtester
          wuzz # TUI: inteactive http curl
        ];
    };

    environment.systemPackages =
      [ ]
      ++ (optionals cfg.basic.enable cfg.basic.packages)
      ++ (optionals cfg.all.enable cfg.all.packages);
  };
}
