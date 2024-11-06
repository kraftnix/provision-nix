# Wireguard Network Generation

This module provides a way to define multiple wireguard network
architectures, currently supported:
  - Point-to-Point
  - Hub and Spoke
  - Peer to Peer (requires public IPs, not useful for private clients / clients behind NAT)

> Currently there are two wireguard integrations in this repo, I am in
> the process of merging these together. The current prefered integration
> is `provision.networking.wireguard.p2p`
