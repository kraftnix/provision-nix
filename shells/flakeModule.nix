localFlake:
{ lib, flake-parts-lib, ... }:
let
  inherit (lib)
    literalExpression
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optionalAttrs
    optionalString
    types
    ;
in
{
  imports = [
    localFlake.inputs.devshell.flakeModule
    localFlake.inputs.git-hooks-nix.flakeModule
  ];
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      { config, ... }:
      let
        cfg = config.provision;
        fcfg = config.provision.formatter;
      in
      {
        _file = ./flakeModule.nix;
        options.provision = mkOption {
          description = ''
            Provision shells module.

            Allows configuring `formatter`, `pre-commit` and `devshells.default`.
          '';
          type = types.submodule {
            options = {
              enable = mkEnableOption "enable provision-nix shell";
              enableDefaults = mkEnableOption "enables pre-commit hook + a default formatter";
              deploy = mkOption {
                default = { };
                description = "Configure which deploy packages to add.";
                type = types.submodule {
                  options = {
                    enable = mkEnableOption "enable adding deploy packages" // {
                      default = true;
                    };
                    packages = mkOption {
                      description = "packages to add to devshell";
                      default = [ ];
                      type = with types; listOf package;
                      example = literalExpression ''
                        [ inputs.colmena.packages.$\{pkgs.stdenv.hostPlatform.system}.colmena ]
                      '';
                    };
                  };
                };
              };
              formatter = mkOption {
                description = ''
                  Configure default formatter for flake, optionally add as a pre-commit hook.
                '';
                default = { };
                type = types.submodule (
                  { config, ... }:
                  {
                    options = {
                      enable = mkEnableOption "enable setting formatter" // {
                        default = config.name != "";
                      };
                      enablePreCommit = mkEnableOption "adds formatter to pre-commit hook";
                      name = mkOption {
                        description = "optional formatter package to use, attempts to infer from `name`.";
                        default = optionalString cfg.enableDefaults "nixfmt";
                        type = types.str;
                      };
                      package = mkOption {
                        description = "optional formatter package to use, attempts to infer from `name`.";
                        default = null;
                        type = with types; nullOr package;
                      };
                    };
                  }
                );
              };
              pre-commit = {
                enable = mkEnableOption "enable pre-commit hooks integration from `git-hooks.nix`" // {
                  default = cfg.enableDefaults;
                };
                formatHook = mkOption {
                  default =
                    if fcfg.name == "nixfmt" then
                      {
                        nixfmt.enable = true;
                      }
                    else if fcfg.name == "alejandra" then
                      {
                        alejandra.enable = true;
                      }
                    else if fcfg.name == "nixfmt-classic" then
                      {
                        nixfmt-classic.enable = true;
                      }
                    else
                      { };
                  type = types.attrsOf types.raw;
                  description = "format hook from `provision.formatter` option";
                };
                hooks = mkOption {
                  default = { };
                  description = "hooks to passthrough to `pre-commit.settings.hooks`";
                  type = types.attrsOf types.raw;
                };
              };
            };
          };
          default = { };
          example = literalExpression ''
            {
              enable = true;
              # enableDefaults = true;
              formatter = {
                enable = true;
                name = "alejandra";
                enablePreCommmit = true;
              };
              pre-commit.hooks.nil.enable = true;
            }
          '';
        };
      }
    );
  };

  config = {
    transposition.provision = { };
    perSystem =
      { config, system, ... }:
      let
        pkgs = localFlake.inputs.nixpkgs.legacyPackages.${system};
        cfg = config.provision;
        pcfg = config.provision.pre-commit;
        fcfg = config.provision.formatter;
      in
      {
        pre-commit = mkIf (cfg.enable && pcfg.enable) { settings.hooks = pcfg.hooks; };
        formatter = mkIf (cfg.enable && fcfg.enable) fcfg.package;
        provision = {
          deploy.packages = mkDefault [
            localFlake.inputs.colmena.packages.${system}.colmena
            localFlake.inputs.deploy-rs.packages.${system}.deploy-rs
            pkgs.nix-fast-build
            pkgs.nixfmt-tree
          ];
          formatter = {
            enablePreCommit = mkDefault cfg.enableDefaults;
            package =
              if (fcfg.name == "nixfmt-rfc-style") || (fcfg.name == "nixfmt") then
                pkgs.nixfmt
              else if fcfg.name == "alejandra" then
                pkgs.alejandra
              else if fcfg.name == "nixfmt-classic" then
                pkgs.nixfmt-classic
              else
                null;
          };
          pre-commit = {
            enable = cfg.enableDefaults;
            hooks = mkMerge [
              (optionalAttrs fcfg.enablePreCommit pcfg.formatHook)
              { nil.enable = cfg.enableDefaults; }
            ];
          };
        };
        devshells.default = {
          imports = [ localFlake.self.devshellModules.provision ];
          devshell.startup.pre-commit = mkIf pcfg.enable { text = config.pre-commit.installationScript; };
          # na-install.enable = true;
          packages =
            config.pre-commit.settings.enabledPackages ++ (lib.optionals cfg.deploy.enable cfg.deploy.packages);
        };
      };
  };
}
