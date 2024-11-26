{ self, ... }:
{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    ;
  cfg = config.provision.hardware.wifi;
in
{
  options.provision.hardware.wifi = {
    enable = mkEnableOption "enable wifi";
  };

  config = mkIf cfg.enable {
    networking = {
      wireless.iwd.enable = true;
      interfaces."wlan0".useDHCP = true;
    };
  };
}
