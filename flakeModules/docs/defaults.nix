localFlake@{ self, ... }:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) literalExpression mkOption types;
in
{
  options = {
    nuscht-search = {
      baseHref = mkOption {
        description = "The directory to where the search is going to be deployed relative to the domain. Defaults to /.";
        default = "/";
        type = types.str;
        example = "/search/";
      };
      title = mkOption {
        description = "The title on the top left. Defaults to NüschtOS Search.";
        default = "Custom Options Search";
        type = types.str;
      };
      customTheme = mkOption {
        description = "Custom theme file that replaces `styles.scss` in upstream package";
        default = null;
        type = with types; nullOr pathInStore;
        example = literalExpression ''
          pkgs.writeText "styles.scss" ''''''
            @import "theme";
            @include theme();
            @import "scss/kanagawa";

            :root {
              --f-color: hsl(214, 41.1%, 78.0%); // lightsteelblue
            }

            * {
              box-sizing: border-box;
              background: #101010;
            }

            pre {
              white-space: pre-wrap;
            }
          ''''''
        '';
      };
    };
    hostOptions = mkOption {
      description = "default options to use for documentation generation";
      type = types.lazyAttrsOf types.raw;
      default = { };
      defaultText = literalExpression ''
        (import (localFlake.inputs.nixpkgs.outPath + "/nixos/lib/eval-config.nix") {
          # Overriden explicitly here, this would include all modules from NixOS otherwise.
          # See: docs of eval-config.nix for more details
          modules = [];
        })
        .options;
      '';
      example = literalExpression "self.nixosConfigurations.myhost.options";
    };
    substitution = {
      outPath = mkOption {
        description = "outPath of the flake, used for rewriting /nix/store/ hardlinks in generated output from mkOptionsDoc";
        type = types.pathInStore;
        default = self.outPath;
        example = literalExpression "self.outPath";
      };
      gitRepoUrl = mkOption {
        description = ''
          URL of git repo, you need to set this.
        '';
        type = lib.mkOptionType {
          name = "string (not empty)";
          inherit (lib.types.str) descriptionClass merge;
          check = x: (lib.types.str.check x) && (x != "");
          description = "non-empty string";
        };
        default = "http://gitea.local.testing";
        example = "https://github.com/kraftnix/provision-nix";
      };
      gitRepoFilePath = mkOption {
        description = ''
          Base URL of git repo file browser, used for rewriting urls to source to the correct URL
        '';
        type = types.str;
        default = "${config.substitution.gitRepoUrl}/tree/master";
        example = "https://github.com/kraftnix/provision-nix/tree/master/";
      };
    };
  };
}
