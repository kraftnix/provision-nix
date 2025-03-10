self:
let
  pkgs = import self.inputs.nixpkgs {
    system = "x86_64-linux";
  };

  modules = [
    self.nixosModules.networking-firewall
    {
      environment.systemPackages = [ pkgs.openssh ];
      services.openssh.enable = true;
      networking.nftables.gen.enable = true;
      networking.nftables.gen.overrideNixosNftables = true;
      networking.nftables.gen.profiles = [ "default" ];
    }
  ];

  nodes = {
    sshonly =
      { ... }:
      {
        imports = modules;
        services.openssh.openFirewall = true;
        networking.nftables.gen.tables.filter = { };
      };
    basic =
      { ... }:
      {
        imports = modules;
        services.openssh.openFirewall = false;
        networking.nftables.gen.tables.filter = {
          input.rules.allow-http = {
            counter = true;
            log = true;
            tcpDport = [ 80 ];
            verdict = "accept";
            comment = "allow http access to httpd";
          };
        };
        networking.nat.externalInterface = "eth1";
        services.httpd.enable = true;
        services.httpd.adminAddr = "foo@example.org";
      };
  };

  nixos-lib = import (self.inputs.nixpkgs + "/nixos/lib") { };
  test = {
    name = "nftables-basic";
    hostPkgs = pkgs;
    inherit nodes;
    testScript = ''

      start_all()

      with subtest("Waiting for multi-user target"):
        basic.wait_for_unit("nftables")
        basic.wait_for_unit("httpd")
        basic.wait_for_unit("sshd")
        sshonly.wait_for_unit("network.target")
        sshonly.wait_for_unit("sshd")

      sshonly.sleep(5)

      with subtest("testing basic access"):
        sshonly.succeed("curl -v http://basic/ >&2")

      # basic should be able to see the openssh server at sshonly
      basic.succeed("ssh-keyscan sshonly")

      # sshonly should not be able to see the openssh server at basic
      sshonly.fail("ssh-keyscan basic")
    '';
  };
in
nixos-lib.runTest test
