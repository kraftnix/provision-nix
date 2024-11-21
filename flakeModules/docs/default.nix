localFlake: {
  self,
  flake-parts-lib,
  ...
}: let
  inherit
    (localFlake.lib)
    literalExpression
    mkEnableOption
    mkOption
    types
    ;
in {
  imports = [(import ./perSystem.nix localFlake)];
  options.flake = flake-parts-lib.mkSubmoduleOptions {
    docs = {
      enable = mkEnableOption "enable docs integration";
      sites = mkOption {
        description = ''
          mdbook sites to generate, optionally generating module options documentation with `mkOptionsDoc`

          The mdbook site for this repository can be found [`site.nix`](https://github.com/kraftnix/provision-nix/tree/master/site.nix)

          Options documentation generated is added to `{mdbook.path}/options/{name}-options.md` before mdbook build is run.

          This means that running mdbook locally (useful when writing docs due to hot-reload), generated options
          documentation won't be avaiable.

          Additionally, in order to use options generated from `docgen`, you must include them in your mdbook SUMMARY.md
          or else mdbook won't include it during its build.
        '';
        type = types.attrsOf (types.submoduleWith {
          specialArgs = {
            inherit self localFlake;
          };
          modules = [./site.nix];
        });
        default = {};
        example = literalExpression ''
          {
            provision-nix-docs-local = {
              mdbook.src = ./.;
              defaults = {
                hostOptions = self.nixosConfigurations.basic.options;
                substitution.outPath = self.outPath;
                substitution.gitRepoUrl = "https://github.com/kraftnix/provision-nix";
                # automatically set by above path
                # substitution.gitRepoFilePath = "https://github.com/kraftnix/provision-nix/tree/master/";
              };
              homepage = {
                url = "http://localhost:1111";
                body = "Homepage";
              };
              docgen.nixos-nftables.filter = option:
                builtins.elemAt option.loc 0 == "networking"
                &&
                builtins.elemAt option.loc 1 == "nftables"
                &&
                builtins.elemAt option.loc 2 == "gen"
                ;
            };
          }
        '';
      };
    };
  };
}
