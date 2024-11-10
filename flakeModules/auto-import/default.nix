localFlake: {
  self,
  lib,
  flake-parts-lib,
  moduleLocation,
  ...
}: let
  inherit
    (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;
  cfg = self.auto-import;
  defaultOpts = (import ./options.nix {inherit lib;}).options;
  genSpecialArgs = class: {
    inherit class localFlake moduleLocation;
    defaults = {inherit (cfg) flakeArgs addTo;};
  };
in {
  options.flake = flake-parts-lib.mkSubmoduleOptions {
    auto-import = {
      enable = mkEnableOption "enable auto-importing modules";
      addTo = defaultOpts.addTo;
      flakeArgs = defaultOpts.flakeArgs;
      nixos = mkOption {
        description = ''
          Auto-imported nixos modules from {dir}

          NixOS modules set, less strict that `flake.nixosModules` since it can be recursiveAttrsOf config.
          Used to allow arbitrary nixosModule attrsets for exporting, to allow for grouping.
        '';
        type = types.submoduleWith {
          specialArgs = genSpecialArgs "nixos";
          modules = [./submodule.nix ./options.nix];
        };
        default = {};
      };
      flake = mkOption {
        description = ''
          Auto-imported flake-parts modules from {dir}
        '';
        type = types.submoduleWith {
          specialArgs = genSpecialArgs "flake";
          modules = [./submodule.nix ./options.nix];
        };
        default = {};
      };
      homeManager = mkOption {
        description = ''
          Auto-imported home-manager modules from {dir}
        '';
        type = types.submoduleWith {
          specialArgs = genSpecialArgs "homeManager";
          modules = [./submodule.nix ./options.nix];
        };
        default = {};
      };
    };
  };

  config.flake = {
    nixosModules = mkIf (cfg.enable && cfg.nixos.addTo.modules) cfg.nixos.__flattened;
    nixosModules' = mkIf cfg.enable cfg.nixos.modules';

    modules = mkIf cfg.enable {
      nixos = mkIf cfg.nixos.addTo.flakeParts cfg.nixos.__flattened;
      flake = mkIf cfg.flake.addTo.flakeParts cfg.flake.__flattened;
      homeManager = mkIf cfg.home.addTo.flakeParts cfg.homeManager.__flattened;
    };

    flakeModules = mkIf (cfg.enable && cfg.flake.addTo.modules) cfg.flake.modules';
    auto-import.flake.genImport = n: c: {
      key = "${toString moduleLocation}#flakeModules.${n}";
      _file = "${toString moduleLocation}#flakeModules.${n}";
      _class = "flake";
      imports = [c];
    };

    homeManagerModules = mkIf (cfg.enable && cfg.homeManager.addTo.modules) cfg.homeManager.modules';
  };
}