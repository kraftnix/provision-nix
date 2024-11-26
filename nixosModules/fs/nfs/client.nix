{ self, ... }:
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    filterAttrs
    flatten
    mapAttrs'
    mkIf
    mkOption
    nameValuePair
    optionals
    pipe
    types
    unique
    ;
  opts = self.lib.options;
  cfg = config.provision.fs.nfs.client;
  mkServiceList =
    default: description:
    mkOption {
      inherit default description;
      type = with types; listOf str;
    };
  nfsSubmodule =
    {
      config,
      name,
      localBase,
      remoteBase,
      remoteUrl,
      nfsVersion,
      ...
    }:
    {
      options = {
        enable = opts.enable "enable ${name} nfs mount";
        hostPath = opts.string "${localBase}/${name}" "local host mount path";
        remotePath = opts.string "${remoteBase}/${name}" "remote host mount path";
        remoteUrl = opts.string remoteUrl "NFS ip / domain";
        nfsVersion = opts.string nfsVersion "nfs version to use";
        requires = mkServiceList [ ] "set systemd requires + after";
        after = mkServiceList [ ] "set systemd after only";
        requiredBy = mkServiceList [ ] "set systemd required by + after";
        before = mkServiceList [ ] "set systemd before only";
        networkOnlineService = mkOption {
          type = with types; nullOr str;
          default = "systemd-networkd-wait-online.service";
          description = "unit to automatically add an after+requires, set to null to disable";
        };
        extraOptions = mkOption {
          type = with types; listOf str;
          description = "extra options to add";
          default = [ ];
        };
        device = opts.string "${config.remoteUrl}:${config.remotePath}" "final device string";
        options = mkOption {
          default = [ ];
          type = with types; listOf str;
          description = "final options to add to mountpoint";
        };
      };
      config.options = unique (
        flatten (
          [
            "nfsvers=${config.nfsVersion}" # "noauto" #"noatime"
            "_netdev"
          ]
          ++ (optionals (config.networkOnlineService != null) [
            "x-systemd.after=${config.networkOnlineService}"
            "x-systemd.requires=${config.networkOnlineService}"
          ])
          ++ (map (service: [
            "x-systemd.after=${service}"
            "x-systemd.requires=${service}"
          ]) config.requires)
          ++ (map (service: "x-systemd.before=${service}") config.before)
          ++ (map (service: [
            "x-systemd.before=${service}"
            "x-systemd.required-by=${service}"
          ]) config.requiredBy)
          ++ (map (service: "x-systemd.after=${service}") config.after)
          ++ config.extraOptions
        )
      );
    };
in
{
  options.provision.fs.nfs.client = {
    enable = opts.enable "enable NFS integrations";
    localBase = opts.string "/mnt/remote" "default base directory for all NFS mounts";
    remoteBase = opts.string "/export" "default remote server base directory for all NFS mounts";
    remoteUrl = opts.string "" "default remote server url / domain";
    nfsVersion = opts.string "4.2" "default NFS version to mount with";
    mounts = mkOption {
      default = { };
      description = "NFS mounts to enable";
      type = types.attrsOf (
        types.submoduleWith {
          class = "nixos";
          description = "NFS submodule";
          modules = [
            nfsSubmodule
            {
              config._module.args = {
                inherit (cfg)
                  localBase
                  remoteBase
                  remoteUrl
                  nfsVersion
                  ;
              };
            }
          ];
        }
      );
    };
  };

  config = mkIf cfg.enable {
    fileSystems = pipe cfg.mounts [
      (filterAttrs (_: c: c.enable))
      (mapAttrs' (
        _: c:
        nameValuePair c.hostPath {
          inherit (c) device options;
          fsType = "nfs";
        }
      ))
    ];
  };
}
