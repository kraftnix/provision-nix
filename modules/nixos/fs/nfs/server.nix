localFlake:
{
  config,
  lib,
  ...
}:
let
  cfg = config.provision.fs.nfs.server;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optional
    types
    ;
  filterEnable = lib.filter (x: x.enable);
  filterEnableAttrs = lib.filterAttrs (_: x: x.enable);

  exportOptions = {
    rw = mkEnableOption "enable rw option";
    insecure = mkEnableOption "enable insecure option";
    subtree_check = mkEnableOption "enable subtree_check option";
    nohide = mkEnableOption "enable nohide option";
    async = mkEnableOption "enable async option";
    fsid = mkOption {
      description = "whether to set fsid, not set when null (default)";
      default = null;
      type = types.nullOr types.int;
    };
    anonuid = mkOption {
      description = "whether to set anonuid, not set when null (default)";
      default = null;
      type = types.nullOr types.int;
    };
    anongid = mkOption {
      description = "whether to set anongid, not set when null (default)";
      default = null;
      type = types.nullOr types.int;
    };
  };

  subnetModule =
    matchSubnet:
    {
      config,
      name,
      defaultOptions,
      ...
    }:
    {
      options = {
        enable = mkEnableOption "enable subnet permissions" // {
          default = true;
        };
        name = mkOption {
          description = "subnet name";
          default = name;
          example = "10.0.0.0/8";
          type = types.str;
        };
        subnet = mkOption {
          description = "subnet to apply permission to";
          default = config.name;
          example = "10.0.0.0/8";
          type = types.str;
        };
        export.options = mkOption {
          description = "export options to use for subnets permissions, sets {permissions}";
          default = { };
          example = {
            rw = true;
          };
          type = types.submodule { options = exportOptions; };
        };
        permissions = mkOption {
          description = "permissions to add to subnet";
          default = [ ];
          example = [
            "rw"
            "insecure"
            "subtree_check"
            "nohide"
            "async"
          ];
          type = types.listOf types.str;
        };
      };
      config =
        (lib.optionalAttrs matchSubnet {
          subnet = lib.mkDefault (
            if cfg.subnets ? ${config.name} then cfg.subnets.${config.name}.subnet else config.name
          );
        })
        // {
          export.options = lib.mapAttrs (_: lib.mkDefault) defaultOptions;
          permissions =
            with config.export.options;
            (
              [ ]
              ++ (optional rw "rw")
              ++ (optional insecure "insecure")
              ++ (optional subtree_check "subtree_check")
              ++ (optional nohide "nohide")
              ++ (optional async "async")
              ++ (optional (anonuid != null) "anonuid=${toString anonuid}")
              ++ (optional (anongid != null) "anongid=${toString anongid}")
              ++ (optional (fsid != null) "fsid=${toString fsid}")
            );
        };
    };

  exportModule =
    { config, name, ... }:
    {
      options = {
        enable = mkEnableOption "enable exporting path" // {
          default = true;
        };
        addToFilesystem = mkEnableOption "adds path to `fileSystems.<path>`" // {
          default = cfg.default.addToFilesystem;
        };
        hostPath = mkOption {
          description = "host path of export, sets `device` of bind mount";
          default = "/${name}";
          example = "/media";
          type = types.path;
        };
        exportPath = mkOption {
          description = "export path of export";
          default = "${cfg.exportDir}${config.hostPath}";
          example = "/export/media";
          type = types.path;
        };
        mountOptions = mkOption {
          description = "mount options to add to export bindmount";
          default = [ ];
          example = [
            "bind"
            "x-systemd.automount"
            "noauto"
            "x-systemd.idle-timeout=600"
          ];
          type = types.listOf types.str;
        };
        export.options = mkOption {
          description = "default export options to use for subnets permissions";
          default = { };
          example = {
            rw = true;
          };
          type = types.submodule { options = exportOptions; };
        };
        mount.options = mkOption {
          description = "mount options for export bindmount";
          default = cfg.default.mount.options;
          type = types.listOf types.str;
        };
        subnets = mkOption {
          description = "subnet permissions for mount";
          default = { };
          type = types.attrsOf (
            types.submoduleWith {
              specialArgs.defaultOptions = config.export.options;
              modules = [ (subnetModule true) ];
            }
          );
        };
      };
      config.export.options = lib.mapAttrs (_: lib.mkDefault) cfg.default.export.options;
    };
in
{
  options.provision.fs.nfs.server = {
    enable = mkEnableOption "enable nfs exports wrapper";

    firewall.enable = mkEnableOption "enable firewall rules for nfs";
    firewall.interfaces = mkOption {
      description = "allowed interfaces added to `networking.firewall.interfaces.<interface>`";
      default = [ ];
      type = types.listOf types.str;
    };

    exportDir = mkOption {
      description = "export directory";
      default = "/export";
      type = types.str;
    };

    default.export.options = mkOption {
      description = "default export options to use for subnet permissions";
      default = { };
      example = {
        rw = true;
      };
      type = types.submodule { options = exportOptions; };
    };
    default.addToFilesystem = mkEnableOption "adds path to `fileSystems.<path>`" // {
      default = true;
    };
    default.mount.options = mkOption {
      description = "mount options for export bindmount";
      default = [
        "bind"
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=600"
      ];
      type = types.listOf types.str;
    };

    exports = mkOption {
      description = "Export paths to enable";
      default = { };
      type = types.attrsOf (types.submodule exportModule);
    };

    subnets = mkOption {
      description = "a short form configuration which generates entries in {provision.fs.nfs.server.exports}";
      default = { };
      type = types.attrsOf (
        types.submoduleWith {
          specialArgs.defaultOptions = cfg.default.export.options;
          modules = [
            (subnetModule false)
            {
              options = {
                paths = mkOption {
                  description = "list of paths to apply these permissions to";
                  default = [ ];
                  type = types.listOf types.str;
                };
              };
            }
          ];
        }
      );
    };
  };

  config = mkIf cfg.enable {

    networking.firewall = mkIf cfg.firewall.enable {
      interfaces = lib.genAttrs cfg.firewall.interfaces (interfaces: {
        allowedTCPPorts = [ 2049 ];
      });
    };

    provision.fs.nfs.server.exports = lib.pipe cfg.subnets [
      (lib.mapAttrsToList (
        _: subnet:
        lib.map (path: {
          ${path}.subnets.${subnet.subnet}.permissions = subnet.permissions;
        }) subnet.paths
      ))
      lib.flatten
      lib.mkMerge
    ];

    services.nfs.server = {
      enable = true;
      exports = lib.pipe cfg.exports [
        (lib.mapAttrsToList (_: e: e))
        # TODO: sort by path
        filterEnable
        (lib.map (
          e:
          "${e.exportPath}\t${
            lib.concatStringsSep " " (
              lib.mapAttrsToList (_: p: "${p.subnet}(${lib.concatStringsSep "," p.permissions})") (
                filterEnableAttrs e.subnets
              )
            )
          }"
        ))
        (lib.concatStringsSep "\n")
      ];
    };

    fileSystems = lib.pipe cfg.exports [
      (lib.filterAttrs (_: e: e.enable && e.addToFilesystem))
      (lib.mapAttrs' (
        _: e:
        lib.nameValuePair e.exportPath {
          device = e.hostPath;
          options = e.mount.options;
          neededForBoot = false;
        }
      ))
    ];

  };
}
