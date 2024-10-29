#{ self, ... }:
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (pkgs.lib.provision.users) operator deploy;
in {
  nix.settings.trusted-users = ["test-deploy"];
  users.users.test-deploy = deploy.mkUser {
    name = "test-deploy";
    # NOTE: password = asdasd
    hashedPassword = "$6$YHDWUzrIoOlhFxr5$.mwhIrllp2DKNbKta67dzhLbVnPgeJBfUkV0Rh3SwDHbfyE5tdPdkg841sTSXlZ1dq8ho/HrTT2o7X7p8xU9X0";
    uid = 9901;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKnXawzrDFuys2nodF9kQpbkspTWO5oAcG738AXOgP9 testvm key"
    ];
    extraGroups = ["deploy"];
  };
  users.groups.deploy.gid = 9001;
  security.doas.extraRules = deploy.mkDoasRules "test-deploy";
  security.sudo.extraRules = deploy.mkSudoRules "test-deploy";
}
