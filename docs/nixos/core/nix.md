# Nix (extended)

A wrapper for setting up sane defaults for nix usage depending on machine type or use case.

Features:
  - profile types: [ `basic` `develop` `builder` `server` ]
    - sets nix scheduling + nix settings defaults
    - useful tools included per profile
  - registry: add your own entries to registry with `provision.nix.flakes.registry`, automatically sets entries if entry is in flake's `inputs`
  - users: add trusted/allowed users
  - cache: add substituters and public keys
  - optimise: some defaults + enablement for garbage collection optimisation

Module Options Reference for [`provision.nix`](../../options/nixos-all-options.md#provisionnixbasic)

## Basic Profile

`provision.nix.basic = true` default options:
  - auto-generate manpage caches after switching to generation
  - change daemon scheduling to batch + class to idle to lower impact of nix on other machine operations
  - increase some defaults in nix settings + auto-enabled `nix-command` and `flakes`
  - lower `connect-timeout` and increase `download-buffer-size`
  - add some basic tools

Snippet

```nix
{{#include ../../../modules/nixos/core/nix-extended.nix:102:128}}
```

## Dev Profile

`provision.nix.dev = true` default options:
  - enables `keep-outputs` and `keep-derivations`
  - increases `log-lines` returned from build failure (triples the default of `20`)
  - more useful dev tools

Snippet

```nix
{{#include ../../../modules/nixos/core/nix-extended.nix:129:146}}
```

## Builder Profile

`provision.nix.builder = true` default options:
  - enables `keep-outputs` and `keep-derivations`
  - adds extra system features (this may be legacy according to [2.28 ocs](https://nix.dev/manual/nix/2.28/command-ref/conf-file.html#conf-system-features)
  - adds a `max-silent-time` of 10 minutes to stop checks with no output for 10 mins to timeout

Snippet

```nix
{{#include ../../../modules/nixos/core/nix-extended.nix:147:164}}
```
