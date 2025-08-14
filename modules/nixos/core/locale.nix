{ self, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    optional
    mkIf
    mkOverride
    types
    ;
  opts = self.lib.options;
  cfg = config.provision.core.locale;
  mkOverrideDefaulty = mkOverride 900;
in
{
  options.provision.core.locale = {
    enable = opts.enable "enable setting default locale, timeZone + key(board) configuration";
    keyMap = opts.string "uk" "keyboard layout (`console.keyMap`)";
    xkbLayout = opts.string "gb" "xserver xkb layout";
    default = opts.string "en_GB.UTF-8" "default locale (`i18m.defaultLocale`)";
    timeZone = opts.string "Europe/Amsterdam" "time zone (`time.timeZone`)";
    swapEscape = opts.enableTrue "swap escape and capslock in console + xserver settings";
  };

  config = mkIf cfg.enable {
    services.xserver.xkb.options = mkIf cfg.swapEscape "caps:escape";
    services.xserver.xkb.layout = mkOverrideDefaulty cfg.xkbLayout;
    console.keyMap = mkOverrideDefaulty cfg.keyMap;
    console.useXkbConfig = mkIf cfg.swapEscape (mkOverrideDefaulty true);
    i18n.defaultLocale = mkOverrideDefaulty cfg.default;
    time.timeZone = mkOverrideDefaulty cfg.timeZone;

    environment.variables = {
      # attempt to resolve LOCALE issues
      LANG = cfg.default;
      LANGUAGE = cfg.default;
      LC_ALL = cfg.default;
    };
  };
}
