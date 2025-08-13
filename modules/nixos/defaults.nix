{ self, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf types mkDefault;
  opts = self.lib.options;
  cfg = config.provision.defaults;
  enable = cfg.enable;
in
{
  options.provision.defaults = {
    enable = opts.enable "Enable defaults to be set. Setting to false overrides all enables in this module.";

    sysctl = {
      bumpInotifyLimits = opts.enableTrue ''
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
      defaultTimeoutSec = lib.mkOption {
        default = null;
        example = 30;
        description = ''
          Set the default timeout for systemd units. If null not set.
        '';
        type = with types; nullOr (ints.between 5 10000000);
      };
    };

    security = {
      doas = {
        enable = opts.enableTrue "enable doas";
        extraRules = lib.mkOption {
          default = [ ];
          description = "extra doas rules";
          type = with types; listOf raw;
        };
      };
      openssh = {
        enable = opts.enableTrue "enable ssh";
      };
      electron.enable = opts.enable "enables chromium suid sandbox";
      libre-only.enable = opts.enable "prevents redistribuation but not free firmware";
      hardened_kernel = {
        enable = opts.enable "enable latest hardened kernel";
        kernel = opts.package pkgs.linux_6_6_hardened "hardened kernel package";
      };
      namespacing.enable = opts.enable "enable unprivilegedUsernsClone";
    };

    debug = {
      systemImportPackages = opts.enable "enable to add all debug packages to `systemPackages`";
      packages = opts.mk {
        default = [ ];
        description = "large list of debug packages";
        type = with types; listOf package;
      };
    };
  };
  config = lib.mkMerge [
    (mkIf enable {
      # shouldn't affect when actually used, but prevents error in nix-repl when previewing `config`
      passthru = lib.mkDefault { };
    })

    ## Inotify / sysctl
    (mkIf (enable && cfg.sysctl.bumpInotifyLimits) {
      boot.kernel.sysctl = {
        "fs.inotify.max_user_instances" = cfg.sysctl.inotifyLimitsMultiple * 128 * 2;
        "fs.inotify.max_user_watches" = cfg.sysctl.inotifyLimitsMultiple * 128;
        "fs.inotify.max_queued_events" = cfg.sysctl.inotifyLimitsMultiple * 128;
      };
    })

    ## Systemd
    (mkIf (enable && (cfg.systemd.defaultTimeoutSec != null)) (
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

    ## Security
    (mkIf (enable && cfg.security.doas.enable) {
      security.doas.enable = true;
      security.doas.extraRules = cfg.security.doas.extraRules;
    })
    (mkIf (enable && cfg.security.openssh.enable) {
      # For rage encryption, all hosts need a ssh key pair
      services.openssh = {
        enable = true;
        openFirewall = lib.mkDefault false;
      };
    })
    (mkIf (enable && cfg.security.electron.enable) {
      security.chromiumSuidSandbox.enable = true;
    })
    (mkIf (enable && cfg.security.libre-only.enable) {
      nixpkgs.config.allowUnfree = false;
      # WARNING: this will likely break your boot for most hardware :(
      hardware.enableRedistributableFirmware = lib.mkOverride 51 false;
    })
    # (mkIf (enable && cfg.security.hardened_kernel.enable) {
    #   boot.kernelPackages = cfg.security.hardened_kernel.kernel;
    # })
    (mkIf (enable && cfg.security.namespacing.enable) {
      security.allowUserNamespaces = mkDefault true;
      security.unprivilegedUsernsClone = mkDefault true;
    })

    ## Debug
    (mkIf (enable && cfg.debug.systemImportPackages) {
      environment.systemPackages = cfg.debug.packages;
    })

    {
      provision.defaults.debug.packages = with pkgs; [
        amdctl # control AMD power states
        btop # top tool
        btrfs-progs # btrfs tools
        conntrack-tools # userspace connection tracking
        dmidecode # get system information
        dua # disk usage analysis (parallel)
        duf # file usage
        du-dust # better du
        ethtool # ethtool
        iperf # internet performance measure
        iproute2 # ip route checking tool
        jc # json output for all things
        lm_sensors # list temperature sensors
        litecli # better sqlite viewer
        linux-router # swiss army knife networking scripts
        lnav # good log viewer
        lshw # list hardware
        lsof # get file locks
        nethogs # group process by network usage
        nftables # nftables firewall (nft)
        nvme-cli # nvme info
        nushell # best shell
        pciutils # pci utility
        powertop # power control view + change power opts
        s-tui # view detailed core info (TUI)
        smartmontools # S.M.A.R.T. ctrl
        sqlite # sqlite3 command
        tshark # wireshark TUI
        usbutils # usb utility
        wavemon # monitor wifi at physical layer
        zenith # top tool with nice graphs
      ];
    }
  ];
}
