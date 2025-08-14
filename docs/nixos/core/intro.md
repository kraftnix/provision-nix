# Core modules

A set of NixOS modules available at `provision.core` that provide defaults for:
  - aliases (optionally enabled use sysadmin + nix shell aliases)
  - defaults (optionally set some sysctl + systemd global defaults)
  - fonts (optionally configure system fonts)
  - locales (optionally configure locale, keymaps, timeZone)
  - packages (optionally enabled a core set of tools to import)
  - shell (starship, zsh, direnv)

## System

### Defaults

Changes some system defaults of `sysctl` and `systemd`.

```nix
provision.core.defaults = {
  # it can be useful to bump inotify limits to when encountering `too many open files` in many places
  sysctl.bumpInotifyLimits = true;
  # multiplied by 128 to set limits in `fs.inotify.max_*` options
  sysctl.inotifyLimitsMultiple = 64;

  # Set a default timeout for systemd units globally
  systemd.defaultTimeoutSec = 30;
};
```

Module Options Reference for [`provision.core.defaults`](../../options/nixos-all-options.md#provisioncoredefaultsenable)

### Packages

Adds packages to `environment.systemPackages`.
Includes some default aliases that I find useful.

```nix
provision.core.packages = {
  # enabling imports the aliases into `environment.systemPackages`
  enable = true;

  # Add your own packages, these are merged with the upstream defaults
  packages = with pkgs; [
    tmux
    ripgrep
  ];

  # You can override all of the upstream defaults with
  # packages = lib.mkForce [ ];
};
```

Module Options Reference for [`provision.core.packages`](../../options/nixos-all-options.md#provisioncorepackagesenable)

### Aliases

Adds shell aliases to `environment.shellAliases`.
Includes some default aliases that I find useful.

```nix
provision.core.aliases = {
  # enabling imports the aliases into `environment.shellAliases`
  enable = true;

  # Define your own aliases, these are merged with the upstream defaults
  aliases = {
    myalias = "ls -la";
    # you can override one of the default upstreams
    np = "nix shell nixos#";
    # or disable it
    n = null;
    nl = "";
  };

  # You can override all of the upstream defaults with
  # aliases = lib.mkForce { };
};
```

Module Options Reference for [`provision.core.aliases`](../../options/nixos-all-options.md#provisioncorealiasesenable)

### Locale

Configures locale, timeZone, keymap

```nix
provision.core.locale = {
  enable = true;
  keyMap = "de";
  default = "de_DE.UTF-8";
  timeZone = "Europe/Berlin";
  # swap caps:escape in xkb.options
  swapEscape = true;
};
```

Module Options Reference for [`provision.core.locale`](../../options/nixos-all-options.md#provisioncorelocaleenable)

### Fonts

Simple wrapper that adds packages to `fonts.packages` and sets `fonts.defaultFonts` names.

```nix
provision.core.fonts = {
  enable = true;
  name = "Hack";
  packages = [ pkgs.hack-font ];
};
```

Module Options Reference for [`provision.core.fonts`](../../options/nixos-all-options.md#provisioncorefontsenable)

### Shell

Add opinionated configurations of some basic shell utilities, currently:
  - starship
  - zsh
  - direnv

```nix
provision.core.shell = {
  # enable all integrations
  enable = true;

  # or enable them on a per integration basic
  direnv.enable = true;
  starship.enable = true;
  zsh.enable = true;
};
```

Module Options Reference for [`provision.core.shell`](../../options/nixos-all-options.md#provisioncoreshellenable)

## Security

Some basic security related options enablement
  - doas + extra rules
  - ssh (no openFirewall)
  - electron compatibility (chromium suid sandbox)
  - hardened kernel (enable + set)
  - user namespacing (enable)

```nix
provision.core.security = {
  # enable doas
  doas.enable = true;
  # add extra rules
  doas.extraRules = [
    {
      users = [ "myuser" ];
      noPass = true;
    }
  ];
  electron.enable = true;
  hardened = {
    enable = true;
    kernel = pkgs.linux_6_6_hardened;
  };
  namespacing.enable = true;
};
```

Module Options Reference for [`provision.core.security`](../../options/nixos-all-options.md#provisioncoresecurityenable)
