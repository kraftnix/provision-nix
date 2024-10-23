{self, ...}: {
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  opts = self.lib.options;
  cfg = config.provision.virt;
in {
  options.provision.virt = {
    build.arm = opts.enable "add `aarch64-linux` to binfmt for cross-compilation";
  };

  config = mkMerge [
    (mkIf cfg.build.arm {
      # emulation of ARM for building iso
      boot.binfmt.emulatedSystems = ["aarch64-linux"];
    })
  ];
}
