{
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    devshells.default.packages = [
      pkgs.caddy
      pkgs.ripgrep
      pkgs.mdbook-linkcheck
      pkgs.mdbook-cmdrun
      config.packages.yapp
      config.packages.mdbook-linkfix
      # config.packages.mdbook-theme
    ];
    devshells.default.commands = [
      {
        help = "run caddy file-server for docs site (dev)";
        name = "build-and-serve-docs";
        command = "caddy file-server --root `nix build $PRJ_ROOT#docs-mdbook-local-docs --no-link --print-out-paths` --listen :8937";
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
