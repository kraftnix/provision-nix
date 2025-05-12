{
  config,
  lib,
  class,
  localFlake,
  moduleLocation,
  ...
}:
let
  inherit (lib)
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
  originalPath = path: c: singleton (nameValuePair (concatStringsSep "." path) c);
  nixosModuleNameFilters = pipe cfg.filterByPath [
    (map (concatStringsSep "-"))
  ];
  filterNixosModules = filterAttrs (name: cfg: !(elem name nixosModuleNameFilters));
  flattenedNixosModules = lib.pipe cfg.modules [
    (lib.filterAttrsRecursive cfg.filterModules)
    (mapAttrsRecursiveCond builtins.isAttrs genPath)
    (collect isList)
    flatten
    lib.listToAttrs
  ];
  flattenedNixosModules' = lib.pipe cfg.moduleFiles [
    (lib.filterAttrsRecursive cfg.filterModules)
    (mapAttrsRecursiveCond builtins.isAttrs (
      path: file:
      originalPath path {
        inherit path;
        module = file;
      }
    ))
    (collect isList)
    flatten
    lib.listToAttrs
  ];
in
{
  options = {
    dir = mkOption {
      description = "If set, modules are raked and imported into `modules.nixos`";
      type = with types; nullOr path;
      default = null;
      example = literalExpression "./nixosModules";
    };
    moduleFiles = mkOption {
      description = ''
        Nix files raked from {dir}
      '';
      type = types.lazyAttrsOf types.raw;
      default = { };
    };
    modules = mkOption {
      description = ''
        Auto-imported ${class} modules from `./dir`

        Optionally add entries _(unfiltered)_ to `${class}Modules` or `modules.${class}` (flake-parts extra module).
      '';
      type = types.lazyAttrsOf types.raw;
      default = { };
      apply = mapAttrsRecursive (k: v: if cfg.flakeArgs == null then v else import v cfg.flakeArgs);
    };
    modulesFlat = mkOption {
      description = ''
        Ready-to-import modules, extra args like `_file` set (using {genImport})
      '';
      type = types.attrsOf (
        types.submodule (
          { config, name, ... }:
          {
            options = {
              addToAll = mkOption {
                description = "add the module to {all}, enabled by default";
                default = true;
                type = types.bool;
              };
              name = mkOption {
                description = "module name";
                default = name;
                type = types.str;
              };
              nameDashed = mkOption {
                description = "name with '-' instead of '.' path, used for adding to ${class}Modules";
                default = lib.replaceStrings [ "." ] [ "-" ] config.name;
                type = types.str;
              };
              path = mkOption {
                description = "file path of module relative to import dir";
                default = lib.splitString "." config.name;
                type = types.listOf types.str;
              };
              specialArgs = mkOption {
                description = "path to module";
                default = null;
                type = types.nullOr types.unspecified;
              };
              module = mkOption {
                description = "path to module file, or inline module snippet";
                default = { };
                type =
                  with types;
                  oneOf [
                    path
                    raw
                    (functionTo raw)
                    (functionTo (functionTo raw))
                  ];
              };
              key = mkOption {
                description = "{key} to use in final import";
                default = "${toString moduleLocation}#${cfg.class}Modules.${config.name}";
                type = types.str;
              };
              _file = mkOption {
                description = "{_file} to use in final import";
                default = if builtins.typeOf config.module == "path" then config.module else config.key;
                type = types.path;
              };
              _class = mkOption {
                description = "{_class} to use in final import";
                default = cfg.class;
                type = types.str;
              };
              imports = mkOption {
                description = "{imports} to use in final import";
                default = [ ];
                defaultText = lib.literalExpression ''
                  if config.specialArgs == null
                    then [ config.module ]
                    else [ (import config.module config.specialArgs) ]
                    ;
                '';
                type = types.listOf types.raw;
              };
              __final = mkOption {
                description = "final importable module";
                default = { };
                type = types.raw;
                defaultText = lib.literalExpression ''
                  { inherit (config) key _file _class imports; }
                '';
              };
            };
            config = {
              imports =
                if config.specialArgs == null then
                  [ config.module ]
                else
                  [ (import config.module config.specialArgs) ];
              specialArgs = cfg.flakeArgs;
              __final = {
                inherit (config)
                  key
                  _file
                  _class
                  imports
                  ;
              };
            };
          }
        )
      );
      default = { };
    };
    modulesNew = mkOption {
      description = ''
        Ready-to-import modules, extra args like `_file` set (using {genImport})
      '';
      type = types.lazyAttrsOf types.raw;
      default = { };
    };
    modules' = mkOption {
      description = ''
        Ready-to-import modules, extra args like `_file` set (using {genImport})
      '';
      type = types.lazyAttrsOf types.raw;
      default = { };
    };
    filterByPath = mkOption {
      description = "list of attr path lists in `modules'` to remove from {all}";
      type = with types; listOf (listOf str);
      default = [ ];
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
        key = "${toString moduleLocation}#${class}Modules.${n}";
        _file = c;
        _class = class;
        imports = [ c ];
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
      default = [ ];
      defaultText = literalExpression "[]";
      # readOnly = true;
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
    # modules = mkIf (cfg.dir != null) (localFlake.inputs.extra-lib.lib.nix.rakeLeaves cfg.dir);
    modules = mkIf (cfg.dir != null) (localFlake.inputs.extra-lib.lib.nix.rakeLeaves cfg.dir);
    moduleFiles = mkIf (cfg.dir != null) (localFlake.inputs.extra-lib.lib.nix.rakeLeaves cfg.dir);
    modules' = mapAttrs cfg.genImport cfg.__flattened;
    modulesFlat = flattenedNixosModules';
    modulesNew = lib.pipe cfg.modulesFlat [
      builtins.attrValues
      (map (mod: {
        inherit (mod) path;
        update = _: mod.__final;
      }))
      (mods: lib.updateManyAttrsByPath mods { })
    ];
    all = lib.pipe cfg.modulesFlat [
      builtins.attrValues
      (lib.filter (m: !(elem m.path cfg.filterByPath)))
      (map (mod: mod.__final))
    ];
  };
}
