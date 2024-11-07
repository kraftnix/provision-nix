# Flake Modules

There are a number of `flake-parts` modules provided within this repo:
  - `channels`: generate sets of `nixpkgs` from flake inputs with `config` and `overlays` applied
  - `packagesGroups`: flake-parts doesn't allow sets of packages in its `packages` option, this allows `packagesGroups.vimPlugins.myplugin`
  - `homeModules*`: some wrappers around auto-importing a directory of homeManagerModules
  - `nixosModules*`: some wrappers around auto-importing a directory of nixosModules
  - `hosts`: define nixosConfigurations with default `modules`, `overlays`, `specialArgs` (and auto-import from directory)
  - `profiles`: nixos modules (as config-only snippets) to import into nixosConfigurations
  - `scripts`: define script snippets, generates `packages` from script snippets
