{
  name,
  config,
  pkgs,
  lib,
  rules,
  mapsets,
  localFlake,
  ...
}: let
  inherit
    (lib)
    attrValues
    concatStringsSep
    elem
    mapAttrs
    mkOption
    optionalString
    ;
  inherit
    (lib.types)
    attrsOf
    bool
    int
    enum
    nullOr
    oneOf
    str
    submodule
    submoduleWith
    ;
  inherit (localFlake.self.lib.firewall) ruleDefaults mkRuleModules;

  getDefaultType = hook:
    if hook == "output"
    then "route"
    else if elem hook ["postrouting" "prerouting"]
    then "nat"
    else "filter";
  getDefaultPriority = hook:
    if elem hook ["input" "forward"]
    then "filter"
    else if hook == "postrouting"
    then "srcnat"
    else if hook == "prerouting"
    then "dstnat"
    else "filter";
  chainTypeModule = submodule ({config, ...}: {
    options = {
      type = mkOption {
        description = ''
          type refers to the kind of chain to be created. Possible types are:
            + filter: Supported by arp, bridge, ip, ip6 and inet table families.
            + route: Mark packets (like mangle for the output hook, for other hooks use the type filter instead), supported by ip and ip6.
            + nat: In order to perform Network Address Translation, supported by ip and ip6.
        '';
        type = enum ["filter" "route" "nat"];
        default = getDefaultType config.hook;
      };
      hook = mkOption {
        description = ''
          hook refers to an specific stage of the packet while it's being processed through the kernel.

          More info in Netfilter hooks.
          https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes#Chains
        '';
        type = enum ["ingress" "prerouting" "forward" "input" "output" "postrouting" "egress"];
        default = "filter";
      };
      priority = mkOption {
        description = ''
          Within a given hook, Netfilter performs operations in order of increasing numerical priority.

          More info in:
          https://wiki.nftables.org/wiki-nftables/index.php/Netfilter_hooks#Priority_within_hook
        '';
        type = oneOf [int str];
        apply = toString;
        default = getDefaultPriority config.hook;
      };
      policy = mkOption {
        description = ''
          policy is the default verdict statement to control the flow in the base chain.

          Possible values are: accept (default) and drop.
          Warning: Setting the policy to drop discards all packets that have not been accepted by the ruleset.
        '';
        type = nullOr (enum ["accept" "drop"]);
        default = null;
      };
      __rendered = mkOption {
        description = "End chain type string.";
        type = str;
        default = ''
          type ${config.type} hook ${config.hook} priority ${config.priority}; ${optionalString (config.policy != null) "policy ${config.policy};"}
        '';
      };
    };
  });

  finalRuleModule = submoduleWith {
    modules =
      (mkRuleModules {
        inherit pkgs lib;
        defaults = config.defaults;
        mapsets = mapsets;
      })
      ++ [
        ({config, ...}: (
          lib.mkIf
          (builtins.hasAttr config.rule rules)
          (mapAttrs (_: lib.mkDefault) {
            # have to pass like this or infinite recursion
            inherit
              (rules.${config.rule})
              n
              enable
              oifname
              iifname
              oif
              iif
              main
              counter
              trace
              log
              verdict
              comment
              udpDport
              udpSport
              tcpDport
              tcpSport
              mapset
              ;
          })
        ))
      ];
  };
  # finalRuleModule = submoduleWith {
  #   modules = [
  #     ./rule.nix
  #     { config._module.args = { inherit pkgs lib; }; }
  #     { config._module.args.defaults = config.defaults; }
  #     { config._module.args.mapsets = mapsets; }
  #     { config._module.args.ruleReplaceMap = {}; }
  #     # If a rule is set, replace all values with
  #     # a mkDefault of the selected rule's value
  #     ({ config, ... }: (lib.mkIf
  #       (builtins.hasAttr config.rule rules)
  #       (mapAttrs (_: lib.mkDefault) { # have to pass like this or infinite recursion
  #         inherit (rules.${config.rule})
  #           n
  #           enable
  #           oifname
  #           iifname
  #           oif
  #           iif
  #           main
  #           counter
  #           trace
  #           log
  #           verdict
  #           comment
  #           udpDport
  #           udpSport
  #           tcpDport
  #           tcpSport
  #           mapset
  #           ;
  #       })
  #     ))
  #   ];
  # };
in {
  options = {
    __type = mkOption {
      description = ''
        Define `nftables` chains rules

        For a fuller description of types see:
        https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes#Chains
      '';
      type = oneOf [str chainTypeModule];
      default = "";
      apply = v:
        if builtins.typeOf v == "string"
        then {
          __rendered = v;
        }
        else v;
    };
    defaults = mkOption {
      description = "Default options to set for all rules";
      default = {};
      apply = new: ruleDefaults // new;
      example = {
        counter = true;
        verdict = "accept";
      };
    };
    rules = mkOption {
      description = "Rules";
      type = attrsOf (oneOf [str finalRuleModule]);
      default = {};
      apply = mapAttrs (_: v:
        if builtins.typeOf v == "string"
        then
          ruleDefaults
          // {
            n = 100;
            __final = v;
          }
        else v);
    };
    __rulesOrdered = mkOption {
      description = "rules objects ordered by their `n` value";
      default = lib.sort (a: b: a.n < b.n) (lib.filter (c: c.enable) (attrValues config.rules));
    };
    finalRule = mkOption {
      description = "Final rule in chain, often useful for a counter, jump or drop.";
      type = str;
      example = "counter";
      default = "";
    };
    finalCounter = mkOption {
      description = "Set final rule in the chain to a named counter.";
      type = bool;
      default = false;
    };
    __rendered = mkOption {
      description = "Table Module.";
      type = str;
      default = ''
        ${config.__type.__rendered}
        ${concatStringsSep "\n" (map (x: x.__final) config.__rulesOrdered)}
        ${optionalString config.finalCounter "counter name chain_final_${name} # Final counter for ${name}"}
        ${config.finalRule}
      '';
    };
  };
}
