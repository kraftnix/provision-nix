{
  lib,
  defaults ? {
    addTo = {
      modules = false;
      flakeParts = false;
    };
    flakeArgs = null;
  },
  ...
}: let
  enable = desc: default: lib.mkEnableOption desc // {inherit default;};
in {
  options = {
    addTo = {
      modules = enable "add {modules'} entries to toplevel flake output (i.e. nixosModules, flakeModules)" defaults.addTo.modules;
      flakeParts = enable "add {modules'} entries to {modules.{class}} (flake-parts extra module)" defaults.addTo.flakeParts;
    };
    flakeArgs = lib.mkOption {
      description = ''
        When set to null, modules are imported purely by path.
        Otherwise, all imported modules are mapped through `import {module} {flakeArgs}`.

        This can allow all auto-imported to have access to your flake level args.
      '';
      type = with lib.types; nullOr unspecified;
      default = defaults.flakeArgs;
      defaultText = lib.literalExpression "defaults.flakeArgs";
      example = lib.literalExpression "localFlake";
    };
  };
}
