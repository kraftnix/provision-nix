localFlake:
{
  config,
  options,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.provision.fs.samba.server;
  inherit (lib)
    filterAttrs
    mapAttrs
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    optional
    types
    ;
  tcpPorts = [
    # services.samba.openFirewall
    139
    445
    # services.samba-wsdd.openFirewall
    5357
  ];
  udpPorts = [
    # services.samba.openFirewall
    137
    138
    # services.samba-wsdd.openFirewall
    3702
    # services.avahi.openFirewall
    5353
  ];
  # similar type as samba share in nixpkgs module
  sambaType = pkgs.formats.json { };
  filterEnable = lib.filter (x: x.enable);
  filterEnableAttrs = lib.filterAttrs (_: x: x.enable);
  mapMkDefault = lib.mapAttrs (_: lib.mkDefault);
  yesNo = val: if val then "yes" else "no";
  ifExists = val: mkIf (val != null) val;
  ifNonEmptyList = val: mkIf (val != [ ]) (lib.concatStringsSep " " val);
  enabledUsers = filterEnableAttrs cfg.users;
  sambaProvisionUsers = filterAttrs (_: u: u.provisionSamba) enabledUsers;
  shareOptions = {
    browseable = mkEnableOption "whether directory is browseable, `browseable`";
    guest.ok = mkEnableOption "enable guest access, `guests ok`";
    read.only = mkEnableOption "set as read only, `read only`";
    create.mask = mkOption {
      description = "mask when creating files, corresponds to `create mask`";
      default = null;
      type = types.nullOr types.str;
    };
    directory.mask = mkOption {
      description = "mask when creating directories, corresponds to `directory mask`";
      default = null;
      type = types.nullOr types.str;
    };
    force.user = mkOption {
      description = "force user permissions to specified user, corresponds to `force user`";
      default = null;
      type = types.nullOr types.str;
    };
    force.group = mkOption {
      description = "force group permissions to specified group, corresponds to `force group`";
      default = null;
      type = types.nullOr types.str;
    };
    hosts.allow = mkOption {
      description = "list of hosts to allow, corresponds to `hosts allow`";
      default = [ ];
      type = types.listOf types.str;
    };
    hosts.deny = mkOption {
      description = "list of hosts to deny, corresponds to `hosts deny`";
      default = [ ];
      type = types.listOf types.str;
    };
    valid.users = mkOption {
      description = "list of valid users, corresponds to `valid users`";
      default = [ ];
      type = types.listOf types.str;
    };
  };

  sambaUserModule =
    { config, name, ... }:
    {
      options = {
        enable = mkEnableOption "enable provisioning samba user" // {
          default = true;
        };
        configureUser = mkEnableOption "whether to configure user in `users.users.<name>`";
        provisionSamba = mkEnableOption "provision samba user password from saved hashedPasswordFile";
        name = mkOption {
          description = "user name";
          default = name;
          example = "media";
          type = types.str;
        };
        description = mkOption {
          description = "description of user in `users.users`";
          default = "Auto-generated SAMBA user from provision-nix";
          type = types.str;
        };
        sambaPasswordFile = mkOption {
          description = "sambaPasswordFile of user, contains the user password for samba, added as samba password when {provisionSamba} is true";
          default = null;
          type = types.nullOr types.str;
        };
        group.name = mkOption {
          description = "user name";
          default = null;
          example = "media";
          type = types.nullOr types.str;
        };
        uid = mkOption {
          description = "uid to set for user (optional)";
          default = null;
          example = 1001;
          type = types.nullOr types.int;
        };
        extraUserConfig = mkOption {
          description = "extra configuration to add to `users.users.<name>`";
          default = { };
          type = sambaType.type;
        };
      };
    };

  shareModule =
    { config, name, ... }:
    {
      options = {
        enable = mkEnableOption "enable exporting share path" // {
          default = true;
        };
        name = mkOption {
          description = "share name";
          default = name;
          example = "media";
          type = types.str;
        };
        path = mkOption {
          description = "host path of export";
          default = "/${config.name}";
          example = "/media";
          type = types.path;
        };
        settings = mkOption {
          description = "end settings for share";
          default = { };
          example = {
            browseable = true;
          };
          # similar type as samba share in nixpkgs module
          type = sambaType.type;
        };
      }
      // shareOptions;
      config = (lib.mapAttrs (_: lib.mkDefault) cfg.default.opts) // {
        settings = {
          path = config.path;
          browseable = yesNo config.browseable;
          "guest ok" = yesNo config.guest.ok;
          "read only" = yesNo config.read.only;
          "directory mask" = ifExists config.directory.mask;
          "force user" = ifExists config.force.user;
          "force group" = ifExists config.force.group;
          "hosts allow" = ifNonEmptyList config.hosts.allow;
          "hosts deny" = ifNonEmptyList config.hosts.deny;
          "valid users" = ifNonEmptyList config.valid.users;
        };
      };
    };
in
{
  options.provision.fs.samba.server = {
    enable = mkEnableOption "enable samba exports wrapper";

    firewall.enable = mkEnableOption "enable firewall rules for samba";
    firewall.legacy = mkEnableOption "use `networking.firewall.interfaces` rules instead of `networking.nftables.gen`";
    firewall.interfaces = mkOption {
      description = "allowed interfaces added to `networking.firewall.interfaces.<interface>`";
      default = [ ];
      type = types.listOf types.str;
    };
    firewall.sourceIPs = mkOption {
      description = "saddr IP addresses or ranges allowed access to NFS ports`";
      default = [ ];
      type = types.listOf types.str;
    };

    interfaces = mkOption {
      description = "interfaces to bind samba daemon to";
      default = { };
      type = types.attrsOf (
        types.submodule (
          { config, name, ... }:
          {
            options = {
              name = mkOption {
                description = "interface name";
                default = name;
                type = types.str;
              };
              subnet = mkOption {
                description = "subnet/interface to bind samba to, by default samba wont bind to wireguard interfaces, can also be used to limit binding";
                default = "";
                type = types.str;
              };
            };
          }
        )
      );
    };

    logging = {
      # further options at https://www.oreilly.com/openbook/samba/book/ch09_01.html
      enable = mkEnableOption "enable logging globally";
      level = mkOption {
        description = "log level to set globally";
        default = "1";
        type = types.str;
      };
    };

    global = mkOption {
      description = "global settings for share";
      default = { };
      example = {
        workgroup = "WORKGROUP";
        "server string" = "smbnix";
        "netbios name" = "smbnix";
        "security" = "user";
        #"use sendfile" = "yes";
        #"max protocol" = "smb2";
        # note: localhost is the ipv6 localhost ::1
        "guest account" = "nobody";
        "map to guest" = "bad user";
      };
      type = sambaType.type;
    };
    settings = mkOption {
      description = "extra settings to merge with auto-generated settings, they take precedence in config merging";
      default = { };
      example = {
        global.workgroup = "WORKGROUP";
      };
      type = sambaType.type;
    };
    default.opts = mkOption {
      description = "default share options";
      default = { };
      example = {
        browseable = true;
      };
      type = types.submodule { options = shareOptions; };
    };

    shares = mkOption {
      description = "Export paths to enable";
      default = { };
      type = types.attrsOf (types.submodule shareModule);
    };

    users = mkOption {
      description = "Samba users to provision";
      default = { };
      type = types.attrsOf (types.submodule sambaUserModule);
    };

  };

  config = mkIf cfg.enable {

    provision.fs.samba.server.firewall.legacy =
      !((options.networking.nftables ? gen) && config.networking.nftables.gen.enable);

    networking.nftables = mkIf (cfg.firewall.enable && !cfg.firewall.legacy) {
      gen.tables.filter.input.rules = {
        allow_samba = {
          counter = true;
          iifname = cfg.firewall.interfaces;
          saddr = cfg.firewall.sourceIPs;
          tcpDport = tcpPorts;
          verdict = "accept";
          comment = "allow samba tcp";
        };
        allow_samba_udp = {
          counter = true;
          iifname = cfg.firewall.interfaces;
          saddr = cfg.firewall.sourceIPs;
          udpDport = udpPorts;
          verdict = "accept";
          comment = "allow samba udp";
        };
      };
    };

    networking.firewall = mkIf (cfg.firewall.enable && cfg.firewall.legacy) {
      interfaces = lib.genAttrs cfg.firewall.interfaces (interfaces: {
        allowedTCPPorts = tcpPorts;
        allowedUDPPorts = udpPorts;
      });
    };

    provision.fs.samba.server.firewall.interfaces = lib.mapAttrsToList (_: i: i.name) cfg.interfaces;
    provision.fs.samba.server.global = {
      interfaces = lib.concatStringsSep " " (lib.mapAttrsToList (_: i: i.subnet) cfg.interfaces);
      "log level" = mkIf cfg.logging.enable cfg.logging.level;
    };
    services.samba = {
      enable = true;
      settings = lib.pipe cfg.shares [
        filterEnableAttrs
        (lib.mapAttrs' (_: share: lib.nameValuePair share.name (mapMkDefault share.settings)))
        (shares: [
          shares
          cfg.settings
          {
            global = mapMkDefault cfg.global;
          }
        ])
        lib.mkMerge
      ];
    };

    services.samba-wsdd = {
      enable = true;
      extraOptions = lib.pipe cfg.firewall.interfaces [
        (lib.map (iface: [
          "--interface"
          iface
        ]))
        lib.flatten
        (mkIf cfg.firewall.enable)
      ];
    };

    services.avahi = {
      publish.enable = true;
      publish.userServices = true;
      # ^^ Needed to allow samba to automatically register mDNS records (without the need for an `extraServiceFile`
      # nssmdns4 = true;
      # ^^ Not one hundred percent sure if this is needed- if it aint broke, don't fix it
      enable = true;
      allowInterfaces = mkIf cfg.firewall.enable cfg.firewall.interfaces;
    };

    ## User Configuration
    users.users = lib.mkMerge [
      (lib.pipe enabledUsers [
        (filterAttrs (_: u: u.configureUser))
        (lib.mapAttrs' (
          _: u:
          lib.nameValuePair u.name {
            description = mkDefault u.description;
            group = mkIf (u.group.name != null) u.group.name;
            uid = mkIf (u.uid != null) u.uid;
            # isNormalUser = mkIf (u.hashedPasswordFile != null) (mkDefault true);
            isNormalUser = true; # TODO: is this needed?
            isSystemUser = false;
            # createHome = lib.mkOverride 900 false; # above mkDefault due to conflict with users-groups.nix
            # shell = lib.mkOverride 900 "/run/current-system/sw/bin/nologin";
          }
        ))
      ])
      (lib.pipe enabledUsers [
        (filterAttrs (_: u: u.configureUser))
        (lib.mapAttrs' (_: u: lib.nameValuePair u.name u.extraUserConfig))
      ])
    ];

    ## Adapated from https://wiki.nixos.org/wiki/Samba#User_Authentication
    systemd.services.samba-provision = lib.mkIf ({ } != sambaProvisionUsers) {
      after = [ "samba-smbd.service" ];
      requires = [ "samba-smbd.service" ];
      partOf = [ "samba.target" ];
      wantedBy = [ "samba.target" ];
      path = [
        pkgs.samba
        pkgs.coreutils
      ];
      script = lib.pipe sambaProvisionUsers [
        (lib.mapAttrsToList (
          _: u: ''
            echo "Setting user password for ${u.name} from ${u.sambaPasswordFile}"
            echo -e "$(cat ${u.sambaPasswordFile})\n$(cat ${u.sambaPasswordFile})\n" | smbpasswd -sa ${u.name}
          ''
        ))
        (lib.concatStringsSep "\n")
      ];
    };

  };
}
