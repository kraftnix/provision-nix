localFlake:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mapAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  inherit (localFlake.self.lib.firewall) mkRuleModules;

  cfg = config.networking.nftables.gen;

  rulesModule =
    (mkRuleModules {
      inherit pkgs lib;
    })
    ++ [
      (
        {
          config,
          name,
          ...
        }:
        {
          config.rule = name;
        }
      )
    ];

  tableModule = types.submoduleWith {
    modules = [
      ./table.nix
      {
        config._module.args = {
          inherit pkgs lib localFlake;
        };
      }
      { config._module.args.rules = cfg.rules; }
    ];
  };

  # host match string1: "<-internal.myhost->" --> "10.1.1.24"
  # netopt match string2: "<-internal.__subnetWithMask->" --> "10.1.1.0/24"
  # range match string3: "<-internal.ranges.my_internal->" --> "10.1.1.50-10.1.10.250"
  # old version, only matches 1 dot separated value
  checkStrOld = ".*<-([[:alnum:]_-]+)\.([[:alnum:]_-]+)->.*";
  # matches n values, but the match printout is not nice
  checkStr = ".*<-([[:alnum:]_-]+(\.[[:alnum:]_-]+)+)->.*";
  # these are attempts to nicely capture each dot separated value
  checkStr3 = ".*<-((?:[[:alnum:]_-]+\.)*[[:alnum:]_-]+)->.*";
  matches = builtins.match checkStr cfg.__rendered;
in
{
  imports = [
    ./bridge.nix
    ./nat.nix
    ./profiles.nix
  ];
  options.networking.nftables.gen = {
    enable = mkEnableOption "whether to enable these nftables rules";
    overrideNixosNftables =
      mkEnableOption "remove nixos defined `networking.nftables.tables` and sets `ruleset` to generated rules from `gen`"
      // {
        default = true;
      };
    rules = mkOption {
      description = "shared/reusable rules";
      type =
        with types;
        attrsOf (submoduleWith {
          modules = rulesModule;
        });
      default = { };
    };
    tables = mkOption {
      description = "tables to generate";
      type = types.attrsOf tableModule;
      default = { };
    };
    profiles = mkOption {
      description = "profiles to enable";
      type = with types; listOf (enum [ "default" ]);
      default = [ "default" ];
    };
    ignoreRegexSanityCheck = mkEnableOption "enable this to skip the sanity check which looks for re-replaced firewall rules like `<-dmz-internal.rockpro->`";
    __rendered = mkOption {
      description = "Final nftables file string";
      type = types.str;
      default = lib.concatStringsSep "\n" (mapAttrsToList (_: t: t.__rendered) cfg.tables);
    };
  };
  config = {
    assertions = [
      {
        assertion = (cfg.enable && !cfg.ignoreRegexSanityCheck) -> (matches == null);
        message = ''
          Found a pattern like <-network.host-> in final generated nftable rules.
          You can disable this check with `networking.nftables.gen.ignoreRegexSanityCheck = true;`.

          Patterns Found (matches found in groups of 2):
          ${lib.concatStringsSep " " matches}

          In nftables final ruleset:
          ${cfg.__rendered}
        '';
      }
    ];

    networking.nftables.enable = mkIf cfg.enable true;
    # checkRuleset doesn't work with bridge filter tables due to uses of lklWithFirewall lib to run check
    networking.nftables.checkRuleset =
      (lib.filterAttrs (name: v: v.__type == "bridge") cfg.tables) == { };
    networking.nftables.tables =
      if cfg.overrideNixosNftables then
        lib.mkForce { }
      else
        mapAttrs (name: t: {
          inherit name;
          family = t.__type;
          content = ''
            ${t.__mapsetsStr}
            ${t.__countersStr}
            ${t.__chainsStr}
          '';
        }) cfg.tables;
    networking.nftables.ruleset = mkIf cfg.overrideNixosNftables cfg.__rendered;
    networking.nftables.gen.rules = import ./default-rules.nix;
  };
}
