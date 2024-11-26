localFlake:
{
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
  inherit (flake-parts-lib)
    mkSubmoduleOptions
    ;
in
{
  options.flake = mkSubmoduleOptions {
    lib = mkOption {
      description = ''
        Flake level `lib` option.
      '';
      type = types.lazyAttrsOf types.anything;
      default = { };
      example = lib.literalExpression ''
        {
          mkEnableTrue = description: lib.mkEnableOption description // { default = true; };
        }
      '';
    };
  };
}
