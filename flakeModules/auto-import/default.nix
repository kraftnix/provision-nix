localFlake:
{
  self,
  lib,
  flake-parts-lib,
  moduleLocation,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkIf
    mkEnableOption
    mkOption
    types
    ;
  cfg = self.auto-import;
  defaultOpts = (import ./options.nix { inherit lib; }).options;
  genSpecialArgs = class: {
    inherit class localFlake moduleLocation;
    defaults = {
      inherit (cfg) flakeArgs addTo;
    };
  };
  flattenModules = lib.mapAttrs' (_: m: lib.nameValuePair m.nameDashed m.__final);
in
{
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
          modules = [
            ./submodule.nix
            ./options.nix
          ];
        };
        default = { };
      };
      flake = mkOption {
        description = ''
          Auto-imported flake-parts modules from {dir}
        '';
        type = types.submoduleWith {
          specialArgs = genSpecialArgs "flake";
          modules = [
            ./submodule.nix
            ./options.nix
          ];
        };
        default = { };
      };
      homeManager = mkOption {
        description = ''
          Auto-imported home-manager modules from {dir}
        '';
        type = types.submoduleWith {
          specialArgs = genSpecialArgs "homeManager";
          modules = [
            ./submodule.nix
            ./options.nix
          ];
        };
        default = { };
      };
    };
  };

  config.flake = {
    homeManagerModules = mkIf (cfg.enable && cfg.homeManager.addTo.modules) (
      flattenModules cfg.homeManager.flattened
    );
    nixosModules = mkIf (cfg.enable && cfg.nixos.addTo.modules) (flattenModules cfg.nixos.flattened);
    flakeModules =
      if (cfg.enable && cfg.flake.addTo.modules) then
        flattenModules cfg.flake.flattened
      else
        mkDefault { };

    modules = mkIf cfg.enable {
      nixos = mkIf cfg.nixos.addTo.flakeParts (flattenModules cfg.nixos.flattened);
      flake = mkIf cfg.flake.addTo.flakeParts (flattenModules cfg.flake.flattened);
      homeManager = mkIf cfg.homeManager.addTo.flakeParts (flattenModules cfg.homeManager.flattened);
    };
  };
}
