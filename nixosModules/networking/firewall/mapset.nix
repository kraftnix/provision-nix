{
  config,
  lib,
  name,
  ...
}: let
  inherit
    (lib)
    concatStringsSep
    mkIf
    mkOption
    optionalString
    ;
  inherit
    (lib.types)
    bool
    enum
    listOf
    nullOr
    str
    submodule
    ;
  cfg = config;

  makeMapType = {
    lhs,
    rhs ? null,
    verdict ? null,
    type ? null,
    ...
  }:
    if (rhs == null) && (verdict == null)
    then "${lhs}"
    else if (rhs == null)
    then "${lhs} : ${verdict}"
    else if (verdict == null)
    then "${lhs} : ${rhs}"
    else if type == "vmapr"
    then "${lhs} : ${rhs} . ${verdict}"
    else "${lhs} . ${rhs} : ${verdict}";

  makeMapMap = lhsType: rhsType: verdict:
    if (rhsType == null) && (verdict == null)
    then "${lhsType} @${config.name}"
    else if (rhsType == null)
    then "${lhsType} vmap @${config.name}"
    else if (verdict == null)
    then "${lhsType} vmap @${config.name}"
    else if cfg.type == "vmapr"
    then "<implement your own>"
    else "${lhsType} . ${rhsType} vmap @${config.name}";

  mapType = {config, ...}: {
    options = {
      l = mkOption {
        default = null;
        description = "<lhs> of map element, required";
        type = nullOr str;
      };
      r = mkOption {
        default = null;
        description = "<rhs> of map element";
        type = nullOr str;
      };
      v = mkOption {
        default = null;
        description = "<verdict> of map element";
        type = nullOr str;
      };
      __final = mkOption {
        description = "end element str";
        type = str;
        default = "";
      };
    };
    config.__final = makeMapType {
      lhs = config.l;
      rhs = config.r;
      verdict = config.v;
      type = cfg.type;
    };
  };

  typeMap = {
    oif = "iface_index";
    iif = "iface_index";
    oifname = "ifname";
    iifname = "ifname";
    daddr = "ipv4_addr";
    saddr = "ipv4_addr";
    "tcp dport" = "inet_service";
    "tcp sport" = "inet_service";
    "udp dport" = "inet_service";
    "udp sport" = "inet_service";
  };
in {
  options = {
    enable = mkOption {
      description = "Whether to include rule in final rendered chain.";
      type = bool;
      default = true;
    };
    name = mkOption {
      default = name;
      type = str;
      description = "name of map/set/vmap";
    };
    lhs = mkOption {
      default =
        if (config.lhsType != null) && (builtins.hasAttr config.lhsType typeMap)
        then typeMap.${config.lhsType}
        else "ipv4_addr";
      type = str;
      description = "`lhs` in the map `<lhs> . <rhs>";
    };
    lhsType = mkOption {
      default = null;
      example = "iifname";
      type = nullOr str;
      description = "type to be used for generating `__map` verdict";
    };
    rhs = mkOption {
      default =
        if (config.rhsType != null) && (builtins.hasAttr config.rhsType typeMap)
        then typeMap.${config.rhsType}
        else null;
      example = "ifname";
      description = "`rhs` in the map `<lhs> . <rhs>";
      type = nullOr str;
    };
    rhsType = mkOption {
      default = null;
      example = "oifname";
      type = nullOr str;
      description = "type to be used for generating `__map` verdict";
    };
    verdict = mkOption {
      default = null;
      description = "optional `verdict` in the map `<lhs> : <verdict>` or `<lhs> . <rhs> : <verdict>`";
      type = nullOr str;
    };
    flags = mkOption {
      default = [];
      type = listOf (enum ["constant" "interval" "timeout"]);
      description = ''
        Available options:
          + constant - set content may not change while bound
          + interval - set contains intervals
          + timeout - elements can be added with a timeout
      '';
    };
    type = mkOption {
      default =
        if (config.rhs == null) && (config.verdict == null)
        then "set"
        else if config.verdict != null
        then "map"
        else "vmap";
      description = ''
        final type of set/map/vmap/natmap
          - set: list of elements [Nftables Sets](https://wiki.nftables.org/wiki-nftables/index.php/Sets)
          - map: hashmap/attrs of elements [Nftables maps](https://wiki.nftables.org/wiki-nftables/index.php/Sets)
          - vmap(r): verdict maps [Nftables verdict maps](https://wiki.nftables.org/wiki-nftables/index.php/Verdict_Maps_(vmaps))
            can be a `vmap` or `vmapr`, `vmapr` reverses the mapping
              -[both]   match         : verdict  ( lhs : verdict )
              -[vmap]   match . match : verdict  ( lhs . rhs : verdict )
              -[vmapr]  match : match . match    ( lhs : rhs . verdict )
            example usage of vmapr [Nfatbles examples](https://wiki.nftables.org/wiki-nftables/index.php/Multiple_NATs_using_nftables_maps)
      '';
      type = enum ["set" "map" "vmap" "vmapr"];
    };
    typeDef = mkOption {
      default = makeMapType {
        inherit (config) lhs rhs verdict type;
      };
      # default = "type ${makeMapType config.lhs config.rhs config.verdict}";
      description = "final type of set/map/vmap";
      type = str;
    };
    typeName = mkOption {
      default =
        if config.type == "vmap" || config.type == "vmapr"
        then "map"
        else config.type;
      type = str;
      description = "type name to set when defining named map/set/vamp";
    };
    elements = mkOption {
      default = [];
      description = "element for map, can be a verdict ";
      type = listOf (submodule mapType);
    };
    extraConfig = mkOption {
      description = "extra config to add";
      type = str;
      default = "";
    };
    __map = mkOption {
      description = "end element str";
      type = str;
      default = "";
    };
    __final = mkOption {
      description = "End chain type string.";
      type = str;
      default = "";
    };
  };
  config = mkIf config.enable {
    __map = makeMapMap config.lhsType config.rhsType config.verdict;
    __final = lib.mkDefault ''
      ${config.typeName} ${config.name} {
        type ${config.typeDef}
        ${optionalString (config.flags != []) "flags ${(concatStringsSep ", " config.flags)}"}
        ${config.extraConfig}
        ${optionalString (config.elements != []) ''
        elements = {
          ${concatStringsSep ",\n" (map (e: e.__final) config.elements)}
        }
      ''}
      }
    '';
  };
}
