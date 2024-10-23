args @ {
  self,
  lib,
  ...
}: {
  imports = [
    ./disko
    ./hosts
    ./install
    ./packages
    ./scripts
  ];

  flake.__provision.nixosModules.flakeArgs = args;
  flake.__provision.nixosModules.dir = ./nixosModules;
  flake.__provision.nixosModules.filterByPath = [
    ["virt" "microvm" "vm"]
    # [ "provision" "scripts" ]
  ];

  flake.profiles = lib.recursiveUpdate (self.lib.nix.rakeLeaves ./profiles) {
    users = {
      #test-deploy = import ./profiles/users/test-deploy.nix args;
      # test-deploy = import ./profiles/users/test-deploy.nix;
      # test-operator = import ./profiles/users/test-operator.nix;
      test-deploy = ./profiles/users/test-deploy.nix;
      test-operator = ./profiles/users/test-operator.nix;
    };
  };
}
