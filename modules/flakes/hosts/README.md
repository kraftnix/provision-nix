# Hosts Integration

A flake-parts module that generates `nixosConfigurations` with defaults:
  - auto-import host configurations from a directory
  - define default `modules`, `overlays`, `specialArgs` for hosts
  - define extra options for colmena, deploy-rs integration

Module Options Reference for [`flake.hosts`](../options/flake-all-options.md#flakehosts)

## Auto Import

Host configurations are imported from `hosts.hostsDir`.

Host configurations can be defined as a file `myhost.nix` or a directory `myhost/default.nix`.
If a file or directory is prefixed with `__`, it will be ignored.
The toplevel `default.nix` is also ignored in `hosts.hostsDir`.

Example Directory Structure:
```sh
tree hosts
├── __archive # everything in directory is ignored
│   └── ignored.nix
├── __ignoreThis.nix # ignored
├── basic.nix
├── default.nix # ignored
├── server
│   └── default.nix
```

Configuration:
```nix
{ self, inputs, ... }:
{
  imports = [ inputs.provision-nix.flakeModules.hosts ];
  flake = {
    hosts.enable = true;
    # populates `hosts.configs`
    hosts.hostsDir = ./hosts;
  };
}
```

## Defaults (modules, overlays, specialArgs)

A number of defaults are added to any hosts defined in `hosts.configs`.

Basic usage:
```nix
{ self, inputs, ... }:
{
  flake.hosts.defaults = {
    # add these modules to all hosts
    modules = [
      { networking.firewall.enable = true; }
      ({ config, ... }: {
        networking.domain = "${config.networking.hostName}.internal";
      });
      inputs.provision-nix.nixosModules.provision-scripts
    ];
    # add these overlays to all hosts
    overlays = [
      (final: prev: {
        inherit (inputs.nixpkgs-latest.legacyPackages.${prev.system})
          prometheus
          vector
          ;
      })
      inputs.provision-nix.overlays.lnav
    ];
    # add specialArgs to all hosts
    specialArgs = {
      inherit self inputs;
    };
  };
}
```

## Extra per-host options

You can also add extra `modules`, `overlays`, `specialArgs` and deployment options (colmena, deploy-rs).

Basic usage:
```nix
{ self, inputs, ... }:
{
  flake.hosts.configs = {
    basic = {
      modules = [ ./containers.nix ];
      overlays = [ ];
      specialArgs = { };
      colmena = {
        targetUser = "deploy";
        targetHost = "192.168.0.15";
      };
      deploy = {
        sshUser = "deploy";
        hostname = "192.168.0.15";
      };
    };
  };
}
```
