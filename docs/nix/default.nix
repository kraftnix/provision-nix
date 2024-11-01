{self, ...}: {
  imports = [./options.nix];
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    packages.docs-site-options = pkgs.stdenvNoCC.mkDerivation {
      name = "docs-site-options";
      nativeBuildInputs = [pkgs.nushell];
      src = pkgs.lib.cleanSourceWith {
        src = ./../..;
        filter = path: type: baseNameOf (toString path) != "nix";
      };
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
          cat ./docs/intro-continued.md
        } <${self.outPath + "/README.md"} >./docs/intro.md
        cp ./docs/intro.md $out/docs
        mkdir -p $out/docs/options
        cp ${config.packages.options-filtered} $out/docs/options/nixos-options.md
        runHook postBuild
      '';
    };
    packages.docs-site = pkgs.stdenvNoCC.mkDerivation {
      name = "docs-site";
      nativeBuildInputs = [
        pkgs.mdbook-linkcheck
        config.packages.mdbook-linkfix
        # config.packages.mdbook-theme
      ];
      src = config.packages.docs-site-options;
      # MDBOOK_OUTPUT__HTML__SITE_URL = "/projects/provision-nix/";
      buildPhase = ''
        runHook preBuild

        cd docs
        mdbook build --dest-dir $TMPDIR/out/docs
        cp -r $TMPDIR/out/docs/html $out

        runHook postBuild
      '';
      dontInstall = true;
    };
    devshells.default.packages = [
      pkgs.caddy
      pkgs.mdbook-linkcheck
      config.packages.mdbook-linkfix
      # config.packages.mdbook-theme
    ];
    devshells.default.commands = [
      {
        help = "run caddy file-server for docs site (dev)";
        name = "build-and-serve-docs";
        command = "caddy file-server --root `nix build $PRJ_ROOT#docs-site --no-link --print-out-paths` --listen :8937";
      }
      {
        help = "run caddy file-server for docs site (dev)";
        name = "serve-docs";
        command = "caddy file-server --root $PRJ_ROOT/result --listen :8937";
      }
      {
        help = "run mdbook serve for docs site";
        name = "watch-docs-md-only";
        command = "mdbook serve --port 8937 $PRJ_ROOT/docs";
      }
    ];
  };
}
