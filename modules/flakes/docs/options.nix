{
  lib,
  defaults,
  name,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkOption
    types
    ;
in
{
  options = {
    enable = mkEnableOption "enable options docs generation" // {
      default = true;
    };
    hostOptions = mkOption {
      description = "host to use for options evaluation";
      type = types.lazyAttrsOf types.raw;
      default = defaults.hostOptions;
      defaultText = literalExpression "defaults.hostOptions";
      example = literalExpression ''
        # gather `flake-parts` options from current flake
        flake-parts-lib.evalFlakeModule
          { inputs.self = self; }
          {
            imports = [ ./flakeModules/my-flake-parts-module.nix ];
            systems = [ (throw "The `systems` option value is not available when generating documentation. This is generally caused by a missing `defaultText` on one or more options in the trace. Please run this evaluation with `--show-trace`, look for `while evaluating the default value of option` and add a `defaultText` to the one or more of the options involved.") ];
          }).options
      '';
    };
    filter = mkOption {
      description = "filter to apply to options";
      type = types.functionTo types.bool;
      default = _: true;
      example = literalExpression ''
        # filter only `networking.nftables` options
        option:
          builtins.elemAt option.loc 0 == "networking"
          &&
          builtins.elemAt option.loc 1 == "nftables"
      '';
    };
    substitution = {
      outPath = mkOption {
        description = "outPath of the flake, used for rewriting /nix/store/ hardlinks in generated output from mkOptionsDoc";
        type = types.path;
        default = defaults.substitution.outPath;
        apply = toString;
        example = literalExpression "self.outPath";
      };
      gitRepoUrl = mkOption {
        description = ''
          URL of git repo
        '';
        type = types.str;
        default = defaults.substitution.gitRepoUrl;
        example = "https://github.com/kraftnix/provision-nix";
      };
      gitRepoFilePath = mkOption {
        description = ''
          Base URL of git repo file browser, used for rewriting urls to source to the correct URL
        '';
        type = types.str;
        default = defaults.substitution.gitRepoFilePath;
        example = "https://github.com/kraftnix/provision-nix/tree/master/";
      };
    };
    out.name = mkOption {
      description = "name of markdown file containing options";
      type = types.str;
      default = "${name}-options.md";
    };
  };
}
