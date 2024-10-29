{
  provision.networking.wireguard.p2p = {
    # generate = "systemd";
    enable = true;
    hosts = {
      testWireguard.subip = 1;
      testWireguard.endpointIP = "192.168.0.1";
      testWireguard.networks = {
        primary.pubkey = "jCaK1PaSQRwG+chve1rDlO5hbfC8Hll1FDiBdI0vEQk=";
        # secondary.gateway.enable = true;
        secondary.pubkey = "jCaK1PaSQRwG+chve1rDlO5hbfC8Hll1FDiBdI0vEQk=";
      };
      testSecurity.subip = 2;
      testSecurity.networks = {
        primary = {
          pubkey = "Ai/4Z7HwmBQuT87Ifp6PRqtkX16VDApkBntdzIPKoGI=";
          endpointIP = "192.168.0.2";
        };
        secondary.pubkey = "Ai/4Z7HwmBQuT87Ifp6PRqtkX16VDApkBntdzIPKoGI=";
      };
      testBtrfsBios.subip = 3;
      testBtrfsBios.networks = {
        primary = {
          pubkey = "mcjbAb+2PQzIHZLlmh/crxZQrn4y8MpRip+eSyAP9iA=";
          endpointIP = "192.168.0.3";
        };
        secondary.pubkey = "mcjbAb+2PQzIHZLlmh/crxZQrn4y8MpRip+eSyAP9iA=";
      };
    };
    networks.primary = {
      mode = "p2p";
      listenPort = 28600;
      subnet = "10.42.1";
      persistentKeepAlive = 15;
      privateKeyFile = "/etc/wireguard-primary.key";
    };
    networks.secondary = {
      mode = "hub-and-spoke";
      listenPort = 28601;
      subnet = "10.52.1";
      persistentKeepAlive = 15;
      privateKeyFile = "/etc/wireguard-secondary.key";
    };
  };
}
