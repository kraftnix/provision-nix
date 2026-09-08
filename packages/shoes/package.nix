{
  lib,
  rustPlatform,
  fetchFromGitHub,
  rust-jemalloc-sys,
  rust-jemalloc-sys-unprefixed,
  nix-update-script,
  fetchgit,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "shoes";
  version = "0.2.7";
  # version = "0.2.8";
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "cfal";
    repo = "shoes";
    tag = "v${finalAttrs.version}";
    hash = "sha256-HynLs4Avnd8rXcu48ees94Yu8QZOmR+bqfpHPk1NYjI=";
    # rev = "7a5a8ee3bd1c52bc15ec57e074e95e374d41f275";
    # hash = "sha256-Pl8RuYhJvEJTS2uW0PVZ73eXyY2+o64FgwSK16hKWR0=";
  };
  patches = [ ./01-jemalloc.patch ];

  # cargoHash = "sha256-nB/9j0M/osadI2DNgIJnyYopxvmeEIPUiH99ySvOHX0="; # 0.2.7
  # cargoHash = "sha256-rwwTPtQpv10SaNvPc7br25o6gAe8NYCUUQKqkOAIXYA="; # master
  ## wont build without this due to git dependency
  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "hickory-net-0.26.0-alpha.1" = "sha256-q4wu3NUwDJzUsYDYlG0WT7fAOCltVVP2AAsCabpys5w=";
    };
  };
  postPatch = ''
    cp ${./Cargo.lock} Cargo.lock
  '';

  # WIP: attempt to get working
  buildInputs = [
    rust-jemalloc-sys
    rust-jemalloc-sys-unprefixed
  ];

  checkFlags = [
    # Requires network
    "--skip=dns::proxy_runtime::tests::test_connect_tcp_respects_timeout"
    "--skip=dns::proxy_runtime::tests::test_connect_tcp_uses_default_timeout_when_none"
  ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "A multi-protocol proxy server written in Rust (HTTP, SOCKS5, Vmess, Vless, Shadowsocks, Trojan, Snell, Hysteria2, TUIC v5, AnyTLS, Naiveproxy, XTLS";
    homepage = "https://github.com/cfal/shoes";
    changelog = "https://github.com/cfal/shoes/blob/${finalAttrs.src.rev}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ kraftnix ];
    mainProgram = "shoes";
  };
})
