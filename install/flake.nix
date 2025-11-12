{
  description = ''

  '';

  inputs = {
    install-nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-anywhere.url = "github:numtide/nixos-anywhere";
    nixos-anywhere.inputs = {
      nixpkgs.follows = "install-nixpkgs";
      nixos-stable.follows = "install-nixpkgs";
    };

    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators = {
      inputs.nixpkgs.follows = "install-nixpkgs";
      inputs.nixlib.follows = "install-nixpkgs";
    };
  };

  outputs = _: { };
}
