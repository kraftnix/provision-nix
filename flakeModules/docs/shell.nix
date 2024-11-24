localFlake: {
  perSystem = {
    config,
    pkgs,
    lib,
    ...
  }: {
    devshells.default = lib.mkIf localFlake.self.docs.enable {
      packages = [
        pkgs.caddy
        pkgs.ripgrep
        pkgs.mdbook-linkcheck
        pkgs.mdbook-variables
        # pkgs.mdbook-cmdrun
        localFlake.self.packages.${pkgs.system}.yapp
        localFlake.self.packages.${pkgs.system}.mdbook-linkfix
        # config.packages.mdbook-theme
      ];

      commands =
        lib.flatten (lib.mapAttrsToList (name: site: [
            {
              help = "run caddy file-server for docs site: ${name} (dev)";
              name = "build-and-serve-${name}-docs-only";
              category = "docs";
              command = ''
                #!/usr/bin/env bash
                set -e

                SITE_ROOT=$(nix build $PRJ_ROOT#docs-mdbook-${name} --no-link --print-out-paths)
                echo "Running: $SITE_ROOT"
                caddy file-server --root "$SITE_ROOT" --listen :8937 --debug
              '';
            }
            {
              # NOTE: this may not work well if `baseHref` is root `/`, expects `/search/`
              help = "run caddy file-server for docs site: ${name} (dev)";
              name = "build-and-serve-${name}";
              category = "docs";
              command = let
                mdbookRoot = "docs-mdbook-${name}";
                nuschtosRoot = "docs-nuschtos-${name}";
                sp = lib.strings.splitString "/" site.nuschtos.baseHref;
                stripped =
                  if builtins.stringLength site.nuschtos.baseHref > 1
                  then
                    lib.concatStringsSep "" (lib.map (s:
                      if s == ""
                      then "/"
                      else s) (lib.take (lib.length sp - 1) sp))
                  else site.nuschtos.baseHref;
                caddyfile = pkgs.writeText "Caddyfile.dev" ''
                  {
                    debug
                  }
                  :8937 {

                    # already full reload
                    header {
                      Cache-Control "no-cache, no-store, must-revalidate"
                      defer
                    }

                    rewrite ${stripped} ${stripped}/
                    handle_path ${site.nuschtos.baseHref}* {
                      root * {$NUSCHTOS_ROOT}
                      file_server
                    }
                    root * {$SITE_ROOT}
                    file_server
                  }
                '';
              in ''
                #!/usr/bin/env bash
                set -e

                export SITE_ROOT=$(nix build $PRJ_ROOT#${mdbookRoot} --no-link --print-out-paths)
                export NUSCHTOS_ROOT=$(nix build $PRJ_ROOT#${nuschtosRoot} --no-link --print-out-paths)
                echo "Running with:"
                echo "- SITE_ROOT: $SITE_ROOT"
                echo "- NUSCHTOS_ROOT: $NUSCHTOS_ROOT"
                caddy run --adapter caddyfile --config ${caddyfile}
              '';
            }
          ])
          config.sites)
        ++ [
          {
            help = "run caddy file-server for docs site (dev)";
            name = "serve-docs";
            category = "docs";
            command = "caddy file-server --root $PRJ_ROOT/result --listen :8937";
          }
          {
            help = "run mdbook serve for docs site";
            name = "watch-docs-md-only";
            category = "docs";
            command = "mdbook serve --port 8937 $PRJ_ROOT/docs";
          }
        ];
    };
  };
}
