# Networking Integration

NixOS options are located at `provision.networking`.

Module Options Reference for [`provision.networking`](../../options/nixos-all-options.md#provisionnetworkingfail2banenable)

The modules can be found at [modules/nixos/networking]({{git_file_base_url}}modules/nixos/networking).

## Features

 - defaults for fail2ban, sshd, wifi, networkd
 - basic config for singular `static` address (useful for single interface IPv4 VPS, simple home thin clients)
    - includes setting kernel param for static address, which can help for LUKS unlock in stage-1 over ssh
