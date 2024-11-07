{
  config,
  self,
  inputs,
  lib,
  flake-parts-lib,
  withSystem,
  ...
}: let
  inherit
    (lib)
    filterAttrs
    hasPrefix
    mapAttrs
    mkDefault
    mkOption
    types
    ;
  inherit
    (flake-parts-lib)
    mkSubmoduleOptions
    ;
  inherit (inputs.extra-lib.lib.std-compat) rakeLeaves;

  rakedHosts = rakeLeaves cfg.hostsDir;
  filterDefault = filterAttrs (n: _: n != "default");
  filterUnderscore = filterAttrs (n: _: !(hasPrefix "__" n));
  filteredRakedHosts = filterDefault (filterUnderscore rakedHosts);

  overlayType = lib.mkOptionType {
    name = "nixpkgs-overlay";
    description = "nixpkgs overlay";
    check = lib.isFunction;
    merge = lib.mergeOneOption;
  };

  hostDefaultsModule = types.submoduleWith {
    modules = [
      ./host-options.nix
      {config._module.args.self = self;}
      {config._module.args.colmena = cfg.colmena;}
    ];
  };
  hostModule = types.submoduleWith {
    modules = [
      ./host-options.nix
      {config._module.args.self = self;}
      {config._module.args.colmena = cfg.colmena;}
      # Rendered host configuration
      ({config, ...}: {
        options.enable = mkOption {
          default = true;
          type = types.bool;
          description = "whether to generate flake config for `nixosConfigurations`, `colmena` and `deploy`";
        };
        options.hostname = mkOption {
          default = config._module.args.name;
          type = types.str;
          description = "hostname to set for `networking.hostName` in hosts nixosConfiguration";
        };
        options.rendered = mkOption {
          type = types.lazyAttrsOf types.raw;
          default = {};
          description = ''
            Post eval nixosConfiguration field, added to `nixosConfigurations`.
          '';
        };
        config.rendered = genNixos config;
      })
    ];
  };

  cfg = config.flake.hosts;

  hostDefaults = cfg.defaults;
  hosts = filterAttrs (_: c: c.enable) cfg.configs;

  evalConfig = pkgs: import "${pkgs.path}/nixos/lib/eval-config.nix";
  # create system with special imported args
  genNixos = {
    hostname,
    system,
    system-config,
    self,
    modules,
    overlays,
    moduleArgs,
    specialArgs,
    nixpkgs,
    ...
  } @ args: let
    c = withSystem system (
      # ctx@{ pkgs, self', inputs', ... }: (evalConfig args.self) {
      ctx @ {
        pkgs,
        self',
        inputs',
        ...
      }:
        (evalConfig nixpkgs) {
          inherit system;
          pkgs = nixpkgs;
          specialArgs = hostDefaults.specialArgs // specialArgs;
          modules = lib.unique (lib.flatten [
            args.system-config
            {
              # config.nixpkgs.pkgs = nixpkgs;
              config.nixpkgs.overlays = hostDefaults.overlays ++ overlays;
              config._module.args =
                hostDefaults.moduleArgs
                // {
                  packages = ctx.config.packages;
                }
                // moduleArgs;
              config.networking.hostName = hostname;
            }
            modules
            hostDefaults.modules
          ]);
        }
    );
  in
    {inherit (c.config.system) build;} // c;

  colmenaHosts =
    mapAttrs
    (
      host: cfg: {
        name,
        nodes,
        pkgs,
        ...
      }: {
        imports = cfg.rendered._module.args.modules;
        deployment = cfg.colmena;
      }
    )
    hosts;

  deployRsHosts =
    mapAttrs
    (hostName: cfg:
      cfg.deploy
      // {
        profiles.system = {
          user = "root";
          path = inputs.deploy-rs.lib.${cfg.system}.activate.nixos cfg.rendered;
        };
      })
    hosts;

  mapDefault = mapAttrs (_: mkDefault);
in {
  options = {
    flake = mkSubmoduleOptions {
      hosts = mkOption {
        description = ''
          Auto-define hosts.
            - auto-import host configurations from a directory
            - define default modules, overlays, specialArgs for hosts
            - define extra options for colmena, deploy-rs integration
        '';
        default = {};
        type = types.submodule {
          config.defaults = mapDefault {
            inherit self;
            system = "x86_64-linux";
            modules = self.modules.default;
            specialArgs = mapDefault {
              inherit self;
              inherit (self) inputs nixosModules profiles;
            };
          };
          options = {
            defaults = mkOption {
              default = {};
              type = hostDefaultsModule;
              description = "default options for generating hosts with `genNixos`";
            };
            configs = mkOption {
              type = types.lazyAttrsOf hostModule;
              default = {};
              # apply = mapAttrs (overrideHosts hostDefaults);
              description = ''
                Define hosts inline, host configurations are auto-imported from {hostsDir} and added to `modules``;
                  - modules: extra modules, auto-adds modules from `defaults.modules`
                  - overlays: extra overlays, auto-adds overlays from `overlays`
                  - nixpkgs: pkgs set, auto-adds from `channels.{system}.nixpkgs.pkgs`
                  - system
                  - specialArgs
                  - deploy options (colmena, deploy-rs)
              '';
            };
            rendered = mkOption {
              readOnly = true;
              type = types.lazyAttrsOf types.raw;
              default = mapAttrs (_: cfg: cfg.rendered.config) hosts;
              description = ''
                Post eval nixosConfiguration's `config` field, useful for introspection.
              '';
            };
            overlays = mkOption {
              type = types.listOf overlayType;
              default = [];
              description = ''
                List of overlays to add to all hosts.
              '';
            };
            colmena = mkOption {
              type = types.raw;
              default = {};
              description = ''
                Colmena options to add to each host.
              '';
            };
            deploy-rs = mkOption {
              type = types.raw;
              default = {};
              description = ''
                Default options for deploy-rs's global options (not including nodes).
              '';
            };
            hostsDir = mkOption {
              type = types.nullOr types.path;
              default = null;
              example = ../../hosts;
              description = ''
                If set, then a `rakeLeaves` is performed on the path, and entries are used
                to seed `flake.hosts.configs`.

                toplevel default file is ignored (`{hostsDir}/default.nix`).
              '';
            };
          };
        };
      };
    };
  };

  config = {
    flake = {
      hosts.configs = lib.mkIf (cfg.hostsDir != null) (
        mapAttrs
        (name: path: {
          modules = [path];
        })
        filteredRakedHosts
      );

      nixosConfigurations =
        mapAttrs
        (
          host: cfg:
            genNixos (cfg
              // {
                # modules = cfg.modules ++ [ self.inputs.colmena.nixosModules.deploymentOptions ];
              })
        )
        hosts;

      colmenaHive = inputs.colmena.lib.makeHive self.outputs.colmena;
      colmena =
        {
          meta = {
            nixpkgs = self.channels.x86_64-linux.nixpkgs.pkgs;
            specialArgs = hostDefaults.specialArgs;
            nodeNixpkgs = mapAttrs (_: cfg: cfg.nixpkgs) hosts;
          };
        }
        // colmenaHosts;
      deploy =
        config.flake.hosts.deploy-rs
        // {
          nodes = deployRsHosts;
        };
    };
  };
}
