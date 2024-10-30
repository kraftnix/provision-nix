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
        src = ./..;
        filter = path: type: baseNameOf (toString path) != "nix";
      };
      buildPhase = ''
        runHook preBuild

        cp -r . $out
        {
          <!-- THIS FILE IS GENERATED, NO CHANGES IN GIT WILL BE APPLIED -->
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
          cat intro-continued.md
        } <${self.outPath + "/README.md"} >./intro.md
        cp ./intro.md $out/
        mkdir -p $out/options
        cp ${config.packages.options-filtered} $out/options/nixos-options.md
        runHook postBuild
      '';
    };
    packages.docs-site = pkgs.stdenvNoCC.mkDerivation {
      name = "docs-site";
      nativeBuildInputs = [config.packages.mdbook-linkfix pkgs.mdbook-linkcheck];
      src = config.packages.docs-site-options;
      buildPhase = ''
        runHook preBuild

        mdbook build --dest-dir $TMPDIR/out
        cp -r $TMPDIR/out/html $out

        runHook postBuild
      '';
      dontInstall = true;
    };
    devshells.default.packages = [
      pkgs.mdbook
      pkgs.mdbook-linkcheck
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
