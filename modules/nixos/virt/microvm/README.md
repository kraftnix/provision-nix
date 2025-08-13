# MicroVM integration

This module wraps around [microvm.nix](https://github.com/astro/microvm.nix) to
easily populate common `microvm` options on both `host` and `guest`.

To get started with `microvm.nix` some configuration is normally required on the host
running the VMs; particularly for networking.

## Host configuration

The following host configuration adds a bridge called `microvm` which attachs
`vm*` tap devices to the bridge.

Module Options Reference for [`provision.virt.microvm.host`](../options/nixos-all-options.md#provisionvirtmicrovmhostenable)

```nix
provision.virt.microvm.host = {
  enable = true;
  network = {
    nat.enable = true;
    basic = {
      enable = true;
      # name = "microvm"; # change bridge name
      # ipv4Subnet = "10.213.0.1/24"; # change internal IPv4 range
      # ipv6Prefix = "fd12:3456:789a::"; # change internal IPv6 range
    };
  };
};
```

## Guest Configuration

There are more options provided for configuring the guest side of the microvms.
Many options are mirrored from `microvm`'s options and are passed through to microvm, if set.

Module Options Reference for [`provision.virt.microvm.guest`](../options/nixos-all-options.md#provisionvirtmicrovmguestenable)

### Basic

The following options are core / basic options that you would set for every microvm:
```nix
microvm.guest.enable = true;
provision.virt.microvm.guest = {
  enable = true;
  # machineid = "deadbeaf"; # optionally set machine-id of guest
  vcpu = 2;
  mem = 1000;
  hypervisor = "cloud-hypervisor";
};
```

### Network

Add a single basic interface to guest VM. The `n` field must be unique per microvm on host
if you want to attach to the default host `microvm` bridge.

This is a bit unideal, future solutions will be provided.

```nix
provision.virt.microvm.guest = {
  network.base = {
    enable = true;
    # n = 1;
  };
};
```

### Volumes and Shares

A unified option is provided to configure both `microvm.shares` and `microvm.volumes` under
`mounts`.

```nix
provision.virt.microvm.guest = {
  mounts.cni = {
    enable = true;
    mountpoint = "/var/lib/cni"; # mountpoint in guest
    volume.size = 1000; # by default, a mount is a volume
  };
  mounts.persist = {
    enable = true;
    mountpoint = "/persist";
    share.enable = true; # use as a share
    # share.proto = "9p"; # change share protocol, default: `virtiofs`
  };
};
```

### Nix Store

You may want to share your host nix store to reduce the image size of the microvm.
If you  want to use nix within the VM, you can enable the `writableStoreOverlay`.

#### Share read-only host `/nix/store` with VM

```nix
provision.virt.microvm.guest.store.readonly.enable = true;
```

#### Share writeable `/nix/store` within the VM

```nix
provision.virt.microvm.guest = {
  store.readwrite = {
    enable = true;
    size = 5000; # 5 GB writable nix store within guest VM
  };
};
```

### ToDo

  - [ ] Add impermanence integration
  - [ ] Reduce default enabled shared in guest module (move to profiles)
