localFlake: {
  lib,
  flake-parts-lib,
  ...
}: let
  inherit
    (lib)
    filterAttrs
    literalExpression
    mkOption
    types
    ;
  inherit
    (flake-parts-lib)
    mkTransposedPerSystemModule
    ;
  opts = localFlake.self.lib.options;
in
  mkTransposedPerSystemModule {
    name = "scripts";
    option = mkOption {
      type = types.submodule ({config, ...}: {
        options = {
          pkgs = mkOption {
            description = ''
              Nixpkgs used to generate script.

              Influences shell runtime.
            '';
            type = types.pkgs;
            default = {};
            defaultText = literalExpression "{}";
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
              specialArgs = {
                inherit (config) defaultShell defaultLibDirs pkgs;
                inherit opts;
              };
              modules = [./module.nix];
            });
            default = {};
            description = "scripts to generate from text, file or nuModule";
            example = literalExpression ''
              {
                my-test-script.text = "ls -l";
                my-test-script-bash-test.shell = "bash";
                my-test-script-bash-test.text = "ls -la";
                my-test-script-env-has.inputs = [pkgs.afetch];
                my-test-script-env-has.text = '''
                  def main [ var ] {
                    print $"Env ($var) present: (envHas $var)"
                    afetch
                  }
                ''';
              }
            '';
          };
          __enabledScripts = mkOption {
            default = filterAttrs (_: c: c.enable) config.scripts;
            description = "enabled scripts";
            readOnly = true;
          };
        };
      });
      default = {};
      description = ''
        Generate scripts from different shells from string snippets, files, or nushell modules.

        Enabled scripts are added to `packages.{system}` by name if `scripts.addToPackages` is set.
      '';
      example = literalExpression ''
        {
          scripts = {
            scripts.my-test-script = "ps -l | sort-by cpu -r | take 5";
          };
          my-test-script.text = "ls -l";
          my-test-script-bash-test.shell = "bash";
          my-test-script-bash-test.text = "ls -la";
          my-test-script-env-has.inputs = [pkgs.afetch];
          my-test-script-env-has.text = '''
            def main [ var ] {
              print $"Env ($var) present: (envHas $var)"
              afetch
            }
          ''';
        }
      '';
    };
    file = ./flakeSystemModule.nix;
  }
