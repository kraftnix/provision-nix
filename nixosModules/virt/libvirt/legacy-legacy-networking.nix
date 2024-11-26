localFlake:
# taken from https://gitlab.com/otevrenamesta/otevrenamesta-cz-configuration/-/blob/master/modules/libvirt.nix#L126
# IPv4 only, /24 subnets only
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (localFlake.lib.networking) genGateway genIP;
  cfg = {
    bridgeName = "libvirt-default";
    externalInterface = "enp1s0";
  };
  subnet = "192.168.15";
in
lib.mkIf config.provision.virt.libvirt.legacy.legacy-networking {
  networking.nat = {
    enable = true;
    internalInterfaces = [ cfg.bridgeName ];
    externalInterface = lib.mkDefault cfg.externalInterface;
  };

  # libvirt uses 192.168.122.0
  networking.bridges."${cfg.bridgeName}".interfaces = [ ];
  networking.interfaces."${cfg.bridgeName}" = {
    ipv4.addresses = [
      {
        address = genGateway subnet;
        prefixLength = 24;
      }
    ];
  };

  services.dhcpd4 = {
    enable = true;
    interfaces = [ cfg.bridgeName ];
    extraConfig = ''
      option routers ${genGateway subnet};
      option broadcast-address ${genIP subnet 255};
      option subnet-mask 255.255.255.0;
      option domain-name-servers 10.1.1.1;
      default-lease-time -1;
      max-lease-time -1;
      subnet ${genIP subnet 0} netmask 255.255.255.0 {
        range ${genIP subnet 10} ${genIP subnet 250};
      }
    '';
  };
}
