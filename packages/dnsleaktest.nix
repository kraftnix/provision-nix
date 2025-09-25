{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "dnsleaktest";
  version = "1.3";

  src = fetchFromGitHub {
    owner = "macvk";
    repo = "dnsleaktest";
    rev = "v${version}";
    hash = "sha256-XYX6hjkSsHZAQHNC8i3yGvhnhUBwNJxAP95tyo+30T0=";
  };

  buildPhase = ''
    mkdir -p $out/bin
    cp ./dnsleaktest.sh $out/bin/dnsleaktest
  '';

  meta = {
    description = "An open source script tests VPN connection for DNS Leak";
    homepage = "https://github.com/macvk/dnsleaktest";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ kraftnix ];
    mainProgram = "dnsleaktest";
    platforms = lib.platforms.all;
  };
}
