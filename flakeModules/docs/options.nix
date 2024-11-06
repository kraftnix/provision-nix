{
  self,
  lib,
  flake-parts-lib,
  ...
}: let
  inherit
    (lib)
    mkEnableOption
    mkOption
    types
    ;
  cfg = self.docs;
  optionsModule = types.submodule ({config, ...}: {
    options = {
      enable = mkEnableOption "enable options docs generation" // {default = true;};
      hostOptions = mkOption {
        default = cfg.defaults.hostOptions;
        type = types.lazyAttrsOf types.raw;
        description = "host to use for options evaluation";
      };
      filter = mkOption {
        default = _: true;
        type = types.functionTo types.bool;
        description = "filter to apply to options";
      };
      substitution = {
        outPath = mkOption {
          default = cfg.defaults.substitution.outPath;
          description = "outPath of the flake, used for rewriting /nix/store/ hardlinks in generated output from mkOptionsDoc";
          type = types.path;
        };
        gitRepoFilePath = mkOption {
          default = cfg.defaults.substitution.gitRepoFilePath;
          description = ''
            Base URL of git repo file browser, used for rewriting urls to source to the correct URL
          '';
          example = "https://github.com/kraftnix/provision-nix/tree/master/";
          type = types.str;
        };
      };
      out.name = mkOption {
        description = "name of markdown file containing options";
        default = "${config._module.args.name}-options.md";
        type = types.str;
      };
    };
  });
in {
  options = {
    flake = flake-parts-lib.mkSubmoduleOptions {
      defaults = {
        hostOptions = mkOption {
          default =
            (import (self.nixosConifugations.basic.pkgs.path + "/nixos/lib/eval-config.nix") {
              # Overriden explicitly here, this would include all modules from NixOS otherwise.
              # See: docs of eval-config.nix for more details
              baseModules = [];
              modules = [];
            })
            .options;
          type = types.lazyAttrsOf types.raw;
          description = "default options to use for documentation generation";
        };
        substitution = {
          outPath = mkOption {
            default = self.outPath;
            description = "outPath of the flake, used for rewriting /nix/store/ hardlinks in generated output from mkOptionsDoc";
            type = types.path;
          };
          gitRepoFilePath = mkOption {
            default = "";
            description = ''
              Base URL of git repo file browser, used for rewriting urls to source to the correct URL
            '';
            example = "https://github.com/kraftnix/provision-nix/tree/master/";
            type = types.str;
          };
        };
      };
      docs = {
        enable = mkEnableOption "enable docs integration";
        options = mkOption {
          description = "nixos option sets to generate";
          type = types.attrsOf optionsModule;
          default = {};
        };
        mdbook.src = mkOption {
          description = "source directory of mdBook documentation";
          type = types.path;
          default = ../../docs;
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
          };
          body = mkOption {
            description = "HTML Snippet inside <a> link used in documentation to point to home page.";
            type = types.str;
            default = "Home";
          };
          siteBase = mkOption {
            description = "Base URL of docs";
            type = types.str;
            default = "/";
            example = "/projects/provision-nix/";
          };
        };
      };
    };
  };
}
