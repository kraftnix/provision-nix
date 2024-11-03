args @ {
  self,
  inputs,
  flake-parts-lib,
  ...
}: let
  inherit (flake-parts-lib) importApply;
in {
  imports = [inputs.devshell.flakeModule inputs.git-hooks-nix.flakeModule];

  flake.nixd.options.nixos = self.nixosConfigurations.testAllProfiles.options;

  flake.devshellModules.provision = importApply ./provision.nix {inherit self inputs;};
  flake.devshellModules.na-install = importApply ./na-install.nix {inherit self inputs;};

  perSystem = {
    config,
    self',
    pkgs,
    system,
    inputs',
    ...
  }: {
    packages.na-install = pkgs.writeShellScriptBin "na-install" (builtins.readFile ./na-install.sh);
    devshells.default = {
      imports = [
        self.devshellModules.provision
        self.devshellModules.na-install
      ];
      devshell.startup.pre-commit = {
        text = config.pre-commit.installationScript;
      };
      na-install.enable = true;
      provision.enable = true;
      provision.nvfetcher.enable = true;
      provision.nvfetcher.sources.nixos.baseDir = "./nixos/packages";
      # na-install.enable = true;
      packages = config.pre-commit.settings.enabledPackages;
    };
    pre-commit = {
      settings.hooks = {
        alejandra.enable = true;
        nil.enable = true;
      };
    };
  };
}
