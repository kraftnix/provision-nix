{self, ...}: {...}: {
  lib.provision = self.lib;

  nixpkgs.overlays = [
    # passthrough provision lib as an overlay to pkgs
    self.overlays.lib
    # (_: prev: {
    #   lib = prev.lib.extend (_: _: {
    #     provision = localFlake.lib;
    #   });
    # })

    # auto import provision-nix flake packages
    self.overlays.default
  ];
}
