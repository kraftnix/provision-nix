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
in {
  options.flake = flake-parts-lib.mkSubmoduleOptions {
    docs = {
      enable = mkEnableOption "enable docs integration";
      sites = mkOption {
        description = "mdbook sites to generate";
        type = types.attrsOf (types.submoduleWith {
          specialArgs = {
            inherit self localFlake;
          };
          modules = [./site.nix];
        });
        default = {};
      };
    };
  };

  config.perSystem = {
    config,
    pkgs,
    lib,
    ...
  }: {
    packages = lib.mkMerge (flatten [
      # populate `docs-options-{name}-base`
      # initial options doc generation with filtering of options
      (lib.pipe cfg.sites [
        filterEnable
        (mapAttrsToList (
          _: site:
            mapAttrsToList (name: opt: {
              "docs-options-${site.name}-${name}-base" =
                (pkgs.nixosOptionsDoc {
                  options = removeAttrs opt.hostOptions ["_module"];
                  transformOptions = option:
                    option
                    // {
                      visible = option.visible && (opt.filter option);
                    };
                })
                .optionsCommonMark;
            }) (filterEnable site.docgen)
        ))
        flatten
      ])

      # populate `docs-options-{name}-filtered`
      # substitute `/nix/store/XXXX` with `/`
      # substitute source url with specified `gitRepoFilePath`
      (lib.pipe cfg.sites [
        filterEnable
        (mapAttrsToList (
          _: site:
            mapAttrsToList (name: opt: {
              "docs-options-${site.name}-${name}-filtered" = let
                ## Very Hacky sed replacements for internal modules
                # escape args for usage with `sed`
                escapedNixStorePath = replaceStrings ["/"] ["\\/"] opt.substitution.outPath;
                escapedSiteRootPath = replaceStrings ["/" "."] ["\\/" "\\."] opt.substitution.gitRepoFilePath;

                # `sed` filters
                removeNixStorePath = "s/${escapedNixStorePath}\\///";
                substituteSiteRoot = "s/file:\\/\\/${escapedNixStorePath}\\//${escapedSiteRootPath}/";
              in
                pkgs.stdenvNoCC.mkDerivation {
                  name = "docs-mdbook-${site.name}";
                  buildInputs = [pkgs.gnused];
                  src = config.packages."docs-options-${site.name}-${name}-base";
                  unpackPhase = ''
                    cp $src .
                  '';
                  buildPhase = ''
                    runHook preBuild
                    sed '${removeNixStorePath}' ${config.packages."docs-options-${site.name}-${name}-base"} > path-filtered.md
                    sed '${substituteSiteRoot}' path-filtered.md > link-filtered.md
                    cp link-filtered.md $out
                    runHook postBuild
                  '';
                };
            }) (filterEnable site.docgen)
        ))
        flatten
      ])

      # populate `docs-mdbook-{name}-preprocessed`
      # pre mdbook generation
      #  - put generated options docs in `{mdbook.path}/options`
      #  - replace `intro.md` with toplevel `README.md` and cat `intro-continued.md` to it
      (mapAttrs' (_: site:
        nameValuePair "docs-mdbook-${site.name}-preprocessed" (pkgs.stdenvNoCC.mkDerivation {
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
              name: opt: ''cp ${config.packages."docs-options-${site.name}-${name}-filtered"} "$out/$DOCS_PATH/options/${opt.out.name}"''
            ) (filterEnable site.docgen))}
            runHook postBuild
          '';
        })) (filterEnable cfg.sites))

      # populate `docs-mdbook-{name}`
      # mdbook build site
      #  - use hacky homepage link injection
      #  - apply overrides for correct self linking
      (mapAttrs' (_: site:
        nameValuePair "docs-mdbook-${site.name}" (pkgs.stdenvNoCC.mkDerivation {
          name = "docs-mdbook-${site.name}";
          buildInputs = [
            pkgs.ripgrep
            pkgs.mdbook-linkcheck
            # pkgs.mdbook-cmdrun
            pkgs.nushell
            localFlake.self.packages.${pkgs.system}.mdbook-linkfix
            localFlake.self.packages.${pkgs.system}.yapp
            localFlake.self.packages.${pkgs.system}.simple-replace
            # config.packages.mdbook-theme
          ];
          src = config.packages."docs-mdbook-${site.name}-preprocessed";
          HOMEPAGE_URL = site.homepage.url;
          HOMEPAGE_BODY = site.homepage.body;
          MDBOOK_OUTPUT__HTML__SITE_URL = site.homepage.siteBase;
          DOCS_PATH = toString site.mdbook.path;
          buildPhase = ''
            runHook preBuild

            cd ${site.mdbook.path}

            # Could also be solved if mdBooks supported custom handlebars templates
            # Injecting an env var can probably be done by mdbook-cmdrum inside .md files
            # hacky way to inject a link back to a homepage, styled in the same way as the Summary items
            if [[ -n "$HOMEPAGE_URL" ]]; then
              local search='<!--HACKY_HOMEPAGE_REPLACE-->'
              local replace="<ol class=\"chapter\"><li class=\"part-title\"><a href=\"$HOMEPAGE_URL\">$HOMEPAGE_BODY</a></li></ol>"
              simple-replace $search "$replace" .
            fi

            mdbook build --dest-dir "$TMPDIR/out/$DOCS_PATH"
            cp -r "$TMPDIR/out/$DOCS_PATH/html" $out

            runHook postBuild
          '';
          dontInstall = true;
        })) (filterEnable cfg.sites))
    ]);
  };
}
