# Channels Integration

A flake-parts perSystem module that generates instances of `nixpkgs` from flake inputs.
  - `config` can defined per channel
  - `overlays` can be appled per channel
  - an overlay is provided at `overlays.channels` which adds each `channels` to `pkgs` (`pkgs.channels.stable.lnav`)

Module Options Reference for [`perSystem.channels`](../options/flake-all-options.md#persystemchannels)

## Usage

With the following flake inputs:
```nix
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.stable.url = "github:nixos/nixpkgs/release-24.05";
  inputs.latest.url = "github:nixos/nixpkgs";
  inputs.provision-nix.url = "github:kraftnix/provision-nix";
  inputs.provision-nix.inputs.nixpkgs.follows = "nixpkgs";
}
```

Usage:
```nix
{ self, inputs, ... }:
{
  imports = [ inputs.provision-nix.flakeModules.channels ];
  perSystem = { config, ... }: {
    channels.nixpkgs = {
      config.permittedInsecurePackages = [ "electron-28.3.3" ];
      config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        "steam"
        "steamcmd"
        "steam-run"
      ];
      overlays = [
        self.overlays.channels
        (final: prev: {
          inherit (final.channels.stable)
            prometheus
            vector
            ;
        })
        inputs.provision-nix.overlays.lnav
      ];
    };
    channels.stable = {};
    channels.latest = {};
  };
}
```
