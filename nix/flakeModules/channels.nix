{
  self,
  inputs,
  lib,
  flake-parts-lib,
  ...
}: let
  inherit
    (lib)
    mapAttrs
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
      inputName = mkOption {
        type = types.raw;
        default = name;
        description = "Flake `nixpkgs` input to use as channel base.";
      };
      input = mkOption {
        type = types.raw;
        default = inputs.${config.inputName};
        description = "Flake `nixpkgs` input to use as channel base.";
      };
      overlays = mkOption {
        type = types.listOf overlayType;
        default = [];
        description = ''
          List of overlays to apply to base `nixpkgs`.
        '';
      };
      extraArgs = mkOption {
        type = types.raw;
        default = {};
        description = ''
          Extra configuration arguments to pass into `import nixpkgs {}`
        '';
      };
      config = mkOption {
        type = types.raw;
        default = {allowUnfree = false;};
        description = ''
          Nixpkgs Config to evaluate base channel with, passed into `import nixpkgs { config }`
        '';
      };
      pkgs = mkOption {
        type = types.pkgs;
        default = import config.input ({
            inherit (pkgs) system;
            overlays = config.overlays;
            inherit (config) config;
          }
          // config.extraArgs);
        description = "Final `pkgs` to use for hosts.";
      };
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
        type = types.attrsOf (types.submodule (channelModule pkgs));
        default = {};
        description = ''
          NixOS Channels (pkgs) to allow hosts to use. ${pkgs.system}
          The `nixpkgs` channel is always created, using your `inputs.nixpkgs`, but this is overridable.
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
    perSystem = {
      config,
      pkgs,
      system,
      ...
    }: {
      channels.nixpkgs = {};
    };
  };
}
