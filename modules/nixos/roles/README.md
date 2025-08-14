# Roles

Roles are used to enable large numbers of default options based on what kind
of machine they are.

This can reduce a lot of boilerplate, if you run many hosts with similar configurations.

Currently there are two available roles:
 - [Desktop](#Desktop)
 - [Edge](#Edge)

## Desktop

Designed for desktop use, sets up:
  - base shell + env
  - systemd-networkd networking
  - boot integrated, systemd-boot by default but can be changed
  - initrd + SSH encrypted root unlock

Module Options Reference for [`provision.roles.desktop`](../../options/nixos-all-options.md#provisionrolesdesktopenable)

Example Usage:
```nix
provision.roles.desktop = {
  enable = true;
  # add myuser as nix trusted user
  trustedNixUsers = ["myuser"];
  # import SSH keyFiles from my user into initrd.networkd authorizedKeyFiles
  initrdUnlockUsers = ["myuser"];
};
```

Produces:
```nix
{{#include ../../../modules/nixos/roles/desktop.nix:25:48}}
```

## Edge

Designed for server use, sets up:
 - base shell + env
 - garbage collected + optimised nix
 - systemd-networkd networking
 - boot integrated, systemd-boot by default but can be changed
 - initrd + SSH encrypted root unlock

Module Options Reference for [`provision.roles.edge`](../../options/nixos-all-options.md#provisionrolesedgeenable)

Example Usage:
```nix
provision.roles.desktop = {
  enable = true;
  # increase inotify limits multiple
  bigMachine = true;
  # add deploy as nix trusted user, can be required for remote deploys
  trustedNixUsers = ["deploy"];
  # import SSH keyFiles from deploy user into initrd.networkd authorizedKeyFiles
  initrdUnlockUsers = ["deploy"];
  # add network kernel modules to stage-1 boot for remote unlock over SSH
  initrdNetModules = ["e1000e"];
};
```

Produces:
```nix
{{#include ../../../modules/nixos/roles/edge.nix:31:54}}
```
