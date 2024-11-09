localFlake: {
  self,
  inputs,
  lib,
  flake-parts-lib,
  ...
}: let
  inherit
    (lib)
    literalExpression
    mapAttrs
    mkDefault
    mkOption
    types
    ;
  overlayType = lib.mkOptionType {
    name = "nixpkgs-overlay";
    description = "nixpkgs overlay";
    check = lib.isFunction;
    merge = lib.mergeOneOption;
  };
  channelModule = pkgs: ({
    config,
    name,
    ...
  }: {
    options = {
      addChannelsOverlay = mkOption {
        description = "insert self `channels` overlay to each channel";
        type = types.bool;
        default = true;
        example = false;
      };
      inputName = mkOption {
        description = "Name of `nixpkgs` input to use as channel base.";
        type = types.str;
        default = name;
      };
      input = mkOption {
        description = "Flake `nixpkgs` input to use as channel base.";
        type = types.raw;
        default = {};
      };
      overlays = mkOption {
        description = ''
          List of overlays to apply to `nixpkgs` from input.
        '';
        type = types.listOf overlayType;
        default = [];
        apply = os:
          if config.addChannelsOverlay
          then [self.overlays.channels] ++ os
          else os;
      };
      extraArgs = mkOption {
        description = ''
          Overrides configuration arguments to pass into `import nixpkgs`
        '';
        type = types.raw;
        default = {};
      };
      config = mkOption {
        description = ''
          Nixpkgs Config to evaluate base channel with, passed into `import nixpkgs { config }`
        '';
        type = types.raw;
        default = {allowUnfree = false;};
        example = literalExpression ''
          {
            permittedInsecurePackages = [ "electron-28.3.3" ];
            allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
              "steam"
              "steam-run"
            ];
          }
        '';
      };
      pkgs = mkOption {
        description = "Final `pkgs` to use for hosts.";
        type = types.pkgs;
        default = {};
      };
    };
    config = {
      input = mkDefault inputs.${config.inputName};
      pkgs = import config.input ({
          inherit (pkgs) system;
          overlays = config.overlays;
          inherit (config) config;
        }
        // config.extraArgs);
    };
  });

  mapChannelOverride = system: mapAttrs (name: channel: channel.pkgs) self.channels.${system};
in {
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption ({
      config,
      pkgs,
      ...
    }: {
      _file = ./channels.nix;
      options.channels = mkOption {
        description = ''
          NixOS Channels (pkgs) to allow hosts to use.
          The `nixpkgs` channel is always created, using your `inputs.nixpkgs`, but this is overridable.
        '';
        type = types.attrsOf (types.submodule (channelModule pkgs));
        default = {};
        example = literalExpression ''
          {
            stable = {};
            latest.inputName = "nixpkgs-master";
            nixpkgs = {
              config.permittedInsecurePackages = [ "electron-28.3.3" ];
              config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
                "steam"
                "steamcmd"
                "steam-run"
              ];
              overlays = [
                self.overlays.channels
                (final: prev: {
                  inherit (final.channels.stable)
                    prometheus
                    vector
                    ;
                })
                inputs.provision-nix.overlays.lnav
              ];
            };
          }
        '';
      };
    });
  };

  config = {
    transposition.channels = {};
    flake.overlays.channels = final: prev: {
      channels =
        if (prev ? channels)
        then (prev.channels // (mapChannelOverride prev.system))
        else (mapChannelOverride prev.system);
    };
  };
}
