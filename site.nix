localFlake: let
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
