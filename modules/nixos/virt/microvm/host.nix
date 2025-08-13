{ self, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.provision.virt.microvm.host;
  opts = self.lib.options;
  inherit (lib)
    mkIf
    ;
in
{
  options.provision.virt.microvm.host = {
    enable = opts.enable ''
      Enables microvm.host extensions
    '';

    network = {
      nat.enable = opts.enable "enable nat for bridge interface";
      basic = {
        enable = opts.enable "enable base network interface";
        name = opts.string "microvm" "bridge interface";
        tapTagMatch = opts.string "vm*" "networkd match tap interface name";
        ipv4Subnet = opts.string "10.213.0.1/24" "ipv4 range for bridge";
        ipv6Prefix = opts.string "fd12:3456:789a::" "ipv6 local prefix for bridge";
      };
    };

    qemu-bridge-fix = opts.enable "enable workaround for qemu-bridge-helper setuid";
  };

  config = mkIf cfg.enable {
    # Otherwise
    /*
      Failed assertions:
      - The security.wrappers.qemu-bridge-helper wrapper is not valid:
      setuid/setgid and capabilities are mutually exclusive.
    */
    # also conflict with nixpkgs `virtualisation/libvirtd.nix`
    security.wrappers.qemu-bridge-helper = mkIf cfg.qemu-bridge-fix {
      setuid = lib.mkForce false;
      source = lib.mkForce "${pkgs.qemu}/libexec/qemu-bridge-helper";
    };

    networking.firewall.interfaces.${cfg.network.basic.name}.allowedUDPPorts = [ 67 ];

    networking.nat = mkIf cfg.network.nat.enable {
      enable = true;
      enableIPv6 = true;
      internalInterfaces = [ cfg.network.basic.name ];
    };

    systemd.network =
      let
        basic = cfg.network.basic;
      in
      mkIf basic.enable {
        netdevs."10-${basic.name}".netdevConfig = {
          Kind = "bridge";
          Name = basic.name;
        };
        networks."10-${basic.name}" = {
          matchConfig.Name = basic.name;
          networkConfig = {
            DHCPServer = true;
            IPv6SendRA = true;
          };
          addresses = [
            { Address = basic.ipv4Subnet; }
            { Address = "${basic.ipv6Prefix}1/64"; }
          ];
          ipv6Prefixes = [
            { Prefix = "${basic.ipv6Prefix}/64"; }
          ];
        };
        networks."11-${basic.name}" = {
          matchConfig.Name = basic.tapTagMatch;
          networkConfig.Bridge = basic.name;
        };
      };
  };
}
