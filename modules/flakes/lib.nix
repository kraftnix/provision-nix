localFlake:
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.flake = flake-parts-lib.mkSubmoduleOptions {
    lib = lib.mkOption {
      description = ''
        Flake level `lib` option.
      '';
      type = with lib.types; attrsOf raw;
      default = { };
      example = lib.literalExpression ''
        {
          mkEnableTrue = description: lib.mkEnableOption description // { default = true; };
        }
      '';
    };
  };
}
