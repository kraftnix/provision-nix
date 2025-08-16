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
          remoteUrl = "server";
          remoteBase = "/pool";
          mounts.public = {
            hostPath = "/public";
            networkOnlineService = "network-online.target";
          };
          # mount so `mylocaluser` can access the files locally
          mounts.user-example = {
            hostPath = "/user-example";
            networkOnlineService = "network-online.target";
            requires = [ "firewall.service" ];
          };
        };
      };
    server =
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
        ];

        # Create ZFS pool for nfs use
        virtualisation.emptyDiskImages = [ 100 ];
        networking.hostId = "deadbeef";
        boot.supportedFilesystems = [ "zfs" ];
        boot.initrd.kernelModules = [ "zfs" ];
        boot.initrd.postDeviceCommands = ''
          ${pkgs.zfs}/bin/zpool create -O acltype=posixacl -O xattr=sa -O compression=lz4 pool /dev/vdb
          ${pkgs.zfs}/bin/zfs set mountpoint=/pool pool
          ${pkgs.zfs}/bin/zfs create pool/public
          ${pkgs.zfs}/bin/zfs create pool/user-example
          ${pkgs.zfs}/bin/zfs mount -r pool
        '';

        ## issue with NixOS VM not setting `fileSystems` correctly for these mounts requires defining them here...
        virtualisation.fileSystems = lib.pipe config.provision.fs.nfs.server.exports [
          (lib.filterAttrs (_: e: e.enable && e.addToFilesystem))
          (lib.mapAttrs' (
            _: e:
            lib.nameValuePair e.exportPath {
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
          default.export.options = {
            rw = true;
            insecure = true;
            subtree_check = true;
            nohide = true;
            async = true;
          };
          exports = {
            "/" = {
              exportPath = "/export";
              # addToFilesystem = false;
              export.options.fsid = 0;
              subnets."*" = { };
            };
            "/pool" = {
              hostPath = "/pool";
              subnets."*" = { };
            };
            "/pool/public" = {
              hostPath = "/pool/public";
              subnets."*" = { };
            };
            "/pool/user-example" = {
              hostPath = "/pool/user-example";
              subnets."*".export.options = {
                anonuid = config.users.users.shared-user.uid;
                anongid = config.users.groups.users.gid;
              };
            };
          };
        };
      };
  };

  nixos-lib = import (self.inputs.nixpkgs + "/nixos/lib") { };
  test = {
    name = "nfs-basic";
    hostPkgs = pkgs;
    inherit nodes;
    testScript = ''

      start_all()

      with subtest("Waiting for multi-user target"):
        client.wait_for_unit("network.target")
        client.wait_for_unit("default.target")
        server.wait_for_unit("network.target")
        server.wait_for_unit("default.target")

      with subtest("Setup permissions"):
        server.succeed("chown -R shared-user:users /pool/public")
        server.succeed("chown -R shared-user:users /pool/user-example")

      with subtest("testing public read access on existing file"):
        server.succeed("sudo -u shared-user sh -c 'echo __EXISTING_FILE__ > /pool/public/existing'")
        client.succeed("sudo -u shared-user sh -c 'cat /public/existing | grep -e __EXISTING_FILE__'")

      with subtest("testing public create/write/read/delete access for new file from client"):
        client.succeed("sudo -u shared-user sh -c 'echo __SUCCESS_STRING__ > /public/newfile'")
        server.succeed("cat /pool/public/newfile | grep -e __SUCCESS_STRING__")
        client.succeed("sudo -u shared-user sh -c 'echo 'EDIT_SUCCESS' >> /public/newfile'")
        server.succeed("cat /pool/public/newfile | grep -e EDIT_SUCCESS")
        client.succeed("sudo -u shared-user sh -c 'cat /public/newfile | grep -e EDIT_SUCCESS'")
        client.succeed("sudo -u shared-user sh -c 'rm /public/newfile'")
        client.fail("sudo -u shared-user sh -c 'test -f /public/newfile'")

      with subtest("testing user-example read access on existing file"):
        server.succeed("sudo -u shared-user sh -c 'echo __EXISTING_FILE__ > /pool/user-example/existing'")
        client.succeed("sudo -u shared-user sh -c 'cat /user-example/existing | grep -e __EXISTING_FILE__'")

      with subtest("testing user-example create/write/read/delete access for new file from client"):
        client.succeed("sudo -u shared-user sh -c 'echo __SUCCESS_STRING__ > /user-example/newfile'")
        server.succeed("cat /pool/user-example/newfile | grep -e __SUCCESS_STRING__")
        client.succeed("sudo -u shared-user sh -c 'echo 'EDIT_SUCCESS' >> /user-example/newfile'")
        server.succeed("cat /pool/user-example/newfile | grep -e EDIT_SUCCESS")
        client.succeed("sudo -u shared-user sh -c 'cat /user-example/newfile | grep -e EDIT_SUCCESS'")
        client.succeed("sudo -u shared-user sh -c 'rm /user-example/newfile'")
        client.fail("sudo -u shared-user sh -c 'test -f /user-example/newfile'")
    '';
  };
in
nixos-lib.runTest test
