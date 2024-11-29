{ lib, ... }:
with lib;
rec {
  /**
    Strips mask from an IPv4 address.

    # Example

    ```nix
    stripMask "10.1.1.1/24"
    =>
    "10.1.1.1"
    ```

    # Type

    ```
    stripMask :: String -> String
    ```

    # Arguments

    ipFragment
    : ip address with subnet mask like "10.1.1.0/24"
  */
  stripMask = ipFragment: elemAt (splitString "/" ipFragment) 0;

  /**
    Generate an IPv4 address from a subnet and ip fragment.

    # Example

    ```nix
    genIP "10.1.1" "42"
    =>
    "10.1.1.42"

    # also
    genIP "10.2" "3.42"
    =>
    "10.2.3.42"
    ```

    # Type

    ```
    genIP :: String -> String -> String
    ```

    # Arguments

    subnet
    : an IPv4 subnet like "10", "10.1", "10.1.1"

    ipFragment
    : an IPv4 fragment which should match the subnet, like "1", "2.3", "2.3.4"
  */
  genIP = subnet: ipFragment: "${subnet}.${toString ipFragment}";

  genGateway = subnet: "${subnet}.1";
  getSubnet = ip: concatStringsSep "." (take 3 (splitString "." ip));
  # ipv4 only
  toDoubleDigit = hex: if stringLength hex == 1 then "0${hex}" else hex;
  toHex = n: toDoubleDigit (toHexString (lib.toInt n));
  ipToMac = ip: concatStringsSep ":" ((map toHex) (splitString "." ip));
}
