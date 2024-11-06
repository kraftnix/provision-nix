{
  localFlake,
  self,
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkEnableOption
    mkOption
    types
    ;
in {
  options = {
    enable = mkEnableOption "enable docs integration" // {default = true;};
    name = mkOption {
      description = "site name";
      type = types.str;
      default = config._module.args.name;
    };
    defaults = {
      hostOptions = mkOption {
        description = "default options to use for documentation generation";
        type = types.lazyAttrsOf types.raw;
        default =
          (import (localFlake.self.nixosConfigurations.basic.pkgs.path + "/nixos/lib/eval-config.nix") {
            # Overriden explicitly here, this would include all modules from NixOS otherwise.
            # See: docs of eval-config.nix for more details
            modules = [];
          })
          .options;
      };
      substitution = {
        outPath = mkOption {
          description = "outPath of the flake, used for rewriting /nix/store/ hardlinks in generated output from mkOptionsDoc";
          type = types.path;
          default = self.outPath;
        };
        gitRepoFilePath = mkOption {
          description = ''
            Base URL of git repo file browser, used for rewriting urls to source to the correct URL
          '';
          type = types.str;
          default = "";
          example = "https://github.com/kraftnix/provision-nix/tree/master/";
        };
      };
    };
    docgen = mkOption {
      description = "nixos option sets to generate";
      type = types.attrsOf (types.submoduleWith {
        specialArgs = {
          inherit (config) defaults;
        };
        modules = [./options.nix];
      });
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
}
