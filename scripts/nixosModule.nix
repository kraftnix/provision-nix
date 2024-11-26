localFlake:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    literalExpression
    mapAttrsToList
    mkIf
    mkOption
    types
    ;
  cfg = config.provision.scripts;
in
{
  options.provision.scripts = mkOption {
    description = ''
      Generate scripts from different shells from string snippets, files, or nushell modules.

      Enabled scripts are added to `environment.systemPackages` by name if `scripts.addToPackages` is set.
    '';
    type = types.submoduleWith {
      specialArgs.pkgs = pkgs;
      modules = [ (import ./submodule.nix localFlake) ];
    };
    default = { };
    example = literalExpression ''
      {
        provision.scripts = {
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
      }
    '';
  };

  config = {
    provision.scripts.pkgs = pkgs;
    environment.systemPackages = mkIf (cfg.enable && cfg.addToPackages) (
      mapAttrsToList (_: c: c.package) cfg.__enabledScripts
    );
  };
}
