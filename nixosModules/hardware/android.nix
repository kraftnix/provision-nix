{ self, ... }:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    ;
  cfg = config.provision.hardware.android;
in
{
  options.provision.hardware.android = {
    enable = mkEnableOption "enable android udev";
  };

  config = mkIf cfg.enable {
    programs.adb.enable = true;
    services.udev.packages = with pkgs; [ android-udev-rules ];
  };
}
