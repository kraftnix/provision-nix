{
  provision.networking.wireguard.p2p = {
    # generate = "systemd";
    enable = true;
    networks.primary = {
      mode = "p2p";
      listenPort = 28600;
      subnet = "10.42.1";
      persistentKeepAlive = 15;
      privateKeyFile = "/etc/wireguard-primary.key";
      peers = {
        testWireguard = {
          subip = 1;
          pubkey = "jCaK1PaSQRwG+chve1rDlO5hbfC8Hll1FDiBdI0vEQk=";
          endpointIP = "192.168.0.1";
        };
        testSecurity = {
          subip = 2;
          pubkey = "Ai/4Z7HwmBQuT87Ifp6PRqtkX16VDApkBntdzIPKoGI=";
          endpointIP = "192.168.0.2";
        };
        testBtrfsBios = {
          subip = 3;
          pubkey = "mcjbAb+2PQzIHZLlmh/crxZQrn4y8MpRip+eSyAP9iA=";
          endpointIP = "192.168.0.3";
        };
      };
    };
    networks.secondary = {
      mode = "hub-and-spoke";
      listenPort = 28601;
      subnet = "10.52.1";
      persistentKeepAlive = 15;
      privateKeyFile = "/etc/wireguard-secondary.key";
      peers = {
        testWireguard = {
          subip = 1;
          pubkey = "jCaK1PaSQRwG+chve1rDlO5hbfC8Hll1FDiBdI0vEQk=";
          endpointIP = "192.168.0.1";
          gateway.enable = true;
        };
        testSecurity = {
          subip = 2;
          pubkey = "Ai/4Z7HwmBQuT87Ifp6PRqtkX16VDApkBntdzIPKoGI=";
        };
        testBtrfsBios = {
          subip = 3;
          pubkey = "mcjbAb+2PQzIHZLlmh/crxZQrn4y8MpRip+eSyAP9iA=";
        };
      };
    };
  };
}
