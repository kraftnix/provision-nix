{ self, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) optional mkIf mkOverride;
  opts = self.lib.options;
  cfg = config.provision.core.env;
  mkOv = mkOverride 900;
in
{
  options.provision.core.env = {
    enable = opts.enable "whether to enable env configuration";
    editor = opts.string "vim" "whether to enable env configuration";
    locale = {
      keyMap = opts.string "uk" "keyboard layout (`console.keyMap`)";
      xkbLayout = opts.string "gb" "xserver xkb layout";
      default = opts.string "en_GB.UTF-8" "default locale (`i18m.defaultLocale`)";
      timeZone = opts.string "Europe/Amsterdam" "time zone (`time.timeZone`)";
      swapEscape = opts.enableTrue "swap escape and capslock in console + xserver settings";
    };
    packages = opts.packageList [ ] "systemPackages to import into environment";
    fonts = {
      packages = opts.packageList [ ] "font packages to add";
      name = opts.stringNull "if set, adds font name in fontconfig default fonts";
      extraConfig = opts.raw { } "extra config to merge with `fonts`";
    };
  };

  config = mkIf cfg.enable {
    services.xserver.xkb.options = mkIf cfg.locale.swapEscape "caps:escape";
    services.xserver.xkb.layout = mkOv cfg.locale.xkbLayout;
    console.keyMap = mkOv cfg.locale.keyMap;
    console.useXkbConfig = mkIf cfg.locale.swapEscape (mkOv true);
    i18n.defaultLocale = mkOv cfg.locale.default;
    time.timeZone = mkOv cfg.locale.timeZone;

    fonts = lib.mkMerge [
      cfg.fonts.extraConfig
      {
        inherit (cfg.fonts) packages;
        fontconfig.defaultFonts = {
          monospace = optional (cfg.fonts.name != null) cfg.fonts.name;
          sansSerif = optional (cfg.fonts.name != null) cfg.fonts.name;
        };
      }
    ];

    environment = {
      variables = {
        EDITOR = cfg.editor;
        # attempt to resolve LOCALE issues
        LANG = cfg.locale.default;
        LANGUAGE = cfg.locale.default;
        LC_ALL = cfg.locale.default;
      };
      # Selection of sysadmin tools that can come in handy
      systemPackages = with pkgs; [
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

      shellAliases = lib.mapAttrs (_: lib.mkDefault) {
        # quick cd
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";
        "....." = "cd ../../../..";

        # get ip
        myip = "curl ifconfig.co/json";

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
    };
  };
}
