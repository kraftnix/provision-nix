{
  perSystem = {
    config,
    pkgs,
    lib,
    ...
  }: {
    devshells.default.packages = [
      pkgs.caddy
      pkgs.ripgrep
      pkgs.mdbook-linkcheck
      # pkgs.mdbook-cmdrun
      config.packages.yapp
      config.packages.mdbook-linkfix
      config.packages.mdbook-variables
      # config.packages.mdbook-theme
    ];
    devshells.default.commands =
      lib.flatten (lib.mapAttrsToList (name: site: [
          {
            help = "run caddy file-server for docs site: ${name} (dev)";
            name = "build-and-serve-${name}";
            category = "docs";
            command = ''
              #!/usr/bin/env bash
              set -e

              SITE_ROOT=$(nix build $PRJ_ROOT#docs-mdbook-${name} --no-link --print-out-paths)
              echo "Running: $SITE_ROOT"
              caddy file-server --root "$SITE_ROOT" --listen :8937 --debug
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
}
