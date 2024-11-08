# Scripts

Generate scripts from different shells from string snippets, files, or nushell modules.

This submodule contains NixOS, home-manager and flake-parts modules to generate user runnable scripts.

To see example usage from this repository, see [`scripts/default.nix`]({{git_file_base_url}}scripts/default.nix)

## Common options

The core set of options is shared between all 3 different modules.

Shared `scripts` Module Options [Reference](../options/scripts-options.md)

The following shows some example usage of these options.
```nix
scripts = {
  # scripts default to nushell
  defaultShell = "nu";
  scripts = {
    # define script inline
    ssh-fpscan.inputs = [pkgs.openssh];
    ssh-fpscan.text = ''
      # scan ssh fingerprints
      def main [
        host = localhost : string # host to scan
      ] {
        ssh-keyscan $host | ssh-keygen -lf -
      }
    '';
    my-ffmpeg = {
      # override runtime shell
      shell = "bash";
      # point to file
      file = ./path/to/my-ffmpeg.bash;
      # dependencies for script
      inputs = [pkgs.ffmpeg];
      # override config passed through to `writeShellApplication` or `writeTextFile`
      extraConfig.allowSubstitutes = true;
    };
    # auto-wrap a nushell module into a script with a main
    mylog.nuModule = ./path/to/mylog.nu;
  };
};
```

## Usage

Scripts can be re-used across all 3 types of modules, here is how to use them.

### Flake Integration

Flake Module Options [Reference](../options/scripts-flake-options.md)

```nix
{ inputs, ... }:
{
  imports = [ inputs.provision-nix.flakeModules.scripts ];
  perSystem = { ... }: {
    scripts = {
      enable = true;
      addToPackages = true; # adds enabled scripts to `packages`
      defaultShell = "nu";  # default
      scripts = {
        my-test-script-nu.text = "ps -l | sort-by cpu -r | take 5";
        my-test-script-bash-test.shell = "bash";
        my-test-script-bash-test.text = "ls -la";
      };
    };
  };
}
```

### NixOS Integration

NixOS Module Options [Reference](../options/scripts-nixos-options.md)

```nix
{ inputs, ... }:
{
  imports = [ inputs.provision-nix.nixosModules.provision-scripts ];
  scripts = {
    enable = true;
    addToPackages = true; # adds enabled scripts to `environment.systemPackages`
    defaultShell = "nu";  # default
    scripts = {
      my-test-script-nu.text = "ps -l | sort-by cpu -r | take 5";
      my-test-script-bash-test.shell = "bash";
      my-test-script-bash-test.text = "ls -la";
    };
  };
}
```

### Home Manager Integration

Home Manager integration depends on how use and import home-manager.

Home Manager Module Options [Reference](../options/scripts-home-options.md)

The following example is for home-manager integrated with NixOS.

```nix
{ inputs, ... }:
{
  home-manager.sharedModules = [ inputs.provision-nix.nixosModules.provision-scripts ];
  home-manager.users.myuser = { config, ... }: {
    scripts = {
      enable = true;
      addToPackages = true; # adds enabled scripts to `home.packages`
      defaultShell = "nu";  # default
      scripts = {
        my-test-script-nu.text = "ps -l | sort-by cpu -r | take 5";
        my-test-script-bash-test.shell = "bash";
        my-test-script-bash-test.text = "ls -la";
      };
    };
  };
}
```
