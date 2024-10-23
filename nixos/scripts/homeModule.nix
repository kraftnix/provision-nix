{self, ...}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) filterAttrs mapAttrsToList mkIf mkOption pipe types;
  cfg = config.provision.scripts;
  opts = self.lib.options;
in {
  options.provision.scripts = {
    enable = opts.enable "enable smartd (smartmontools) hard drive monitoring/testing";
    addToHomePackages = opts.enableTrue "add all enabled scripts to `environment.systemPackages`";
    defaultShell = opts.string "nu" "set default shell for all scripts";
    defaultLibDirs = mkOption {
      type = with types; nullOr path;
      description = "optional script lib dir set for all nushell scripts";
      default = null;
    };
    scripts = mkOption {
      type = types.attrsOf (types.submoduleWith {
        modules = [
          ../scripts/module.nix
          {
            config._module.args = {
              inherit (cfg) defaultShell defaultLibDirs;
              inherit opts pkgs;
            };
          }
        ];
      });
      default = {};
      description = "scripts";
    };
    __enabledScripts = mkOption {
      default = filterAttrs (_: c: c.enable) cfg.scripts;
      description = "enabled scripts";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = mkIf cfg.addToHomePackages (mapAttrsToList (_: c: c.package) cfg.__enabledScripts);
  };
}
