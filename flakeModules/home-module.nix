{
  self,
  lib,
  flake-parts-lib,
  moduleLocation,
  ...
} @ args: let
  inherit
    (lib)
    concatStringsSep
    mapAttrsRecursive
    mkOption
    types
    ;
  inherit
    (flake-parts-lib)
    importApply
    mkSubmoduleOptions
    ;

  stringOrConcat = val:
    if builtins.typeOf val == "string"
    then val
    else concatStringsSep "." val;

  checkImported = as: !(as ? "_file");
  homeModuleLists =
    lib.mapAttrsRecursiveCond
    checkImported
    (path: c: [c])
    self.homeModules;
  homeModulesAll = lib.flatten (lib.collect lib.isList homeModuleLists);
in {
  options = {
    flake = mkSubmoduleOptions {
      homeModulesDir = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = ../../home/modules;
        description = "If set, modules are raked and imported into `homeModules`";
      };
      homeModulesFlakeArgs = mkOption {
        type = types.nullOr types.unspecified;
        default = null;
        # example = args;
        description = "If set, first argument for imported modules is this arg set";
      };
      homeModulesAll = mkOption {
        type = types.listOf types.unspecified;
        default = [];
        description = ''
          A list of all home modules.
        '';
      };
      homeModules = mkOption {
        type = types.lazyAttrsOf types.unspecified;
        default = {};
        apply = mapAttrsRecursive (k: v: {
          _file = "${toString moduleLocation}#homeModules.${stringOrConcat k}";
          # class = "homeManager";
          imports =
            if self.homeModulesFlakeArgs == null
            then [v]
            else (importApply v args).imports;
          # imports = (importApply v args).imports;
          # imports = [ v ];
        });
        description = ''
          Home modules.

          You may use this for reusable pieces of home-manager configuration, modules, etc.
        '';
      };
    };
  };

  config.flake = {
    homeModules =
      lib.mkIf
      (self.homeModulesDir != null)
      (self.inputs.extra-lib.lib.nix.rakeLeaves self.homeModulesDir);
    homeModulesAll = homeModulesAll;
  };
}
