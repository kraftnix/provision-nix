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
      wireguard-basic = import ./tests/wireguard-basic.nix self;
      wireguard-firewall = import ./tests/wireguard-firewall.nix self;
    };

  flake.provisionOverlays = [
    self.overlays.lib
    self.overlays.lnav
    self.overlays.nix-curl
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
    lnav = final: prev: {
      # https://github.com/tstack/lnav/issues/1291
      lnav = final.channels.stable.lnav;
      # lnav = prev.lnav.overrideAttrs (self: {
      #   nativeBuildInputs = self.nativeBuildInputs ++ [prev.tzdata];
      #   buildInputs = self.buildInputs ++ [prev.tzdata];
      # });
    };
    nix-curl =
      final: prev:
      let
        # From: https://github.com/diogotcorreia/dotfiles/commit/b68234101b62b52226a6b8c286bda282602db24f
        # Hot fix for curl in nix breaking with netrc
        # https://github.com/NixOS/nixpkgs/pull/356133
        patched-curl = prev.curl.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or [ ]) ++ [
            # https://github.com/curl/curl/issues/15496
            (prev.fetchpatch {
              url = "https://github.com/curl/curl/commit/f5c616930b5cf148b1b2632da4f5963ff48bdf88.patch";
              hash = "sha256-FlsAlBxAzCmHBSP+opJVrZG8XxWJ+VP2ro4RAl3g0pQ=";
            })
            # https://github.com/curl/curl/issues/15513
            (prev.fetchpatch {
              url = "https://github.com/curl/curl/commit/0cdde0fdfbeb8c35420f6d03fa4b77ed73497694.patch";
              hash = "sha256-WP0zahMQIx9PtLmIDyNSJICeIJvN60VzJGN2IhiEYv0=";
            })
          ];
        });
      in
      {
        nix = prev.nix.override (old: {
          curl = patched-curl;
        });
        nixVersions = prev.nixVersions // {
          nix_2_24 = final.nix;
        };
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
