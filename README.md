# Provision Nix

`provision-nix` is a library-like collection of flake and nixos modules reduce boilerplate code for a bunch of setups.

The module extends NixOS with default configurations and behaviours, focusing on:
    + networking
        + wireguard
        + networkd
        + ssh
        + firewall
    + filesystems
        + disko profiles
        + boot
        + basic support: bcachefs, btrfs, zfs, nfs

<!-- TODO: replace with proper docs link -->
For more information, have a look at the [Documentation](https://github.com/kraftnix/provision-nix)
