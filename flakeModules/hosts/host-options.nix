{
  config,
  lib,
  name,
  colmena,
  self,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkOption
    recursiveUpdate
    types
    ;
  overlayType = lib.mkOptionType {
    name = "nixpkgs-overlay";
    description = "nixpkgs overlay";
    check = lib.isFunction;
    merge = lib.mergeOneOption;
  };
in
{
  options = {
    system = mkOption {
      description = "system for host.";
      type = types.enum lib.platforms.all;
      default = "x86_64-linux";
      example = "aarch64-linux";
    };
    self = mkOption {
      description = "reference to current flake-parts self";
      type = with types; lazyAttrsOf unspecified;
      default = self;
      defaultText = literalExpression "self";
      example = literalExpression "self";
    };
    nixpkgs = mkOption {
      description = ''
        The Nixpkgs to use for this host.
          - if set to a `string`, then a channel's pkgs will be looked up in `flake.channels.{system}.{name}.pkgs`
          - otherwise, can be set to a `pkgs` directly.

        By default uses `nixpkgs` channel in `channels` option.
      '';
      type =
        with types;
        oneOf [
          str
          pkgs
        ];
      default = "nixpkgs";
      apply =
        val: if builtins.typeOf val == "string" then self.channels.${config.system}.${val}.pkgs else val;
      example = "nixpkgs-stable";
    };

    modules = mkOption {
      description = "extra nixos modules to eval for host.";
      type = types.listOf types.raw;
      default = [ ];
      example = literalExpression ''
        [
          inputs.provision.nixosModules.provision-scripts
          { networking.firewall.enable = lib.mkForce true; }
        ];
      '';
    };
    overlays = mkOption {
      description = "extra overlays to add for host";
      type = types.listOf overlayType;
      default = [ ];
      example = literalExpression ''
        [
          inputs.provision-nix.overlays.lnav
        ]
      '';
    };
    specialArgs = mkOption {
      description = "extra arguments to add to `specialArgs` in `eval-config.nix`";
      type = with types; lazyAttrsOf raw;
      default = { };
      example = literalExpression ''
        {
          inherit self inputs;
        }
      '';
    };
    colmena = mkOption {
      description = "extra arguments to add in flake `colmena.<host>.deployment`";
      type = with types; attrsOf anything;
      default = { };
      apply = recursiveUpdate (colmena // { targetHost = name; });
      example = literalExpression ''
        {
          targetPort = 22;
          targetUser = "deploy";
        }
      '';
    };
    deploy = mkOption {
      description = "extra arguments to add in flake `deploy.nodes.<host>`";
      type = with types; attrsOf anything;
      default = { };
      apply = recursiveUpdate {
        hostname = config.colmena.targetHost;
      };
      example = literalExpression ''
        {
          fastConnection = true;
          sshUser = "deploy";
          magicRollback = true;
          autoRollback = true;
        }
      '';
    };
  };
}
