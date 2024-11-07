{
  self,
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkOption
    types
    ;
in {
  options = {
    system = mkOption {
      type = types.enum lib.platforms.all;
      default = "x86_64-linux";
      description = "system for host.";
    };
    self = mkOption {
      type = types.lazyAttrsOf types.unspecified;
      default = config._module.args.self;
      description = "reference to current flake-parts self";
    };
    nixpkgs = mkOption {
      description = ''
        The Nixpkgs to use for this host.
          - if set to a `string`, then a channel's pkgs will be looked up in `flake.channels.{system}.{name}.pkgs`
          - otherwise, can be set to a `pkgs` directly.
      '';
      type = with types; oneOf [str pkgs];
      default = "nixpkgs";
      apply = val:
        if builtins.typeOf val == "string"
        then self.channels.${config.system}.${val}.pkgs
        else val;
    };

    modules = mkOption {
      type = types.listOf types.raw;
      default = [];
      description = "extra nixos modules to eval for host.";
    };
    overlays = mkOption {
      default = [];
      description = "extra overlays to add for host";
    };
    moduleArgs = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = {};
      description = "extra arguments to add to `_module.args` in host";
    };
    specialArgs = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = {};
      description = "extra arguments to add to `specialArgs` in `eval-config.nix`";
    };
    colmena = mkOption {
      type = types.raw;
      default = {};
      apply = lib.recursiveUpdate (config._module.args.colmena
        // {
          targetHost = config._module.args.name;
        });
      description = "extra arguments to add in flake `colmena.<host>.deployment`";
    };
    deploy = mkOption {
      type = types.raw;
      default = {};
      apply = lib.recursiveUpdate {
        hostname = config.colmena.targetHost;
      };
      description = "extra arguments to add in flake `deploy.nodes.<host>`";
    };
  };
}
