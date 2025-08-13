# `nixos-anywhere` automated installs

> NOTE: this is somewhat legacy and hasn't been used in a while and is probably in need of a rework

`nixos-anywhere` is used for installing NixOS onto already booted machines
that may be running other linux distributions (such as Ubuntu, ArchLinux, etc.).

This is particularly useful for installing NixOS on VPSs which don't offer NixOS
or the ability to upload an install iso.

## Initial Install

1. Acquire a VPS with root credentials.
2. Log in to VPS Server.
    - run `lsblk` to find desired install disk name (e.g. `/dev/vda`)
    - lookup interface name with `ip a` (e.g. `enp3s0`)
3. Create a new `nixosConfiguration` for the install target

See [VPS with grub + bios + luks + initd](./examples)`vpsLuksInitrdInstall`.

Inlined here:
```nix
# You can set these internal options to override the default password ("test") and authorizedKeys
flake.internal = {
  authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL1YjGEgfKLvytHTvTvu+B4G/NsjCVY2iaNgy73Nuxv9" ];
  # password: test
  rootPasswordHash = "$6$JjB.fbuq4DmTPagZ$Jymgcmbmp4xaIFzUQvqDFHJgKAfAbKiDrWp0yS0Z1lT46bpsQzRdkEFz6GXFk4MgKfLyLSyG3lYBsgNwgP3Kw1";
};
# actual config
flake.nixosConfigurations.myNewHost = inputs.nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = with self.nixosModules; [
    nixosAnywhereInstall
    testRootUser
    (import ./vps-disk.nix { device = "/dev/vda"; })
    initrdNetwork
    ({ config, ... }: {
      # any extra nixos configuration
      networking.hostName = "myNewHost"
    })
  ];
};
```

    a. (optional if on real hardware + initrd) you may need to add some additional kernel modules if trying to install a system remotely that has additional (non VM) hardware.

    SSH into the machine and generate a nixos-config
    ```sh
    ssh $NA_ROOT_SSH
    nixos-generate-config
    cat /etc/nixos/hardware-configuration.nix
    ```

    e.g. you may add
    ```nix
    boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "usbhid" "sd_mod" ]
    ```

    You may also need to add a network device for remote SSH LUKS unlock, the following command (nushell) shows the devices and kernel modules
    ```nu
        ls /sys/class/net/*/device/driver -l
            | select name target
            | update name {|| $in
                | parse "/sys/class/net/{device}/device/driver" 
                | get device.0
            }
            | update target {|| $in
                | split row "/"
                | last
            }
            | rename name inet_device
            | rename target kernel_module
    ```

    which may result in adding
    ```nix
    boot.initrd.availableKernelModules = [ "cdc_ncm" "mt7921e" "i40e" "r8169" "alx" ]; # lots of examples here
    ```

4. Set environment options for `na-install` command

Accepted ENV variables
    - `NA_HOST`: matches a host configuration in `nixosConfigurations.{NA_HOST}`.
    - `NA_ROOT_SSH`: matches an SSH command to access `root` on remote install target.
    - `NA_LUKS_PROVISION`: set to anything to enable LUKS provisioning with a random passphrase.
    - `NA_INITRD_PROVISION`: set to anything to initrd SSH setup with LUKS provisioning.

Usage:
```sh
export NA_HOST=myNewHost
export NA_ROOT_SSH=root@my.public.ip
# to skip set to empty (value doesn't matter e.g. `export NA_LUKS_PROVISION=`)
export NA_LUKS_PROVISION=y
export NA_INITRD_PROVISION=y
# second argument represents length of LUKS passphrase to be generated
# if omitted, then the default (128) is used.
na-install 32
```

5. Check there is no errored output.
your root luks key should be at `/tmp/root-luks.key` on your host.
the initrd ssh fingerprint is right at the top of the output
6. The remote VPS should have rebooted.
7. (if initrd enabled) ssh into port `7979`
```sh
ssh -p 7979 $NA_ROOT_SSH
# enter your passphrase from `/tmp/root-luks.key`
```
8. ssh into the box and check functional
```sh
ssh $NA_ROOT_SSH
```

You now have a LUKS encrypted VPS with remote SSH unlock, with a root user login.

## Further Setup

To set this machine up properly, we will want to find out further hardware information
and be able to easily remote deploy to the machine.

### Hardware Information

```sh
# generate config
nixos-generate-config
```

Inspect config for wanted options in `/etc/nixos/hardware-configuration.nix` like:
  - `boot.initrd.availableKernelModules`
  - `boot.kernelModules`
and add them to your new `nixosConfiguration`.

Remove `(modulesPath + "/installer/scan/not-detected.nix")` from imports

Add `networking.hostName`

### Deploy

First add your own proper users + remove the test user.
Check hizakura's [`users.nix`](../hosts/hizakura/users.nix) for example configuration of
a deploy user. Otherwise you can set a root user for deploy and only make it available
over SSH with public keys.

We will use `deploy-rs` for deployment.

You can set an ip address to resolve for deployment using
```nix
flake.deploy.nodes.myHost.hostname = "192.168.1.1";
```

Then run a deploy with
```sh
# when running the first time you might want to add disable rollback
# especially if you are changing users + removing user you are deploying as
deploy .#myHost -s --magic-rollback false --auto-rollback false

# otherwise you can normally run
deploy .#myHost -s
```
  - `-s` is used to skip flake checks
  - you can use `--hostname 1.1.1.1` to force the host to resolve to an ip
  - you can change the ssh user with `--ssh-user deploy` or set it at `flake.deploy.sshUser`
    or `flake.deploy.nodes.myHost.sshUser`
  - see `deploy --help` for all available options

## Troubleshooting

Check for any output in the `nixos-install` script, theres a chance you are:
  - missing permissions (if not using a root user, or kexec is not allowed)
  - missing required programs (archlinux minimal image was missing `cpio`)

### Static Address required

Some VPS providers (such as Hizakura) don't seem to have functioning DHCP,
which complicates the `nixos-anywhere` install, especially on LUKS encrypted systems,
but can also effect regular systems on first boot.

A library function is provided [`initrdStaticIp`](./default.nix) which can be used to generate configuration
required to provide static IP information that works with LUKS initrd networking + grub/bios boot.
