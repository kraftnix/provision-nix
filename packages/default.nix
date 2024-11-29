{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    let
      sources = pkgs.callPackage (import ./_sources/generated.nix) { };
    in
    {
      overlayAttrs = {
        inherit (config.packages) btrfs-list;
      };
      packages = {
        btrfs-list = pkgs.callPackage (import ./btrfs-list.nix sources.btrfs-list) { };
        # https://github.com/rust-lang/mdBook/pull/1802
        mdbook-linkfix = pkgs.mdbook.overrideAttrs (old: rec {
          src = pkgs.fetchFromGitHub {
            owner = "JesusPerez";
            repo = "mdBook";
            rev = "master";
            hash = "sha256-1UI+HRUz8ImG+ZfIw+k8LlKV5XxIKfMbG/O0BEwh6nQ=";
          };
          cargoDeps = old.cargoDeps.overrideAttrs {
            inherit src;
            outputHash = "sha256-3GVFRwKCvtZoqW4nktBLBdS5OEqM8tfoAct2JRHYmTw=";
          };
        });
        mdbook-theme = pkgs.callPackage (import ./mdbook-theme.nix) { };
        # TODO(remove): has been upstreamed
        # mdbook-variables = pkgs.callPackage (import ./mdbook-variables.nix) {};
        yapp = pkgs.callPackage (import ./yapp.nix) { };
      };
    };
}
