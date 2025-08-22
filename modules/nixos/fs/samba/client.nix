localFlake:
{
  config,
  options,
  pkgs,
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
  opts = localFlake.self.lib.options;
  idleOption =
    description:
    mkOption {
      inherit description;
      default = null;
      type =
        with types;
        nullOr (oneOf [
          str
          int
        ]);
    };
  cfg = config.provision.fs.samba.client;
  mkServiceList =
    default: description:
    mkOption {
      inherit default description;
      type = with types; listOf str;
      example = [
        "systemd-nspawn@media.service"
        "zfs-import-pool.service"
      ];
    };
  sambaSubmodule =
    {
      config,
      name,
      localBase,
      remoteUrl,
      sambaVersion,
      default,
      ...
    }:
    {
      options = {
        enable = opts.enableTrue "enable ${name} samba mount";
        share = opts.string name "share name";
        hostPath = opts.string "${localBase}/${config.share}" "local host mount path";
        remoteUrl = opts.string remoteUrl "samba server ip / fqdn / hostname";
        uid = opts.stringNull "local uid to map ownership to, can be a username or uid";
        gid = opts.stringNull "local gid to map ownership to, can be a group or gid";
        user = opts.stringNull "remote samba user to login as, if not set a guest mount is assumed";
        passwordFile = mkOption {
          description = ''
            (optional) file containing samba password, a `credentials` file containing the password is generated as an activation script

            used instead of {credentials} options when you want to use only a single password as the contents of the file rather than a
            file compatible with the `credentials` mount option.
          '';
          default = null;
          example = "/root/my-samba-password";
          type = types.nullOr types.path;
        };
        credentialsFile = mkOption {
          description = ''
            (optional) file containing samba credentials, expected to be useable by mount option `credentials` containing:
            ```
            username=myuser
            password=mypass
            domain=mydomain
            ```
          '';
          default = null;
          example = "/root/my-samba-credentials";
          type = types.nullOr types.path;
        };
        sambaVersion = opts.stringNull "samba version to use" // {
          default = sambaVersion;
          example = "3.1";
        };
        automount = opts.enableTrue "enable automount via `x-systemd.automount`";
        noatime = opts.enable "adds `noatime` mount option, Do not update inode access times on this filesystem";
        timeouts = {
          idle = idleOption "idle timeout for automount unit, see TimeoutIdleSec in systemd.automount, specify a time in seconds or append `s`, `min`, `h` etc.";
          device = idleOption "how long systemd should wait for a device to show up before giving up, specify a time in seconds or append `s`, `min`, `h` etc.";
          mount = idleOption "how long systemd should wait for the mount command to finish up before giving up, specify a time in seconds or append `s`, `min`, `h` etc.";
        };
        noauto = opts.enable "adds `noauto` mount option, mount unit will not be added to local-fs.target or remote-fs.target (no affect when {automount} is used)";
        requires =
          mkServiceList [ ]
            "systemd services to add to requires + after with `x-systemd.requires` and `x-systemd.after`";
        after = mkServiceList [ ] "systemd services to add to after with `x-systemd.after`";
        requiredBy =
          mkServiceList [ ]
            "systemd services to add to requiredBy + before with `x-systemd.requiredBy` and `x-systemd.before`";
        before = mkServiceList [ ] "systemd services to add to before with `x-systemd.before`";
        networkOnlineService = mkOption {
          description = "unit to automatically add an after+requires, set to null to disable";
          default = "systemd-networkd-wait-online.service";
          type = with types; nullOr str;
        };
        extraOptions = mkOption {
          description = "extra mount options to add to {options}";
          default = [ ];
          example = [
            "ro"
            "x-systemd.idle-timeout=60"
          ];
          type = with types; listOf str;
        };
        device =
          opts.string "//${config.remoteUrl}/${config.share}" "final device string, is a valid CIFS path"
          // {
            example = "//192.168.0.1/media";
          };
        options = mkOption {
          description = ''
            final mount options to add to mountpoint (equivalent to -o mount options)

            this is generated according to other config set within the share submodule and {extraOptions}

            you normally should not need to edit this
          '';
          default = [ ];
          type = with types; listOf str;
        };
      };
      config = default // {
        options = unique (
          flatten (
            [
              "_netdev"
              "user"
              "users"
            ]
            ++ (optionals config.automount [ "x-systemd.automount" ])
            ++ (optionals config.noauto [ "noauto" ])
            ++ (optionals config.noatime [ "noatime" ])
            ++ (optionals (config.timeouts.idle != null) [
              "x-systemd.idle-timeout=${toString config.timeouts.idle}"
            ])
            ++ (optionals (config.timeouts.mount != null) [
              "x-systemd.mount-timeout=${toString config.timeouts.mount}"
            ])
            ++ (optionals (config.timeouts.device != null) [
              "x-systemd.device-timeout=${toString config.timeouts.device}"
            ])
            ++ (optionals (config.passwordFile != null) [
              "credentials=/root/samba-password-${config.share}"
            ])
            ++ (optionals (config.credentialsFile != null) [
              "credentials=${config.credentialsFile}"
            ])
            ++ (optionals (config.user != null) [
              "sec=ntlmssp"
              "username=${toString config.user}"
            ])
            ++ (optionals (config.user == null) [
              "sec=none"
            ])
            ++ (optionals (config.uid != null) [
              "uid=${toString config.uid}"
            ])
            ++ (optionals (config.gid != null) [
              "gid=${toString config.gid}"
            ])
            ++ (optionals (config.sambaVersion != null) [
              "vers=${config.sambaVersion}"
            ])
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
    };

  enabledMounts = filterAttrs (_: m: m.enable) cfg.mounts;
  sambaPasswordFiles = filterAttrs (_: m: m.passwordFile != null) enabledMounts;
in
{
  options.provision.fs.samba.client = {
    enable = opts.enable "enable samba client";
    localBase = opts.string "/mnt/remote" "default base directory for all samba mounts";
    remoteUrl = opts.string "" "default remote server url / domain";
    sambaVersion = opts.stringNull "default samba version to mount with (optional)";
    default = mkOption {
      description = "default options to add to `mounts.<name>`";
      default = { };
      example = {
        noauto = true;
        automount = true;
        extraOptions = [
          "ro"
          "diratime"
        ];
      };
      type = types.raw;
    };
    mounts = mkOption {
      description = ''
        Samba mount network shares to mount via CIFS.

        This module generates an entry in `fileSystems` for each mount defined here.

        Configuration options are provided to aid:
          - mounting remote share with specific local user/group (uid/gid)
          - mount ordering (after/before/requires/requiredBy) of related systemd services
          - samba credential file location (`credentials=` compatible file path)
          - samba password file location (generated a `credentials` compatible file path containing `password=<password-file>`)
      '';
      default = { };
      example = {
        media = {
          path = "/pool/media";
          hosts.allow = [
            "10.40.10."
            "192.168.0.71"
            "localhost"
          ];
          hosts.deny = [ "0.0.0.0/0" ];
          force.user = "media";
          force.group = "media";
          valid.users = [
            "smb-media"
            "myuser"
          ];
        };
      };
      type = types.attrsOf (
        types.submoduleWith {
          class = "nixos";
          description = "samba mount submodule";
          specialArgs = {
            inherit (cfg)
              localBase
              remoteUrl
              sambaVersion
              default
              ;
          };
          modules = [ sambaSubmodule ];
        }
      );
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.cifs-utils ];
    boot.supportedFilesystems = [ "cifs" ];
    system.activationScripts = mkIf ({ } != sambaPasswordFiles) {
      init_smbpasswd_client.text = pipe sambaPasswordFiles [
        (lib.mapAttrsToList (
          _: s: ''
            ${pkgs.coreutils}/bin/echo -e "password=$(${pkgs.coreutils}/bin/cat ${s.passwordFile})" > /root/samba-password-${s.share}
          ''
        ))
        (lib.concatStringsSep "\n")
      ];
      # required for ordering init script to run after agenix has descrypted passwords
      init_smbpasswd_client.deps = mkIf ((options ? age) && (config.age.secrets != { })) [
        "agenixInstall"
      ];
    };
    fileSystems = mapAttrs' (
      _: c:
      nameValuePair c.hostPath {
        inherit (c) device options;
        fsType = "cifs";
      }
    ) enabledMounts;
  };
}
