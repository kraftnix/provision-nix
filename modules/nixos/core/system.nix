{ self, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    optional
    mkDefault
    mkIf
    mkOverride
    types
    ;
  opts = self.lib.options;
  cfg = config.provision.core;
in
{
  options.provision.core = {
    enable = opts.enable ''
      Enables all default integrations under {provision.core}:
        - aliases
        - locale
        - packages
        - shell

      Integrations can also be enabled individually with {provision.core.aliases.enable} etc.
    '';
    editor = opts.string "" "sets `EDITOR` as a system environment variable {environment.variables.EDITOR}, set if not empty string";
    packages = {
      enable = opts.enable "import {packages.packages} into system packages";
      packages = lib.mkOption {
        description = "packages in the same form as {environment.systemPackages}";
        default = [ ];
        type = types.listOf types.package;
      };
    };
    aliases = {
      enable = opts.enable "enable adding some default shell alias shortcuts for sysadmin + nix usage";
      aliases = lib.mkOption {
        description = "aliases in the same form as {environment.shellAliases}";
        default = { };
        type = types.attrsOf types.str;
      };
    };
    fonts = {
      enable = opts.enable "enable setting font defaults and adding fonts";
      packages = opts.packageList [ ] "font packages to add";
      name = opts.stringNull "if set, adds font name in fontconfig default fonts";
      extraConfig = opts.raw { } "extra config to merge with `fonts`";
    };
  };

  config = lib.mkMerge [

    (mkIf cfg.enable {
      provision.core = {
        aliases.enable = mkDefault true;
        defaults.enable = mkDefault true;
        locale.enable = mkDefault true;
        packages.enable = mkDefault true;
        shell.enable = mkDefault true;
      };
    })

    {
      environment = {
        systemPackages = lib.mkIf cfg.packages.enable cfg.packages.packages;
        shellAliases = lib.mkIf cfg.aliases.enable (lib.mapAttrs (_: lib.mkDefault) cfg.aliases.aliases);
        variables.EDITOR = lib.mkIf (cfg.editor != "") cfg.editor;
      };

      # Selection of sysadmin tools that can come in handy
      provision.core.packages.packages = with pkgs; [
        vim
        nushell # best shell
        git # can be required for flake things
        curl # curl things
        coreutils # GNU Core utils
        dnsutils # nslookup + dig
        dosfstools # fat + msdos tools
        dust # better du
        fd # quicker find
        ripgrep # quicker grep
        jq # filter json
        btop # lightweight top
        gptfdisk # *gdisk tools
        iputils # ping
        rustscan # nmap replacement
        usbutils # lsusb
        util-linux # very core commands
        pciutils # lspci
        whois # lookup who-is records
      ];
      provision.core.aliases.aliases = {
        # quick cd
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";
        "....." = "cd ../../../..";

        # get ip
        myip = "curl https://ifconfig.co/json";

        # nix
        n = "nix";
        nr = "nix repl -f.";
        nrr = "nix repl -f.";
        np = "nix repl nixpkgs"; # requires `repl-flake`
        npp = "nix repl --expr 'import <nixpkgs>{}'";
        nppl = "nix repl '<nixpkgs>'";
        ns = "nix search --no-update-lock-file";
        nf = "nix flake";
        nl = "nix flake lock";
        srch = "nix search nixos";
        orch = "nix search override";

        # mn = ''
        #   manix "" | grep '^# ' | sed 's/^# \(.*\) (.*/\1/;s/ (.*//;s/^# //' | sk --preview="manix '{}'" | xargs manix
        # '';

        # # fix nixos-option
        # nixos-option = "nixos-option -I nixpkgs=${inputs.self}/lib/compat";

        # systemd
        ctl = "systemctl";
        ctls = "systemctl status";
        ctld = "systemctl down";
        ctlu = "systemctl up";

        # journalctl
        j = "journalctl";
        jf = "journalctl -f";
        ju = "journalctl -u";
        jfu = "journalctl -f -u";
      };
    }

    (mkIf cfg.fonts.enable {
      fonts = {
        inherit (cfg.fonts) packages;
        fontconfig.defaultFonts = {
          monospace = optional (cfg.fonts.name != null) cfg.fonts.name;
          sansSerif = optional (cfg.fonts.name != null) cfg.fonts.name;
        };
      };
    })

  ];
}
