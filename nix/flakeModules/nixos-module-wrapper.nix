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
  options = {
    flake = mkSubmoduleOptions {
      __provision = {
        nixosModules = {
          dir = mkOption {
            type = with types; nullOr path;
            default = null;
            example = ../../nixos/modules;
            description = "If set, modules are raked and imported into `nixosModules`";
          };
          flakeArgs = mkOption {
            type = with types; nullOr unspecified;
            default = null;
            example = args;
            description = "If set, first argument for imported modules is this arg set";
          };
          filterByPath = mkOption {
            type = with types; listOf (listOf str);
            default = [];
            description = "list of attr path lists in `nixosModules'` to remove from `nixosModulesAll`";
            example = [
              ["virt" "microvm" "vm"]
            ];
          };
          filterPathCompat = mkOption {
            type = types.bool;
            default = true;
            description = "performs compat filter for renamed nixosModules'";
          };
          all = mkOption {
            type = with types; listOf raw;
            default = lib.attrValues (self.nixosModules);
            description = "all nixos modules from `nixosModules'` before being filtered by `filterAll`";
          };
        };
      };
      nixosModulesAll = mkOption {
        type = types.listOf types.unspecified;
        default = [];
        description = ''
          A list of all home modules.
        '';
      };
      nixosModules' = mkOption {
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
        description = ''
          NixOS modules.

          You may use this for reusable pieces of nixos configuration, modules, etc.
        '';
      };
      modules = mkOption {
        type = types.lazyAttrsOf types.raw;
        default = {};
        # apply = lib.recursiveUpdate (self.nixosModules // { default = lib.attrValues self.nixosModules; });
        description = ''
          NixOS modules set, less strict that `flake.nixosModules` since it can be anything.
          Used to allow arbitrary nixosModule attrsets for exporting, to allow for grouping.

          Always adds a `default` entry which contains all modules in `flake.nixosModules` in a list.
          Always adds the rest of the modules in `nixosModules`.
        '';
      };
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
