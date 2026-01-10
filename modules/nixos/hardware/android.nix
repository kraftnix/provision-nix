{ self, ... }:
{ lib, config, pkgs, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.provision.hardware.android;
in {
  options.provision.hardware.android = {
    enable = mkEnableOption "adds android-tools to packages";
  };

  config =
    mkIf cfg.enable { environment.systemPackages = [ pkgs.android-tools ]; };
}
