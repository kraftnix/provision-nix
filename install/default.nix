{
  self,
  lib,
  flake-parts-lib,
  inputs,
  ...
}@args:
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
  flake.install = {
    devshellModules.na-install =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.na-install;
        inherit (lib)
          mkIf
          mkEnableOption
          ;
      in
      {
        options.na-install = {
          enable = mkEnableOption "Enable na-install integration";
          enableLuksProvision = mkEnableOption "Enable LUKS provisioning for script by default" // {
            default = true;
          };
          enableInitrdProvision = mkEnableOption "Enable initrd provisioning for script by default" // {
            default = true;
          };
        };

        config = mkIf cfg.enable {
          packages = lib.trace (lib.attrNames inputs) [
            inputs.nixos-anywhere.packages.${pkgs.stdenv.hostPlatform.system}.default
            self.packages.${pkgs.stdenv.hostPlatform.system}.na-install
          ];
          env = [
            {
              name = "NA_LUKS_PROVISION";
              value = cfg.enableLuksProvision;
            }
            {
              name = "NA_INITRD_PROVISION";
              value = cfg.enableInitrdProvision;
            }
          ];
          commands = [
            {
              name = "na-install";
              category = "na-install";
              package = self.packages.${pkgs.stdenv.hostPlatform.system}.na-install;
              help = ''
                Use `nixos-anywhere` to install a to an external host.
                                - `NA_HOST`: matches a host configuration in `nixosConfigurations.{NA_HOST}`.
                                - `NA_ROOT_SSH`: matches an SSH command to access `root` on remote install target.
                                - `NA_LUKS_PROVISION`: set to anything to enable LUKS provisioning with a random passphrase.
                                - `NA_INITRD_PROVISION`: set to anything to initrd SSH setup with LUKS provisioning.
                              Example: `NA_HOST=vpsInstall NA_ROOT_SSH=root@vps.hostname.or.ip na-install`
              '';
            }
          ];
        };
      };

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
  flake.installLib.initrdStaticIp =
    {
      # ipv4 address (45.133.117.40)
      address,
      # ipv4 address (45.133.117.1)
      gateway,
      # netmask for local interface (255.255.255.0)
      netmask,
      # interface name (enp3s0)
      interface,
      prefixLength ? 24,
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

  perSystem =
    { pkgs, ... }:
    {
      packages.na-install = pkgs.writeShellScriptBin "na-install" (
        builtins.readFile ./na-install/na-install.sh
      );
      devshells.default = {
        imports = [ self.install.devshellModules.na-install ];
        na-install.enable = true;
      };
    };
}
