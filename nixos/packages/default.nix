{
  self,
  inputs,
  lib,
  ...
}: let
  additionalFeatures = p: [
    "default"
    "dataframe"
  ];
in {
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    sources = pkgs.callPackage (import ./_sources/generated.nix) {};
  in {
    overlayAttrs = {
      inherit (config.packages) btrfs-list;
    };
    packages = {
      tmux_3_3a = pkgs.callPackage (import ./tmux.nix) {};
      btrfs-list = pkgs.callPackage (import ./btrfs-list.nix sources.btrfs-list) {};
    };
    # packages.nushell-latest = pkgs.callPackage (import ./nushell.nix sources.nushell-latest "sha256-G22bfkdfAPyMslEm52x0LTb62xC05Ih9UOFP7pg3MEY=") {
    #   inherit additionalFeatures;
    # };
    # packages.nushell-master = pkgs.callPackage (import ./nushell.nix sources.nushell-master "sha256-hNMjuoMU1NFt9cURgSyUD3hED93j9usRJ+7ydqtXu+Y=") {
    #   inherit additionalFeatures;
    # };
    # packagesGroups.nushell = {
    #   inherit (config.packages) nushell-latest nushell-master;
    # };
  };
}
