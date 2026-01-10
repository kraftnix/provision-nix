localFlake:
{ self, ... }: {
  perSystem = { config, system, lib, ... }:
    let pkgs = self.inputs.nixpkgs.legacyPackages.${system};
    in {
      devshells.default = lib.mkIf self.docs.enable {
        packages = [
          pkgs.caddy
          pkgs.ripgrep
          pkgs.mdbook
          # pkgs.mdbook-linkcheck
          localFlake.self.packages.${pkgs.stdenv.hostPlatform.system}.mdbook-linkcheck
          # pkgs.mdbook-variables
          localFlake.inputs.nixpkgs-mdbook-variables.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mdbook-variables
          # pkgs.mdbook-cmdrun
          # localFlake.self.packages.${pkgs.stdenv.hostPlatform.system}.yapp
        ];

        commands = lib.flatten (lib.mapAttrsToList (name: site: [
          {
            help = "run caddy file-server for docs site: ${name} (dev)";
            name = "build-and-serve-${name}-docs-only";
            category = "docs";
            command = ''
              #!/usr/bin/env bash
              set -e
              SITE_DOCS_ONLY_PORT="''${SITE_DOCS_ONLY_PORT:-8937}"

              SITE_ROOT=$(nix build $PRJ_ROOT#docs-mdbook-${name} --no-link --print-out-paths)
              echo "Running: $SITE_ROOT"
              caddy file-server --root "$SITE_ROOT" --listen :$SITE_DOCS_ONLY_PORT --debug
            '';
          }
          {
            # NOTE: this may not work well if `baseHref` is root `/`, expects `/search/`
            help = "run caddy file-server for docs site: ${name} (dev)";
            name = "build-and-serve-${name}";
            category = "docs";
            command = let
              mdbookRoot = "docs-mdbook-${name}";
              nuschtRoot = "nuscht-search-${name}";
              siteConfig = self.docs.sites.${name};
              sp = lib.strings.splitString "/"
                siteConfig.defaults.nuscht-search.baseHref;
              stripped = if builtins.stringLength
              siteConfig.defaults.nuscht-search.baseHref > 1 then
                lib.concatStringsSep "" (lib.map (s: if s == "" then "/" else s)
                  (lib.take (lib.length sp - 1) sp))
              else
                siteConfig.defaults.nuscht-search.baseHref;
              caddyfile = pkgs.writeText "Caddyfile.dev" ''
                {
                  debug
                  admin off
                }
                :8937 {

                  # already full reload
                  header {
                    Cache-Control "no-cache, no-store, must-revalidate"
                    defer
                  }

                  rewrite ${stripped} ${stripped}/
                  handle_path ${siteConfig.defaults.nuscht-search.baseHref}* {
                    root * {$NUSCHT_ROOT}
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
              export NUSCHT_ROOT=$(nix build $PRJ_ROOT#${nuschtRoot} --no-link --print-out-paths)
              echo "Running with:"
              echo "- SITE_ROOT: $SITE_ROOT"
              echo "- NUSCHT_ROOT: $NUSCHT_ROOT"
              caddy run --adapter caddyfile --config ${caddyfile}
            '';
          }
        ]) config.sites) ++ [
          {
            help = "run caddy file-server for docs site (dev)";
            name = "serve-docs";
            category = "docs";
            command =
              "caddy file-server --root $PRJ_ROOT/result --listen :8937";
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
