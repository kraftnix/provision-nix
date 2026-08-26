{
  self,
  flake-parts-lib,
  ...
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (flake-parts-lib) importApply;
  inherit (lib)
    mkIf
    mkDefault
    optional
    types
    ;
  opts = self.lib.options;
  cfg = config.provision.virt.containers;
  network = cfg.podman.network;
  settingsType = pkgs.formats.toml { };
in
{
  imports = [
    (importApply ./netns.nix self)
  ];

  options.provision.virt.containers = {
    enable = opts.enable "enable containers";
    docker = {
      enable = opts.enable "enable docker";
      zfs = opts.enable "enable zfs dataset for docker storage";
      zfsDataset = opts.string "" "zfs dataset to use as base for docker";
    };
    conf = lib.mkOption {
      description = "containers.conf configuration, populated based on {provision.virt.containers.podman} configuration";
      default = { };
      type = (pkgs.formats.toml { }).type;
    };
    podman = {
      enable = opts.enable "enable podman";
      dockerSocket = opts.enable' (!cfg.docker.enable) "symlink rootful podman socket to rootful docker";
      rootless = opts.enable ''
        add options to make running rootless containers possible and set some extra defaults
        like enabling pasta and other defaults

        sets {option}`provision.core.security.namespacing.enable`
      '';
      network = {
        enable = opts.enableTrue "set up a netavark, aardvark + slipnetns podman networking setup";
        netavark.enable = opts.enableTrue "enable netavark, a rust based network stack for containers designed for Podman. default since 4.0";
        aardvark.enable = opts.enableTrue "enable aardvark, an authoritative dns server for A/AAAA container records. It can forward other requests to configured resolvers.";
        slirp4netns.enable = opts.enable "enable slirp4netns, user-mode networking for unprivileged network namespaces.";
        pasta.enable = opts.enable "enable pasta, ";
        rootless_cmd = opts.stringNull ''
          set `network.default_rootless_network_cmd`, defaults order (if enabled):
            - pasta
            - slirp4netns
            - not set
        '';
        subnet = lib.mkOption {
          description = "changes the default subnet if set (podman upstream defaults to: 10.88)";
          default = "10.88";
          type = with lib.types; nullOr str;
        };
        default = lib.mkOption {
          description = "default network for podman";
          default = { };
          type = (pkgs.formats.json { }).type;
          example = {
            dns_enabled = true;
            driver = "bridge";
            id = "0000000000000000000000000000000000000000000000000000000000000000";
            internal = false;
            ipam_options = {
              driver = "host-local";
            };
            ipv6_enabled = false;
            name = "podman";
            network_interface = "podman0";
            subnets = [
              {
                gateway = "10.98.0.1";
                subnet = "10.98.0.0/16";
              }
            ];
          };
        };
      };
    };

    storageContainerOverlay = opts.enable "fuse mount /run/containers to /var/lib/containers";

    registries = {
      enable = opts.enableTrue "enable configuration of registries";
      extra = lib.mkOption {
        description = "extra settings to add to {option}`virtualisation.containers.registries.settings`";
        default = { };
        type = settingsType.type;
      };
      config = lib.mkOption {
        description = "a set of registries which is transformed into a list and provided to {option}`virtualisation.containers.registries.settings.registry`";
        default = { };
        type = types.attrsOf (
          types.submodule (
            { name, ... }: {
              freeformType = settingsType.type;
              options = {
                enable = opts.enableTrue "enable registry configuration";
                location = opts.string name "location of registry";
              };
            }
          )
        );
        example = {
          "docker.io".enable = true;
          github = {
            enable = true;
            location = "ghcr.io";
          };
        };
      };
    };

    legacy = {
      netns = opts.enable "wip profile for docker netns";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.docker-client
    ]
    ++ (optional cfg.podman.enable pkgs.podman-compose);
    provision.core.security.namespacing = mkIf cfg.podman.rootless {
      enable = true;
    };

    provision.virt.containers = {
      podman.network = {
        pasta.enable = mkIf cfg.podman.rootless (lib.mkDefault true);
        rootless_cmd = mkIf (network.slirp4netns.enable || network.pasta.enable) (
          if network.pasta.enable then "pasta" else "slirp4netns"
        );
      };
      conf = mkIf (cfg.podman.enable && network.enable) {
        network.network_backend = mkIf network.netavark.enable "netavark";
        network.network_config_dir = "/etc/containers/networks";
        network.default_rootless_network_cmd = mkIf (network.rootless_cmd != null) network.rootless_cmd;
        engine.helper_binaries_dir =
          [ ]
          ++ (optional network.netavark.enable "${pkgs.netavark}/bin")
          ++ (optional network.aardvark.enable "${pkgs.aardvark-dns}/bin")
          ++ (optional network.slirp4netns.enable "${pkgs.slirp4netns}/bin")
          ++ (lib.optionals network.pasta.enable [
            "${pkgs.passt}/bin"
            "${config.virtualisation.podman.package}/libexec/podman"
          ]);
      };
    };

    virtualisation = {
      docker = mkIf cfg.docker.enable {
        enable = true;
        storageDriver = lib.mkIf cfg.docker.zfs "zfs";
        daemon.settings = lib.mkIf cfg.docker.zfs {
          storage-opts = [ "zfs.fsname=${cfg.docker.zfsDataset}" ];
        };
      };

      containers = {
        enable = true;
        containersConf.settings = cfg.conf;
        registries.settings = mkIf cfg.registries.enable (
          lib.mkMerge [
            cfg.registries.extra
            {
              registry = lib.pipe cfg.registries.config [
                (lib.filterAttrs (_: c: c.enable))
                (lib.mapAttrsToList (_: c: lib.removeAttrs c [ "enable" ]))
              ];
            }
          ]
        );
        storage = mkIf cfg.storageContainerOverlay {
          settings.storage = {
            driver = "overlay";
            graphroot = "/var/lib/containers/storage";
            runroot = "/run/containers/storage";
            options = {
              mount_program = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs";
            };
          };
        };
      };

      podman = mkIf cfg.podman.enable {
        enable = true;
        dockerSocket.enable = cfg.podman.dockerSocket;
        defaultNetwork.settings = lib.mkMerge [
          network.default
          {
            dns_enabled = mkDefault true;
            subnets = mkIf (network.subnet != null) [
              {
                gateway = "${network.subnet}.0.1";
                subnet = "${network.subnet}.0.0/16";
              }
            ];
          }
        ];
      };
    };
  };
}
