# Nüscht Search Integration

Nüscht Search is a project which generates a simple and fast static web page
for searching NixOS Options, similar to `search.nixos.org`.

  - GitHub Repo: [NüschtOS/search](https://github.com/NuschtOS/search)
  - Nüscht Search Upstream Example: [https://search.nüschtos.de](https://search.xn--nschtos-n2a.de/)
  - This Repo's Example: <https://kraftnix.dev/projects/search>

A `perSystem` integration is provided with at `perSystem.nuscht-search.<search>`.

## Basic Setup

Multiple nuscht-search sites can be generated from
[`nuscht-search.<system>.<search>`](../options/flake-all-options.md#persystemnuscht-search).

The final Nüscht Search site can be found at:
  - [`nuscht-search.<system>.<search>.multiSearch`](../options/flake-all-options.md#persystemnuscht-searchmultisearch)
  - `packages.<system>.nuscht-search-<search>`

### Basic Configuration

Generates a built search site at `packages.nuscht-search-example`.

```nix
# flake.nix: inputs.nixos-modules.url = "github:NuschtOS/nixos-modules";
{ inputs, ... }:
{
  perSystem = { config, ... }: {
    nuscht-search.example = {
      enable = true;
      scopes."NüschtOS Modules" = {
        modules = [ inputs.nixos-modules.nixosModule ];
        urlPrefix = "https://github.com/NuschtOS/nixos-modules/blob/main/";
      };
    };
  };
};
```

## Integration with `provision-nix` docs

The Nüscht Search integration is enabled by default and populated from options defined
in `docs.sites.<site>.docgen`.

### Worked Example

Generates a built search site at `packages.nuscht-search-my-site`.

Generates a mdbook documentation site at `packages.docs-mdbook-docs-my-site`.

```nix
docs.defaults = {
  # By default, all scopes will use this git repo for `urlPrefix`
  substitution.gitRepoUrl = "https://gitea.home.lan/kraftnix/provision-nix";
  nuscht-search = {
    title = "My Custom Search Site";
    baseHref = "/"; # expects to be served from root
  };
};
docs.sites.my-site.docgen.nixos-all = {
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
