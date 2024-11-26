{
  lib,
  profiles,
  pkgs,
  ...
}:
let
  genMapset = verdict: {
    verdict = "verdict";
    lhsType = "iifname";
    rhsType = "oifname";
    elements = [
      {
        l = "dmz";
        r = "vpn-egress";
        v = verdict;
      }
      {
        l = "libvirtbr0";
        r = "enp1s0";
        v = verdict;
      }
    ];
  };
in
{
  imports = with profiles; [
    users.test-operator
    users.test-deploy
  ];

  networking.nftables.gen = {
    enable = true;

    # override defaults in `default` profile
    profiles = [ "default" ];
    tables.filter.input.finalCounter = false;
    tables.filter.input.rules.accept-to-local.enable = false;

    ## Example shared rule
    rules.allow-ssh = {
      tcpDport = [ 22 ];
      comment = "allow SSH inbound";
    };
    tables.filter.input.rules.allow-ssh.iifname = [ "vpn" ];

    ## Wireguard verdict map example
    tables.filter.mapsets.wireguard_inbound_udp = {
      verdict = "verdict";
      lhsType = "udp dport";
      elements = [
        {
          l = toString 51820;
          v = "accept";
        }
        {
          l = toString 51821;
          v = "jump log-and-accept";
        }
      ];
    };
    tables.filter.log-and-accept.rules.default = {
      log = true;
      counter = true;
      verdict = "accept";
    };
    tables.filter.input.rules.wg-in = {
      mapset = "wireguard_inbound_udp";
      comment = "handle inbound wireguard udp";
    };

    ## basic Set example
    tables.filter.mapsets.https_inbound = {
      lhsType = "ip daddr";
      elements = map (ip: { l = ip; }) [
        "10.11.1.1"
        "10.11.22.33"
      ];
    };
    tables.filter.input.rules.testing = {
      log = true;
      counter = true;
      tcpDport = [
        80
        443
      ];
      mapset = "https_inbound";
    };

    ## Selective NAT forwarding example
    # generate forward and snat allow maps for snat forwarding
    tables.filter.mapsets = {
      egress_allow_map = genMapset "accept";
      egress_snat_map = genMapset "jump masquerade_random";
    };
    tables.filter.masquerade_random.rules.all = {
      comment = "masquerade all";
      verdict = "masquerade random";
      counter = true;
    };
    # allow forwarding for specific interfaces mapset
    tables.filter.forward.rules.egress_allow_map = {
      comment = "allow forwarding from internal -> egress";
      mapset = "egress_allow_map";
    };
    # egress + masquerade specific interfaces from mapset
    tables.filter.egress-snat.__type.hook = "postrouting";
    tables.filter.egress-snat.rules.map = {
      mapset = "egress_snat_map";
      comment = "NAT from lan -> egress";
    };
  };

  provision = {
    defaults.enable = true;
    fs = {
      boot = {
        enable = true;
        device = "/dev/vda1";
        grub.devices = [ "/dev/vda" ];
        configurationLimit = 10;
      };
      initrd = {
        enable = true;
        ssh.usersImportKeyFiles = [ "test-operator" ];
      };
      luks.devices.enc-root = "/dev/vda2";
      btrfs.enable = true;
      btrfs.gen.enc-root.subvolumes.root.isRoot = true;
    };
    core = {
      shell.enable = true;
      env.enable = true;
    };
    nix.basic = true;
    networking.networkd.enable = true;
  };

  system.stateVersion = lib.mkDefault "23.05";
}
