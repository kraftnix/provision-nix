{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  dbus,
  stdenv,
  darwin,
}:
rustPlatform.buildRustPackage rec {
  pname = "mdbook-theme";
  version = "0.1.5";

  src = fetchFromGitHub {
    owner = "zjp-CN";
    repo = "mdbook-theme";
    rev = "v${version}";
    hash = "sha256-2lfi2Wyldh5zE5GR9OqBhrPS+f10FhUJMIXsURJYK2E=";
  };

  cargoHash = "sha256-iSlP7LaIeALbveh24hT2Er2RZWCLJygQ1cfxx6OCP3U=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs =
    [
      dbus
    ]
    ++ lib.optionals stdenv.isDarwin [
      darwin.apple_sdk.frameworks.CoreFoundation
      darwin.apple_sdk.frameworks.CoreServices
    ];

  meta = {
    description = "A preprocessor and a backend to config themes for mdbook, especially creating a pagetoc on the right and setting full color themes from the offical ace editor";
    homepage = "https://github.com/zjp-CN/mdbook-theme";
    changelog = "https://github.com/zjp-CN/mdbook-theme/blob/${src.rev}/CHANGELOG.md";
    license = with lib.licenses; [mit mpl20];
    maintainers = ["kraftnix"];
    mainProgram = "mdbook-theme";
  };
}
