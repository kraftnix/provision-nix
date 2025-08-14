{ self, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    attrNames
    filterAttrs
    flatten
    mapAttrs
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    pipe
    types
    ;
  opts = self.lib.options;
  cfg = config.provision.fs.zfs.luks;
  # unlockPool = pkgs: keyfile: disks:
  #   (self.nuMount.writeNu pkgs)
  #     "nushell-unlock-pool.nu"
  #     ''
  #     $env.disks = [
  #       ${lib.concatStringsSep "\n" (map (disk:
  #         "{ device : \"${disk.device}\",  label : \"${disk.label}\" }"
  #       ) disks)}
  #     ]
  #     $env.keyfile = "${keyfile}"
  #     ${builtins.readFile ./unlock-pool.nu}
  #     '';
  writeNu =
    pkgs:
    pkgs.writers.makeScriptWriter {
      interpreter = "${pkgs.nushell}/bin/nu";
    };
  unlockPool =
    pkgs: keyfile: disks:
    (writeNu pkgs) "nushell-unlock-pool.nu" ''
      $env.disks = [
        ${lib.concatStringsSep "\n" (
          map (disk: "{ device : \"${disk.device}\",  label : \"${disk.label}\" }") disks
        )}
      ]
      $env.keyfile = "${keyfile}"
      ${builtins.readFile ./unlock-pool.nu}
    '';
  nuUnlockPool = unlockPool pkgs;
  getDisks =
    disko:
    mapAttrsToList (name: cfg: {
      inherit (cfg) device;
      label = cfg.content.name;
    }) (import disko { inherit lib; }).disko.devices.disk;
  enabledPools = pipe cfg.pools [
    (filterAttrs (_: cfg: cfg.enable))
    (filterAttrs (_: cfg: cfg.mode == "keyfile"))
    (filterAttrs (_: cfg: cfg.disks != [ ]))
    (mapAttrs (
      pool: cfg: {
        # boot.zfs.extraPools = [ pool ];
        drives = map (x: x.device) cfg.disks;
        services."zfs-import-${pool}" = {
          path = [ pkgs.cryptsetup ];
          preStart = "${nuUnlockPool cfg.source cfg.disks}";
        };
      }
    ))
  ];
in
{
  options.provision.fs.zfs.luks = {
    enable = opts.enable "enable parallel zfs unlock, only works on ZFS pools over LUKS";
    pools = mkOption {
      default = { };
      description = "pools of disks to unlock";
      type = types.attrsOf (
        types.submodule (
          { config, ... }:
          {
            options = {
              enable = opts.enableTrue "enable parallel unlock for this pool";
              mode = opts.string "keyfile" "mode to use. only keyfile is supported atm";
              source = opts.string "" "location of the key file";
              disko = mkOption {
                default = null;
                type = types.nullOr types.path;
                description = "a disko root configuration file";
              };
              disks = mkOption {
                default = [ ];
                description = "disks to mount using specified keyfile";
                type = types.listOf (
                  types.submodule {
                    options.device = opts.string "" ''
                      device path
                      example: /dev/disk/by-id/ata-Samsung_SSD_870_EVO_2TB_S6PPXXXXXXXXX
                    '';
                    options.label = opts.string "" ''
                      unique device label
                      example: mypool-1
                    '';
                  }
                );
              };
            };
            config = {
              disks = mkIf (config.disko != null) (getDisks config.disko);
            };
          }
        )
      );
    };
  };

  config = mkIf cfg.enable {
    boot.zfs.extraPools = attrNames enabledPools;
    hardware.sensor.hddtemp.drives = flatten (mapAttrsToList (pool: cfg: cfg.drives) enabledPools);
    systemd.services = mkMerge (mapAttrsToList (_: c: c.services) enabledPools);
  };
}
