localFlake: {
  self,
  lib,
  flake-parts-lib,
  moduleLocation,
  ...
}: let
  inherit
    (lib)
    attrValues
    collect
    concatStringsSep
    elem
    filterAttrs
    flatten
    isList
    literalExpression
    mapAttrsRecursive
    mapAttrsRecursiveCond
    mkIf
    mkEnableOption
    mkOption
    nameValuePair
    pipe
    singleton
    types
    ;
  inherit
    (flake-parts-lib)
    mkSubmoduleOptions
    ;
  cfg = self.provision.nixos;
  genPath = path: c: singleton (nameValuePair (concatStringsSep "-" path) c);
  nixosModuleNameFilters = pipe cfg.filterByPath [
    (map (concatStringsSep "-"))
  ];
  filterNixosModules = filterAttrs (name: cfg: ! (elem name nixosModuleNameFilters));
  flattenedNixosModules = lib.pipe cfg.modules [
    (mapAttrsRecursiveCond builtins.isAttrs genPath)
    (collect isList)
    flatten
    lib.listToAttrs
  ];
in {
  options.flake = mkSubmoduleOptions {
    provision.nixos = {
      modules = mkOption {
        description = ''
          Auto-imported nixos modules from `./dir`

          NixOS modules set, less strict that `flake.nixosModules` since it can be recursiveAttrsOf config.
          Used to allow arbitrary nixosModule attrsets for exporting, to allow for grouping.

          Always adds an additional `default` module entry which contains all _(filtered)_ modules in {all}.
          Optionally add entries _(unfiltered)_ to `nixosModules` or `modules.nixos` (flake-parts extra module).
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
      addTo = {
        nixosModules = mkEnableOption "add {modules'} entries to {nixosModules}";
        fpModules = mkEnableOption "add {modules'} entries to {modules.nixos} (flake-parts extra module)";
      };
      dir = mkOption {
        description = "If set, modules are raked and imported into `modules.nixos`";
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
      };
    };
  };

  config.flake = {
    provision.nixos.modules =
      mkIf
      (cfg.dir != null)
      (localFlake.inputs.extra-lib.lib.nix.rakeLeaves cfg.dir);
    nixosModules' = cfg.modules';
    provision.nixos.modules' =
      lib.mapAttrs (n: c: {
        # _file = toString c;
        _file = "${toString moduleLocation}#nixosModules.${n}";
        class = "nixos";
        imports = [c];
      })
      flattenedNixosModules;
    modules.nixos = mkIf cfg.addTo.fpModules flattenedNixosModules;
    nixosModules = mkIf cfg.addTo.nixosModules flattenedNixosModules;
  };
}
