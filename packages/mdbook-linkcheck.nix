{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
  testers,
  mdbook-linkcheck,
}:

rustPlatform.buildRustPackage rec {
  pname = "mdbook-linkcheck";
  version = "0.7.7-fix";

  src = fetchFromGitHub {
    owner = "Michael-F-Bryan";
    repo = pname;
    rev = "ed981be6ded11562e604fff290ae4c08f1c419c5";
    sha256 = "sha256-GTVWc/vkqY9Hml2fmm3iCHOzd/HPP1i/8NIIjFqGGbQ=";
  };

  cargoHash = "sha256-+73aI/jt5mu6dR6PR9Q08hPdOsWukb/z9crIdMMeF7U=";

  buildInputs = lib.optionals (!stdenv.hostPlatform.isDarwin) [ openssl ];

  nativeBuildInputs = lib.optionals (!stdenv.hostPlatform.isDarwin) [ pkg-config ];

  OPENSSL_NO_VENDOR = 1;

  doCheck = false; # tries to access network to test broken web link functionality

  passthru.tests.version = testers.testVersion { package = mdbook-linkcheck; };

  meta = with lib; {
    description = "Backend for `mdbook` which will check your links for you";
    mainProgram = "mdbook-linkcheck";
    homepage = "https://github.com/Michael-F-Bryan/mdbook-linkcheck";
    license = licenses.mit;
    maintainers = with maintainers; [
      zhaofengli
      matthiasbeyer
    ];
  };
}
