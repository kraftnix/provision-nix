{
  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      sources = pkgs.callPackage (import ./_sources/generated.nix) { };
      linuxKernel = kernel: pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor kernel);
    in
    {
      overlayAttrs = { inherit (config.packages) btrfs-list; };
      packages = {
        btrfs-list = pkgs.callPackage (import ./btrfs-list.nix sources.btrfs-list) { };
        dnsleaktest = pkgs.callPackage (import ./dnsleaktest.nix) { };
        mdbook-linkcheck = pkgs.callPackage (import ./mdbook-linkcheck.nix) { };
        yapp = pkgs.callPackage (import ./yapp.nix) { };
        linux_6_12_hardened = pkgs.callPackage (import ./hardened_kernel.nix {
          version = "6.12.79-hardened1";
          hash = "sha256-TKrLHk4aB47vqehEdp5ks4WtMCq/XCDr9ro3eQOoPvE=";
          branch = "6.12";
        }) { };
        # # 6_18 broken due to PREEMPT_VOLUNTARY not being set somehow...
        # linux_6_18_hardened = pkgs.callPackage (import ./hardened_kernel.nix {
        #   version = "6.18.20-hardened1";
        #   hash = "sha256-U8Fuosb7vYU273G7jcMdPuHecENMBe9HaGTned9Teis=";
        #   branch = "6.18";
        #   kernelConfigOverrides = with lib.kernel; {
        #     GCC_PLUGIN_STACKLEAK = option yes;
        #     PREEMPT_LAZY = yes;
        #     PREEMPT_VOLUNTARY = lib.mkForce yes;
        #   };
        # }) { };
        # # 6_19 broken due to PREEMPT_VOLUNTARY not being set somehow...
        # linux_6_19_hardened = pkgs.callPackage (import ./hardened_kernel.nix {
        #   version = "6.19.10-hardened1";
        #   hash = "sha256-qXLOtG/dPtWD1jvwuMXGpo8vYkdZN52KhCOUFZotu5Y=";
        #   branch = "6.19";
        #   kernelConfigOverrides = with lib.kernel; {
        #     PREEMPT_LAZY = yes;
        #     PREEMPT_VOLUNTARY = yes;
        #   };
        # }) { };
      };
    };
}
