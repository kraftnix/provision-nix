localFlake: {
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
    literalExpression
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
    specialArgs = {
      inherit self;
      inherit (cfg) colmena;
    };
    modules = [./host-options.nix];
  };
  hostModule = types.submoduleWith {
    specialArgs = {
      inherit self;
      inherit (cfg) colmena;
    };
    modules = [
      ./host-options.nix
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
    self, # flake's self
    hostname, # networking.hostName
    system, # system i.e.`x86_64-linux`
    modules, # host-specific modules to add
    overlays, # host-specific overlays to add
    specialArgs, # specialArgs (`config._module.args`)
    nixpkgs, # nixpkgs (sets pkgs in `eval-config`)
    ...
  }: let
    c = withSystem system (
      ctx:
        (evalConfig nixpkgs) {
          inherit system;
          pkgs = nixpkgs;
          specialArgs =
            {
              packages = ctx.config.packages;
            }
            // hostDefaults.specialArgs
            // specialArgs;
          modules = lib.unique (lib.flatten [
            {
              # config.nixpkgs.pkgs = nixpkgs;
              config.nixpkgs.overlays = hostDefaults.overlays ++ overlays;
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
  options.flake = mkSubmoduleOptions {
    hosts = mkOption {
      description = ''
        Generate `nixosConfigurations` with defaults:
          - auto-import host configurations from a directory
          - define default `modules`, `overlays`, `specialArgs` for hosts
          - define extra options for colmena, deploy-rs integration
      '';
      default = {};
      type = types.submodule {
        config.defaults = mapDefault {
          inherit self;
          system = "x86_64-linux";
          modules = [];
          specialArgs = mapDefault {
            inherit self;
            inherit (self) inputs nixosModules profiles;
          };
        };
        options = {
          defaults = mkOption {
            description = "default options for generating hosts with `genNixos`";
            type = hostDefaultsModule;
            default = {};
            example = literalExpression ''
              {
                modules = [
                  { networking.firewall.enable = lib.mkForce true; }
                ];
                overlays = [
                  inputs.provision-nix.overlays.lnav
                ];
                specialArgs = {
                  inherit self inputs;
                };
              }
            '';
          };
          configs = mkOption {
            description = ''
              Define hosts inline, host configurations are auto-imported from {hostsDir} and added to `modules``;
                - modules: extra modules, auto-adds modules from `defaults.modules`
                - overlays: extra overlays, auto-adds overlays from `overlays`
                - nixpkgs: pkgs set, auto-adds from `channels.{system}.nixpkgs.pkgs`
                - system
                - specialArgs
                - deploy options (colmena, deploy-rs)
            '';
            type = types.lazyAttrsOf hostModule;
            default = {};
            # apply = mapAttrs (overrideHosts hostDefaults);
          };
          rendered = mkOption {
            description = ''
              Post eval nixosConfiguration's `config` field, useful for introspection.
            '';
            readOnly = true;
            type = types.lazyAttrsOf types.raw;
            default = mapAttrs (_: cfg: cfg.rendered.config) hosts;
          };
          overlays = mkOption {
            description = ''
              List of overlays to add to all hosts.
            '';
            type = types.listOf overlayType;
            default = [];
            example = literalExpression ''
              [
                (final: prev: {
                  rofi-calc = prev.rofi-calc.override {
                    rofi-unwrapped = final.rofi-wayland-unwrapped;
                  };
                })
                inputs.provision-nix.overlays.lnav
              ]
            '';
          };
          colmena = mkOption {
            description = ''
              Colmena options to add to each host.
            '';
            type = types.raw;
            default = {};
            example = literalExpression ''
              {
                targetPort = 22;
                targetUser = "deploy";
              }
            '';
          };
          deploy-rs = mkOption {
            description = ''
              Default options for deploy-rs's global options (not including nodes).
            '';
            type = types.raw;
            default = {};
            example = literalExpression ''
              {
                fastConnection = true;
                sshUser = "deploy";
                magicRollback = true;
                autoRollback = true;
              }
            '';
          };
          hostsDir = mkOption {
            description = ''
              If set, then a `rakeLeaves` is performed on the path, and entries are used
              to seed `flake.hosts.configs`.

              toplevel default file is ignored (`{hostsDir}/default.nix`).
            '';
            type = types.nullOr types.path;
            default = null;
            example = literalExpression "./hosts";
          };
        };
      };
    };
  };

  config.flake = {
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
}
