localFlake: {
  self,
  flake-parts-lib,
  ...
}: let
  inherit
    (localFlake.lib)
    concatStringsSep
    filterAttrs
    flatten
    literalExpression
    mapAttrs
    mapAttrs'
    mapAttrsToList
    mkEnableOption
    mkOption
    nameValuePair
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
    config,
    pkgs,
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
        };

        config = let
          site = cfg.sites.${siteConfig.name};
        in {
          docgen =
            mapAttrs (name: opt: rec {
            }) (filterEnable site.docgen);

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
            src = config.mdbook-pre;
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
  config.perSystem = {
    config,
    pkgs,
    lib,
    ...
  }: {
    sites = mapAttrs (_: site: {}) (filterEnable cfg.sites);
    packages = mapAttrs' (name: site: nameValuePair "docs-mdbook-${name}" site.mdbook) config.sites;
  };
}
