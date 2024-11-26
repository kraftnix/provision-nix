{ lib, ... }:
with lib;
let
  flib = {
    mapNftablesList = vals: "{ ${concatStringsSep ", " vals} }";

    filterUnderscores = filterAttrs (n: _: !(hasPrefix "__" n) && !(hasPrefix "_" n));

    /*
      Generates a set of ingress -> list[egress] rule mappings

      Type:
      genEgressRules :: AttrSet -> AttrSet
    */
    genEgressRules = mapAttrsToList (
      ingress: egressInterfaces: {
        iifname = [ ingress ];
        oifname = egressInterfaces;
        counter = true;
        verdict = "accept";
        comment = "allow (${ingress}) -> [${concatStringsSep " " egressInterfaces}] egress";
      }
    );

    /*
      Flattens an attribute set into a list of all (unique) values

      Type:
      flatMapUnique :: AttrSet<k, v> -> [v]
    */
    flatMapUnique =
      am:
      pipe am [
        attrValues
        flatten
        unique
      ];

    /*
      Merges two attribute sets of lists into a single set

      Type:
      flattenAttrList :: AttrSet -> AttrSet -> AttrSet
    */
    flattenAttrList =
      acc: new:
      acc
      // (mapAttrs (
        name: value: if hasAttr name acc then unique (flatten (acc.${name} ++ value)) else value
      ) new);

    ruleDefaults = {
      n = 100;
      pre = "";
      main = "";
      enable = true;
      counter = false;
      trace = false;
      log = false;
      verdict = "";
      comment = "";
      iifname = [ ];
      oifname = [ ];
      iif = [ ];
      oif = [ ];
      udpDport = [ ];
      udpSport = [ ];
      tcpDport = [ ];
      tcpSport = [ ];
      daddr = [ ];
      saddr = [ ];
    };
  };
in
flib
// {
  mkRuleModules =
    {
      pkgs,
      lib ? lib,
      defaults ? flib.ruleDefaults,
      mapsets ? { },
      firewallLib ? flib,
      ruleReplaceMap ? { },
      modules ? [ ],
      ...
    }:
    modules
    ++ [
      ../nixosModules/networking/firewall/rule.nix
      {
        config._module.args = {
          inherit
            pkgs
            lib
            firewallLib
            defaults
            mapsets
            ruleReplaceMap
            ;
        };
      }
      # (if name == "" then ({ config, ... }: {
      #   config.rule = config._module.args.name;
      # }) else {
      #   config.rule = name;
      # })
    ];
}
