{
  config,
  lib,
  ...
}:
lib.mkIf config.provision.fs.initrd.legacy.test-keys {
  boot.initrd.network.ssh.authorizedKeys =
    lib.mkOverride 1200
      config.users.users.test-operator.openssh.authorizedKeys.keys;
}
