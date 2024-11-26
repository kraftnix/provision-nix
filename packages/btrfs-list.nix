source:
{
  stdenv,
  perl,
  btrfs-progs,
}:
let
  inherit (source) version src pname;
in
stdenv.mkDerivation {
  inherit pname src version;
  buildInputs = [
    perl
    btrfs-progs
  ];
  installPhase = ''
    mkdir -p $out/bin
    cp $src/btrfs-list $out/bin
    substituteInPlace $out/bin/btrfs-list --replace "#! /usr/bin/perl" "#!/usr/bin/env perl"
  '';
}
