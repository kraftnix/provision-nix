# initrd / boot

There are two main ways to do stage-1 boot in NixOS; via systemd as the init process or NixOS' custom stage-1 initrd script.

This module focuses on easing configuration of unlocking encrypted disks over SSH during stage-1,
and provides support for both systemd and scripted stage-1 as targets.

## Systemd initrd boot vs NixOS scripted boot

NixOS scripted boot is a custom stage-1 initrd script generated from options in `boot.initrd` and system configuration.
It can be used with `systemd-boot` or `grub` as a bootloader to boot a NixOS system.

NixOS also supports configuring initrd with systemd running in and managing the initrd process.
This allows configuring systemd services in `boot.initrd.systemd.services`, and network configuration in `boot.initrd.systemd.network`.

The systemd initrd can be very useful in writing more complex initrd access controls or with more complex hardware and stage-1 requirements.

## Usage

### Simple (laptop or desktop)

The simplest setup is using both systemd as both the initrd and bootloader, which can be done with:

```nix
provision.fs.boot = {
  enable = true;
  device = "/dev/sda"; # sets `/boot` to a vfat device here
  systemd.enable = true;
  systemd.initrd.enable = true;
};
```

In many setups like a laptop or desktop computer, this is often enough.

### Grub / BIOS

Some VPSs or older hardware may not support UEFI boot or you may have other reasons for using grub.

```nix
provision.fs.boot = {
  enable = true;
  device = "/dev/sda";
  grub.enable = true;
};
```

### Server decrypt drives over SSH

You can enable SSH in the initrd process to allow unlocking encrypted filesystems without being physically at the host.

> The private/public key pair used by the host for this stage-1 SSH access is normally stored on the unencrypted boot partition.
> You **should not use the same key pair for the host for the regular openssh daemon**, it highly encouraged to generate a new
> SSH keypair for this purpose only (e.g. with `ssh-keygen -t ed25519 -N "" -C "initrd-root-ssh@host" -f "/etc/initrd/ssh_host_ed25519_key"`)

```nix
provision.fs.boot = {
  enable = true;
  device = "/dev/sda";
  systemd.enable = true;
  systemd.initrd.enable = true;
  initrd.ssh = {
    # enable SSH in initrd
    enable = true;

    # configure the SSH port during initrd
    port = 2222; # 9797 by default

    # location on disk where initrd SSH only host keys are stored, they are made accessible to the initrd by copying
    hostKeys = [ "/etc/initrd/ssh_host_ed25519_key" ]; # default value
    authorizedKeyFiles = [ ./mykey.pub ];

    # you can add keyfiles from users in `users.users.<name>.ssh.authorizedKeyFiles` with the following option
    usersImportKeyFiles = [ "myuser" ];

  };
  # not all network kernel modules may be present at boot to connect to the network for SSH to be acccessible
  # you can add kernel modules to load when initrd is enabled to ensure networks can be configured during initrd
  initrd.netModules = [
    "8021q" # VLAN
    "bridge" # bridge / switch
    # example hardware
    "r8169"
    "igb"
    "e1000e"
    "i40e"
  ];
};
```

You can find which kernel modules you might need to add to `provision.fs.boot.initrd.netModules` for your hardware by running
```sh
INTERFACE=enp1s0
ethtool -i $INTERFACE | grep driver
```

### Complex Network boots

Some hosts are in environments which require complex network setups to even be accessible to be decrypted.

If you are already using systemd-networkd, you there are some options which can automatically populate
the entries of `boot.initrd.systemd.network` with your regular host network configuration.

```nix
systemd.network = {
  links.wan = { };
  netdevs.enp6s0 = { };
  netdevs.vlan-18 = { };
  networks.bridge = { };
  networks.vlan-18 = { };
};
provision.boot.systemd.network = {
  # imports all links, netdevs and networks from `systemd.network` to `boot.initrd.systemd.network`
  all = true;
  # target specific links/netdevs/networks
  links = [ "wan" ];
  netdevs = [ "enp6s0" "vlan-18" ];
  networks = [ "bridge" "vlan-18" ];
};
```

### Wireguard in initrd

TODO
