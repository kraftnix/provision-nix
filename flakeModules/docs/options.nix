{
  lib,
  defaults,
  name,
  ...
}: let
  inherit
    (lib)
    mkEnableOption
    mkOption
    types
    ;
in {
  options = {
    enable = mkEnableOption "enable options docs generation" // {default = true;};
    hostOptions = mkOption {
      default = defaults.hostOptions;
      type = types.lazyAttrsOf types.raw;
      description = "host to use for options evaluation";
    };
    filter = mkOption {
      default = _: true;
      type = types.functionTo types.bool;
      description = "filter to apply to options";
    };
    substitution = {
      outPath = mkOption {
        default = defaults.substitution.outPath;
        description = "outPath of the flake, used for rewriting /nix/store/ hardlinks in generated output from mkOptionsDoc";
        type = types.path;
      };
      gitRepoFilePath = mkOption {
        default = defaults.substitution.gitRepoFilePath;
        description = ''
          Base URL of git repo file browser, used for rewriting urls to source to the correct URL
        '';
        example = "https://github.com/kraftnix/provision-nix/tree/master/";
        type = types.str;
      };
    };
    out.name = mkOption {
      description = "name of markdown file containing options";
      default = "${name}-options.md";
      type = types.str;
    };
  };
}
