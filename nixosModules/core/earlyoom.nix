{ self, ... }:
{
  config,
  lib,
  ...
}:
let
  opts = self.lib.options;
  cfg = config.provision.core.earlyoom;
in
{
  options.provision.core.earlyoom = {
    enable = opts.enable "enable earlyoom";
    enableDebug = opts.enable "enable debug info";
    memoryThreshold = opts.int 5 "threshold to 5% until killing processes";
    extraArgs = opts.stringList [
      # "--avoid '(^|/)(init|Xorg|ssh|qemu)$'"
      # "--prefer '(^|/)(java|chromium|firefox)$'"
    ] "extra args to add to earlyoom";
    settings = opts.raw {
      reportInterval = 0; # disable reporting (so much log spam)
    } "extra settings";
  };

  config = lib.mkIf cfg.enable {
    services.earlyoom = lib.mkMerge [
      {
        enable = lib.mkOverride 900 true;
        enableDebugInfo = cfg.enableDebug;
        freeMemThreshold = cfg.memoryThreshold;
        inherit (cfg) extraArgs;
      }
      cfg.settings
    ];
  };
}
