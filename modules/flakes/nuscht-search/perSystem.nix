localFlake:
{ flake-parts-lib, ... }:
let
  inherit (localFlake.lib)
    literalExpression
    mapAttrs'
    mapAttrsToList
    mkEnableOption
    mkOption
    nameValuePair
    optionalAttrs
    optionalString
    types
    ;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      _file = ./perSystem.nix;
      options.nuscht-search = mkOption {
        description = ''
          Nüscht Search integration which combines all options in `docgen` into scopes

          Options from a host, or `evalModules` can be provided, and custom
          filters can be applied to generate only specific options.
        '';
        default = { };
        example = literalExpression ''
          my-search = {
            title = "My Custom Options Search";
            baseHref = "/search/";
            scopes = {
              customScope = {
                name = "NixOS Modules";
                modules = [ self.inputs.nixos-modules.nixosModule ];
                urlPrefix = "https://github.com/NuschtOS/nixos-modules/blob/main/";
              };
            };
          }
        '';
        type = types.attrsOf (
          types.submodule (
            {
              name,
              config,
              ...
            }:
            {
              options = {
                enable = mkEnableOption "enable nuscht-search generation" // {
                  default = true;
                };
                customTheme = mkOption {
                  description = "Custom theme file that replaces `styles.scss` in upstream package";
                  default = null;
                  type = with types; nullOr path;
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
                baseHref = mkOption {
                  description = "The directory to where the search is going to be deployed relative to the domain. Defaults to /.";
                  default = "/";
                  type = types.str;
                  example = "/search/";
                };
                title = mkOption {
                  description = "The title on the top left. Defaults to NüschtOS Search.";
                  default = "${name} Options Search";
                  type = types.str;
                };
                multiSearch = mkOption {
                  description = "final output of `mkMultiSearch`";
                  type = types.pathInStore;
                };
                scopes = mkOption {
                  default = { };
                  description = ''
                    an attrset of scope attributes which each takes name, modules, optionsJSON, optionsPrefix or urlPrefix option.
                    used as args for `mkMultiSearch`.

                    Automatically uses options from `docgen`.

                    see <https://github.com/NuschtOS/search?tab=readme-ov-file#explanation-of-options> for more information
                  '';
                  type = types.attrsOf (
                    types.submodule (
                      {
                        name,
                        config,
                        ...
                      }:
                      {
                        config = {
                          optionsJSON =
                            if config.optionsJSONPackage != null then
                              "${config.optionsJSONPackage}/share/doc/nixos/options.json"
                            else
                              null;
                        };
                        options = {
                          enable = mkEnableOption "enable inclusion of scope in module" // {
                            default = true;
                          };
                          name = mkOption {
                            description = "Scope name";
                            default = name;
                            type = types.str;
                            example = "Custom Search";
                          };
                          modules = mkOption {
                            description = "A list of NixOS modules as an attrset or file similar to the nixosSystem function. Exclusive with optionsJSON.";
                            default = null;
                            type = with types; nullOr (listOf raw);
                            example = literalExpression "[ self.inputs.nixos-modules.nixosModule ]";
                          };
                          optionsJSONPackage = mkOption {
                            description = "optional output of `pkgs.nixosOptionsDoc`";
                            default = null;
                            type = with types; nullOr package;
                          };
                          optionsJSON = mkOption {
                            description = "Path to a pre-generated options.json file. Exclusive with modules.";
                            default = null;
                            type = with types; nullOr path;
                            example = literalExpression "./path/to/options.json";
                          };
                          optionsPrefix = mkOption {
                            description = "A static prefix to append to all options. An extra dot is always appended. Defaults to being empty.";
                            default = null;
                            type = with types; nullOr str;
                            example = "programs.example";
                          };
                          urlPrefix = mkOption {
                            description = "The prefix which is prepended to the declaration link. This is usually a link to a git.";
                            default = "";
                            type = types.str;
                            example = "https://git.example.com/blob/main/";
                          };
                        };
                      }
                    )
                  );
                };
              };

              config =
                let
                  # inherit (localFlake.inputs.nuschtos-search.packages.${pkgs.system}) nuscht-search ixxPkgs;
                  inherit (localFlake.inputs.nuschtos-search.packages.${pkgs.system})
                    mkMultiSearch
                    ;
                  cfg = config;
                  nuschtos-pkgs = localFlake.inputs.nuschtos-search.inputs.nixpkgs.legacyPackages.${pkgs.system};

                in
                {
                  multiSearch =
                    (mkMultiSearch {
                      inherit (cfg) baseHref title;
                      scopes = mapAttrsToList (
                        _: c:
                        {
                          inherit (c) name modules urlPrefix;
                        }
                        // (optionalAttrs (c.optionsPrefix != null) {
                          inherit (c) optionsPrefix;
                        })
                        // (optionalAttrs (c.optionsJSON != null) {
                          inherit (c) optionsJSON;
                        })
                      ) cfg.scopes;
                    }).overrideAttrs
                      (oldAttrs: {
                        postPatch = oldAttrs.postPatch + ''
                          ${optionalString (cfg.customTheme != null) "cp ${cfg.customTheme} src/styles.scss"}
                        '';
                      });
                };
            }
          )
        );
      };
    }
  );

  config.transposition.nuscht-search = { };
  config.perSystem =
    { config, ... }:
    {
      packages = mapAttrs' (
        name: search: nameValuePair "nuscht-search-${name}" search.multiSearch
      ) config.nuscht-search;
    };
}
