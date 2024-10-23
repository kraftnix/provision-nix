{
  self,
  pkgs,
  ...
}: {
  # combines with hosts.test-vm.modules []; definition in top-level flake.nix
  microvm.vms = {
    test-vm = {
      #flake = self;
      #flake = builtins.toFile "test-vm.nix" ''{
      #  nixosConfigurations.test-vm =
      #    self.nixosConfigurations.test-vm;
      #};'';
      flake =
        pkgs.runCommand "test-vm.flake"
        {
          passthru.nixosConfigurations."test-vm" = self.nixosConfigurations.test-vm;
        } "touch $out";
      updateFlake = "git+file:///home/$USER/config";
    };
  };
}
