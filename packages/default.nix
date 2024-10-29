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
