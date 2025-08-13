localFlake:
{
  self,
  flake-parts-lib,
  ...
}:
{
  imports = [
    (import ./perSystem.nix localFlake)
  ];
}
