# Firewall integration (nftables)

A custom NixOS module for generating [nftables](https://wiki.nftables.org) rules.

The aim of these options is to allow fully declarative configuration of nftables rules
while providing the flexibility to insert custom rules (have an escape hatch) for configurations
which don't fit nicely in the current module.

## Module Structure

The configuration options try to match actual nftables config files as close as possible.
Options that start with `__` are used to define toplevel options, defaults or the rendered snippet

Mappings:
  - `tables.<table>`: [Tables](https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes#Tables)
  - `tables.<table>.mapsets.<mapset>`: one of [Sets](https://wiki.nftables.org/wiki-nftables/index.php/Sets) or [Maps](https://wiki.nftables.org/wiki-nftables/index.php/Maps) or [Verdict Maps](https://wiki.nftables.org/wiki-nftables/index.php/Verdict_Maps_(vmaps))
  - `tables.<table>.<chain>`: [Chains](https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes#Chains)
  - `tables.<table>.<chain>.rules.<rule>`: [Rules](https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes#Rules)

Shared rules can be defined at `rules.<myrule>`, and then used by:
  - naming your rule in `tables.<table>.<chain>.rules.<myrule>` the same as a shared rule
  - set the shared rule used in `tables.<table>.<chain>.rules.<custom-rule>.rule = "myrule"`

### Introspection

You can view the final configuration and snippets generated in the repl:
  - `networking.nftables.ruleset`: final ruleset (including from other host `networking.nftables` configuration)
  - `networking.nftables.gen.__rendered`: ruleset generated from this module
  - `networking.nftables.gen.tables.<table>.__rendered`: full `table` generated ruleset
  - `networking.nftables.gen.tables.<table>.<chain>.__rendered`: full `chain` generated ruleset
  - `networking.nftables.gen.tables.<table>.<chain>.rules.<rule>.__rendered`: full `rule` generated ruleset

> 💡 Tip: You can use `:p` in the repl to pretty print these strings
>
> `:p nixosConfiguration.<host>.config.networking.nftables.ruleset`

## Example Configuration (explained)

The following example generates a simple nftables firewall which allows inbound SSH at port 22.

The `default` profile generates a single table (type `inet`) with two chains `input` and `forward`.

```nix
networking.nftabes.gen.enable = true;
networking.nftabes.gen.profiles = ["default"];
networking.nftabes.gen.tables.filter = {
  input.rules.testing = {
    log = true;
    counter = true;
    tcpDport = [22];
  };
};
```

It also populates both with some sane `default` rules enabled:
  - `ct-drop-invalid`: drop invalid packets
  - `icmp-defalt`: allow ICMP
  - `ipv6-accept-link-local-dhcp`: accept DHCPv6 packet at link-local
  - `ct-related-accept`: allow established connections
  - `ct-dnat-trace`: allow established DNAT connections
  - `accept-to-local`: allow local connections to host (from `lo`)
  - counts packets in a named counter before the final default policy of the chain (`finalCounter = true;`)

These rules can be selectively disabled (or reordered) with:
```nix
networking.nftabes.gen.tables.filter = {
  input.finalCounter = false; # removes named counter before `finalRule` (if set) / chain policy
  input.rules.accept-to-local.enable = false;
};
```

These two snippets put together; generates a config looking something like:

```bash
table inet filter {
  counter chain_final_forward {
    comment "forward default policy"
  }

  chain all-input-handle { }
  chain input {
    type filter hook input priority filter; policy drop;

    meta l4proto { icmp, ipv6-icmp } counter accept comment "accept ICMPv4 + ICMPv6 (ARP / ping)"
    ct state { established, related } counter accept comment "accept established/related packets"
    ct status dnat counter accept comment "accept incoming DNAT"
    ct state invalid counter drop comment "drop invalid packets"
    ip6 daddr fe80::/64 udp dport dhcpv6-client counter accept comment "accept all DHCPv6 packets received at a link-local address"
    counter jump all-input-handle comment "all-input-handle"
    tcp dport 22 log counter accept comment "testing"
  }

  chain forward {
    type filter hook forward priority filter; policy drop;

    ct state { established, related } counter accept comment "accept established/related packets"
    ct status dnat counter accept comment "accept incoming DNAT"
    ct state invalid counter drop comment "drop invalid packets"
    oifname lo  counter jump all-input-handle comment "all-input-handle"
    counter name chain_final_forward # Final counter for forward
  }
}
```
