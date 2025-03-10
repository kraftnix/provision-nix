{
  lib,
  rustPlatform,
  fetchFromGitHub,
  stdenv,
  darwin,
}:
rustPlatform.buildRustPackage rec {
  pname = "yapp";
  version = "1.0.2";

  src = fetchFromGitHub {
    owner = "EngosSoftware";
    repo = "yapp";
    rev = "v${version}";
    hash = "sha256-ady5v/Z1/jXLsiVFNZhtwWYeDwsN0dQ5/91UN5TiMEM=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-khG1IxiIRzKpsU26hgVYKk8f6T4FD9xkJt2MFe50voU=";

  buildInputs = lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.CoreFoundation
    darwin.apple_sdk.frameworks.CoreServices
  ];

  meta = {
    description = "Yet another preprocessor for mdBook";
    homepage = "https://github.com/EngosSoftware/yapp";
    license = lib.licenses.mit;
    maintainers = [ "kraftnix" ];
    mainProgram = "yapp";
  };
}
