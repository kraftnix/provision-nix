{ self, ... }:
{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    mkDefault
    optionalAttrs
    ;
  cfg = config.provision.networking.static;
  opts = self.lib.options;
in
{
  options.provision.networking.static = {
    enable = opts.enable' (cfg.address != "") "enable static IP";
    address = opts.string "" "IPv4 address" // {
      example = "45.89.126.43";
    };
    gateway = opts.string "" "IPv4 gateway" // {
      example = "45.89.126.1";
    };
    netmask = opts.string "255.255.255.0" "IPv4 address";
    interface = opts.string "" "network interface";
    prefixLength = opts.int 24 "prefix length, must match netmask";
    kernelArg = opts.string "ip=${cfg.address}::${cfg.gateway}:${cfg.netmask}::${cfg.interface}:off" ''
      Kernel arg passed in, setting the IP statically during on kernel boot
    '';
  };

  config = mkIf cfg.enable {
    networking.useDHCP = mkDefault true;
    boot.kernelParams = [ cfg.kernelArg ];
    networking.interfaces.${cfg.interface}.ipv4.addresses = [
      {
        inherit (cfg) address prefixLength;
      }
    ];
    networking.defaultGateway = {
      address = cfg.gateway;
      inherit (cfg) interface;
    };
  };
}
