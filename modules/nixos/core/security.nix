{ self, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf types mkDefault;
  opts = self.lib.options;
  cfg = config.provision.core.security;
in
{
  options.provision.core.security = {
    doas = {
      enable = opts.enable "enable doas";
      extraRules = lib.mkOption {
        description = "extra doas rules";
        default = [ ];
        type = with types; listOf raw;
      };
    };
    openssh = {
      enable = opts.enable "enable ssh ({openFirewall} disabled by default)";
    };
    electron.enable = opts.enable "enables chromium suid sandbox";
    libre-only.enable = opts.enable "prevents redistribuation but not free firmware";
    hardened_kernel = {
      enable = opts.enable "enable latest hardened kernel";
      kernel = lib.mkOption {
        description = "hardened kernel package";
        default = pkgs.linuxPackages_hardened;
        defaultText = lib.literalExpression "pkgs.linuxPackages_hardened";
        example = lib.literalExpression "pkgs.linuxPackages_hardened";
        type = types.raw;
      };
    };
    namespacing.enable = opts.enable "enable unprivilegedUsernsClone";
  };
  config = lib.mkMerge [

    ## Security
    (mkIf (cfg.doas.enable) {
      security.doas.enable = true;
      security.doas.extraRules = cfg.doas.extraRules;
    })
    (mkIf (cfg.openssh.enable) {
      # For rage encryption, all hosts need a ssh key pair
      services.openssh = {
        enable = true;
        openFirewall = lib.mkDefault false;
      };
    })
    (mkIf (cfg.electron.enable) {
      security.chromiumSuidSandbox.enable = true;
    })
    (mkIf (cfg.libre-only.enable) {
      nixpkgs.config.allowUnfree = false;
      # WARNING: this will likely break your boot for most hardware :(
      hardware.enableRedistributableFirmware = lib.mkOverride 51 false;
    })
    (mkIf (cfg.hardened_kernel.enable) {
      boot.kernelPackages = cfg.hardened_kernel.kernel;
    })
    (mkIf (cfg.namespacing.enable) {
      security.allowUserNamespaces = mkDefault true;
      security.unprivilegedUsernsClone = mkDefault true;
    })
  ];
}
