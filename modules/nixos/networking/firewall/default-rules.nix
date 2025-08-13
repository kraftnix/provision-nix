{
  accept-to-local = {
    n = 1;
    main = "iifname lo";
    comment = "accept all to host";
    counter = false;
    verdict = "accept";
  };
  icmp-default = {
    n = 10;
    main = "meta l4proto { icmp, ipv6-icmp }";
    comment = "accept ICMPv4 + ICMPv6 (ARP / ping)";
    counter = true;
    verdict = "accept";
  };
  ct-related-accept = {
    n = 20;
    main = "ct state { established, related }";
    comment = "accept established/related packets";
    counter = true;
    verdict = "accept";
  };
  ct-dnat-trace = {
    n = 25;
    main = "ct status dnat";
    comment = "accept incoming DNAT";
    # trace = true;
    verdict = "counter accept";
  };
  ct-drop-invalid = {
    n = 30;
    main = "ct state invalid";
    comment = "drop invalid packets";
    counter = true;
    verdict = "drop";
  };
  arp-reply = {
    n = 33;
    main = "arp operation reply";
    comment = "accept ARP reply";
    verdict = "accept";
  };
  ipv6-accept-link-local-dhcp = {
    n = 40;
    main = "ip6 daddr fe80::/64 udp dport dhcpv6-client";
    counter = true;
    verdict = "accept";
    comment = "accept all DHCPv6 packets received at a link-local address";
  };
}
