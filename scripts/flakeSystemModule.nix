{self, ...}: {
  lib,
  flake-parts-lib,
  ...
}: let
  inherit
    (lib)
    filterAttrs
    mkOption
    types
    ;
  inherit
    (flake-parts-lib)
    mkTransposedPerSystemModule
    ;
  opts = self.lib.options;
in
  mkTransposedPerSystemModule {
    name = "scripts";
    option = mkOption {
      type = types.submodule ({config, ...}: {
        options = {
          pkgs = mkOption {
            default = {};
            description = ''
              Must be set in `perSystem` to `pkgs`:

              ```ni`
              perSystem = { pkgs, ... }: {
                scripts.pkgs = pkgs;
              };
              ```
            '';
          };
          addToPackages = opts.enableTrue "adds all scripts to flake's `packages.<system>`";
          defaultShell = opts.string "nu" "set default shell for all scripts";
          defaultLibDirs = mkOption {
            type = with types; nullOr path;
            description = "optional script lib dir set for all nushell scripts";
            default = null;
          };
          scripts = mkOption {
            type = types.attrsOf (types.submoduleWith {
              modules = [
                ./module.nix
                {
                  config._module.args = {
                    inherit (config) defaultShell defaultLibDirs pkgs;
                    inherit opts;
                  };
                }
              ];
            });
            default = {};
            description = "scripts";
          };
          __enabledScripts = mkOption {
            default = filterAttrs (_: c: c.enable) config.scripts;
            description = "enabled scripts";
          };
        };
      });
      default = {};
      description = "scripts";
    };
    file = ./flakeSystemModule.nix;
  }
