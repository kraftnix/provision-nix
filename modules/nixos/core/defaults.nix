{ self, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    types
    mkDefault
    mkOption
    ;
  opts = self.lib.options;
  cfg = config.provision.core.defaults;
in
{
  options.provision.core.defaults = {
    enable = opts.enable ''
      Changes some system defaults:
        - increase sysctl inotify limits
        - change systemd DefaultTimeout settings
    '';
    sysctl = {
      bumpInotifyLimits = opts.enable ''
        Bump inotify limits, the defaults are very low.

        Low settings here can cause many issues with:
          - Failed to allocate directory watch: Too many open files
          - systemd-nspawn: Initializing machine ID from container UUID.
            systemd-nspawn: Failed to create control group inotify object: Too many open files
            systemd-nspawn: Failed to allocate manager object: Too many open files
            systemd-nspawn: [!!!!!!] Failed to allocate manager object.
            systemd-nspawn: Exiting PID 1...

        This can also affect hungry desktop applications.

        More info + potential upstream fix here: https://github.com/NixOS/nixpkgs/pull/126777/files
      '';
      inotifyLimitsMultiple = opts.mk {
        default = 64;
        example = 10000;
        description = ''
          Set the limits multiplier against the base (`128`) for inotify limits types.
          Running many containers might require increasing this limit.

          Current NixOS Upstream would be: `1` , which becomes `128`.

          Default (64): results in `64 * 128` = `8192`.
        '';
        type = types.ints.between 1 100000000;
      };
    };

    systemd = {
      defaultTimeoutSec = mkOption {
        default = null;
        example = 30;
        description = ''
          Set the default timeout for systemd units. If null not set.
        '';
        type = with types; nullOr (ints.between 5 10000000);
      };
    };

  };

  config = lib.mkMerge [
    (mkIf cfg.enable {
      provision.core.defaults.sysctl.bumpInotifyLimits = true;
    })

    ## Inotify / sysctl
    (mkIf cfg.sysctl.bumpInotifyLimits {
      boot.kernel.sysctl = {
        "fs.inotify.max_user_instances" = cfg.sysctl.inotifyLimitsMultiple * 128 * 2;
        "fs.inotify.max_user_watches" = cfg.sysctl.inotifyLimitsMultiple * 128;
        "fs.inotify.max_queued_events" = cfg.sysctl.inotifyLimitsMultiple * 128;
      };
    })

    ## Systemd
    (mkIf (cfg.systemd.defaultTimeoutSec != null) (
      let
        timeout = "${toString cfg.systemd.defaultTimeoutSec}s";
      in
      {
        systemd.settings.Manager = {
          DefaultTimeoutStartSec = timeout;
          DefaultTimeoutStopSec = timeout;
        };
        systemd.user.extraConfig = ''
          DefaultTimeoutStartSec=${timeout}
          DefaultTimeoutStopSec=${timeout}
        '';
      }
    ))
  ];
}
