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
      options.scripts = mkOption {
        description = ''
          Generate scripts from different shells from string snippets, files, or nushell modules.

          Enabled scripts are added to `packages.{system}` by name if `scripts.addToPackages` is set.
        '';
        type = types.submoduleWith {
          specialArgs = {};
          modules = [(import ./submodule.nix localFlake)];
        };
        default = {};
        example = literalExpression ''
          {
            perSystem = { ... }: {
              scripts = {
                enable = true;
                addToPackages = true; # default
                defaultShell = "nu";  # default
                scripts = {
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
                };
              };
            };
          }
        '';
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
        lib.mkIf (config.scripts.enable && config.scripts.addToPackages)
        (lib.mapAttrs (_: c: c.package) config.scripts.__enabledScripts);
    };
  };
}
