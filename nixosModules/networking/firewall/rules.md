# Rules

[Rules](https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes#Rules) can either be:
  - shared config snippets defined at `rules`
  - concrete snippet generated within chains at `tables.<table>.<chain>.rules.<rule>`

There are a number of rules auto-included when the `default` profile is enabled.

## Default shared rules

These shared rules are added by default under `rules`

```nix
# included from ./default-rules.nix
{{#include ../../../nixosModules/networking/firewall/default-rules.nix}}
```

And can be used with

```nix
networking.nftables.gen.tables.filter.input.rules = {
  accept-to-local = {};
  icmp-default = {};
  ct-related-accept = {};
  ct-dnat-trace = {};
  ct-drop-invalid = {};
  ipv6-accept-link-local-dhcp = {};
}
```

Rules are enabled by default when defined, but can be disabled by setting `enable = false`.

## Overriding rules

You can use override shared rules simply by setting a value

```nix
networking.nftables.gen = {
  rules.allow-ssh = {
    tcpDport = [22];
    comment = "allow SSH inbound";
  };
  tables.filter.input.rules.allow-ssh.iifname = ["vpn"];
};
```

We can inspect the final rule generated in the repl
```nix-repl
nix-repl> nixosConfigurations.<host>.config.networking.nftables.gen.tables.filter.input.rules.allow-ssh.__final
"iifname vpn tcp dport 22  comment \"allow SSH inbound\""
```
