{
  perSystem =
    { config, pkgs, ... }:
    let
      sources = pkgs.callPackage (import ./_sources/generated.nix) { };
    in
    {
      overlayAttrs = { inherit (config.packages) btrfs-list; };
      packages = {
        btrfs-list = pkgs.callPackage (import ./btrfs-list.nix sources.btrfs-list) { };
        dnsleaktest = pkgs.callPackage (import ./dnsleaktest.nix) { };
        mdbook-linkcheck = pkgs.callPackage (import ./mdbook-linkcheck.nix) { };
        yapp = pkgs.callPackage (import ./yapp.nix) { };
      };
    };
}
