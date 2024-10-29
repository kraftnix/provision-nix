{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.nixpkgs-stable.url = "github:nixos/nixpkgs/release-24.05";
  inputs.nixlib.url = "github:nix-community/nixpkgs.lib";

  inputs.extra-lib.url = "github:kraftnix/extra-lib";
  inputs.extra-lib.inputs.nixlib.follows = "nixlib";

  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  inputs.microvm = {
    url = "github:astro/microvm.nix";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-utils.follows = "flake-utils";
  };

  # core
  inputs = {
    systems.url = "github:nix-systems/default";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";
    flake-compat = {
      url = "github:inclyc/flake-compat";
      flake = false;
    };
  };

  # dev
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixlib";

    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    git-hooks-nix.inputs = {
      nixpkgs.follows = "nixpkgs";
      nixpkgs-stable.follows = "nixpkgs-stable";
      flake-compat.follows = "flake-compat";
    };

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
  };

  # deploy
  inputs = {
    # https://github.com/zhaofengli/colmena/pull/228
    colmena.url = "github:zhaofengli/colmena/direct-flake-eval";
    colmena.inputs = {
      nixpkgs.follows = "nixpkgs";
      stable.follows = "nixpkgs-stable";
      flake-utils.follows = "flake-utils";
      flake-compat.follows = "flake-compat";
    };

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs = {
      nixpkgs.follows = "nixpkgs";
      utils.follows = "flake-utils";
      flake-compat.follows = "flake-compat";
    };
  };

  # install
  inputs = {
    nixos-anywhere.url = "github:numtide/nixos-anywhere";
    nixos-anywhere.inputs = {
      nixpkgs.follows = "nixpkgs";
      flake-parts.follows = "flake-parts";
      nixos-stable.follows = "nixpkgs-stable";
      disko.follows = "disko";
    };

    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators = {
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixlib.follows = "nixlib";
    };
  };

  # TODO: better way to enable
  # if you want to use yubikey iso
  # inputs.drduh.url = "github:DrDuh/YubiKey-Guide";
  # inputs.drduh.inputs.nixpkgs.follows = "nixpkgs";

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      debug = true;
      imports = [
        ./disko
        ./docs/nix
        ./hosts
        ./install
        ./packages
        ./scripts
        ./shells
        ./toplevel.nix
      ];
      systems = ["x86_64-linux" "aarch64-linux"];
    };

  nixConfig = {
    extra-experimental-features = ["nix-command" "flakes"];
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://colmena.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg="
    ];
  };
}
