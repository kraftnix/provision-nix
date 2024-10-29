{
  lib,
  extra-lib,
  ...
} @ args: let
  inherit (extra-lib.std-compat) rakeLeaves;
  rakedLib =
    lib.mapAttrs
    (_: v: import v args)
    (lib.filterAttrs (n: _: n != "default") (rakeLeaves ./.));
  mkPDefault = lib.mkOverride 990;
in
  rakedLib
  // extra-lib
  // {
    inherit mkPDefault;
    mkDefaults = lib.mapAttrs (_: val: mkPDefault val);
    getScriptsFromHost = flake: host:
      lib.mapAttrs
      (
        script: cfg:
          cfg.package
      )
      flake.nixosConfigurations.${host}.config.provision.scripts.__enabledScripts;
  }
