{
  self,
  flake-parts-lib,
  ...
}:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (flake-parts-lib) importApply;
  opts = self.lib.options;
  cfg = config.provision.virt.libvirt;
in
{
  imports = [
    (importApply ./legacy-legacy-networking.nix self)
    ./legacy-libvirt-networking.nix
    ./legacy-networking.nix
  ];

  options.provision.virt.libvirt = {
    enable = opts.enable "enable libvirt";

    legacy = {
      legacy-networking = opts.enable "import the legacy profile for `legacy-networking`, do not use unless already using";
      libvirt-networking = opts.enable "import the legacy profile for `legacy-networking`, do not use unless already using";
      networking = opts.enable "import the legacy profile for `test-keys`, do not use unless already using";
    };
  };

  config = mkIf cfg.enable {
    virtualisation = {
      spiceUSBRedirection.enable = true;
      libvirtd = {
        enable = true;
      };
    };
  };
}
