{
  config,
  lib,
  name,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    mkDefault
    mkIf
    mkOption
    optionalString
    types
    ;
  cfg = config;

  makeMapType =
    {
      lhs,
      rhs ? null,
      verdict ? null,
      type ? null,
      ...
    }:
    if type == "set" then
      if rhs == null then
        lhs
      else if verdict == null then
        "${lhs} . ${rhs}"
      else
        "${lhs} . ${rhs} . ${verdict}"
    else if type == "map" then
      if verdict == null then "${lhs} : ${rhs}" else "${lhs} : ${rhs} . ${verdict}"
    else if rhs == null then
      "${lhs} : ${verdict}"
    else if type == "vmapr" then
      "${lhs} : ${rhs} . ${verdict}"
    else
      "${lhs} . ${rhs} : ${verdict}";

  makeMapMap =
    {
      name,
      type,
      lhsType,
      rhsType ? null,
      verdictType ? null,
      ...
    }:
    if type == "set" then
      if rhsType == null then
        "${lhsType} @${name}"
      else if verdictType == null then
        "${lhsType} . ${rhsType} @${name}"
      else
        "${lhsType} . ${rhsType} . ${verdictType} @${name}"
    else if type == "map" then
      if verdictType != null then
        "${lhsType} . ${rhsType} to ${verdictType} map @${name}"
      else
        "${lhsType} . ${rhsType} map @${name}"
    else if rhsType == null then
      "${lhsType} vmap @${name}"
    else if type == "vmapr" then
      "<implement your own>"
    else
      "${lhsType} . ${rhsType} vmap @${name}";

  mkNullableStringInt =
    description:
    mkOption {
      inherit description;
      default = null;
      type =
        with types;
        nullOr (oneOf [
          str
          int
        ]);
      apply = x: if x == null then null else toString x;
    };
  mapType =
    { config, ... }:
    {
      options = {
        l = mkNullableStringInt "<lhs> of map element, required";
        r = mkNullableStringInt "<rhs> of map element";
        v = mkNullableStringInt "<verdict> of map element";
        __final = mkOption {
          description = "end element str";
          type = types.str;
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
    # used with map in dnat usecases
    port = "inet_service";
    "ip addr" = "ipv4_addr";
  };
in
{
  options = {
    enable = mkOption {
      description = "Whether to include rule in final rendered chain.";
      type = types.bool;
      default = true;
    };
    name = mkOption {
      description = "name of map/set/vmap";
      default = name;
      type = types.str;
    };
    lhs = mkOption {
      description = "`lhs` in the map `<lhs> . <rhs>";
      default =
        if (config.lhsType != null) && (builtins.hasAttr config.lhsType typeMap) then
          typeMap.${config.lhsType}
        else
          "ipv4_addr";
      type = types.str;
    };
    lhsType = mkOption {
      description = "type to be used for generating `__map` verdict";
      default = null;
      type = with types; nullOr str;
      example = "iifname";
    };
    rhs = mkOption {
      description = "`rhs` in the map `<lhs> . <rhs>";
      default =
        if (config.rhsType != null) && (builtins.hasAttr config.rhsType typeMap) then
          typeMap.${config.rhsType}
        else
          null;
      type = with types; nullOr str;
      example = "ifname";
    };
    rhsType = mkOption {
      description = "type to be used for generating `__map` verdict";
      default = null;
      type = with types; nullOr str;
      example = "oifname";
    };
    verdict = mkOption {
      description = "optional `verdict` in the map `<lhs> : <verdict>` or `<lhs> . <rhs> : <verdict>`";
      default =
        if (config.verdictType != null) && (builtins.hasAttr config.verdictType typeMap) then
          typeMap.${config.verdictType}
        else
          null;
      type = with types; nullOr str;
    };
    verdictType = mkOption {
      description = "**weird naming**, only used for `set` type where 3 elements are concatenationed together, used to generate `typeDef`";
      default = null;
      type = with types; nullOr str;
      example = "oifname";
    };
    flags = mkOption {
      description = ''
        Available options:
          + constant - set content may not change while bound
          + interval - set contains intervals
          + timeout - elements can be added with a timeout
      '';
      default = [ ];
      type =
        with types;
        listOf (enum [
          "constant"
          "interval"
          "timeout"
        ]);
    };
    type = mkOption {
      description = ''
        final type of set/map/vmap/natmap
          - set: list or [generic sets](https://wiki.nftables.org/wiki-nftables/index.php/Sets) of elements [Nftables Sets](https://wiki.nftables.org/wiki-nftables/index.php/Concatenations)
            - list or generic sets
          - map: hashmap/attrs of elements [Nftables maps](https://wiki.nftables.org/wiki-nftables/index.php/Sets)
            - often used with `dnat to`, `snat to`, will never be selected by default
          - vmap(r): verdict maps [Nftables verdict maps](https://wiki.nftables.org/wiki-nftables/index.php/Verdict_Maps_(vmaps))
            can be a `vmap` or `vmapr`, `vmapr` reverses the mapping
              -[both]   match         : verdict  ( lhs : verdict )
              -[vmap]   match . match : verdict  ( lhs . rhs : verdict )
              -[vmapr]  match : match . match    ( lhs : rhs . verdict )
            example usage of vmapr [Nftables examples](https://wiki.nftables.org/wiki-nftables/index.php/Multiple_NATs_using_nftables_maps)
      '';
      default =
        if config.verdict == null then
          "set"
        # else if config.rhs == null && config.verdict != null then
        #   "map"
        else
          "vmap";
      type = types.enum [
        "set"
        "map"
        "vmap"
        "vmapr"
      ];
    };
    typeDef = mkOption {
      description = "final type of set/map/vmap";
      default = makeMapType {
        inherit (config)
          lhs
          rhs
          verdict
          type
          ;
      };
      # default = "type ${makeMapType config.lhs config.rhs config.verdict}";
      type = types.str;
    };
    typeName = mkOption {
      description = "type name to set when defining named map/set/vamp";
      default = if config.type == "vmap" || config.type == "vmapr" then "map" else config.type;
      type = types.str;
    };
    elements = mkOption {
      description = "element for map, can be a verdict ";
      default = [ ];
      type = with types; listOf (submodule mapType);
    };
    counter = mkOption {
      description = "adds a counter to each element, only applicable to `set` type";
      default = false;
      type = types.bool;
    };
    extraConfig = mkOption {
      description = "extra config to add";
      type = types.lines;
      default = "";
    };
    __map = mkOption {
      description = "end element str";
      type = types.str;
      default = "";
    };
    __final = mkOption {
      description = "End chain type string.";
      type = types.str;
      default = "";
    };
  };
  config = mkIf config.enable {
    __map = mkDefault (makeMapMap config);
    # NOTE: weird spacing is so the toplevel nftables ruleset is aligned and easier to debug/preview
    __final = mkDefault ''
      ${config.typeName} ${config.name} {
          type ${config.typeDef}
          ${optionalString config.counter "counter"}
          ${optionalString (config.flags != [ ]) "flags ${(concatStringsSep ", " config.flags)}"}
          ${config.extraConfig}
          ${optionalString (config.elements != [ ]) ''
            elements = {
                  ${concatStringsSep ",\n      " (map (e: e.__final) config.elements)}
                }
          ''}
        }
    '';
  };
}
