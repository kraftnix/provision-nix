# taken from https://gitlab.com/otevrenamesta/otevrenamesta-cz-configuration/-/blob/master/modules/libvirt.nix#L126
# IPv4 only, /24 subnets only
{
  config,
  lib,
  utils,
  ...
}:
let
  bridgeName = "virbr0";
  externalInterface = "enp1s0";
  subnet = "192.168.122";
in
lib.mkIf config.provision.virt.libvirt.legacy.libvirt-networking {
  networking.firewall.interfaces.${bridgeName}.allowedUDPPorts = [
    53
    67
  ];
  networking.nat = {
    enable = true;
    internalInterfaces = [ bridgeName ];
    externalInterface = lib.mkDefault externalInterface;
  };

  systemd.services.libvirt-guests.after = [
    "systemd-networkd.service"
    "systemd-networkd-wait-online.service"
    "sys-subsystem-net-devices-${utils.escapeSystemdPath bridgeName}.device"
  ];
}
