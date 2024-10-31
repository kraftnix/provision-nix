{
  config,
  lib,
  name,
  defaults,
  mapsets,
  ruleReplaceMap,
  firewallLib,
  ...
}: let
  inherit (firewallLib) mapNftablesList;
  inherit
    (lib)
    concatStringsSep
    head
    filterAttrs
    flatten
    length
    listToAttrs
    mapAttrsToList
    mkEnableOption
    mkOption
    nameValuePair
    optional
    pipe
    ;
  inherit
    (lib.types)
    attrsOf
    bool
    int
    listOf
    str
    submodule
    ;

  genNftList = filter: vals:
    if length vals == 1
    then "${filter} ${toString (head vals)}"
    else "${filter} ${mapNftablesList vals}";

  # returns an nftables filter string if `config.field` is not an empty list
  maybeList = config: field:
    optional
    (config.${field} != [])
    (genNftList field config.${field});

  mapIp = field:
    if field == "daddr"
    then "ip daddr"
    else if field == "saddr"
    then "ip saddr"
    else throw "Unsupported field ${field}";
  # returns an nftables filter string if `config.field` is not an empty list
  maybeIpList = config: field:
    optional
    (config.${field} != [])
    (genNftList (mapIp field) (map toString config.${field}));

  mapPort = field:
    if field == "tcpDport"
    then "tcp dport"
    else if field == "tcpSport"
    then "tcp sport"
    else if field == "udpDport"
    then "udp dport"
    else if field == "udpSport"
    then "udp sport"
    else throw "Unsupported field ${field}";
  # returns an nftables filter string if `config.field` is not an empty list
  maybePortList = config: field:
    optional
    (config.${field} != [])
    (genNftList (mapPort field) (map toString config.${field}));

  /*
  returns `name` if `name` not in `config`
  if list, returns first element
  if string returns string
  */
  getString = config: name: let
    v = config.${name};
  in
    # if !(builtins.hasAttr name config) then name
    if builtins.typeOf v == "list"
    then
      if builtins.length v == 0
      then "__${name}__"
      else builtins.head v
    else v;
in {
  options = {
    ruleReplaceMap = mkOption {
      default = {};
      description = "a list of string replacements to run to create final rule";
      type = attrsOf (submodule {
        options = {
          enable = mkEnableOption "enable string replacement" // {default = true;};
          stringMatch = mkOption {
            default = "";
            description = "string to match";
            type = str;
          };
          replace = mkOption {
            default = "";
            description = "string replacement";
            type = str;
          };
        };
      });
    };
    rewriteLists = mkOption {
      type = attrsOf (listOf str);
      default = {
        match =
          (mapAttrsToList (_: r: r.stringMatch) (filterAttrs (_: r: r.enable) config.ruleReplaceMap))
          ++ [
            "__name__"
            "__iifname__"
            "__oifname__"
            "__iif__"
            "__oif__"
            "__saddr__"
            "__daddr__"
          ];
        replace =
          (mapAttrsToList (_: r: r.replace) (filterAttrs (_: r: r.enable) config.ruleReplaceMap))
          ++ [
            (getString config "__name")
            (getString config "iifname")
            (getString config "oifname")
            (getString config "iif")
            (getString config "oif")
            (getString config "saddr")
            (getString config "daddr")
          ];
      };
      description = "string replacements run on rule to generate __final";
    };
    n = mkOption {
      description = ''
        Ordering of rule when evaluated by chain.

        Default is: ${toString defaults.n}.
      '';
      type = int;
      default = defaults.n;
    };
    enable = mkOption {
      description = "Whether to include rule in final rendered chain.";
      type = bool;
      default = defaults.enable;
    };
    rule = mkOption {
      description = ''
        Rule to lookup in `networking.nftables.gen.rules` and set values to.
      '';
      type = str;
      default = name;
      example = "icmp-default";
    };
    pre = mkOption {
      description = ''
        extra string snipet to add before auto-generated matchers
      '';
      type = str;
      default = defaults.pre;
      example = "meta protocol ip";
    };
    udpDport = mkOption {
      description = "Filter by `udp dport`";
      type = listOf int;
      default = defaults.udpDport;
      example = [53 67];
    };
    udpSport = mkOption {
      description = "Filter by `udp sport`";
      type = listOf int;
      default = defaults.udpSport;
      example = [53 67];
    };
    tcpDport = mkOption {
      description = "Filter by `tcp dport`";
      type = listOf int;
      default = defaults.tcpDport;
      example = [53 67];
    };
    tcpSport = mkOption {
      description = "Filter by `tcp sport`";
      type = listOf int;
      default = defaults.tcpSport;
      example = [53 67];
    };
    oifname = mkOption {
      description = "Filter by oifname";
      type = listOf str;
      default = defaults.oifname; # [];
      example = ["wan"];
    };
    iifname = mkOption {
      description = "Filter by iifname";
      type = listOf str;
      default = defaults.iifname; # [];
      example = ["lan"];
    };
    oif = mkOption {
      description = "Filter by oif";
      type = listOf str;
      default = defaults.oif; # [];
      example = ["wan"];
    };
    iif = mkOption {
      description = "Filter by iif";
      type = listOf str;
      default = defaults.iif; # [];
      example = ["lan"];
    };
    saddr = mkOption {
      description = "Filter by saddr";
      type = listOf str;
      default = defaults.saddr; # [];
      example = ["10.11.0.0/24"];
    };
    daddr = mkOption {
      description = "Filter by daddr";
      type = listOf str;
      default = defaults.daddr; # [];
      example = ["10.1.1.1"];
    };
    main = mkOption {
      description = ''
        Main action in rule.

        {preset filters} {main} {debug flags} {verdict}
      '';
      type = str;
      default = defaults.main; # "";
      example = "meta l4proto { icmp, iv6-icmp }";
    };
    counter = mkOption {
      description = "Whether to add a counter before the verdict.";
      type = bool;
      default = defaults.counter;
    };
    trace = mkOption {
      description = "Whether to set an nftrace before the verdict. `nftrace set 1`";
      type = bool;
      default = defaults.trace;
    };
    log = mkOption {
      description = "Whether to add a log before the verdict.";
      type = bool;
      default = defaults.log;
    };
    mapset = mkOption {
      description = "Mapset in table `mapsets` to match";
      type = str;
      default = "";
    };
    verdict = mkOption {
      description = ''
        What verdict to add to the end of the rule. Default: ""

        Example: "accept"
      '';
      type = str;
      example = "jump another-chain";
      default = defaults.verdict;
    };
    comment = mkOption {
      description = ''
        Comment to add to the end of the rule. Default: ""

        Example: "allow all to host"
      '';
      type = str;
      example = "jump another-chain";
      default =
        if defaults.comment == ""
        then config.__name
        else defaults.comment;
    };
    __name = mkOption {
      description = "Rule name, doesn't influence rule except setting the comment by default";
      type = str;
      default = name;
    };
    __final = mkOption {
      description = "End chain type string.";
      type = str;
      default = "";
    };
  };
  config = {
    ruleReplaceMap = pipe ruleReplaceMap [
      (mapAttrsToList (
        network:
          mapAttrsToList (host: ip:
            nameValuePair "host-replace-${network}-${host}" {
              stringMatch = "<-${network}.${host}->";
              replace = ip;
            })
      ))
      flatten
      listToAttrs
    ];

    __final =
      lib.pipe [
        (maybeList config "iif")
        (maybeList config "iifname")
        (maybePortList config "tcpSport")
        (maybePortList config "udpSport")
        (maybeIpList config "saddr")
        (maybeList config "oif")
        (maybeList config "oifname")
        (maybePortList config "tcpDport")
        (maybePortList config "udpDport")
        (maybeIpList config "daddr")
        config.main
        (optional config.log "log")
        (optional config.counter "counter")
        (optional config.trace "meta nftrace set 1")
        (optional (config.mapset != "") mapsets.${config.mapset}.__map)
        (optional (config.verdict != "") config.verdict)
        (optional (config.comment != "") "comment \"${config.comment}\"")
      ] [
        flatten
        (concatStringsSep " ")
        (builtins.replaceStrings config.rewriteLists.match config.rewriteLists.replace)
        lib.mkDefault
      ];
  };
}
