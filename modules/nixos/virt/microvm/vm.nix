{ self, ... }:
{
  config,
  options,
  lib,
  pkgs,
  ...
}:
let
  toplevel = config;
  cfg = config.provision.virt.microvm.vm;
  opts = self.lib.options;
  inherit (lib)
    hasAttr
    filterAttrs
    flatten
    optionalString
    mkDefault
    mkIf
    mkMerge
    types
    ;
  # n:
  # - cloud-hypervisor: 2
  # - nspawn: 3
  mkVolume =
    {
      image,
      size,
      mountpoint,
      ...
    }:
    {
      inherit image size;
      mountPoint = mountpoint;
      # image = "var.img";
    };
  mkShare =
    {
      hostPath,
      mountpoint,
      tag,
      proto,
      socket,
      ...
    }:
    {
      inherit proto tag socket;
      source = hostPath;
      mountPoint = mountpoint;
    };
in
{
  options.provision.virt.microvm.vm = {
    enable = opts.enable ''
      Enables microvm vm extensions.

      You must still enable `microvm.guest.enable`, cannot set in this module due to infinite recursion.
    '';
    cid = opts.intNull "sets vsock.cid (and {network.base.id})";
    machineid = opts.stringNull "if set, sets a machine id in the microvm (useful for persistent logs)";
    vcpu = opts.intNull "number of vCPUs (`microvm.vcpu`)";
    mem = opts.intNull "amount of RAM for server in MB (`microvm.mem`)";
    socket = opts.string "control.socket" "name control socket of VM (`microvm.socket`)";
    hypervisor = lib.mkOption {
      default = "cloud-hypervisor";
      description = "sets `microvm.hypervisor`";
      type = types.enum [
        "cloud-hypervisor"
        "qemu"
        "firecracker"
        "crosvm"
      ];
    };

    network = {
      base = {
        enable = opts.enableTrue "enable base network interface";
        n = opts.int 0 "vm number, only support up to 10 (0-9)";
        mac = opts.string "00:02:00:01:01:0${toString cfg.network.base.n}" ''
          MAC Address of microvm's base interface. Auto-generated using `n`.
        '';
        id = opts.string "vmch-${builtins.substring 0 12 config.networking.hostName}" ''
          Virto-io tag name
        '';
        type = lib.mkOption {
          type = lib.types.enum [ "tap" ];
          default = "tap";
          description = "interface type";
        };
      };
    };

    mounts = lib.mkOption {
      description = "combined share/volume wrapper around microvm shares/volumes";
      default = { };
      type = types.attrsOf (
        types.submodule (
          {
            config,
            name,
            ...
          }:
          {
            options = {
              enable = opts.enable "enable mount, overrides volume + share enablement, volume is default";
              name = opts.string name "mount name";
              mountpoint = opts.string "/var/lib/${config.name}" "vm internal mountpoint";
              volume = {
                enable = opts.enable' (!config.share.enable) "enable volume";
                sizeGB = opts.int 3 "size (in GB of volumes)";
                size = opts.int (config.volume.sizeGB * 1000) "size (in MB) of volume";
                mountpoint = opts.string config.mountpoint "volume mountpoint in VM";
                image = opts.string "${config.name}.img" "image name";
              };
              share = {
                enable = opts.enable "share for mount in VM";
                hostPath = opts.string "/var/lib/microvms/${toplevel.networking.hostName}/${config.name}" ''
                  Host path of share
                '';
                mountpoint = opts.string config.mountpoint "share mountpoint in VM";
                tag = opts.string config.name "share mountpoint in VM";
                socket = opts.string "${config.share.tag}.sock" "share mountpoint in VM";
                proto = lib.mkOption {
                  default = "virtiofs";
                  description = "mount / share protocol";
                  type = types.enum [
                    "virtiofs"
                    "9p"
                  ];
                };
              };
            };
          }
        )
      );
    };

    store = {
      readwrite = {
        enable = opts.enable "enable re-write store via writeable volume on top of host read-only share";
        size = opts.int 2000 "size of volume in MB";
      };
      readonly.enable = opts.enable' (cfg.store.readwrite.enable) "enable ro-store overlay of host store";
    };
  };

  config = mkMerge (flatten [

    (mkIf cfg.enable {
      provision.virt.microvm.vm.mounts = {
        containers.share.enable = true;
        etc = {
          volume.size = mkDefault 50;
          mountpoint = "/etc";
        };
        home = {
          share.enable = true;
          mountpoint = mkDefault "/home";
        };
        journal = {
          share.enable = true;
          mountpoint = mkDefault "/var/log/journal";
        };
        var = {
          mountpoint = mkDefault "/var";
          volume.sizeGB = mkDefault 1;
        };
        ro-store = {
          enable = cfg.store.readonly.enable;
          mountpoint = "/nix/.ro-store";
          share.enable = true;
          share.hostPath = "/nix/store";
        };
        rw-store-vol = {
          enable = cfg.store.readwrite.enable;
          mountpoint = optionalString cfg.store.readwrite.enable config.microvm.writableStoreOverlay;
          volume.size = cfg.store.readwrite.size;
        };
      };

      environment.etc = mkIf (cfg.machineid != null) {
        machine-id = {
          mode = "0644";
          text = cfg.machineid;
        };
      };
    })

    (lib.optional ((hasAttr "microvm" options) && (hasAttr "guest" options.microvm)) {
      microvm = mkIf cfg.enable {
        guest.enable = true;
        hypervisor = cfg.hypervisor;
        vsock.cid = mkIf (cfg.cid != null) cfg.cid;
        writableStoreOverlay = mkIf cfg.store.readwrite.enable "/nix/.rw-store";
        vcpu = mkIf (cfg.vcpu != null) cfg.vcpu;
        mem = mkIf (cfg.mem != null) cfg.mem;
        socket = cfg.socket;
        shares = lib.pipe cfg.mounts [
          (lib.filterAttrs (_: mount: mount.enable && mount.share.enable))
          (lib.mapAttrsToList (_: mount: [ (mkShare mount.share) ]))
          lib.flatten
        ];
        volumes = lib.pipe cfg.mounts [
          (lib.filterAttrs (_: mount: mount.enable && mount.volume.enable))
          (lib.mapAttrsToList (_: mount: [ (mkVolume mount.volume) ]))
          lib.flatten
        ];
        interfaces = mkIf cfg.network.base.enable [ { inherit (cfg.network.base) id mac type; } ];
      };
    })

  ]);

}
