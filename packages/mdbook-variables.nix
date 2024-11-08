{
  lib,
  rustPlatform,
  fetchFromGitLab,
  stdenv,
  darwin,
}:
rustPlatform.buildRustPackage rec {
  pname = "mdbook-variables";
  version = "0.2.4";

  src = fetchFromGitLab {
    owner = "tglman";
    repo = "mdbook-variables";
    rev = version;
    hash = "sha256-whvRCV1g2avKegfQpMgYi+E6ETxT2tQqVS2SWRpAqF8=";
  };

  cargoHash = "sha256-uw1oWIoKi6qsObI4SkEiHwEj9QoxE9jufu9O+ZKM8DI=";

  buildInputs = lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.CoreFoundation
    darwin.apple_sdk.frameworks.CoreServices
  ];

  meta = {
    description = "Preprocessor for mdbook to add replace values in double brackets with ENV or book.toml set variables.";
    homepage = "https://gitlab.com/tglman/mdbook-variables";
    license = lib.licenses.mpl20;
    maintainers = ["kraftnix"];
    mainProgram = "mdbook-variables";
  };
}
