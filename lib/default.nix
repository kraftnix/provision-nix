{
  lib,
  extra-lib,
  ...
}@args:
let
  inherit (extra-lib.std-compat) rakeLeaves;
  rakedLib = lib.mapAttrs (_: v: import v args) (
    lib.filterAttrs (n: _: n != "default") (rakeLeaves ./.)
  );
in
rakedLib
// extra-lib
// {
  getScriptsFromHost =
    flake: host:
    lib.mapAttrs (
      script: cfg: cfg.package
    ) flake.nixosConfigurations.${host}.config.provision.scripts.__enabledScripts;
}
