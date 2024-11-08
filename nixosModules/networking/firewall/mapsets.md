# Mapsets

Mapsets can be one of:
  - [Sets](https://wiki.nftables.org/wiki-nftables/index.php/Sets) (i.e. `{ 10.11.1.1, 10.11.22.33 }`)
  - [Maps](https://wiki.nftables.org/wiki-nftables/index.php/Maps) (i.e. `{ 80 : 192.168.1.100 }`)
  - [Verdict Maps](https://wiki.nftables.org/wiki-nftables/index.php/Verdict_Maps_(vmaps)) (i.e. `{ 192.168.1.1 : drop }` or `{ 192.168.1.1 . 80 : drop }`)

One reason mapsets can be useful, is they allow modifying the firewall while it is running
with `nft` commands, without needing to write the full rules out.

I'll now show some examples, to keep config more readable, consider everything prefixed with `networking.nftables.gen`.

## Sharing mapsets between rules

Allows only 3 specific internal hosts to SSH or HTTP/HTTPS.

```nix
# match against saddr
tables.filter.mapsets.internal_hosts = {
  lhsType = "saddr";
  elements = [
    { l = "10.11.1.1"; }
    { l = "10.11.22.33"; }
    { l = "10.44.55.66"; }
  ];
};
# Allow HTTP/HTTPS inbound only to specified mapset
tables.filter.input.rules.reverse-proxy = {
  tcpDport = [80 443];
  mapset = "internal_hosts";
  log = true;
};
# Allow HTTP/HTTPS inbound only to specified mapset
tables.filter.input.rules.internal-ssh = {
  tcpDport = [22];
  mapset = "internal_hosts";
  counter = true;
};
```

We can then modify the mapset at runtime without changing the NixOS configuration:
```sh
# for a Set
nft add element "inet filter internal_hosts { 192.168.1.1 }"
nft add element "inet filter wireguard_inbound_udp { 19999 : accept }"
```

## Examples

### Wireguard UDP Inbound

This example shows using a verdict map to allow multiple inbound udp for an external interface

```nix
tables.filter.mapsets.wireguard_inbound_udp = {
  verdict = "verdict";
  lhsType = "udp dport";
  elements = [
    { l = 51820; v = "accept"; }
    { l = 51821; v = "jump log-and-accept"; }
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
```

### Selective NAT with forwarding

Sometimes when performing NAT for internal networks / bridges you want to align the forwarding table and NAT postrouting chains.

Defining this as a mapset can both reduce duplication, and allow configuration while the system is running.

```nix
let
  genMapset = verdict: {
    verdict = "verdict";
    lhsType = "iifname";
    rhsType = "oifname";
    elements = [
      { l = "dmz"; r = "vpn-egress"; v = verdict; }
      { l = "libvirtbr0"; r = "enp1s0"; v = verdict; }
    ];
  };
in
tables.filter = {
  # generate forward and snat allow maps for snat forwarding
  mapsets = {
    egress_allow_map = genMapset "accept";
    egress_snat_map = genMapset "jump masquerade_random";
  };
  masquerade_random.rules.all = {
    comment = "masquerade all";
    verdict = "masquerade random";
    counter = true;
  };
  # allow forwarding for specific interfaces mapset
  forward.rules.egress_allow_map = {
    comment = "allow forwarding from internal -> egress";
    mapset = "egress_allow_map";
  };
  # egress + masquerade specific interfaces from mapset
  egress-snat.__type.hook = "postrouting";
  egress-snat.rules.map = {
    mapset = "egress_snat_map";
    comment = "NAT from lan -> egress";
  };
};
```

This generates the following config in nftables.

```bash
table inet filter {
  map egress_allow_map {
    type ifname . ifname : verdict
    elements = {
      dmz . vpn-egress : accept,
      libvirtbr0 . enp1s0 : accept
    }
  }

  map egress_snat_map {
    type ifname . ifname : verdict
    elements = {
      dmz . vpn-egress : jump masquerade_random,
      libvirtbr0 . enp1s0 : jump masquerade_random
    }
  }

  chain forward {
    type filter hook forward priority filter; policy drop;
    counter iifname . oifname vmap @egress_allow_map accept comment "allow forwarding from internal -> egress"
  }

  chain egress-snat {
    type nat hook postrouting priority srcnat;
    iifname . oifname vmap @egress_snat_map comment "NAT from lan -> egress"
  }
}
```
