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
        mdbook-theme = pkgs.callPackage (import ./mdbook-theme.nix) { };
        # TODO(remove): has been upstreamed
        # mdbook-variables = pkgs.callPackage (import ./mdbook-variables.nix) {};
        yapp = pkgs.callPackage (import ./yapp.nix) { };
      };
    };
}
