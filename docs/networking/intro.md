# Networking Integration

NixOS options are located at `provision.networking`.

The modules can be found at [nixosModules/networking](https://github.com/kraftnix/provision-nix/tree/master/nixosModules/networking).

## Features

 - defaults for fail2ban, sshd, wifi, networkd
 - basic config for singular `static` address (useful for single interface IPv4 VPS, simple home thin clients)
    - includes setting kernel param for static address, which can help for LUKS unlock in stage-1 over ssh
