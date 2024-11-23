localFlake: {
  self,
  flake-parts-lib,
  ...
}: let
  inherit
    (localFlake.lib)
    concatStringsSep
    filterAttrs
    literalExpression
    mapAttrs
    mapAttrs'
    mapAttrsToList
    mkDefault
    mkEnableOption
    mkMerge
    mkOption
    nameValuePair
    optionalAttrs
    optionalString
    pipe
    replaceStrings
    types
    ;
  cfg = self.docs;
  filterEnable = filterAttrs (_: c: c.enable);
  docgenPackagesModule = {
    name,
    config,
    pkgs,
    siteConfig,
    ...
  }: {
    options = {
      outName = mkOption {
        default = "";
        type = types.str;
        description = "output name, used for package names / prefix";
      };
      docsout = mkOption {
        description = "`nixosOptionsDocs` output";
        type = with types; lazyAttrsOf raw;
        default = {};
      };
      filtered = mkOption {
        description = "filter `optionsCommonMark` output of {mkdocs}, removing file paths + fixing siteRoot links";
        type = types.package;
      };
    };
    config = let
      opt = cfg.sites.${siteConfig.name}.docgen.${name};
    in {
      outName = opt.out.name;
      docsout =
        removeAttrs
        (pkgs.nixosOptionsDoc {
          options = removeAttrs opt.hostOptions ["_module"];
          transformOptions = option:
            option
            // {
              visible = option.visible && (opt.filter option);
            };
        })
        ["optionsDocBook"];
      filtered = let
        ## Very Hacky sed replacements for internal modules
        # escape args for usage with `sed`
        escapedNixStorePath = replaceStrings ["/"] ["\\/"] opt.substitution.outPath;
        escapedSiteRootPath = replaceStrings ["/" "."] ["\\/" "\\."] opt.substitution.gitRepoFilePath;

        # `sed` filters
        removeNixStorePath = "s/${escapedNixStorePath}\\///";
        substituteSiteRoot = "s/file:\\/\\/${escapedNixStorePath}\\//${escapedSiteRootPath}/";
      in
        pkgs.stdenvNoCC.mkDerivation {
          name = "docs-options-${siteConfig.name}-${name}-filtered";
          buildInputs = [pkgs.gnused];
          src = config.docsout.optionsCommonMark;
          unpackPhase = ''
            cp $src options.md
          '';
          buildPhase = ''
            runHook preBuild
            sed '${removeNixStorePath}' options.md > path-filtered.md
            sed '${substituteSiteRoot}' path-filtered.md > link-filtered.md
            cp link-filtered.md $out
            runHook postBuild
          '';
        };
    };
  };
in {
  options.perSystem = flake-parts-lib.mkPerSystemOption ({
    pkgs,
    lib,
    ...
  }: {
    _file = ./perSystem.nix;
    options.sites = mkOption {
      description = "generated docs packages";
      default = {};
      type = types.attrsOf (types.submodule (siteConfig @ {
        config,
        name,
        ...
      }: {
        options = {
          docgen = mkOption {
            description = "option docs generated from `docs.sites.<site>.docgen`";
            default = {};
            type = types.attrsOf (types.submoduleWith {
              specialArgs = {inherit siteConfig pkgs;};
              modules = [docgenPackagesModule];
            });
          };
          mdbook-pre = mkOption {
            description = "mdbook with some preprocessing applied + docgen options copied in";
            type = types.package;
          };
          mdbook = mkOption {
            description = "mdbook build and some postprocessing";
            type = types.package;
          };
          nuschtos = mkOption {
            description = ''
              NuschtOS search integration which combines all options in `docgen` into scopes

              Options from a host, or `evalModules` can be provided, and custom
              filters can be applied to generate only specific options.
            '';
            type = types.submodule ({config, ...}: {
              options = {
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
                  default = "";
                  type = types.str;
                };
                multiSearch = mkOption {
                  description = "final output of `mkMultiSearch`";
                  type = types.package;
                };
                scopes = mkOption {
                  default = {};
                  description = ''
                    an attrset of scope attributes which each takes name, modules, optionsJSON, optionsPrefix or urlPrefix option.
                    used as args for `mkMultiSearch`.

                    Automatically uses options from `docgen`.

                    see <https://github.com/NuschtOS/search?tab=readme-ov-file#explanation-of-options> for more information
                  '';
                  type = types.attrsOf (types.submodule ({
                    name,
                    config,
                    ...
                  }: {
                    options = {
                      enable = mkEnableOption "enable inclusion of scope in module" // {default = true;};
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
                        default =
                          if config.optionsJSONPackage != null
                          then "${config.optionsJSONPackage}/share/doc/nixos/options.json"
                          else null;
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
                  }));
                };
              };
            });
            default = {};
            example = literalExpression ''
              {
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
          };
        };

        config = let
          site = cfg.sites.${siteConfig.name};
          # inherit (localFlake.inputs.nuschtos-search.packages.${pkgs.system}) nuscht-search ixxPkgs;
          inherit (localFlake.inputs.nuschtos-search.packages.${pkgs.system}) ixxPkgs mkSearchData mkMultiSearch;
        in {
          docgen =
            mapAttrs (name: opt: {
            }) (filterEnable site.docgen);

          nuschtos.customTheme = mkDefault site.defaults.nuschtos.customTheme;
          nuschtos.title = mkDefault site.defaults.nuschtos.title;
          nuschtos.baseHref = mkDefault site.defaults.nuschtos.baseHref;
          nuschtos.scopes = pipe config.docgen [
            # (filterAttrs (_: c: c.enable))
            (mapAttrs (n: c: {
              name = "${n} Options Search";
              optionsJSONPackage = c.docsout.optionsJSON;
              # optionsJSON = "${c.docsout.optionsJSON}/share/doc/nixos/options.json";
              urlPrefix = site.defaults.substitution.gitRepoUrl;
            }))
          ];
          # nuschtos.multiSearch = localFlake.inputs.nuschtos-search.packages.${pkgs.system}.mkMultiSearch {
          nuschtos.multiSearch = mkMultiSearch {
            inherit (config.nuschtos) baseHref title;
            nuscht-search = (pkgs.callPackage "${localFlake.inputs.nuschtos-search}/nix/frontend.nix" {}).overrideAttrs (oldAttrs: {
              postPatch =
                oldAttrs.postPatch
                + ''
                  ${optionalString (config.nuschtos.customTheme != null) "cp ${config.nuschtos.customTheme} src/styles.scss"}
                '';
            });
            scopes =
              mapAttrsToList (
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
              )
              config.nuschtos.scopes;
          };

          mdbook-pre = pkgs.stdenvNoCC.mkDerivation {
            name = "docs-mdbook-${site.name}-preprocessed";
            buildInputs = [pkgs.nushell];
            src = pkgs.lib.cleanSourceWith {
              src = site.mdbook.src;
              # filter = path: type: baseNameOf (toString path) != "nix";
            };
            DOCS_PATH = toString site.mdbook.path;
            buildPhase = ''
              runHook preBuild

              cp -r . $out
              {
                echo '<!-- THIS FILE IS GENERATED, NO CHANGES IN GIT WILL BE APPLIED -->'
                while read ln; do
                  case "$ln" in
                    *end_of_intro*)
                      break
                      ;;
                    *)
                      echo "$ln"
                      ;;
                  esac
                done
                cat ./$DOCS_PATH/intro-continued.md
              } <${site.defaults.substitution.outPath + "/README.md"} >./$DOCS_PATH/intro.md
              cp ./$DOCS_PATH/intro.md $out/$DOCS_PATH
              mkdir -p "$out/$DOCS_PATH/options"
              ${concatStringsSep "\n" (mapAttrsToList (
                  name: opt: ''cp ${opt.filtered} "$out/$DOCS_PATH/options/${opt.outName}"''
                )
                config.docgen)}
              runHook postBuild
            '';
          };

          mdbook = pkgs.stdenvNoCC.mkDerivation {
            name = "docs-mdbook-${site.name}";
            buildInputs = [
              pkgs.ripgrep
              pkgs.mdbook-linkcheck
              # pkgs.mdbook-cmdrun
              pkgs.nushell
              localFlake.self.packages.${pkgs.system}.mdbook-linkfix
              localFlake.self.packages.${pkgs.system}.mdbook-variables
              localFlake.self.packages.${pkgs.system}.yapp
              localFlake.self.packages.${pkgs.system}.simple-replace
              # config.packages.mdbook-theme
            ];
            # have to set as string or can't evaluate in nix repl
            src = "${config.mdbook-pre}";
            HOMEPAGE_URL = site.homepage.url;
            HOMEPAGE_BODY = site.homepage.body;
            DOCSITE_BASE = "${site.homepage.url}${site.homepage.siteBase}";
            MDBOOK_OUTPUT__HTML__SITE_URL = site.homepage.siteBase;
            DOCS_PATH = toString site.mdbook.path;
            GIT_REPO_FILE_BASE = site.defaults.substitution.gitRepoFilePath;
            buildPhase = ''
              runHook preBuild

              cd ${site.mdbook.path}

              # Could also be solved if mdBooks supported custom handlebars templates
              # Injecting an env var can probably be done by mdbook-cmdrum inside .md files
              # hacky way to inject a link back to a homepage, styled in the same way as the Summary items
              if [[ -n "$HOMEPAGE_URL" ]]; then
                local search='<!--HACKY_HOMEPAGE_REPLACE-->'
                local replace="<ol class=\"chapter\"><li class=\"part-title homepage-url\"><a href=\"$HOMEPAGE_URL\">$HOMEPAGE_BODY</a></li></ol>"
                simple-replace $search "$replace" .
              fi

              simple-replace '<--DOCSITE_BASE-->' "$DOCSITE_BASE" .
              simple-replace '<--GIT_REPO_FILE_BASE-->' "$GIT_REPO_FILE_BASE" .

              mdbook build --dest-dir "$TMPDIR/out/$DOCS_PATH"
              cp -r "$TMPDIR/out/$DOCS_PATH/html" $out

              runHook postBuild
            '';
            dontInstall = true;
          };
        };
      }));
    };
  });

  config.transposition.sites = {};
  config.perSystem = {config, ...}: {
    sites = mapAttrs (_: site: {}) (filterEnable cfg.sites);
    packages = mkMerge [
      (mapAttrs' (name: site: nameValuePair "docs-mdbook-${name}" site.mdbook) config.sites)
      (mapAttrs' (name: site: nameValuePair "docs-nuschtos-${name}" site.nuschtos.multiSearch) config.sites)
      {
      }
    ];
  };
}
