args: {
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.provision.hardware.amdgpu;
  inherit
    (lib)
    mkDefault
    mkEnableOption
    mkIf
    ;
in {
  options.provision.hardware.amdgpu = {
    enable = mkEnableOption "enable amdgpu";
    headless = mkEnableOption "headless only amdgpu";
    addTools = mkEnableOption "add rocm/amd tools to system packages" // {default = true;};
    opencl = mkEnableOption "enable opencl" // {default = true;};
    vulkan = mkEnableOption "enable amd vulkan" // {default = true;};
  };

  config = mkIf cfg.enable {
    services.xserver = mkIf (!cfg.headless) {
      videoDrivers = ["amdgpu"];
    };
    environment = mkIf cfg.addTools {
      systemPackages = with pkgs; [
        # rocmPackages.rocm-smi
        amdgpu_top
        lact
        radeontop
        radeon-profile
        nvtopPackages.amd
      ];
    };
    hardware = {
      # You nearly always need this when using a GPU, even with `amdgpu` and `i915`
      enableRedistributableFirmware = mkDefault true;
      amdgpu = {
        initrd.enable = !cfg.headless;
        opencl.enable = cfg.opencl;
        amdvlk = {
          enable = cfg.vulkan;
          support32Bit.enable = true;
        };
      };
    };
    # systemd.tmpfiles.rules = [
    #   "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.hip}"
    # ];
  };
}
