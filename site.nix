localFlake: let
  lib = localFlake.lib;
  provision-nix-docs-local = {
    mdbook.src = ./.;
    defaults = {
      hostOptions = localFlake.self.nixosConfigurations.basic.options;
      substitution.outPath = localFlake.self.outPath;
      substitution.gitRepoFilePath = "https://github.com/kraftnix/provision-nix/tree/master/";
    };
    homepage = {
      url = "http://localhost:1111";
      body = "Homepage";
    };
    docgen.flake-all = {
      hostOptions =
        (localFlake.flake-parts-lib.evalFlakeModule
          {inputs.self = localFlake.self;}
          {
            imports = [
              localFlake.self.flakeModules.channels
              localFlake.self.flakeModules.docs
              localFlake.self.flakeModules.home
              localFlake.self.flakeModules.hosts
              localFlake.self.flakeModules.lib
              localFlake.self.flakeModules.nixosModulesExtended
              localFlake.self.flakeModules.packagesGroups
              localFlake.self.flakeModules.profiles
              # localFlake.self.flakeModules.scripts
            ];
            systems = [(throw "The `systems` option value is not available when generating documentation. This is generally caused by a missing `defaultText` on one or more options in the trace. Please run this evaluation with `--show-trace`, look for `while evaluating the default value of option` and add a `defaultText` to the one or more of the options involved.")];
          })
        .options;
      filter =
        option: let
          flakeEnabled = (
            builtins.elemAt option.loc 0
            == "flake"
            && builtins.length option.loc > 1
          );
          perSystemEnabled = (
            builtins.elemAt option.loc 0
            == "perSystem"
            && builtins.length option.loc > 1
          );
        in
          (flakeEnabled
            && (
              (builtins.elemAt option.loc 1 == "docs")
              && option.loc != ["flake" "docs" "sites" "<name>" "defaults" "hostOptions"]
              && option.loc != ["flake" "docs" "sites" "<name>" "docgen" "<name>" "hostOptions"]
              || (builtins.elemAt option.loc 1 == "hosts")
              && option.loc != ["flake" "hosts" "defaults" "self"]
              && option.loc != ["flake" "hosts" "configs" "<name>" "self"]
              || (builtins.elemAt option.loc 1 == "profiles")
              || (lib.hasPrefix "homeModules" (builtins.elemAt option.loc 1))
              || (builtins.elemAt option.loc 1 == "nixosModules'")
              || (builtins.elemAt option.loc 1 == "nixosModulesAll")
              || (builtins.elemAt option.loc 1 == "scripts")
            ))
          || (perSystemEnabled
            && (
              (builtins.elemAt option.loc 1 == "channels")
              || (builtins.elemAt option.loc 1 == "packagesGroups")
              || (builtins.elemAt option.loc 1 == "scripts")
            ))
        # ||
        # (builtins.elemAt option.loc 0 == "perSystem" && (builtins.length option.loc == 1))
        ;
    };
    docgen.nixos-all.filter = option:
      (
        builtins.elemAt option.loc 0
        == "provision"
        # NOTE: tofix
        && option.loc != ["provision" "scripts" "scripts" "<name>" "file"]
        && option.loc != ["provision" "nix" "flakes" "inputs"]
        && option.loc != ["provision" "fs" "zfs" "kernel" "latest"]
      )
      || (
        builtins.elemAt option.loc 0
        == "networking"
        && builtins.elemAt option.loc 1 == "nftables"
        && builtins.elemAt option.loc 2 == "gen"
      );
    docgen.nixos-nftables.filter = option: (
      builtins.elemAt option.loc 0
      == "networking"
      && builtins.elemAt option.loc 1 == "nftables"
      && builtins.elemAt option.loc 2 == "gen"
    );
  };
in {
  flake.docs = {
    enable = true;
    sites = {
      inherit provision-nix-docs-local;
      provision-nix-docs =
        provision-nix-docs-local
        // {
          homepage = {
            url = "https://kraftnix.dev";
            body = "Homepage";
            siteBase = "/projects/provision-nix/";
          };
        };
    };
  };
}
