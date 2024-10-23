{
  config,
  lib,
  pkgs,
  opts,
  defaultShell,
  defaultLibDirs,
  ...
}: let
  inherit (lib) filterAttrs mapAttrsToList mkOption optionalString pipe types;
  getNuFiles = dir:
    pipe dir [
      (builtins.readDir)
      (filterAttrs (name: ftype: (lib.hasSuffix ".nu" name) && (ftype == "regular")))
      (mapAttrsToList (name: _: name))
    ];
  makeEnv = name: dir:
    builtins.toFile "provision-scripts-${name}-env.nu" (
      lib.concatStringsSep "\n" (map (n: "source ${dir}/${n}") (getNuFiles dir))
    );
in {
  options = {
    enable = opts.enableTrue "enable script";
    name = opts.string config._module.args.name "script name";
    file = mkOption {
      default = builtins.toFile "${config.name}.nu" config.text;
      type = types.path;
      description = "optionally set script file path, recommended for script files which only contain a single main";
    };
    nuLibDirs = mkOption {
      type = with types; nullOr path;
      description = "sets NU_LIB_DIRS in nushell scripts";
      default = defaultLibDirs;
    };
    nuModule = mkOption {
      type = with types; nullOr path;
      description = "optional nu module wrapper, very basic wrapper that exports a module to be called from cli";
      default = null;
    };
    nuLegacyModule = mkOption {
      type = with types; nullOr path;
      description = "optional nu legacy module wrapper";
      default = null;
    };
    text =
      opts.string
      (
        if config.nuLegacyModule == null
        then ""
        else ''
          # wrapper script around nu module at ${config.nuModule}
          def main [
            ...userArgs              # user provided arguments to module
            --debug(-d)              # print command before running
            --escapedArgs(-e) = ""   #
          ] {
            let command = $"
              source ${config.nuModule}
              overlay use ${config.name}
              ${config.name} ($userArgs | append $escapedArgs | str join ' ')
            "
            if $debug { print $"Running command: (ansi yellow)($command)(ansi reset)" }
            nu --env-config ${makeEnv config.name config.nuLibDirs} -c $command
          }
        ''
      ) "nushell script";
    shell = mkOption {
      type = types.str;
      default = defaultShell;
      description = "runtime shell of script";
    };
    checkPhase = mkOption {
      type = with types; nullOr str;
      default =
        if lib.hasPrefix "nu" config.shell
        then ""
        else null;
      description = "setting of `writeShellApplication`, if null runs a default bash one";
    };
    runtimeShell =
      opts.package
      (
        if lib.hasPrefix "nu" config.shell
        then pkgs.nushell
        else if config.shell == "zsh"
        then pkgs.zsh
        else if config.shell == "sh"
        then pkgs.sh
        else pkgs.bash
      ) "shell package";
    inputs = mkOption {
      type = with types; listOf package;
      default = [];
      description = "runtime inputs to add to script";
    };
    env = mkOption {
      type = with types; nullOr (attrsOf str);
      default = null;
      description = "runtime env to provide to script";
    };
    extraConfig = mkOption {
      type = with types; attrsOf raw;
      default = {};
      description = "extra config to add to `writeShellApplication";
    };
    package =
      opts.package
      (
        if lib.hasPrefix "nu" config.shell
        then
          (
            if config.nuModule != null
            then
              pkgs.writeShellApplication
              ({
                  inherit (config) name checkPhase;
                  runtimeInputs = [config.runtimeShell] ++ config.inputs;
                  runtimeEnv = config.env;
                  text = ''
                    command=$(cat << EOM
                      source ${config.nuModule}
                      ${config.name} ''${@}
                    EOM
                    )
                    nu ${
                      optionalString (config.nuLibDirs != null)
                      "--env-config ${makeEnv config.name config.nuLibDirs}"
                    } -c "$command"
                  '';
                }
                // config.extraConfig)
            else
              pkgs.writeTextFile {
                inherit (config) name;
                executable = true;
                destination = "/bin/${config.name}";
                #!${config.runtimeShell}/bin/${config.shell} --env-config ${makeEnv config.name config.nuLibDirs}
                # source ${makeEnv config.name config.nuLibDirs}
                text = ''
                  #!${config.runtimeShell}/bin/${config.shell}
                  ${optionalString (config.env != null) ''
                    load-env (open ${builtins.toFile "${config.name}-env.json" (builtins.toJSON config.env)})
                  ''}
                  ${optionalString (config.inputs != []) ''
                    $env.PATH = ($env.PATH | append ${lib.makeBinPath config.inputs})
                  ''}
                  ${optionalString (config.nuLibDirs != null) ''
                    $env.NU_LIB_DIRS = ($env.NU_LIB_DIRS | append ${config.nuLibDirs})
                  ''}

                  ## imported from ${config.file}

                  ${builtins.readFile config.file}
                '';
                meta.mainProgram = config.name;
              }
          )
        else
          pkgs.writeShellApplication ({
              inherit (config) name checkPhase text;
              runtimeInputs = [config.runtimeShell] ++ config.inputs;
              runtimeEnv = config.env;
            }
            // config.extraConfig)
      ) "package binary for running script";
  };
}
