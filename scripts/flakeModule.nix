localFlake: {
  lib,
  flake-parts-lib,
  ...
}: {
  imports = [
    (flake-parts-lib.importApply ./flakeSystemModule.nix localFlake)
  ];
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    scripts.pkgs = pkgs;
    packages =
      lib.mkIf config.scripts.addToPackages
      (lib.mapAttrs (_: c: c.package) config.scripts.__enabledScripts);
  };
}
