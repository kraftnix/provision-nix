{ self, ... }:
{
  # uses a host defined in ./hosts, inferred via vm name
  microvm.vms.microVM = {
    # Host build-time reference to where the MicroVM NixOS is defined
    # under nixosConfigurations
    #flake = self.nixosConfigurations.microVM.config.microvm.runner.cloud-hypervisor;
    #flake = self.nixosConfigurations.microVM;
    flake = self;
    # Specify from where to let `microvm -u` update later on
    updateFlake = "git+file:///home/$USER/config";
  };
}
