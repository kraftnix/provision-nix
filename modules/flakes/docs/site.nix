{
  localFlake,
  self,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkOption
    types
    ;
in
{
  options = {
    enable = mkEnableOption "enable docs integration" // {
      default = true;
    };
    name = mkOption {
      description = "site name";
      type = types.str;
      default = config._module.args.name;
      example = "provision-nix";
    };
    defaults = mkOption {
      description = "default values to pass into sites";
      default = self.docs.defaults;
      defaultText = literalExpression ''
        {

          # use a host from your config and optionally pass extra modules
          hostOptions =
            (import (localFlake.self.nixosConfigurations.basic.pkgs.path + "/nixos/lib/eval-config.nix") {
              # Overriden explicitly here, this would include all modules from NixOS otherwise.
              # See: docs of eval-config.nix for more details
              modules = [];
            }).options;

          # set some nuscht-search defaults
          nuscht-search = {
            baseHref = "/";
            customTheme = null;
            title = "Custom Options Search";
          };

          # substitutions for nuscht-search and options references
          substitution = {
            gitRepoUrl = "https://github.com/kraftnix/provision-nix";

            # by default, adds "/tree/master" to `gitRepoUrl`
            # gitRepoFilePath = "https://github.com/kraftnix/provision-nix/tree/master";

            # by default: is set to current flake's outPath
            # outPath = self.outPath;
          };
        }
      '';
      type = types.submoduleWith {
        modules = [ (import ./defaults.nix localFlake) ];
      };
    };
    docgen = mkOption {
      description = ''
        Tranforms modules options into markdown files.

        Options from a host, or `evalModules` can be provided, and custom
        filters can be applied to generate only specific options.
      '';
      type = types.attrsOf (
        types.submoduleWith {
          specialArgs = {
            inherit (config) defaults;
          };
          modules = [ ./options.nix ];
        }
      );
      default = { };
      example = lib.literalExpression ''
        {
          filter = option:
            builtins.elemAt option.loc 0 == "networking"
            &&
            builtins.elemAt option.loc 1 == "nftables"
            ;
        }
      '';
    };
    mdbook.src = mkOption {
      description = "source directory of mdBook documentation, take care to use string interpolation to force path into nix store";
      type = types.path;
      default = config.defaults.substitution.outPath;
      defaultText = lib.literalExpression "$\{self.outPath}";
      example = literalExpression "$\{./.}";
    };
    mdbook.path = mkOption {
      description = "path in `src` where mdbook docs are located";
      type = types.str;
      default = "docs";
    };
    homepage = {
      url = mkOption {
        description = "Homepage of the website (for when siteBase is not at root)";
        type = types.str;
        default = "http://localhost:1111";
        example = "https://mydocswebsite.com";
      };
      body = mkOption {
        description = "HTML Snippet inside <a> link used in documentation to point to home page.";
        type = types.str;
        default = "Home";
        example = "Homepage";
      };
      siteBase = mkOption {
        description = "Base URL of docs";
        type = types.str;
        default = "/";
        example = "/projects/provision-nix/";
      };
    };
  };
}
