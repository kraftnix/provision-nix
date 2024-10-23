{self, ...}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkIf
    types
    mapAttrsToList
    flatten
    optional
    mkMerge
    optionalString
    ;
  opts = self.lib.options;
  cfg = config.provision.fs.btrfs;

  subvolume = {
    config,
    name,
    mntBase,
    rootName,
    devicePath,
    defaultOptions,
    ...
  }: {
    options = {
      __rootName = opts.string rootName "name of the root btrfs filesystem";
      __devicePath = opts.string devicePath "root fs path, normally inheritted by root";
      __mntBase = opts.string mntBase "base mountpoint of the filesystem";
      __mnt =
        opts.string "${config.__mntBase}${optionalString (config.mnt != "") config.mnt}" "final mount location"
        // {
          apply = lib.replaceStrings ["//" "///"] ["/" "/"];
        };
      subvol = opts.string name "name of subvolume";
      mnt = opts.string (optionalString (!config.isRoot) config.subvol) "mountpoint of the subvolume";
      isRoot = opts.enable "allow handling mounting root btrfs fs, not applicable if you have use a subvolume for root";
      opts =
        opts.stringList defaultOptions "options to set on subvolume"
        // {
          example = ["compress=zstd" "noatime"];
        };
    };
  };

  btrfsFs = {
    name,
    config,
    ...
  }: {
    options = {
      name = opts.string name "name of the filesystem, by default sets fs root path to `/dev/mapper/<name>";
      devicePath =
        opts.string "/dev/mapper/${config.name}" "root fs path"
        // {
          example = "/dev/disk/by-label/nixos";
        };
      mntBase = opts.string "/" "root of this btrfs filesystem";
      defaultOptions =
        opts.stringList [] "default options to add to all subvolumes, can be overridden"
        // {
          example = ["compress=zstd"];
        };
      subvolumes = lib.mkOption {
        type = types.attrsOf (types.submoduleWith {
          modules = [
            subvolume
            {
              config._module.args = {
                rootName = config.name;
                inherit (config) devicePath defaultOptions mntBase;
              };
            }
          ];
        });
        default = {};
        description = "subvolumes under this btrfs filesystem";
      };
    };
  };
in {
  imports = [
    ./legacy-initrd.nix
    ./legacy-root-bios.nix
    ./legacy-root-uefi.nix
    ./btrbk/core-root.nix
    ./btrbk/snapshot-root.nix
    ./btrbk/snapshot-root-nix.nix
  ];

  options.provision.fs.btrfs = {
    enable = opts.enable "enable btrfs configuration, adds btrfs to supportedFilesystems";

    gen = lib.mkOption {
      default = {};
      type = types.attrsOf (types.submodule btrfsFs);
      description = ''
        generate btrfs filesystem mounts
      '';
      example = {
        enc-root = {
          # otherwise set to "/dev/mapperenc-root"
          devicePath = "/dev/disk/by-uuid/my-luks-decrupted-uuid";
          defaultOptions = ["compress=zstd"];
          subvolumes = {
            root.path = "/";
            home = {};
            nix.options = ["compress=zstd,noatime"];
            log.path = "/var/log";
          };
        };
      };
    };

    legacy = {
      root-bios = opts.enable "import the legacy profile for `root-bios`, do not use unless already using";
      root-uefi = opts.enable "import the legacy profile for `root-uefi`, do not use unless already using";
      initrd = opts.enable "import the legacy profile for `initrd`, do not use unless already using";
      btrbk-core-root = opts.enable "import the legacy profile for `btrbk/core-root`, do not use unless already using";
      btrbk-snapshot-root = opts.enable "import the legacy profile for `btrbk/snapshot-root`, do not use unless already using";
      btrbk-snapshot-root-nix = opts.enable "import the legacy profile for `btrbk/snapshot-root-nix`, do not use unless already using";
    };
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems = ["btrfs"];
    environment.systemPackages = with pkgs; [
      btrfs-progs
      btrfs-heatmap
      btdu
      btrfs-list
    ];

    fileSystems = lib.pipe cfg.gen [
      (mapAttrsToList (
        _: cfg:
          mapAttrsToList
          (_: subvol: {
            "${subvol.__mnt}" = let
              opts = subvol.opts ++ (optional (!subvol.isRoot) "subvol=${subvol.subvol}");
            in {
              options = lib.mkIf (opts != []) opts;
              device = subvol.__devicePath;
              fsType = "btrfs";
            };
          })
          cfg.subvolumes
      ))
      flatten
      mkMerge
    ];
  };
}
