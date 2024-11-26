{
  self,
  lib,
  ...
}:
let
  disks = lib.removeAttrs (self.lib.nix.rakeLeaves ./.) [ "default" ];
in
{
  flake.disko = lib.recursiveUpdate disks { };
}
