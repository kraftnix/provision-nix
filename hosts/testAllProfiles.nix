{
  lib,
  pkgs,
  inputs,
  profiles,
  ...
}:
{
  imports = with profiles.users; [
    inputs.microvm.nixosModules.host
    test-operator
    test-deploy
  ];

  provision.scripts.enable = true;
  provision.scripts.scripts = {
    my-test-script.env.TEST_HOME_PATH = "/home";
    my-test-script.text = ''
      ls -la $env.TEST_HOME_PATH
    '';
    my-test-script-ls-coreutils.env.TEST_PACKAGE_PATH = "${pkgs.coreutils}/bin";
    my-test-script-ls-coreutils.text = ''
      ls -la $env.TEST_PACKAGE_PATH
    '';
    my-test-script-ls-coreutils2.text = ''
      ls -la ${pkgs.coreutils}/bin
    '';
    my-test-script-bash-test.shell = "bash";
    my-test-script-bash-test.text = ''
      ls -la
    '';
    my-test-script-env-has.inputs = [ pkgs.afetch ];
    my-test-script-env-has.text = ''
      source ${../scripts/nu/from.nu}

      def main [ var ] {
        print $"Env ($var) present: (envHas $var)"
        afetch
      }
    '';
  };

  boot.initrd.luks.devices.enc-root.device = "/dev/vda2";

  provision.hardware = {
    amdgpu.enable = true;
    android.enable = true;
    zram.enable = true;
    wifi.enable = true;
  };

  provision.core = {
    enable = true;

    debug.enable = true;
    debug.packages = [ pkgs.bcc ];

    defaults = {
      enable = true; # auto enable commented fields below
      # sysctl.bumpInotifyLimits = true;
      sysctl.inotifyLimitsMultiple = 1000;
      systemd.defaultTimeoutSec = 30;
    };

    security = {
      doas.enable = true;
      openssh.enable = true;
      electron.enable = true;
      namespacing.enable = true;
    };

    earlyoom = {
      enable = true;
      enableDebug = true;
      memoryThreshold = 3;
      extraArgs = [
        "--avoid '(^|/)(init|Xorg|ssh|qemu)$'"
        "--prefer '(^|/)(java|chromium|firefox)$'"
      ];
    };
    locale = {
      enable = true;
      keyMap = "uk";
      default = "en_GB.UTF-8";
      timeZone = "Europe/London";
    };
    fonts = {
      enable = true;
      packages = [ pkgs.hack-font ];
      name = "Hack";
    };
  };

  provision.nix = {
    develop = true;
    builder = true;
    optimise.enable = true;
    optimise.gc = true;
    trustedUsers = [ "test-deploy" ];
    substituters = {
      nix-community = {
        substituter = "https://nix-community.cachix.org";
        publicKey = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
        use = true; # actually use the binary cache for all builds
      };
      colmena = {
        substituter = "https://colmena.cachix.org";
        publicKey = "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg=";
        use = false; # allow use by others users, but don't use by default
      };
      internal = {
        enable = false; # completely disable
        substituter = "https://attic.home.internal";
        publicKey = "attic.home.internal-1:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=";
      };
    };
  };

  provision.fs = {
    automount = true;
    ntfs = true;
    hddtemp.enable = true;
    smartd.enable = true;
    nfs.client = {
      enable = true;
      remoteUrl = "10.1.1.7";
      remoteBase = "/export";
      mounts = {
        documents.enable = true;
        media.enable = true;
        pictures.enable = true;
      };
    };
    zfs = {
      enable = true;
      hostId = "deafbeeb";
      kernel.enable = true;
    };
    boot = {
      enable = true;
      device = "/dev/vda1";
      configurationLimit = 10;
      # grub.enable = true;
      systemd = {
        enable = true;
        initrd.enable = true;
        initrd.emergencyAccess = true;
      };
      initrd = {
        enable = true;
        ssh.usersImportKeyFiles = [ "test-operator" ];
      };
    };
    luks.devices.enc-root = "/dev/vda2";
    btrfs = {
      enable = true;
      gen.enc-root = {
        # otherwise set to "/dev/mapper/enc-root"
        # devicePath = "/dev/disk/by-uuid/my-luks-decrupted-uuid";
        defaultOptions = [ "compress=zstd" ];
        # mntBase = "/";
        subvolumes = {
          root.mnt = "/";
          home = { };
          nix.opts = [
            "compress=zstd"
            "noatime"
          ];
          log.mnt = "/var/log";
        };
      };
      gen.containers = {
        devicePath = "/dev/disk/by-uuid/my-big-drive";
        mntBase = "/containers";
        subvolumes.root.isRoot = true;
      };
    };
  };

  provision.networking = {
    wifi.enable = true;
    tools.basic.enable = true;
    networkd.enable = true;
    # disable automatic DHCPv4 on all ethernet devices
    networkd.ethernetUseDhcp = false;
    static = {
      address = "192.168.0.187";
      interface = "ens8";
      gateway = "192.168.0.1";
      netmask = "255.255.254.0";
      prefixLength = 23;
    };
    fail2ban.enable = true;
    ssh = {
      enable = true;
      hardened = true;
      tor.enable = true;
    };
    vpn.mullvad-app = true;
    wireguard.p2p = {
      enable = true;
      hosts.testSecurity = {
        subip = 7;
        networks.mynet.pubkey = "qiVO9J9D6C+RUwmQLlgNVxNtnaokcteXLyK/PJoLdw8=";
      };
      hosts.testWireguard = {
        subip = 2;
        networks.mynet.pubkey = "CS8snaZMkyJ0Ow5T/NxYhaEm3pTkm8XaQJnFkb3Dxgc=";
      };
      hosts.testAllProfiles = {
        subip = 3;
        endpointIP = "45.45.45.45";
        networks.mynet = {
          gateway.enable = true;
          pubkey = "PhWJphrjtbX4M5wObUi1UK1Ih19BsmkIGU8RxwXp43U=";
        };
      };
      networks.mynet = {
        subnet = "10.77.88";
        listenPort = 51834;
        privateKeyFile = "/var/lib/wg/mynet";
      };
    };
  };

  provision.virt = {
    qemu.guestAgent = true;
    qemu.smart.enable = true;
    libvirt.enable = true;
    libvirt.legacy.networking = true;
    containers = {
      enable = true;
      podman.enable = true;
      storageContainerOverlay = true;
    };
    build.arm = true;
    microvm.host = {
      enable = true;
      network.basic.enable = true;
      network.nat.enable = true;
      qemu-bridge-fix = true;
    };
  };

  system.stateVersion = lib.mkDefault "23.05";
}
