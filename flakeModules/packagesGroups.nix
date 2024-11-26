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
    mkTransposedPerSystemModule
    ;
in
mkTransposedPerSystemModule {
  name = "packagesGroups";
  option = mkOption {
    description = ''
      An attribute set of packages to be built by [`nix build`](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-build.html).
      `nix build .#<name>` will build `packages.<name>`.
    '';
    type = types.lazyAttrsOf (types.lazyAttrsOf types.package);
    default = { };
    example = lib.literalExpression ''
      {
        nushellPlugins = {
          explore = pkgs.callPackage ./nushell_plugin_explore.nix {};
          dbus = pkgs.callPackage ./nushell_plugin_dbus.nix {};
        };
      }
    '';
  };
  file = ./packagesGroups.nix;
}
