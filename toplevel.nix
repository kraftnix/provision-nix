localFlake@{
  self,
  lib,
  inputs,
  flake-parts-lib,
  ...
}:
let
  l = lib;
  inherit (flake-parts-lib) importApply;
in
{
  imports =
    [
      inputs.flake-parts.flakeModules.easyOverlay
      ./install
      ./scripts
    ]
    # we can't import `provison.flake.all` due to infinite cursion
    ++ (l.mapAttrsToList (_: c: importApply c localFlake) {
      auto-import = ./flakeModules/auto-import;
      channels = ./flakeModules/channels;
      docs = ./flakeModules/docs;
      hosts = ./flakeModules/hosts;
      lib = ./flakeModules/lib.nix;
      nuscht-search = ./flakeModules/nuscht-search;
      packagesGroups = ./flakeModules/packagesGroups.nix;
      profiles = ./flakeModules/profiles.nix;
      scripts = ./scripts/flakeModule.nix;
      site = ./site.nix;
      shells = ./shells/flakeModule.nix;
    });

  flake = {
    devshellModules.provision = importApply ./shells/provision.nix localFlake;
    devshellModules.na-install = importApply ./shells/na-install.nix localFlake;
    nixd.options.nixos = self.nixosConfigurations.testAllProfiles.options;
    lib = import ./lib {
      inherit lib;
      extra-lib = inputs.extra-lib.lib;
    };
    auto-import = {
      enable = true;
      flakeArgs = localFlake;
      addTo = {
        flakeParts = true;
        modules = true;
      };
      flake = {
        dir = ./flakeModules;
        modules.scripts = ./scripts/flakeModule.nix;
        modules.provision-shells = ./shells/flakeModule.nix;
      };
      nixos = {
        dir = ./nixosModules;
        filterByPath = [
          [
            "virt"
            "microvm"
            "vm"
          ]
          # [ "provision" "scripts" ]
        ];
        modules.provision.scripts = ./scripts/nixosModule.nix;
      };
      homeManager.modules.provision.scripts = ./scripts/homeModule.nix;
    };

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
    ] (name: self.nixosConfigurations.${name}.config.system.build.toplevel))
    // {
      nftables-basic = import ./tests/nftables/basic.nix self;
      nftables-nat-and-bridge-filter = import ./tests/nftables/nat-and-bridge-filter.nix self;
      wireguard-basic = import ./tests/wireguard-basic.nix self;
      wireguard-firewall = import ./tests/wireguard-firewall.nix self;
    };

  flake.provisionOverlays = [
    self.overlays.lib
    self.overlays.lnav
  ];
  flake.overlays = {
    lib = final: prev: {
      lib = prev.lib.extend (
        _: _: {
          provision = self.lib;
          # siteBase = "/projects/provision-nix/";
        }
      );
    };
    nix-fast-build = final: prev: {
      # https://github.com/tstack/lnav/issues/1291
      nix-fast-build = localFlake.self.packages.${final.system}.nix-fast-build;
      # lnav = prev.lnav.overrideAttrs (self: {
      #   nativeBuildInputs = self.nativeBuildInputs ++ [prev.tzdata];
      #   buildInputs = self.buildInputs ++ [prev.tzdata];
      # });
    };
    lnav = final: prev: {
      # https://github.com/tstack/lnav/issues/1291
      lnav = final.channels.stable.lnav;
      # lnav = prev.lnav.overrideAttrs (self: {
      #   nativeBuildInputs = self.nativeBuildInputs ++ [prev.tzdata];
      #   buildInputs = self.buildInputs ++ [prev.tzdata];
      # });
    };
  };

  perSystem =
    { config, ... }:
    {
      channels.nixpkgs.overlays = self.hosts.defaults.overlays;
      channels.stable.input = inputs.nixpkgs-stable;
      channels.stable.overlays = [
        (final: prev: {
          # import packages from other channels via overlays
          inherit (config.channels.nixpkgs.pkgs)
            yazi
            dnscrypt-proxy
            matrix-synapse-unwrapped
            ;
        })
      ];
      # FIX(zfs): 6_10 removed from stable and unstable
      channels.nixpkgs-zfs.inputName = "nixpkgs-zfs";
      provision = {
        enable = true;
        enableDefaults = true;
      };
      devshells.default = {
        imports = [ self.devshellModules.na-install ];
        na-install.enable = true;
      };
    };
}
