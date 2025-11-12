{ self, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf types;
  opts = self.lib.options;
  cfg = config.provision.core.debug;
in
{
  options.provision.core.debug = {
    enable = opts.enable "enable to add all debug packages specified in {debug.packages} to `systemPackages`";
    packages = opts.mk {
      default = [ ];
      description = "large list of debug packages";
      type = with types; listOf package;
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = cfg.packages;
    provision.core.debug.packages = with pkgs; [
      amdctl # control AMD power states
      btop # top tool
      btrfs-progs # btrfs tools
      conntrack-tools # userspace connection tracking
      dmidecode # get system information
      dua # disk usage analysis (parallel)
      duf # file usage
      dust # better du
      ethtool # ethtool
      iperf # internet performance measure
      iproute2 # ip route checking tool
      jc # json output for all things
      lm_sensors # list temperature sensors
      litecli # better sqlite viewer
      linux-router # swiss army knife networking scripts
      lnav # good log viewer
      lshw # list hardware
      lsof # get file locks
      nethogs # group process by network usage
      nftables # nftables firewall (nft)
      nvme-cli # nvme info
      nushell # best shell
      pciutils # pci utility
      powertop # power control view + change power opts
      s-tui # view detailed core info (TUI)
      smartmontools # S.M.A.R.T. ctrl
      sqlite # sqlite3 command
      tshark # wireshark TUI
      usbutils # usb utility
      wavemon # monitor wifi at physical layer
      # zenith # top tool with nice graphs
    ];
  };
}
