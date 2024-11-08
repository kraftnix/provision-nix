# Installation

First add `provision-nix` to your flake inputs.

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    provision-nix.url = "github:kraftnix/provision-nix";
    provision-nix.inputs.nixpkgs.follows = "nixpkgs";
  };
}

```

## Flake Modules

Flake integration is provided via `flake-parts` modules under `flakeModules`.

More info for provided flakes [here](../flake/intro.md).

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    provision-nix.url = "github:kraftnix/provision-nix";
    provision-nix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs @ { self, flake-parts, ... }:
    flake-parts.lib.mkFlake {inherit inputs;} {

      # selectively import
      imports = [
        inputs.provision-nix.flakeModules.channels
        inputs.provision-nix.flakeModules.hosts
        inputs.provision-nix.flakeModules.scripts
      ];

      # or import all
      # imports = inputs.provision-nix.flakeModulesAll

      systems = ["x86_64-linux" "aarch64-linux"];
    };
}
```

## NixOS Modules

NixOS Modules are provided under `nixosModules`.

More info for provided NixOS integrations [here](../core/intro.md).

Use a single module:
```nix
{ inputs, ... }:
{
  imports = [ inputs.provision-nix.nixosModules.scripts ]; 
  provision.scripts.enable = true;
  provision.scripts.scripts.top-five.text = "ps -l | sort-by cpu -r | take 5";
}
```

Alternatively, you can import all nixos modules provided:
```nix
{ inputs, ... }:
{
  imports = inputs.provision-nix.nixosModulesAll;
  provision.core.env.enable = true;
  networking.nftables.gen.enable = true;
}
```

## Home Manager Modules

A single home-manager module is provided by for the [Scripts Integration](../scripts/intro.md).

## Other Outputs

Some library functions are provided at `lib`.

Disko profiles can be directly imported from `disko`, however using the nixosModule integration is suggested.
See [Disko Integration Docs](../filesystems/disko.md) for more information.
