localFlake: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mapAttrsToList
    mkEnableOption
    mkOption
    ;
  inherit
    (lib.types)
    attrsOf
    enum
    str
    submoduleWith
    ;

  inherit (localFlake.self.lib.firewall) mkRuleModules;

  cfg = config.networking.nftables.gen;

  rulesModule =
    (mkRuleModules {
      inherit pkgs lib;
    })
    ++ [
      ({
        config,
        name,
        ...
      }: {config.rule = name;})
    ];

  tableModule = submoduleWith {
    modules = [
      ./table.nix
      {config._module.args = {inherit pkgs lib localFlake;};}
      {config._module.args.rules = cfg.rules;}
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
in {
  imports = [./profiles.nix];
  options.networking.nftables.gen = {
    enable = mkEnableOption "whether to enable these nftables rules";
    rules = mkOption {
      description = "shared/reusable rules";
      type = attrsOf (submoduleWith {modules = rulesModule;});
      default = {};
    };
    tables = mkOption {
      description = "tables to generate";
      type = attrsOf tableModule;
      default = {};
    };
    profiles = mkOption {
      description = "profiles to enable";
      type = enum ["default"];
      default = "default";
    };
    ignoreRegexSanityCheck = mkEnableOption "enable this to skip the sanity check which looks for re-replaced firewall rules like `<-dmz-internal.rockpro->`";
    __rendered = mkOption {
      description = "Final nftables file string";
      type = str;
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

    networking.nftables.gen.rules = {
      accept-to-local = {
        n = 1;
        main = "iifname lo";
        comment = "accept all to host";
        counter = false;
        verdict = "accept";
      };
      icmp-default = {
        n = 10;
        main = "meta l4proto { icmp, ipv6-icmp }";
        comment = "accept ICMPv4 + ICMPv6 (ARP / ping)";
        counter = true;
        verdict = "accept";
      };
      ct-related-accept = {
        n = 20;
        main = "ct state { established, related }";
        comment = "accept established/related packets";
        counter = true;
        verdict = "accept";
      };
      ct-dnat-trace = {
        n = 25;
        main = "ct status dnat";
        comment = "accept incoming DNAT";
        # trace = true;
        verdict = "counter accept";
      };
      ct-drop-invalid = {
        n = 30;
        main = "ct state invalid";
        comment = "drop invalid packets";
        counter = true;
        verdict = "drop";
      };
      arp-reply = {
        n = 33;
        main = "arp operation reply";
        comment = "accept ARP reply";
        verdict = "accept";
      };
      ipv6-accept-link-local-dhcp = {
        n = 40;
        main = "ip6 daddr fe80::/64 udp dport dhcpv6-client";
        counter = true;
        verdict = "accept";
        comment = "accept all DHCPv6 packets received at a link-local address";
      };
    };
  };
}
