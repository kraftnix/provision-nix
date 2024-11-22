# NüschtOS Integration

NüschtOS Search is a project which generates a simple and fast static web page
for searching NixOS Options, similar to `search.nixos.org`.

  - GitHub Repo: [NüschtOS/search](https://github.com/NuschtOS/search)
  - NuschtOS Upstream Example: [https://search.nüschtos.de](https://search.xn--nschtos-n2a.de/)
  - This Repo's Example: <https://kraftnix.dev/projects/search>

A `perSystem` integration is provided with at `perSystem.sites.<site>.nuschtos`.

## Basic Setup

The NüschtOS integration is enabled by default and populated from options defined
in `docs.sites.<site>.docgen`.

The final NüschtOS site can be found at:
  - `docs.sites.<site>.nuschtos.multiSearch`
  - `packages.docs-nuschtos-<site>`

## Additional Configuration

There are minor customisations that can be made to the static search site which
is generated.

### Worked Example

```nix
docs.my-site.docgen.nixos-all = {
  # By default, all scopes will use this git repo for `urlPrefix`
  defaults.substitution.gitRepoUrl = "https://gitea.home.lan/kraftnix/provision-nix";
  defaults.nuschtos = {
    title = "My Custom Search Site";
    baseHref = "/"; # expects to be served from root
  };
  hostOptions = self.nixosConfigurations.basic.options;
  filter = option:
    builtins.elemAt option.loc 0 == "provision"
    || (
      builtins.elemAt option.loc 0 == "networking"
      &&
      builtins.elemAt option.loc 1 == "nftables"
      &&
      builtins.elemAt option.loc 2 == "gen"
    );
};
```

### Extra scopes

Extra scopes can be added in addition to those automatically generated from `docgen`.

```nix
# flake.nix: inputs.nixos-modules.url = "github:NuschtOS/nixos-modules";
{ inputs, ... }:
{
  perSystem = { config, ... }: {
    sites.my-site.nuschtos.scopes."NüschtOS Modules" = {
      modules = [ inputs.nixos-modules.nixosModule ];
      urlPrefix = "https://github.com/NuschtOS/nixos-modules/blob/main/";
    };
  };
}
```
