self:
let
  pkgs = import self.inputs.nixpkgs {
    system = "x86_64-linux";
  };

  serverIPv4 = "192.168.1.2"; # /24
  serverIPv6 = "2001:db8:1::2"; # /64

  modules = [
    {
      networking.firewall.enable = true;
      environment.systemPackages = [
        pkgs.nfs-utils
      ];
      # ids must be syncronised across nfs for ease of use
      users.users.shared-user = {
        uid = 5454;
        isNormalUser = true;
      };
    }
  ];

  serverModule =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      imports = modules ++ [
        self.nixosModules.networking-firewall
        self.nixosModules.fs-nfs-server
        self.nixosModules.fs-boot
        self.nixosModules.fs-zfs
        (import ./init-zfs.nix { })
      ];

      provision.fs.zfs = {
        enable = true;
        hostId = "deadbeef";
        kernel = {
          enable = true;
          version = "stable";
        };
      };

      # Create ZFS pool for nfs use
      virtualisation.emptyDiskImages = [ 100 ];

      ## issue with NixOS VM not setting `fileSystems` correctly for these mounts requires defining them here...
      virtualisation.fileSystems = lib.pipe config.provision.fs.nfs.server.exports [
        (lib.filterAttrs (_: e: e.enable && e.addToFilesystem))
        (lib.mapAttrs' (
          _: e:
          lib.nameValuePair e.exportPath {
            fsType = "auto";
            device = e.hostPath;
            options = e.mount.options;
            neededForBoot = false;
          }
        ))
      ];

      users.users.server-only = {
        uid = 2200;
        isNormalUser = true;
      };

      provision.fs.nfs.server = {
        enable = true;
        exportDir = "/export";
        firewall.enable = true;
        firewall.interfaces = [
          "eth0"
          "eth1"
        ];
        default.addToFilesystem = true;
        default.rootFsid = 0;
        default.export.options = {
          rw = true;
          insecure = true;
          subtree_check = true;
          nohide = true;
          async = true;
        };
        exports = {
          root.subnets."*" = { };
          public = {
            hostPath = "/pool/var/public";
            subnets."*" = { };
          };
          "/pool/user-example".subnets."*".export.options = {
            anonuid = config.users.users.shared-user.uid;
            anongid = config.users.groups.users.gid;
          };
        };
      };
    };

  nodes = {
    client =
      { config, lib, ... }:
      {
        imports = modules ++ [
          self.nixosModules.fs-nfs-client
        ];
        ## issue with NixOS VM not setting `fileSystems` correctly for these mounts requires defining them here...
        virtualisation.fileSystems = lib.mapAttrs' (
          _: c:
          lib.nameValuePair c.hostPath {
            inherit (c) device options;
            fsType = "nfs";
          }
        ) (lib.filterAttrs (_: m: m.enable) config.provision.fs.nfs.client.mounts);

        users.users = {
          mylocaluser = {
            uid = 6000;
            isNormalUser = true;
          };
        };
        provision.fs.nfs.client = {
          enable = true;
          localBase = "/";
          remoteUrl = "server_stable";
          remoteBase = "/pool";
          ## stable
          mounts.public = {
            remotePath = "/public";
            networkOnlineService = "network-online.target";
          };
          # mount so `mylocaluser` can access the files locally
          mounts.user-example = {
            hostPath = "/user-example";
            # remotePath = "/pool/user-example"; # {remoteBase}/{hostPath}
            networkOnlineService = "network-online.target";
            requires = [ "firewall.service" ];
          };
          ## latest
          mounts.latest-public = {
            hostPath = "/latest-public";
            remoteUrl = "server_latest";
            remotePath = "/public";
            networkOnlineService = "network-online.target";
          };
          # mount so `mylocaluser` can access the files locally
          mounts.latest-user-example = {
            hostPath = "/latest-user-example";
            remoteUrl = "server_latest";
            remotePath = "/pool/user-example";
            networkOnlineService = "network-online.target";
            requires = [ "firewall.service" ];
          };
        };
      };

    server_stable = {
      imports = [ serverModule ];
    };
    server_latest =
      { lib, ... }:
      {
        imports = [ serverModule ];
        provision.fs.zfs.kernel.version = lib.mkForce "latest";
      };
  };

  nixos-lib = import (self.inputs.nixpkgs + "/nixos/lib") { };
  test = {
    name = "nfs-basic-zfs";
    hostPkgs = pkgs;
    inherit nodes;
    testScript = ''

      start_all()

      with subtest("Waiting for multi-user target"):
        client.wait_for_unit("network.target")
        client.wait_for_unit("default.target")
        server_stable.wait_for_unit("network.target")
        server_stable.wait_for_unit("default.target")
        server_latest.wait_for_unit("network.target")
        server_latest.wait_for_unit("default.target")

      with subtest("Setup permissions (stable)"):
        server_stable.succeed("chown -R shared-user:users /pool/var/public")
        server_stable.succeed("chown -R shared-user:users /pool/user-example")

      with subtest("testing public read access on existing file (stable)"):
        server_stable.succeed("sudo -u shared-user sh -c 'echo __EXISTING_FILE__ > /pool/var/public/existing'")
        server_stable.succeed("sudo -u shared-user sh -c 'cat /pool/var/public/existing | grep -e __EXISTING_FILE__'")
        client.succeed("sudo -u shared-user sh -c 'cat /public/existing | grep -e __EXISTING_FILE__'")

      with subtest("testing public create/write/read/delete access for new file from client (stable)"):
        client.succeed("sudo -u shared-user sh -c 'echo __SUCCESS_STRING__ > /public/newfile'")
        server_stable.succeed("cat /pool/var/public/newfile | grep -e __SUCCESS_STRING__")
        server_stable.succeed("cat /export/public/newfile | grep -e __SUCCESS_STRING__")
        client.succeed("sudo -u shared-user sh -c 'echo 'EDIT_SUCCESS' >> /public/newfile'")
        server_stable.succeed("cat /pool/var/public/newfile | grep -e EDIT_SUCCESS")
        server_stable.succeed("cat /export/public/newfile | grep -e EDIT_SUCCESS")
        client.succeed("sudo -u shared-user sh -c 'cat /public/newfile | grep -e EDIT_SUCCESS'")
        client.succeed("sudo -u shared-user sh -c 'rm /public/newfile'")
        client.fail("sudo -u shared-user sh -c 'test -f /public/newfile'")

      with subtest("testing user-example read access on existing file (stable)"):
        server_stable.succeed("sudo -u shared-user sh -c 'echo __EXISTING_FILE__ > /pool/user-example/existing'")
        client.succeed("sudo -u shared-user sh -c 'cat /user-example/existing | grep -e __EXISTING_FILE__'")

      with subtest("testing user-example create/write/read/delete access for new file from client (stable)"):
        client.succeed("sudo -u shared-user sh -c 'echo __SUCCESS_STRING__ > /user-example/newfile'")
        server_stable.succeed("cat /pool/user-example/newfile | grep -e __SUCCESS_STRING__")
        client.succeed("sudo -u shared-user sh -c 'echo 'EDIT_SUCCESS' >> /user-example/newfile'")
        server_stable.succeed("cat /pool/user-example/newfile | grep -e EDIT_SUCCESS")
        client.succeed("sudo -u shared-user sh -c 'cat /user-example/newfile | grep -e EDIT_SUCCESS'")
        client.succeed("sudo -u shared-user sh -c 'rm /user-example/newfile'")
        client.fail("sudo -u shared-user sh -c 'test -f /user-example/newfile'")

      with subtest("Setup permissions (latest)"):
        server_latest.succeed("chown -R shared-user:users /pool/var/public")
        server_latest.succeed("chown -R shared-user:users /pool/user-example")

      with subtest("testing public read access on existing file (latest)"):
        server_latest.succeed("sudo -u shared-user sh -c 'echo __EXISTING_FILE__ > /pool/var/public/existing'")
        server_latest.succeed("sudo -u shared-user sh -c 'cat /pool/var/public/existing | grep -e __EXISTING_FILE__'")
        client.succeed("sudo -u shared-user sh -c 'cat /latest-public/existing | grep -e __EXISTING_FILE__'")

      with subtest("testing public create/write/read/delete access for new file from client (latest)"):
        client.succeed("sudo -u shared-user sh -c 'echo __SUCCESS_STRING__ > /latest-public/newfile'")
        server_latest.succeed("cat /pool/var/public/newfile | grep -e __SUCCESS_STRING__")
        server_latest.succeed("cat /export/public/newfile | grep -e __SUCCESS_STRING__")
        client.succeed("sudo -u shared-user sh -c 'echo 'EDIT_SUCCESS' >> /latest-public/newfile'")
        server_latest.succeed("cat /pool/var/public/newfile | grep -e EDIT_SUCCESS")
        server_latest.succeed("cat /export/public/newfile | grep -e EDIT_SUCCESS")
        client.succeed("sudo -u shared-user sh -c 'cat /latest-public/newfile | grep -e EDIT_SUCCESS'")
        client.succeed("sudo -u shared-user sh -c 'rm /latest-public/newfile'")
        client.fail("sudo -u shared-user sh -c 'test -f /latest-public/newfile'")

      with subtest("testing user-example read access on existing file (latest)"):
        server_latest.succeed("sudo -u shared-user sh -c 'echo __EXISTING_FILE__ > /pool/user-example/existing'")
        client.succeed("sudo -u shared-user sh -c 'cat /latest-user-example/existing | grep -e __EXISTING_FILE__'")

      with subtest("testing user-example create/write/read/delete access for new file from client (latest)"):
        client.succeed("sudo -u shared-user sh -c 'echo __SUCCESS_STRING__ > /latest-user-example/newfile'")
        server_latest.succeed("cat /pool/user-example/newfile | grep -e __SUCCESS_STRING__")
        client.succeed("sudo -u shared-user sh -c 'echo 'EDIT_SUCCESS' >> /latest-user-example/newfile'")
        server_latest.succeed("cat /pool/user-example/newfile | grep -e EDIT_SUCCESS")
        client.succeed("sudo -u shared-user sh -c 'cat /latest-user-example/newfile | grep -e EDIT_SUCCESS'")
        client.succeed("sudo -u shared-user sh -c 'rm /latest-user-example/newfile'")
        client.fail("sudo -u shared-user sh -c 'test -f /latest-user-example/newfile'")
    '';
  };
in
nixos-lib.runTest test
