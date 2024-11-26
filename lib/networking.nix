{ lib, ... }:
with lib;
rec {
  stripMask = ip: elemAt (splitString "/" ip) 0;
  genIP = subnet: ip: "${subnet}.${toString ip}";
  genGateway = subnet: "${subnet}.1";
  getSubnet = ip: concatStringsSep "." (take 3 (splitString "." ip));
  # ipv4 only
  toDoubleDigit = hex: if stringLength hex == 1 then "0${hex}" else hex;
  toHex = n: toDoubleDigit (toHexString (lib.toInt n));
  ipToMac = ip: concatStringsSep ":" ((map toHex) (splitString "." ip));
}
