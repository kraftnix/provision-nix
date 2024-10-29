{
  self,
  lib,
  profiles,
  inputs,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    (import self.disko.ext4-simple-uefi {})
    #inputs.nixos-generators.nixosModules.nixos-generators
    profiles.users.test-operator
    profiles.users.test-deploy
  ];
  boot.loader.systemd-boot.enable = true;

  provision.defaults.enable = true;
  provision.core.shell.enable = true;
  provision.core.env.enable = true;
  provision.nix.basic = true;
  provision.nix.flakes.enable = true;

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [22];

  # will be overridden by the bootstrapIso instrumentation
  fileSystems."/" = lib.mkDefault {device = "/dev/disk/by-label/nixos";};

  system.stateVersion = "23.05";
}
