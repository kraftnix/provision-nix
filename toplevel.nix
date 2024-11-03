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
    scripts = importApply ./scripts/flakeModule.nix localFlake;
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
    __provision.nixosModules.flakeArgs = localFlake;
    __provision.nixosModules.dir = ./nixosModules;
    __provision.nixosModules.filterByPath = [
      ["virt" "microvm" "vm"]
      # [ "provision" "scripts" ]
    ];

    profiles = lib.recursiveUpdate (self.lib.nix.rakeLeaves ./profiles) {
      users = {
        #test-deploy = import ./profiles/users/test-deploy.nix args;
        # test-deploy = import ./profiles/users/test-deploy.nix;
        # test-operator = import ./profiles/users/test-operator.nix;
        test-deploy = ./profiles/users/test-deploy.nix;
        test-operator = ./profiles/users/test-operator.nix;
      };
    };
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

  perSystem = {config, ...}: {
    channels.nixpkgs.overlays = self.hosts.defaults.overlays;
    channels.stable.input = inputs.nixpkgs-stable;
    channels.stable.overlays = [
      (final: prev: {
        # import packages from other channels via overlays
        inherit
          (config.channels.nixpkgs.pkgs)
          yazi
          dnscrypt-proxy
          matrix-synapse-unwrapped
          ;
      })
    ];
    # FIX(zfs): 6_10 removed from stable and unstable
    channels.nixpkgs-zfs.inputName = "nixpkgs-zfs";
  };
}
