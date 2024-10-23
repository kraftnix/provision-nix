{
  self,
  flake-parts-lib,
  ...
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (flake-parts-lib) importApply;
  inherit (lib) mkIf optional;
  opts = self.lib.options;
  cfg = config.provision.virt.containers;
in {
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
    podman = {
      enable = opts.enable "enable podman";
      dockerSocket = opts.enable' (!cfg.docker.enable) "symlink rootful podman socket to rootful docker";
      allowRootless = opts.enable "required `security.unprivilegedUsernsClone` to be set";
      niceNetworkStack = opts.enableTrue "set up a netavark, aardvark + slipnetns podman networking setup";
    };

    storageContainerOverlay = opts.enable "fuse mount /run/containers to /var/lib/containers";

    registries = {
      search = opts.stringList [
        "localhost"
        "quay.io"
        "nixery.dev"
        # "docker.io"
      ] "registries to search";
      block = opts.stringList [] "registries to block";
    };

    legacy = {
      netns = opts.enable "wip profile for docker netns";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages =
      [
        pkgs.docker-client
      ]
      ++ (optional cfg.podman.enable pkgs.podman-compose);
    security.unprivilegedUsernsClone = mkIf cfg.podman.allowRootless true;

    virtualisation = {
      containerd.enable = true;
      docker = {
        enable = cfg.docker.enable;
        storageDriver = lib.mkIF cfg.docker.zfs "zfs";
        daemon.settings = lib.mkIf cfg.docker.zfs {
          storage-opts = ["zfs.fsname=${cfg.docker.zfsDataset}"];
        };
      };

      containers = {
        enable = true;
        registries = {
          inherit (cfg.registries) search block;
        };
        containersConf = mkIf cfg.podman.enable {
          settings = mkIf cfg.podman.niceNetworkStack {
            network.network_backend = "netavark";
            engine.helper_binaries_dir = with pkgs; [
              "${netavark}/bin"
              "${aardvark-dns}/bin"
              "${slirp4netns}/bin"
            ];
          };
        };
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
        dockerSocket.enable = true;
        defaultNetwork.settings.dns_enabled = lib.mkDefault true;
      };
    };
  };
}
