{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (pkgs.lib.provision.users) operator deploy;
in {
  users.users.test-operator = operator.mkUser {
    name = "test-operator";
    uid = 9900;
    # NOTE: password = asdasd
    hashedPassword = "$6$YHDWUzrIoOlhFxr5$.mwhIrllp2DKNbKta67dzhLbVnPgeJBfUkV0Rh3SwDHbfyE5tdPdkg841sTSXlZ1dq8ho/HrTT2o7X7p8xU9X0";
    openssh.authorizedKeys.keyFiles = [./test-keys.pub];
  };
  security.doas.extraRules = operator.mkDoasRules "test-operator" pkgs;
  security.sudo.extraRules = operator.mkSudoRules "test-operator";
}
