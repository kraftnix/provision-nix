{self, ...}: {
  lib,
  config,
  ...
}: let
  inherit
    (lib)
    mkIf
    mkEnableOption
    ;
  cfg = config.provision.hardware.zram;
in {
  options.provision.hardware.zram = {
    enable = mkEnableOption "enable zram";
  };

  config = mkIf cfg.enable {
    zramSwap.enable = true;
  };
}
