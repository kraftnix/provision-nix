{
  config,
  lib,
  pkgs,
  name,
  rules,
  localFlake,
  ...
}: let
  inherit
    (lib)
    concatStringsSep
    filterAttrs
    mapAttrsToList
    mkOption
    ;
  inherit
    (lib.types)
    attrsOf
    enum
    oneOf
    str
    submodule
    submoduleWith
    ;
  inherit (localFlake.self.lib.firewall) filterUnderscores;

  chainModule = mapsets:
    submoduleWith {
      modules = [
        ./chain.nix
        {config._module.args = {inherit pkgs lib localFlake;};}
        {config._module.args.rules = rules;}
        {config._module.args.mapsets = mapsets;}
      ];
    };
in {
  freeformType = attrsOf (oneOf [str (chainModule config.mapsets)]);
  options.mapsets = mkOption {
    description = "define custom set/map/vmap";
    type = attrsOf (submodule (import ./mapset.nix));
    default = {};
  };
  options.__type = mkOption {
    description = "Table Module.";
    type = enum ["inet" "ip" "ip6" "bridge" "netdev" "arp"];
    default = "inet";
  };
  options.__chains = mkOption {
    description = "Chains objects";
    default = lib.pipe config [
      filterUnderscores
      (filterAttrs (n: _: n != "mapsets"))
    ];
  };
  options.__chainsStr = mkOption {
    description = "Chains rendered into a string";
    default = lib.concatStringsSep "\n" (mapAttrsToList
      (name: chain: ''
        chain ${name} {
          ${
          if builtins.typeOf chain == "string"
          then chain
          else chain.__rendered
        }
        }
      '')
      config.__chains);
  };
  options.__rendered = mkOption {
    description = "Table Module.";
    type = str;
    default = ''
      ## Table ${name}
      table ${config.__type} ${name} {
        ${concatStringsSep "\n" (mapAttrsToList (_: c: c.__final) config.mapsets)}
        ${concatStringsSep "\n" (mapAttrsToList (chain: chainCfg: ''
        counter chain_final_${chain} {
          comment "${chain} default policy"
        }
      '') (filterAttrs (_: c: (builtins.typeOf c != "string") && c.finalCounter) config.__chains))}
        ${config.__chainsStr}
      }
    '';
  };
}
