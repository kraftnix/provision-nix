{
  self,
  inputs,
  ...
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.na-install;
  inherit
    (lib)
    concatStringsSep
    filterAttrs
    hasAttr
    mapAttrsToList
    mkEnableOption
    mkOption
    optional
    types
    ;
in {
  options.na-install = {
    enable = mkEnableOption "Enable na-install integration";
    enableLuksProvision = mkEnableOption "Enable LUKS provisioning for script by default" // {default = true;};
    enableInitrdProvision = mkEnableOption "Enable initrd provisionig for script by default" // {default = true;};
  };

  config = lib.mkIf cfg.enable {
    packages = [
      inputs.nixos-anywhere.packages.${pkgs.system}.default
      self.packages.${pkgs.system}.na-install
    ];
    env = [
      {
        name = "NA_LUKS_PROVISION";
        value = cfg.enableLuksProvision;
      }
      {
        name = "NA_INITRD_PROVISION";
        value = cfg.enableInitrdProvision;
      }
    ];
    commands = [
      {
        name = "na-install";
        category = "na-install";
        package = self.packages.${pkgs.system}.na-install;
        help = ''
          Use `nixos-anywhere` to install a to an external host.
                          - `NA_HOST`: matches a host configuration in `nixosConfigurations.{NA_HOST}`.
                          - `NA_ROOT_SSH`: matches an SSH command to access `root` on remote install target.
                          - `NA_LUKS_PROVISION`: set to anything to enable LUKS provisioning with a random passphrase.
                          - `NA_INITRD_PROVISION`: set to anything to initrd SSH setup with LUKS provisioning.
                        Example: `NA_HOST=vpsInstall NA_ROOT_SSH=root@vps.hostname.or.ip na-install`
        '';
      }
    ];
  };
}
