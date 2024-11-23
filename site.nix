localFlake: let
  lib = localFlake.lib;
  provision-nix-docs-local = {
    mdbook.src = ./.;
    defaults = {
      nuschtos.baseHref = "/search/";
      nuschtos.title = "Provision Nix Options Search";
      nuschtos.customTheme = ./docs/theme/css/nuschtos.css;
      hostOptions = localFlake.self.nixosConfigurations.basic.options;
      substitution.outPath = localFlake.self.outPath;
      substitution.gitRepoUrl = "https://gitea.home.lan/kraftnix/provision-nix";
      # substitution.gitRepoFilePath = "https://github.com/kraftnix/provision-nix/tree/master/";
      substitution.gitRepoFilePath = "https://gitea.home.lan/kraftnix/provision-nix/src/branch/master/";
    };
    homepage = {
      url = "http://localhost:8937";
      body = "Homepage";
    };
    docgen.scripts.hostOptions =
      (lib.evalModules {
        modules = [(import ./scripts/submodule.nix localFlake)];
      })
      .options;
    docgen.scripts-flake.filter = option:
      builtins.elemAt option.loc 0
      == "perSystem"
      && builtins.length option.loc > 1
      && builtins.elemAt option.loc 1 == "scripts";
    docgen.scripts-flake.hostOptions =
      (localFlake.flake-parts-lib.evalFlakeModule
        {inputs.self = localFlake.self;}
        {
          imports = [localFlake.self.flakeModules.scripts];
          systems = [(throw "The `systems` option value is not available when generating documentation. This is generally caused by a missing `defaultText` on one or more options in the trace. Please run this evaluation with `--show-trace`, look for `while evaluating the default value of option` and add a `defaultText` to the one or more of the options involved.")];
        })
      .options;
    docgen.scripts-nixos.filter = option:
      builtins.elemAt option.loc 0
      == "provision"
      && builtins.elemAt option.loc 1 == "scripts";
    docgen.scripts-home.hostOptions =
      (lib.evalModules {
        modules = [
          (import ./scripts/homeModule.nix localFlake)
          {options.home.packages = lib.mkOption {default = {};};}
        ];
      })
      .options;
    docgen.scripts-home.filter = option:
      builtins.elemAt option.loc 0
      == "provision"
      && builtins.elemAt option.loc 1 == "scripts";
    docgen.flake-all = {
      hostOptions =
        (localFlake.flake-parts-lib.evalFlakeModule
          {inputs.self = localFlake.self;}
          {
            imports = [
              localFlake.self.auto-import.flake.modules.auto-import
              localFlake.self.auto-import.flake.modules.channels
              localFlake.self.auto-import.flake.modules.docs
              localFlake.self.auto-import.flake.modules.hosts
              localFlake.self.auto-import.flake.modules.lib
              localFlake.self.auto-import.flake.modules.packagesGroups
              localFlake.self.auto-import.flake.modules.profiles
              localFlake.self.auto-import.flake.modules.scripts
            ];
            systems = [(throw "The `systems` option value is not available when generating documentation. This is generally caused by a missing `defaultText` on one or more options in the trace. Please run this evaluation with `--show-trace`, look for `while evaluating the default value of option` and add a `defaultText` to the one or more of the options involved.")];
          })
        .options;
      filter = option: let
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
        loc1 = name: builtins.elemAt option.loc 1 == name;
      in
        (flakeEnabled
          && (
            (loc1 "docs")
            || (loc1 "hosts")
            || (loc1 "lib")
            || (loc1 "profiles")
            || (loc1 "auto-import")
            || (loc1 "scripts")
            || (loc1 "__provision")
          ))
        || (perSystemEnabled
          && (
            (loc1 "channels")
            || (loc1 "sites")
            || (loc1 "packagesGroups")
            || (loc1 "scripts")
          ));
    };
    docgen.nixos-all.filter = option:
      builtins.elemAt option.loc 0
      == "provision"
      || (
        builtins.elemAt option.loc 0
        == "networking"
        && builtins.elemAt option.loc 1 == "nftables"
        && builtins.elemAt option.loc 2 == "gen"
      );
    docgen.nixos-nftables.filter = option:
      builtins.elemAt option.loc 0
      == "networking"
      && builtins.elemAt option.loc 1 == "nftables"
      && builtins.elemAt option.loc 2 == "gen";
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
          defaults =
            provision-nix-docs-local.defaults
            // {
              substitution = {
                outPath = localFlake.self.outPath;
                gitRepoUrl = "https://github.com/kraftnix/provision-nix";
              };
            };
        };
    };
  };
}
