# Documentation Generation

A flake parts module that uses [mdBook](https://github.com/rust-lang/mdBook) to generate project documentation.

Documentation can be generated for any module using the nixpkgs module system, such as:
  - `nixosModules` (NixOS modules)
  - `flakeModules` (flake-parts modules)
  - `homeManagerModules` (home-manager modules)
  - any output from `evalModules`

Module Options Reference for [`flake.docs`](../options/flake-all-options.md#flakedocs).

Intermediate packages are defined at [`perSystem.sites`](../options/flake-all-options.md#persystemsites).

You can see an example of a documentation site generated via this module at [provision-nix docs](https://kraftnix.dev/projects/provision-nix).

## Basic Setup

The following shows a basic example of generating mdbook docs with some simple options generated.
```nix
{ self, inputs, ... }:
{
  imports = [ inputs.provision-nix.flakeModules.docs ];
  flake.docs = {
    enable = true;
    sites.my-local-site = {
      mdbook.src = ./docs;
      defaults = {
        # Use an existing host's options output for docs generation
        hostOptions = self.nixosConfigurations.basic.options;
        substitution.outPath = self.outPath; # default
        substitution.gitRepoFilePath = "https://github.com/kraftnix/provision-nix/tree/master/";
      };
      docgen.firewall-docs = {
        # filters options generated to only `networking.firewall`
        filter = option:
          builtins.elemAt option.loc 0 == "networking"
          &&
          builtins.elemAt option.loc 1 == "firewall"
          ;
      };
    };
  };
}
```

In order to include the options generated from `docs.sites.<site>.docgen` in the final mdBook site,
you must include a reference to the options in your `SUMMARY.md` at the root of `docs.sites.<site>.mdbook.src`.

Options are generated during nix build, and so aren't available when running `mdbook serve` or other
`mdbook` commands.
The generated options files are placed into `option/<name>.md`, so a reference in `SUMMARY.md` might look like
```markdown
- [Full NixOS Options Reference](./options/firewall-docs.md)
```

## Build Process

The documentation site is generated using mdBook and the nixpkgs library function `nixosOptionsDoc`.

In order to make the site more presentable, some pre and post-processing steps are performed during
the build process.

### Stages

1. `nixosOptionsDoc` is run for each entry in `docs.sites.<site>.docgen.<opt>`
    - available at [`perSystem.sites.<site>.docgen.<opt>.mdbook`](#)
2. the `optionsCommonMark` output from _(1)_ is post-processed:
    - rewrite `/nix/store/XXXX` current flake paths to point to the git repo base url in `substitution.gitRepoFilePath`
    - rewrite markdown links to fix current page linking
    - available at [`perSystem.sites.<site>.docgen.<opt>.filtered`](#)
3. combine `mdbook.src` and options markdown files generated in _(2)_
    - available at [`perSystem.sites.<site>.mdbook-pre`]
4. run mdBook build + run some very hacky pre-processing of HTML to fix homepage url
    - available at [`perSystem.sites.<site>.mdbook`]

### Outputs

The final build artifact is also added to `perSystem.packages.docs-mdbook-<site>`

Additionally a script is provided via `devshell` integraton to run a local instance of the site with Caddy.

```sh
build-and-serve-<site>
```

## Examples

The current documentation for this project is located at [`site.nix`]({{git_file_base_url}}site.nix).

### Flake Options Generation

Below basic documentation generation for a single flake module using `evalModules`:

```nix
docs.my-site.docgen.scripts.hostOptions =
  (lib.evalModules {
    modules = [(import ./scripts/submodule.nix localFlake)];
  }).options;
```

In this case, since we are only including the singular module we need, no `filter` needs to be passed in.

### Home Manager Options Generation

Simple example for home-manager options generation, also using `evalModules`, but resolving an issue
where one of the options required config from home-manager.

```nix
docs.my-site.docgen.scripts-home.hostOptions =
  (lib.evalModules {
    modules = [
      (import ./scripts/homeModule.nix localFlake)
      {options.home.packages = lib.mkOption {default = {};};}
    ];
  }).options;
};
```

### NixOS Modules from Host

When your custom NixOS modules are very tightly coupled with other modules from nixpkgs, you may
want to simply re-use the options from a host, and then filter the options for documentation you
want to include.


The example from this site is:
```nix
docs.my-site.docgen.nixos-all = {
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

### Many integrated flake modules

Like the last example, this example is from this site, and the `flakeModules` imported are tightly
bound to `flake-parts` modules, so need to use `evalFlakeModule` from `flake-parts`.

```nix
{{#include ../../site.nix:51:99}}
```
