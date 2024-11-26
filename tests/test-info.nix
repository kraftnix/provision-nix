rec {
  hostips = {
    gateway = "192.168.0.1";
    peer2 = "192.168.0.2";
    peer3 = "192.168.0.3";
    peer4 = "192.168.0.4";
  };

  primary = {
    gateway = {
      id = 1;
      ip = "10.42.1.1";
      privateKey = "SCH1bKS0+IY9IRehJpd2SiU/MpDf0934lnyuhIgpS30=";
      endpointIP = "192.168.0.1";
      publicKey = "jCaK1PaSQRwG+chve1rDlO5hbfC8Hll1FDiBdI0vEQk=";
    };
    peer2 = {
      id = 2;
      ip = "10.42.1.2";
      privateKey = "CDYmffkmuXH8M7GNd2Bk55yu9QUs8LzsM8zBJoqCc3k=";
      publicKey = "Ai/4Z7HwmBQuT87Ifp6PRqtkX16VDApkBntdzIPKoGI=";
      endpointIP = "192.168.0.2";
    };
    peer3 = {
      id = 3;
      ip = "10.42.1.3";
      privateKey = "ONhaca/jLoK+YAcg5HcaYzzzRNJ4rGw1s/NOu4nJTlQ=";
      publicKey = "mcjbAb+2PQzIHZLlmh/crxZQrn4y8MpRip+eSyAP9iA=";
      endpointIP = "192.168.0.3";
    };
  };
  secondary = {
    gateway = {
      id = 1;
      ip = "10.52.1.1";
      endpointIP = "192.168.0.1";
      # gateway.enable = true;
      privateKey = "SCH1bKS0+IY9IRehJpd2SiU/MpDf0934lnyuhIgpS30=";
      publicKey = "jCaK1PaSQRwG+chve1rDlO5hbfC8Hll1FDiBdI0vEQk=";
      # privateKey = "UGsAZIlLkyDqRRxV661hxVk3lvL/AHywLIIFfngWg2M=";
      # publicKey = "Mc4Pq+YkuReYem3IFNGnYucTd5N/ZS1VMZ5dM4qzmCY=";
    };
    peer2 = {
      id = 2;
      ip = "10.52.1.2";
      privateKey = "CDYmffkmuXH8M7GNd2Bk55yu9QUs8LzsM8zBJoqCc3k=";
      publicKey = "Ai/4Z7HwmBQuT87Ifp6PRqtkX16VDApkBntdzIPKoGI=";
      # privateKey = "2LKXKUqT3mqdWckIy9R0XJOiLMKiv9ltrfp2SZJyS0M=";
      # publicKey = "zVDFjS8kh8f+6dgthPxXyj4LWG546fipyWBNCxkG9FA=";
    };
    peer3 = {
      id = 3;
      ip = "10.52.1.3";
      privateKey = "ONhaca/jLoK+YAcg5HcaYzzzRNJ4rGw1s/NOu4nJTlQ=";
      publicKey = "mcjbAb+2PQzIHZLlmh/crxZQrn4y8MpRip+eSyAP9iA=";
      # privateKey = "2AVDzxeNqoj+IAXsosvkhCulfQ9Bb3ArmBYCOkYcK30=";
      # publicKey = "CQqiI5qE9qFJ6nzAHO+KXZ7P64sr24qf1CEtQH7ozj8=";
    };
    peer4 = {
      id = 4;
      ip = "10.52.1.4";
      privateKey = "2AVDzxeNqoj+IAXsosvkhCulfQ9Bb3ArmBYCOkYcK30=";
      publicKey = "CQqiI5qE9qFJ6nzAHO+KXZ7P64sr24qf1CEtQH7ozj8=";
    };
  };

  defaultHostConfig =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      name = config.networking.hostName;
      ip = hostips.${name};
    in
    {
      boot.loader.systemd-boot.enable = true;
      systemd.network.enable = true;
      networking.useNetworkd = true;
      networking.useDHCP = false;
      # networking.firewall.interfaces.eth1.allowedUDPPorts = lib.optionals (name == "gateway") [ 28600  28601 ];
      networking.interfaces.eth1.ipv4.addresses = [
        {
          address = ip;
          prefixLength = 24;
        }
      ];
      fileSystems."/" = lib.mkDefault { device = "/dev/disk/by-label/One"; };
      environment.systemPackages = with pkgs; [
        fd
        ripgrep
        tmux
        vim
      ];
      users.users.root.hashedPassword = lib.mkDefault "$y$j9T$vMHW6Xt2v3axdGdkltO8e.$Lgr2IcIPoGasOSv8PE3RVIPFqSzQU.duhw8/xPI2uzD"; # empty
      users.users.root.hashedPasswordFile = lib.mkForce null; # due to warning
      virtualisation.memorySize = 500;
      virtualisation.emptyDiskImages = [ 250 ];
      system.stateVersion = "22.11";
    };
}
