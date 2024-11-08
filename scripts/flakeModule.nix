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
  opts = localFlake.self.lib.options;
in {
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption ({
      config,
      pkgs,
      ...
    }: {
      _file = ./flakeModule.nix;
      options.scripts = {
        pkgs = mkOption {
          description = "Nixpkgs used to generate script. Influences shell runtime.";
          type = types.pkgs;
          default = {};
          defaultText = literalExpression "pkgs";
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
              inherit (config.scripts) defaultShell defaultLibDirs pkgs;
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
          default = filterAttrs (_: c: c.enable) config.scripts.scripts;
          description = "enabled scripts";
          readOnly = true;
        };
      };
    });
  };

  config = {
    transposition.scripts = {};
    perSystem = {
      config,
      pkgs,
      ...
    }: {
      scripts.pkgs = pkgs;
      packages =
        lib.mkIf config.scripts.addToPackages
        (lib.mapAttrs (_: c: c.package) config.scripts.__enabledScripts);
    };
  };
}
