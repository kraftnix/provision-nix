{ self, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  opts = self.lib.options;
  cfg = config.provision.core.shell;
in
{
  options.provision.core.shell = {
    enable = opts.enable "enable basic shell integrations";
    starship = {
      enable = opts.enableTrue "enable starship integration";
      settings = opts.raw { } "starship settings";
    };
    direnv = {
      enable = opts.enableTrue "enable direnv on bash/zsh";
    };
    zsh = {
      enable = opts.enableTrue "enable zsh";
    };
  };

  config = lib.mkIf cfg.enable {
    provision.core.shell.starship.settings = lib.mapAttrs (
      _:
      lib.mkDefault {
        add_newline = false;
        format = "$all\$fill\$time\$line_break\$character";
        dill.symbool = " ";
        shell.disabled = false;
        time = {
          disabled = false;
          format = "$date [ $time ]($style)";
          time_format = "🗓️ {%D} 🕙 [%T]";
        };
        cmd_duration = {
          min_time = 500;
          format = "took [$duration](bold yellow) ";
        };
        username = {
          show_always = true;
          format = "[$user](bold red)";
        };
        hostname = {
          ssh_only = false;
          format = "[@](bold yellow)[$hostname](bold bright-cyan) [|](bold bright-green) ";
        };
        directory.format = "[$path](bold bright-cyan)[$read_only](bold bright-red) ";
        nix_shell.heuristic = true;
      }
    );
    programs.starship = mkIf cfg.starship.enable {
      enable = true;
      settings = cfg.starship.settings;
    };

    programs.bash = {
      # Enable starship
      promptInit = mkIf cfg.starship.enable ''
        eval "$(${pkgs.starship}/bin/starship init bash)"
      '';
      # Enable direnv, a tool for managing shell environments
      interactiveShellInit = mkIf cfg.direnv.enable ''
        eval "$(${pkgs.direnv}/bin/direnv hook bash)"
      '';
    };

    programs.zsh = {
      enable = mkIf cfg.zsh.enable true;
      # Enable starship
      promptInit = mkIf cfg.starship.enable ''
        eval "$(${pkgs.starship}/bin/starship init zsh)"
      '';
      # Enable direnv, a tool for managing shell environments
      interactiveShellInit = mkIf cfg.direnv.enable ''
        eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
      '';
    };

    # So zsh can autocmplete system installed cli
    environment.pathsToLink = mkIf config.programs.zsh.enable [ "/share/zsh" ];
  };
}
