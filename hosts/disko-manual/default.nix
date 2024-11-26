{
  self,
  inputs,
  profiles,
  pkgs,
  lib,
  ...
}:
let
  diskoLib = inputs.disko.lib;
  diskoCfg = import self.disko.ext4-simple-bios-uefi { };
in
{
  imports = with profiles; [
    (diskoLib.config diskoCfg)
    users.test-operator
    users.test-deploy
  ];
  provision.defaults.enable = true;
  provision.core.env.enable = true;
  boot.loader.systemd-boot.enable = true;

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  environment.systemPackages = with pkgs; [
    (writeScriptBin "tsp-create" (diskoLib.create diskoCfg))
    (writeScriptBin "tsp-mount" (diskoLib.mount diskoCfg))
  ];

  system.stateVersion = lib.mkDefault "23.05";
}
