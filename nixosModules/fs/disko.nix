{ self, ... }:
{
  config,
  options,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    filterAttrs
    hasPrefix
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    pipe
    recursiveUpdate
    types
    ;
  opts = self.lib.options;
  cfg = config.provision.fs.disko;
  diskoEnabled = options ? disko;
in
{
  options.provision.fs.disko = {
    enable = opts.enable' (cfg.devices != { }) "enable disko extension wrapper";
    profiles = lib.mkOption {
      type = with types; attrsOf path;
      default = self.disko;
      description = "disko configuration snippets / profiles";
    };
    devices = lib.mkOption {
      default = { };
      description = "map of luks name -> device path to unlock";
      example = {
        enc-root = {
          device = "/dev/vda1";
          profile = "btrfs-luks-uefi";
        };
      };
      type = types.attrsOf (
        types.submodule (
          { config, ... }:
          {
            options = {
              diskName = opts.string config._module.args.name "disk name to apply to profile";
              device = opts.string "" "device to apple disko profile to";
              profile = opts.string "" "profile to apply from `provision.fs.disko.profiles`";
              args = mkOption {
                type = types.raw;
                default = { };
                apply = recursiveUpdate { inherit (config) device diskName; };
                description = "Args to apply to disko profile";
              };
              generated = mkOption {
                default = { };
                description = "generated disko config to import";
              };
              __profilePath = mkOption {
                default = null;
                description = "profile path to apply `args` to";
                type = with types; nullOr path;
              };
            };
            config.__profilePath = mkIf (config.profile != "") cfg.profiles.${config.profile};
            config.generated = mkIf (config.profile != "") (
              pipe config.args [
                (filterAttrs (name: _: !(hasPrefix "__" name)))
                (
                  filtered:
                  import config.__profilePath (
                    filtered
                    // {
                      inherit lib;
                    }
                  )
                )
              ]
            );
          }
        )
      );
    };
  };

  config =
    if diskoEnabled then
      (mkIf cfg.enable {
        disko = pipe cfg.devices [
          (mapAttrsToList (_: device: device.generated.disko))
          mkMerge
        ];
      })
    else
      {
        assertions = [
          {
            assertion = !cfg.enable;
            message = ''
              You have enabled disko integration in `provision.fs.disko.enable`
              but there is no disko module found.

              Please import the disko nixosModule into the host.
            '';
          }
        ];
      };
}
