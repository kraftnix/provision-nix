{self, ...}: {
  config,
  options,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mapAttrsToList;
  opts = self.lib.options;
  cfg = config.provision.fs.bcachefs;
in {
  options.provision.fs.bcachefs = {
    enable = opts.enable "enable bcachefs at boot";
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems = ["bcachefs"];
    environment.systemPackages = with pkgs; [bcachefs-tools];
  };
}
