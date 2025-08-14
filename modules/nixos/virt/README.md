# Virtualisation

This submodule contains NixOS modules for configuring virtualisation technologies.

These are defined under `provision.virt`, which helps to configure:
  - [MicroVM wrapper]({{DOCSITE_BASE}}/virtualisation/microvm.html)
  - containerisation (i.e. `docker`, `podman`)
  - qemu guest options

Module Options Reference for [`provision.virt`](../../options/nixos-all-options.md#provisionvirtbuildarm)

## QEMU

There is a shortcut for the equivalent of importing nixpkgs' guest-agent
```nix
provision.virt.qemu.guestAgent = true;
```

There are some quirky qemu-user magic optimisations that I found somewhere (lost in time)
and have tested a little bit at `provision.virt.qemu.smart`, your mileage may vary.

## Libvirt

There are some small integrations to make running libvirt a bit easier.

> ⚠ At the moment, this module is mostly legacy code, in general you should not use
> ⚠ it unless you already are (and don't want to move). It will be eventually
> ⚠ removed, and replaced with a cleaner setup.

This enabled libvirtd and creates a bridge network called `libvirt-default` on `enp1s0`
with a subnet of `192.168.15.0/24`. (see how badly this is hardcoded)
```nix
provision.virt.libvirt = {
  enable = true; # enables libvirtd + Spice USB emulation
  legacy.networking.enable = true;
};
```
