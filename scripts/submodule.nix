localFlake: {
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    filterAttrs
    literalExpression
    mapAttrs
    mkOption
    removeAttrs
    types
    ;
  opts = localFlake.self.lib.options;
in {
  options = {
    enable = opts.enableTrue "enable scripts integration";
    pkgs = mkOption {
      description = "Nixpkgs used to generate script. Influences shell runtime.";
      type = types.pkgs;
      default = {};
      defaultText = literalExpression "pkgs";
    };
    addToPackages = opts.enableTrue ''
      adds all scripts to packages depending on module type
        - flake: `packages.{system}`
        - nixos: `environment.systemPackages`
        - home:  `home.packages`
    '';
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
        modules = [./script.nix];
      });
      default = {};
      description = ''
        Generate scripts from different shells from string snippets, files, or nushell modules.

        Enabled scripts are added to `packages.{system}` by name if `scripts.addToPackages` is set.
      '';
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
    __exportableScripts = mkOption {
      default = mapAttrs (_: c: removeAttrs c ["package"]) config.__enabledScripts;
      description = "enabled scripts, with some config removed, suitable for importing between scripts";
      readOnly = true;
    };
  };
}
