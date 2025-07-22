{
  inputs,
  self,
  ...
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    filterAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    optional
    types
    ;
  cfg = config.provision;
  ncfg = config.provision.nvfetcher;
  enabledSources = filterAttrs (_: c: c.enable) ncfg.sources;
  nvfetcherModule =
    { config, name, ... }:
    {
      options.enable = mkEnableOption "Enable nvfetcher integration for ${name}" // {
        default = ncfg.enable;
      };
      options.name = mkOption {
        default = name;
        type = types.str;
        description = "name of source";
      };
      options.baseDir = mkOption {
        default = "./nix/packages";
        type = types.str;
        description = "path to sources base dir, used for setting default locations.";
      };
      options.sourcesToml = mkOption {
        default = "${config.baseDir}/sources.toml";
        type = types.str;
        description = "path to `sources.toml`";
      };
      options.sourcesDir = mkOption {
        default = "${config.baseDir}/_sources";
        type = types.str;
        description = "path to sources dir with `generated.{nix,json}`";
      };
      options.sourcesScript = mkOption {
        default = ''
          echo "Updating nvfetcher: ${config.name}, sourceFile: ${config.sourcesToml}, sourceDir: ${config.sourcesDir}"
          nvfetcher -c ${config.sourcesToml} -o ${config.sourcesDir} "$@"
        '';
        type = types.str;
        description = "script string to run for sourcing";
      };
    };
in
{
  options.provision = {
    enable = mkEnableOption "Enable default provision devshell.";
    nvfetcher = mkOption {
      default = { };
      type = types.submodule {
        options = {
          enable = mkEnableOption "Enable nvfetcher integration";
          sources = mkOption {
            default = { };
            description = "sources to pull from";
            type = types.attrsOf (types.submodule nvfetcherModule);
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    packages = [ ] ++ (optional ncfg.enable pkgs.nvfetcher);
    commands = [
      {
        category = "deploy";
        package = inputs.deploy-rs.packages.${pkgs.system}.default;
      }
      {
        category = "deploy";
        package = inputs.colmena.packages.${pkgs.system}.colmena;
      }
    ]
    ++ (optional (enabledSources != { }) {
      category = "ops";
      name = "sources";
      help = "Update all nvfetcher sources, i.e. [${
        concatStringsSep ", " (mapAttrsToList (_: c: c.name) ncfg.sources)
      }]";
      command = concatStringsSep "\n" (mapAttrsToList (_: c: c.sourcesScript) ncfg.sources);
    })
    ++ (mapAttrsToList (_: c: {
      category = "ops";
      name = "sources-${c.name}";
      help = "Source ${c.name}: nvfetcher update from `${c.sourcesToml}` to `${c.sourcesDir}`";
      command = c.sourcesScript;
    }) enabledSources);
  };
}
