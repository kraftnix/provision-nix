{
  self,
  lib,
  flake-parts-lib,
  moduleLocation,
  ...
} @ args: let
  inherit
    (lib)
    attrValues
    collect
    concatStringsSep
    elem
    filterAttrs
    filterAttrsRecursive
    flatten
    hasAttrByPath
    isList
    listToAttrs
    literalExpression
    mapAttrsRecursive
    mapAttrsRecursiveCond
    mkOption
    nameValuePair
    pipe
    singleton
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
  nixosModuleLists =
    mapAttrsRecursiveCond
    checkImported
    (path: c: [c])
    self.nixosModules';
  nixosModulesAll = flatten (collect isList nixosModuleLists);

  genPath = path: c: singleton (nameValuePair (concatStringsSep "-" path) c);
  pathedNixosModules =
    mapAttrsRecursiveCond
    checkImported
    genPath
    # (path: c: [{
    #   inherit path c;
    # }])
    self.nixosModules';
  flattenAttrLists = modules: flatten (collect isList modules);
  # flattenedNixosModules = flatten (collect isList pathedNixosModules);
  flattenedNixosModules = flatten (collect isList pathedNixosModules);
  # flattenedNixosModules' = flattenAttrLists pathedNixosModules;
  # flattenedNixosModules =
  #   mapAttrsRecursive
  #     (path: value: concatStringsSep "-" (path ++ [value]))
  #     self.nixosModules'
  #   ;

  # nixosModuleNameFilters = pipe self.nixosModules' [
  #   (mapAttrsRecursiveCond checkImported (path: c: [ (genPath path c ) ]))
  #   flattenAttrLists
  #   (map (a: a.name))
  # ];
  nixosModuleNameFilters = pipe self.__provision.nixosModules.filterByPath [
    (map (concatStringsSep "-"))
  ];
in {
  options.flake = mkSubmoduleOptions {
    __provision = {
      nixosModules = {
        dir = mkOption {
          description = "If set, modules are raked and imported into `nixosModules`";
          type = with types; nullOr path;
          default = null;
          example = literalExpression "./nixosModules";
        };
        flakeArgs = mkOption {
          description = ''
            When set to null, modules are imported purely by path.
            Otherwise, all imported modules are mapped through `import {module} {flakeArgs}`.

            This can allow all auto-imported to have access to your flake level args.
          '';
          type = with types; nullOr unspecified;
          default = null;
          example = literalExpression "localFlake";
        };
        filterByPath = mkOption {
          description = "list of attr path lists in `nixosModules'` to remove from `nixosModulesAll`";
          type = with types; listOf (listOf str);
          default = [];
          example = literalExpression ''
            [
              ["virt" "microvm" "vm"]
            ]
          '';
        };
        filterPathCompat = mkOption {
          description = "performs compat filter for renamed nixosModules'";
          type = types.bool;
          default = true;
          example = false;
        };
        all = mkOption {
          description = "all nixos modules from `nixosModules'` before being filtered by `filterAll`";
          type = with types; listOf raw;
          default = lib.attrValues (self.nixosModules);
          readOnly = true;
        };
      };
    };
    nixosModulesAll = mkOption {
      description = ''
        A list of all home modules.
      '';
      type = types.listOf types.unspecified;
      default = [];
    };
    nixosModules' = mkOption {
      description = ''
        NixOS modules.

        You may use this for reusable pieces of nixos configuration, modules, etc.
      '';
      type = types.lazyAttrsOf types.unspecified;
      default = {};
      apply = mapAttrsRecursive (
        k: v:
          if self.__provision.nixosModules.flakeArgs == null
          then {
            _file = toString v;
            # class = "nixos";
            imports = [v];
          }
          else {
            _file = toString v;
            # class = "nixos";
            imports = [(import v self.__provision.nixosModules.flakeArgs)];
          }
      );
    };
    modules = mkOption {
      description = ''
        NixOS modules set, less strict that `flake.nixosModules` since it can be anything.
        Used to allow arbitrary nixosModule attrsets for exporting, to allow for grouping.

        Always adds a `default` entry which contains all modules in `flake.nixosModules` in a list.
        Always adds the rest of the modules in `nixosModules`.
      '';
      type = types.lazyAttrsOf types.raw;
      default = {};
      # apply = lib.recursiveUpdate (self.nixosModules // { default = lib.attrValues self.nixosModules; });
    };
  };

  config.flake = {
    # __test = nixosModuleNameFilters;
    # __test2 = flattenedNixosModules;
    # flake-parts nixosModules compat: flattens nested modules into path separated "-"
    modules = listToAttrs flattenedNixosModules;
    nixosModules = lib.listToAttrs flattenedNixosModules;
    nixosModules' =
      lib.mkIf
      (self.__provision.nixosModules.dir != null)
      (self.inputs.extra-lib.lib.nix.rakeLeaves self.__provision.nixosModules.dir);
    nixosModulesAll = lib.pipe self.modules [
      # (filterAttrsRecursive (path: mod: ! (hasAttrByPath path self.__provision.nixosModules.filterByPath)) )
      (filterAttrs (name: cfg: ! (elem name nixosModuleNameFilters)))
      attrValues
    ];
  };
}
