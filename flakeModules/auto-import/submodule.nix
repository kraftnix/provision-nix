{
  config,
  lib,
  class,
  localFlake,
  moduleLocation,
  ...
}: let
  inherit
    (lib)
    attrValues
    collect
    concatStringsSep
    elem
    hasPrefix
    filterAttrs
    flatten
    isList
    literalExpression
    mapAttrs
    mapAttrsRecursive
    mapAttrsRecursiveCond
    mkIf
    mkOption
    nameValuePair
    pipe
    singleton
    types
    ;
  cfg = config;
  genPath = path: c: singleton (nameValuePair (concatStringsSep "-" path) c);
  nixosModuleNameFilters = pipe cfg.filterByPath [
    (map (concatStringsSep "-"))
  ];
  filterNixosModules = filterAttrs (name: cfg: ! (elem name nixosModuleNameFilters));
  flattenedNixosModules = lib.pipe cfg.modules [
    (lib.filterAttrsRecursive cfg.filterModules)
    (mapAttrsRecursiveCond builtins.isAttrs genPath)
    (collect isList)
    flatten
    lib.listToAttrs
  ];
in {
  options = {
    dir = mkOption {
      description = "If set, modules are raked and imported into `modules.nixos`";
      type = with types; nullOr path;
      default = null;
      example = literalExpression "./nixosModules";
    };
    modules = mkOption {
      description = ''
        Auto-imported ${class} modules from `./dir`

        Optionally add entries _(unfiltered)_ to `${class}Modules` or `modules.${class}` (flake-parts extra module).
      '';
      type = types.lazyAttrsOf types.raw;
      default = {};
      apply = mapAttrsRecursive (
        k: v:
          if cfg.flakeArgs == null
          then v
          else import v cfg.flakeArgs
      );
    };
    modules' = mkOption {
      description = ''
        Ready-to-import modules, extra args like `_file` set (using {genImport})
      '';
      type = types.lazyAttrsOf types.raw;
      default = {};
    };
    filterByPath = mkOption {
      description = "list of attr path lists in `modules'` to remove from {all}";
      type = with types; listOf (listOf str);
      default = [];
      example = literalExpression ''
        [
          ["virt" "microvm" "vm"]
        ]
      '';
    };
    filterModules = mkOption {
      description = "If set, apply this filter function to auto-imported modules from {dir}";
      type = with types; functionTo (functionTo bool);
      default = n: c: !(hasPrefix "__" n);
      defaultText = literalExpression ''n: c: !(hasPrefix "__" n)'';
      example = literalExpression "_: _: true";
    };
    class = mkOption {
      description = "Class to set by default for imports";
      type = types.str;
      default = class;
      example = "homeManager";
    };
    genImport = mkOption {
      description = "";
      type = with types; functionTo (functionTo raw);
      default = n: c: {
        _file = "${toString moduleLocation}#${class}Modules.${n}";
        _class = class;
        imports = [c];
      };
      defaultText = ''
        n: c: {
          _file = "$\{toString moduleLocation}#$\{class}Modules.$\{n}";
          _class = class;
          imports = [c];
        }
      '';
    };
    all = mkOption {
      description = "all nixos modules from `nixosModules'` after being filtered by `filterAll`";
      type = with types; listOf raw;
      default = lib.pipe cfg.modules' [
        filterNixosModules
        attrValues
      ];
      defaultText = literalExpression "[]";
      readOnly = true;
    };
    __all = mkOption {
      description = "all nixos modules from `nixosModules'` before being filtered by `filterAll`";
      type = with types; listOf raw;
      default = lib.attrValues cfg.modules';
      defaultText = literalExpression "[]";
      readOnly = true;
      internal = true;
    };
    __flattened = mkOption {
      description = "all nixos modules from `nixosModules'` before being filtered by `filterAll`";
      type = with types; lazyAttrsOf raw;
      default = flattenedNixosModules;
      defaultText = literalExpression "{}";
      readOnly = true;
      internal = true;
    };
  };

  config = {
    modules =
      mkIf
      (cfg.dir != null)
      (localFlake.inputs.extra-lib.lib.nix.rakeLeaves cfg.dir);
    modules' = mapAttrs cfg.genImport cfg.__flattened;
  };
}
