{
  self,
  lib,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkForce
    ;
in
{
  imports = [
    ./examples
    ./modules
  ];

  # internal options used for installs
  flake.internal = {
    authorizedKeys = mkDefault [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL1YjGEgfKLvytHTvTvu+B4G/NsjCVY2iaNgy73Nuxv9"
    ];
    # password: test
    rootPasswordHash = mkDefault "$6$JjB.fbuq4DmTPagZ$Jymgcmbmp4xaIFzUQvqDFHJgKAfAbKiDrWp0yS0Z1lT46bpsQzRdkEFz6GXFk4MgKfLyLSyG3lYBsgNwgP3Kw1";
    generateIsos = {
      inherit (self.nixosConfigurations)
        basic-iso
        bcachefs-iso
        vpsBasicInstall
        vpsLuksInitrdInstall
        vpsLuksInitrdInstallBtrfs
        hizakuraStaticInstall
        ;
    };
  };

  # Generate a Static IP configuration that works with `boot.initrd` (for grub + luks + initrd)
  flake.lib.initrdStaticIp =
    {
      address,
      # ipv4 address (45.133.117.40)
      gateway,
      # ipv4 address (45.133.117.1)
      netmask,
      # netmask for local interface (255.255.255.0)
      interface,
      # interface name (enp3s0)
      prefixLength ? 24,
    # prefixLength
    }:
    {
      networking.useDHCP = mkForce true;
      boot.kernelParams = [ "ip=${address}::${gateway}:${netmask}::${interface}:off" ];
      networking.interfaces.${interface}.ipv4.addresses = [
        {
          inherit address prefixLength;
        }
      ];
      networking.defaultGateway = {
        inherit interface;
        address = gateway;
      };
    };
}
