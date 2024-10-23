{
  self,
  lib,
  flake-parts-lib,
  moduleLocation,
  ...
}: let
  inherit
    (lib)
    concatStringsSep
    mapAttrsRecursive
    mkOption
    types
    ;
  inherit
    (flake-parts-lib)
    mkSubmoduleOptions
    ;
in {
  options = {
    flake = mkSubmoduleOptions {
      profiles = mkOption {
        type = types.lazyAttrsOf types.unspecified;
        default = {};
        apply = mapAttrsRecursive (k: v: {
          _file = "${toString moduleLocation}#profiles.${concatStringsSep "." k}";
          imports = [v];
          # passthru = v; # causes weird issues
        });
        description = ''
          NixOS profiles.

          You may use this for reusable snippets pieces of pure configuration (i.e. without options).
        '';
      };
    };
  };
}
