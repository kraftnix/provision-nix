{ lib, ... }:
let
  inherit (lib.types)
    int
    ints
    listOf
    nullOr
    str
    ;
  inherit (lib)
    mkOption
    ;
in
{
  name =
    default:
    mkOption {
      description = "Wireguard network name, default: ${default}.";
      type = str;
      inherit default;
    };
  publicKey =
    default:
    mkOption {
      description = "Public key of wireguard peer, default: ${default}.";
      type = str;
      inherit default;
    };
  privateKeyFile =
    default:
    mkOption {
      description = "Private key file location on this host (only used for configuration on that host), default: ${toString default}.";
      type = str;
      inherit default;
    };
  persistentKeepAlive =
    default:
    mkOption {
      description = "PersistentKeepalive of the wireguard network, default: ${toString default}.";
      type = nullOr int;
      inherit default;
    };
  mtu =
    default:
    mkOption {
      description = "Wireguard MTU, default: ${toString default}.";
      type = ints.between 576 1000000;
      inherit default;
    };
  allowedIPs =
    default:
    mkOption {
      description = "Allowed IPs for wireguard network, default: ${toString default}.";
      type = listOf str;
      inherit default;
    };
  listenPort =
    default:
    mkOption {
      description = "Wireguard listen port, default: ${toString default}.";
      type = int;
      inherit default;
    };
  endpointIP =
    default:
    mkOption {
      description = "Endpoint IP address of the wireguard network, default: ${toString default}.";
      type = nullOr str;
      inherit default;
    };
  id =
    default:
    mkOption {
      description = "ID of the peer, used for IP address calculation, max 255 due to IPv4 support, default ${toString default}.";
      type = ints.between 1 255;
      inherit default;
    };
  ipv4 =
    default:
    mkOption {
      description = "Internal wireguard IPv4 address";
      type = str;
      inherit default;
    };
  subnet =
    default:
    mkOption {
      example = "192.168.200";
      description = "First 3 parts of wireguard network's IPv4 subnet, default: ${default}.";
      type = str;
      inherit default;
    };
  ula =
    default:
    mkOption {
      example = "fda2:d982:1da2";
      description = "IPv6 ula of wireguard network, default: ${default}.";
      type = str;
      inherit default;
    };
  gua =
    default:
    mkOption {
      example = "2001:470:b1bb";
      description = "IPv6 gua of wireguard network, default: ${default}.";
      type = str;
      inherit default;
    };
  gateway =
    default:
    mkOption {
      type = nullOr str;
      description = "Internal Gateway for wireguard network, default: ${toString default}.";
      inherit default;
    };
}
