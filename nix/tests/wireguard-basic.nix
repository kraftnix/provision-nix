self: let
  pkgs = import self.inputs.nixpkgs {
    system = "x86_64-linux";
  };

  info = import ./test-info.nix;
  hostips = info;

  wireguard = {
    # generate = "systemd";
    enable = true;
    networks.primary = {
      mode = "p2p";
      listenPort = 28600;
      subnet = "10.42.1";
      persistentKeepAlive = 15;
      privateKeyFile = "/etc/wireguard-primary.key";
      peers =
        builtins.mapAttrs
        (n: {
          endpointIP ? "",
          id,
          publicKey,
          gateway ? {},
          ...
        }: {
          inherit endpointIP;
          subip = id;
          pubkey = publicKey;
          gateway = gateway;
        })
        info.primary;
    };
    networks.secondary = {
      mode = "hub-and-spoke";
      listenPort = 28601;
      subnet = "10.52.1";
      persistentKeepAlive = 15;
      privateKeyFile = "/etc/wireguard-secondary.key";
      peers =
        builtins.mapAttrs
        (n: {
          endpointIP ? "",
          id,
          publicKey,
          gateway ? {},
          ...
        }: {
          inherit endpointIP;
          subip = id;
          pubkey = publicKey;
          gateway = gateway;
        })
        info.secondary;
    };
  };

  defaultHostConfig = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (lib) mkIf hasAttr;
    name = config.networking.hostName;
    ip = hostips.${config.networking.hostName};
  in {
    imports = [
      self.nixosModules.networking-wireguard-network
      self.nixosModules.networking-firewall
      info.defaultHostConfig
    ];
    # default test expects keys at /etc/wireguard-{name}.key
    # we keep the snakeoil keys in ./test-info.nix
    environment.etc."wireguard-primary.key" = mkIf (hasAttr name info.primary) {
      text = info.primary.${name}.privateKey;
      mode = "400";
      user = "systemd-network";
    };
    environment.etc."wireguard-secondary.key" = mkIf (hasAttr name info.secondary) {
      text = info.secondary.${name}.privateKey;
      mode = "400";
      user = "systemd-network";
    };
    networking.nat.externalInterface = lib.mkIf (config.networking.hostName == "gateway") "eth1";

    provision.networking.wireguard.p2p = wireguard;
  };

  nixos-lib = import (self.inputs.nixpkgs + "/nixos/lib") {};
  ping = "ping -c3 -W 6";
  test = {
    name = "wireguard-basic";
    hostPkgs = pkgs;
    node.specialArgs.pkgs = pkgs;
    nodes.gateway = defaultHostConfig;
    nodes.peer2 = defaultHostConfig;
    nodes.peer3 = defaultHostConfig;
    nodes.peer4 = defaultHostConfig;
    testScript = ''

      start_all()

      with subtest("Waiting for multi-user target"):
        gateway.wait_for_unit("multi-user.target")
        peer2.wait_for_unit("multi-user.target")
        peer3.wait_for_unit("multi-user.target")
        peer4.wait_for_unit("multi-user.target")

      gateway.sleep(5)

      with subtest("testing primary network"):
        gateway.succeed("${ping} ${info.primary.peer2.ip}")
        gateway.succeed("${ping} ${info.primary.peer3.ip}")
        peer2.succeed("${ping} ${info.primary.gateway.ip}")
        peer2.succeed("${ping} ${info.primary.peer3.ip}")
        peer3.succeed("${ping} ${info.primary.gateway.ip}")
        peer3.succeed("${ping} ${info.primary.peer2.ip}")

      with subtest("testing secondary network"):
        gateway.succeed("${ping} ${info.secondary.peer2.ip}")
        gateway.succeed("${ping} ${info.secondary.peer3.ip}")
        gateway.succeed("${ping} ${info.secondary.peer4.ip}")
        peer2.succeed("${ping} ${info.secondary.gateway.ip}")
        peer2.succeed("${ping} ${info.secondary.peer3.ip}")
        peer2.succeed("${ping} ${info.secondary.peer4.ip}")
        peer3.succeed("${ping} ${info.secondary.gateway.ip}")
        peer3.succeed("${ping} ${info.secondary.peer2.ip}")
        peer3.succeed("${ping} ${info.secondary.peer4.ip}")
        peer4.succeed("${ping} ${info.secondary.gateway.ip}")
        peer4.succeed("${ping} ${info.secondary.peer2.ip}")
        peer4.succeed("${ping} ${info.secondary.peer3.ip}")
    '';
  };
in
  nixos-lib.runTest test
