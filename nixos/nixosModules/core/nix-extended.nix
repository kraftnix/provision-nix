{
  self,
  inputs,
  ...
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) filterAttrs mapAttrs mapAttrsToList mkDefault mkOption mkMerge mkIf types;
  opts = self.lib.options;
  cfg = config.provision.nix;
  enabledSubstituters = filterAttrs (_: s: s.enable) cfg.substituters;
  substitutersUsed = lib.partition (sub: sub.use) (lib.attrValues enabledSubstituters);
in {
  options.provision.nix = {
    basic = opts.enable "good defaults for most usecases";
    develop = opts.enable "good defaults for developers";
    builder = opts.enable "good defaults for powerful building machines";
    server = opts.enable "good defaults for servers / edge devices etc.";
    optimise = {
      enable = opts.enable "optimise / deduplication store";
      gc = opts.enable "run garbage collection on a schedule";
      dates = opts.string "weekly" "how often to run garbage collection";
      options = opts.string "--delete-older-than 30d" "options to pass into `nix-collect-garbage`";
    };

    trustWheel = opts.enable "add wheel as allowed + trusted users";
    trustedUsers = opts.stringList [] "adds these users to `allowed-users` and `trusted-users`";

    substituters = mkOption {
      description = "easily set binary cache substituters and keys";
      default = {};
      type = types.attrsOf (types.submodule ({config, ...}: {
        options = {
          enable = opts.enable' (config.publicKey != "" && config.substituter != "") ''
            Whether to allow (but not enable by default) a substituter:

            sets `trusted-substituters"
          '';
          use = opts.enable "use as a system substituter";
          publicKey = opts.string "" "Pubkey that signed substituter store paths, sets `trusted-public-keys`";
          substituter = opts.string "" "Substituter for binaries, sets `trusted-public-keys`";
        };
      }));
    };

    flakes = {
      enable = opts.enable "enable basic flakes usage (--experimental-features)";
      inputs = mkOption {
        type = with types; attrsOf unspecified;
        default = {};
        example = inputs;
        description = "Flake inputs to add to nix-path and registry";
      };
      registry = mkOption {
        description = "registry entries to add, expects set(name -> input)";
        type = with types; attrsOf unspecified;
        default = mapAttrs (_: value: {flake = value;}) cfg.flakes.inputs;
      };
    };
  };

  config = lib.mkMerge [
    ## Profiles
    (mkIf cfg.basic {
      nix.daemonCPUSchedPolicy = mkDefault "batch";
      nix.daemonIOSchedClass = mkDefault "idle";
      nix.daemonIOSchedPriority = mkDefault 7;
      nix.settings = {
        fallback = true; # if true, fall back to building source if missing in cache
        sandbox = true;
        # frees garbage until `max-free` when disk space drops below `min-free` during a build
        min-free = mkDefault 536870912; # 500MB
        max-free = mkDefault 1036870912; # 1GB
        experimental-features = ["nix-command" "flakes"];
        connect-timeout = mkDefault 5; # timeout for substituters
      };
      environment.systemPackages = with pkgs; [
        nix-diff # Explain why two Nix derivations differ
        nix-du # A tool to determine which gc-roots take space in your nix store
        nix-output-monitor # nom, pretty build printing
        nix-tree # Interactively browse a Nix store paths dependencies
        nvd # Nix/NixOS package version diff tool
      ];
    })
    (mkIf cfg.develop {
      nix.settings = {
        keep-outputs = true;
        keep-derivations = true;
        log-lines = mkDefault 40; # double loglines shown after build failure
      };
      environment.systemPackages = with pkgs; [
        nix-doc # An interactive Nix documentation tool
        nix-init # Command line tool to generate Nix packages from URLs
        nix-ld # Run unpatched dynamic binaries on NixOS
        nix-melt # A ranger-like flake.lock viewer
        nix-output-monitor # nom, pretty build printing
        nix-search-cli # cli tool that search nixos.org, can search for packages
        nix-template # Make creating nix expressions easy
        nurl # generate fetchers from url
      ];
    })
    (mkIf cfg.builder {
      nix.settings = {
        keep-outputs = true;
        keep-derivations = true;
        system-features = ["nixos-test" "benchmark" "big-parallel" "kvm"];
        max-silent-time = mkDefault 600; # timeout after 10mins if no stdout in build
      };
      environment.systemPackages = with pkgs; [
        nix-tree # Interactively browse a Nix store paths dependencies
        nvd # Nix/NixOS package version diff tool
        nix-output-monitor # nom, pretty build printing
      ];
    })
    (mkIf cfg.server {
      nix.settings = {
        keep-outputs = true;
        keep-derivations = true;
        system-features = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      };
      environment.systemPackages = with pkgs; [
        nix-tree # Interactively browse a Nix store paths dependencies
        nvd # Nix/NixOS package version diff tool
        nix-output-monitor # nom, pretty build printing
      ];
    })

    ## User ops / ACLs
    (mkIf cfg.trustWheel {
      nix.settings = {
        allowed-users = ["@wheel"];
        trusted-users = ["root" "@wheel"];
      };
    })
    {
      nix.settings = {
        allowed-users = cfg.trustedUsers;
        trusted-users = cfg.trustedUsers;

        ## binary cache
        trusted-public-keys = mapAttrsToList (_: sub: sub.publicKey) enabledSubstituters;
        substituters = map (sub: sub.substituter) substitutersUsed.right;
        trusted-substituters = map (sub: sub.substituter) substitutersUsed.wrong;

        ## ops
        auto-optimise-store = cfg.optimise.enable; # deduplications
      };
      ## garbage collection
      nix.gc = {
        automatic = cfg.optimise.gc;
        inherit (cfg.optimise) dates options;
      };
    }

    ## Flakes
    (mkIf cfg.flakes.enable {
      nix.nixPath = ["nixpkgs=flake:nixos"]; # https://github.com/NixOS/nixpkgs/issues/241356
      nix.settings.extra-experimental-features = ["flakes" "nix-command"];
      nix.registry = mkMerge [
        cfg.flakes.registry
        {
          nixos = mkDefault {
            flake = inputs.nixpkgs;
          };
          stable = mkDefault {
            flake = inputs.nixpkgs-stable;
          };
        }
      ];
      nix.settings.nix-path = mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
    })
  ];
}
