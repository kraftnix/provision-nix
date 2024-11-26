{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    optional
    optionals
    optionalAttrs
    ;
  cfg = config.provision.virt.qemu.smart;
  arm = {
    interpreter = "${pkgs.qemu-user-arm}/bin/qemu-arm";
    magicOrExtension = ''\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00'';
    mask = ''\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\x00\xff\xfe\xff\xff\xff'';
  };
  aarch64 = {
    interpreter = "${pkgs.qemu-user-arm64}/bin/qemu-aarch64";
    magicOrExtension = ''\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00'';
    mask = ''\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\x00\xff\xfe\xff\xff\xff'';
  };
  riscv64 = {
    interpreter = "${pkgs.qemu-riscv64}/bin/qemu-riscv64";
    magicOrExtension = ''\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xf3\x00'';
    mask = ''\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\x00\xff\xfe\xff\xff\xff'';
  };
in
mkIf (cfg.enable && (cfg.arm || cfg.aarch64)) {
  # nixpkgs = {
  #   overlays = [ (import ./overlays-foo/qemu) ];
  # };
  boot.binfmt.registrations =
    optionalAttrs cfg.arm { inherit arm; }
    // optionalAttrs cfg.aarch64 { inherit aarch64; }
    // optionalAttrs cfg.riscv64 { inherit riscv64; };
  provision.virt.qemu.smart.supportedPlatforms =
    (optionals cfg.arm [
      "armv6l-linux"
      "armv7l-linux"
    ])
    ++ (optional cfg.aarch64 "aarch64-linux");
  nix.extraOptions = ''
    extra-platforms = ${toString cfg.supportedPlatforms} i686-linux
  '';
  nix.sandboxPaths = [
    "/run/binfmt"
  ] ++ (optional cfg.arm "${pkgs.qemu-user-arm}") ++ (optional cfg.aarch64 "${pkgs.qemu-user-arm64}");
}
