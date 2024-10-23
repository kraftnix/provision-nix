localFlake @ {
  self,
  lib,
  inputs,
  flake-parts-lib,
  ...
}: let
  l = lib;
  inherit (flake-parts-lib) importApply;
  flakeModules = {
    hosts = ./flakeModules/hosts/hosts.nix;
    lib = ./flakeModules/lib-module.nix;
    packagesGroups = ./flakeModules/packagesGroups.nix;
    channels = ./flakeModules/channels.nix;
    profiles = ./flakeModules/profiles.nix;
    home = ./flakeModules/home-module.nix;
    nixosModulesExtended = ./flakeModules/nixos-module-wrapper.nix;
    scripts = importApply ../nixos/scripts/flakeModule.nix localFlake;
  };
  provision = import ./lib {
    inherit lib;
    extra-lib = inputs.extra-lib.lib;
  };
  flakeModulesAll = l.attrValues flakeModules;
in {
  imports =
    [
      inputs.flake-parts.flakeModules.easyOverlay
    ]
    ++ (l.attrValues flakeModules);

  flake = {
    inherit flakeModules flakeModulesAll;
    lib = provision;
  };

  # for CI / nix-fast-build
  flake.checks.x86_64-linux =
    (lib.genAttrs [
        "basic"
        "basic-iso"
        "testAllProfiles"
        "testSecurity"
        "testBtrfsBios"
        "testZfsUefi"
      ]
      (name: self.nixosConfigurations.${name}.config.system.build.toplevel))
    // {
      wireguard-basic = import ./tests/wireguard-basic.nix self;
      wireguard-firewall = import ./tests/wireguard-firewall.nix self;
    };

  flake.provisionOverlays = [
    self.overlays.lib
    self.overlays.lnav
  ];
  flake.overlays = {
    lib = final: prev: {
      lib = prev.lib.extend (_: _: {
        inherit provision;
      });
    };
    lnav = final: prev: {
      # https://github.com/tstack/lnav/issues/1291
      lnav = prev.lnav.overrideAttrs (self: {
        nativeBuildInputs = self.nativeBuildInputs ++ [prev.tzdata];
        buildInputs = self.buildInputs ++ [prev.tzdata];
      });
    };
  };
}
