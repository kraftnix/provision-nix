localFlake: {self, ...}: let
  inherit
    (localFlake.lib)
    concatStringsSep
    filterAttrs
    flatten
    mapAttrsToList
    replaceStrings
    ;
  cfg = self.docs;
in {
  imports = [./options.nix ./shell.nix];

  config = {
    perSystem = {
      config,
      pkgs,
      lib,
      ...
    }: {
      packages = lib.mkMerge (flatten [
        # populate `options-{name}-base`
        # initial options doc generation with filtering of options
        (lib.pipe cfg.options [
          (mapAttrsToList (name: opt: {
            "options-${name}-base" = let
              optionsDoc = pkgs.nixosOptionsDoc {
                options = removeAttrs opt.hostOptions ["_module"];
                transformOptions = option:
                  option
                  // {
                    visible = option.visible && (opt.filter option);
                  };
              };
            in
              pkgs.runCommand "options-${name}-base.md" {} ''
                cat ${optionsDoc.optionsCommonMark} >> $out
              '';
          }))
          flatten
        ])

        # populate `options-{name}-filtered`
        # substitute `/nix/store/XXXX` with `/`
        # substitute source url with specified `gitRepoFilePath`
        (lib.pipe cfg.options [
          (mapAttrsToList (name: opt: {
            "options-${name}-filtered" = let
              ## Very Hacky sed replacements for internal modules
              # escape args for usage with `sed`
              escapedNixStorePath = replaceStrings ["/"] ["\\/"] opt.substitution.outPath;
              escapedSiteRootPath = replaceStrings ["/" "."] ["\\/" "\\."] opt.substitution.gitRepoFilePath;

              # `sed` filters
              removeNixStorePath = "s/${escapedNixStorePath}\\///";
              substituteSiteRoot = "s/file:\\/\\/${escapedNixStorePath}\\//${escapedSiteRootPath}/";
            in
              pkgs.runCommand "filter-opts-common-mark" {} ''
                ${pkgs.gnused}/bin/sed '${removeNixStorePath}' ${config.packages."options-${name}-base"} > path-filtered.md
                ${pkgs.gnused}/bin/sed '${substituteSiteRoot}' path-filtered.md > link-filtered.md
                cp link-filtered.md $out
              '';
          }))
          flatten
        ])

        # populate `docs-mdbook-{name}-preprocessed`
        # pre mdbook generation
        #  - put generated options docs in `{mdbook.path}/options`
        #  - replace `intro.md` with toplevel `README.md` and cat `intro-continued.md` to it
        (let
          site.name = "site";
        in {
          "docs-mdbook-${site.name}-preprocessed" = pkgs.stdenvNoCC.mkDerivation {
            name = "docs-mdbook-${site.name}-preprocessed";
            nativeBuildInputs = [pkgs.nushell];
            src = pkgs.lib.cleanSourceWith {
              src = cfg.mdbook.src;
              # filter = path: type: baseNameOf (toString path) != "nix";
            };
            DOCS_PATH = toString cfg.mdbook.path;
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
              } <${self.outPath + "/README.md"} >./$DOCS_PATH/intro.md
              cp ./$DOCS_PATH/intro.md $out/$DOCS_PATH
              mkdir -p "$out/$DOCS_PATH/options"
              ${concatStringsSep "\n" (mapAttrsToList (
                name: opt: ''cp ${config.packages."options-${name}-filtered"} "$out/$DOCS_PATH/options/${opt.out.name}"''
              ) (filterAttrs (_: opt: opt.enable) cfg.options))}
              runHook postBuild
            '';
          };
        })

        # populate `docs-mdbook-{name}`
        # mdbook build site
        #  - use hacky homepage link injection
        #  - apply overrides for correct self linking
        (let
          site.name = "site";
        in {
          "docs-mdbook-${site.name}" = pkgs.stdenvNoCC.mkDerivation {
            name = "docs-mdbook-${site.name}";
            nativeBuildInputs = [
              pkgs.ripgrep
              pkgs.mdbook-linkcheck
              pkgs.mdbook-cmdrun
              pkgs.nushell
              config.packages.mdbook-linkfix
              config.packages.yapp
              config.packages.simple-replace
              # config.packages.mdbook-theme
            ];
            src = config.packages."docs-mdbook-${site.name}-preprocessed";
            HOMEPAGE_URL = cfg.homepage.url;
            HOMEPAGE_BODY = cfg.homepage.body;
            MDBOOK_OUTPUT__HTML__SITE_URL = cfg.homepage.siteBase;
            buildPhase = ''
              runHook preBuild

              cd ${cfg.mdbook.path}

              # Could also be solved if mdBooks supported custom handlebars templates
              # Injecting an env var can probably be done by mdbook-cmdrum inside .md files
              # hacky way to inject a link back to a homepage, styled in the same way as the Summary items
              if [[ -n "$HOMEPAGE_URL" ]]; then
                local search='<!--HACKY_HOMEPAGE_REPLACE-->'
                local replace="<ol class=\"chapter\"><li class=\"part-title\"><a href=\"$HOMEPAGE_URL\">$HOMEPAGE_BODY</a></li></ol>"
                simple-replace $search "$replace" .
              fi

              mdbook build --dest-dir $TMPDIR/out/${cfg.mdbook.path}
              cp -r $TMPDIR/out/${cfg.mdbook.path}/html $out

              runHook postBuild
            '';
            dontInstall = true;
          };
        })
      ]);
    };
  };
}
