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
    collect
    concatStringsSep
    elem
    filter
    filterAttrsRecursive
    flatten
    hasPrefix
    isList
    listToAttrs
    literalExpression
    mapAttrsRecursiveCond
    mkIf
    mkOption
    nameValuePair
    pipe
    singleton
    types
    updateManyAttrsByPath
    ;
  cfg = config;
  genPath = path: c: singleton (nameValuePair (concatStringsSep "." path) c);
in
{
  options = {
    dir = mkOption {
      description = "If set, modules are raked and imported into `modules.nixos`";
      type = with types; nullOr path;
      default = null;
      example = literalExpression "./nixosModules";
    };
    files = mkOption {
      description = ''
        A recursive attrSet of file paths containing ${class} modules
      '';
      type = types.lazyAttrsOf types.raw;
      default = { };
    };
    modules = mkOption {
      description = ''
        Ready-to-import modules
      '';
      type = types.lazyAttrsOf types.raw;
      default = { };
    };
    flattened = mkOption {
      description = ''
        attrSet containing all imported module definitions.
      '';
      default = { };
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
    };
    filterByPath = mkOption {
      description = "list of attr path lists in `modules` to remove from {all}";
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
    all = mkOption {
      description = "all nixos modules from `modules` after being filtered by `filterAll`";
      type = with types; listOf raw;
      default = [ ];
      defaultText = literalExpression "[]";
      # readOnly = true;
    };
  };

  config = {
    files = mkIf (cfg.dir != null) (localFlake.inputs.extra-lib.lib.nix.rakeLeaves cfg.dir);
    flattened = pipe cfg.files [
      (filterAttrsRecursive cfg.filterModules)
      (mapAttrsRecursiveCond builtins.isAttrs (
        path: file:
        genPath path {
          inherit path;
          module = file;
        }
      ))
      (collect isList)
      flatten
      listToAttrs
    ];
    modules = lib.pipe cfg.flattened [
      builtins.attrValues
      (map (mod: {
        inherit (mod) path;
        update = _: mod.__final;
      }))
      (mods: updateManyAttrsByPath mods { })
    ];
    all = lib.pipe cfg.flattened [
      builtins.attrValues
      (filter (m: !(elem m.path cfg.filterByPath)))
      (map (mod: mod.__final))
    ];
  };
}
