self:
let
  pkgs = import self.inputs.nixpkgs {
    system = "x86_64-linux";
  };

  snakeoilPasswordFile = "${pkgs.writeText "snakeoil-password" "myuserpassword"}";

  serverIPv4 = "192.168.1.2"; # /24
  serverIPv6 = "2001:db8:1::2"; # /64

  modules = [
    {
      networking.firewall.enable = true;
      environment.systemPackages = [
        pkgs.samba
        pkgs.cifs-utils
      ];
    }
  ];

  nodes = {
    client =
      { config, lib, ... }:
      {
        imports = modules ++ [
          self.nixosModules.fs-samba-client
        ];
        ## issue with NixOS VM not setting `fileSystems` correctly for these mounts requires defining them here...
        virtualisation.fileSystems = lib.mapAttrs' (
          _: c:
          lib.nameValuePair c.hostPath {
            inherit (c) device options;
            fsType = "cifs";
          }
        ) (lib.filterAttrs (_: m: m.enable) config.provision.fs.samba.client.mounts);

        users.users = {
          mylocaluser = {
            uid = 6000;
            isNormalUser = true;
          };
        };
        provision.fs.samba.client = {
          enable = true;
          remoteUrl = "server";
          mounts.public = {
            hostPath = "/public";
            networkOnlineService = "network-online.target";
          };
          mounts.private = {
            hostPath = "/private";
            networkOnlineService = "network-online.target";
            requires = [ "firewall.service" ];
            user = "smb-generated-user";
            passwordFile = snakeoilPasswordFile;
          };
          # mount so `mylocaluser` can access the files locally
          mounts.user-example = {
            uid = "mylocaluser";
            gid = "users";
            user = "smb-generated-user";
            passwordFile = snakeoilPasswordFile;
            hostPath = "/user-example";
            networkOnlineService = "network-online.target";
          };
        };
      };
    server =
      { pkgs, ... }:
      {
        imports = modules ++ [
          self.nixosModules.networking-firewall
          self.nixosModules.fs-samba-server
        ];

        # Create ZFS pool for samba use
        virtualisation.emptyDiskImages = [ 100 ];
        networking.hostId = "deadbeef";
        boot.supportedFilesystems = [ "zfs" ];
        boot.initrd.kernelModules = [ "zfs" ];
        boot.initrd.postDeviceCommands = ''
          ${pkgs.zfs}/bin/zpool create -O acltype=posixacl -O xattr=sa -O compression=lz4 pool /dev/vdb
          ${pkgs.zfs}/bin/zfs set mountpoint=/pool pool
          ${pkgs.zfs}/bin/zfs create pool/public
          ${pkgs.zfs}/bin/zfs create pool/private
          ${pkgs.zfs}/bin/zfs create pool/user-example
          ${pkgs.zfs}/bin/zfs mount -r pool
        '';

        users.users.server-unix-user = {
          uid = 5454;
          isNormalUser = true;
        };

        provision.fs.samba.server = {
          enable = true;
          firewall.enable = true;
          logging.enable = true;
          logging.level = "3";
          interfaces = {
            localhost.subnet = "lo";
            # add local ethernet device in VM
            eth0.subnet = "eth0";
            eth1.subnet = "eth1";
          };
          global = {
            workgroup = "WORKGROUP";
            "bind interfaces only" = "yes";
            "server string" = "Samba %v on (%L)";
            "netbios name" = "SMBNIX";
            "security" = "user";
            #"use sendfile" = "yes";
            #"max protocol" = "smb2";
            # "guest account" = "smb-generated-user";
            # "map to guest" = "bad user";
          };
          default.opts = {
            browseable = true;
            read.only = false;
            guest.ok = false;
            create.mask = "0644";
            directory.mask = "0755";
            hosts.allow = [
              "10.0.2." # IPv4 of eth0
              "127.0.0.1"
              "localhost"
              "2001:db8:1::" # IPv6 of eth1
            ];
            hosts.deny = [ "0.0.0.0/0" ];
          };
          shares = {
            public = {
              path = "/pool/public";
              guest.ok = true;
              force.user = "smb-public";
              force.group = "users";
            };
            private = {
              path = "/pool/private";
              force.user = "smb-public";
              force.group = "users";
              valid.users = [ "smb-generated-user" ];
            };
            user-example = {
              path = "/pool/user-example";
              # hosts.allow = [ "127.0.0.1" "localhost" ];
              force.user = "server-unix-user";
              force.group = "users";
              valid.users = [ "smb-generated-user" ];
            };
          };
          users = {
            # create a simple user (but dont assign password using provisionSamba)
            smb-public = {
              uid = 7991; # only required if user doesn't already exist in `users.users`
              configureUser = true; # only required if user doesn't already exist in `users.users`
              group.name = "users"; # optional
            };
            # create a specific user only for use with samba, and provision its password with a file containing a password
            smb-generated-user = {
              uid = 8911; # only required if user doesn't already exist in `users.users`
              configureUser = true; # only required if user doesn't already exist in `users.users`
              provisionSamba = true;
              group.name = "users"; # optional
              sambaPasswordFile = snakeoilPasswordFile;
            };
          };
        };
      };
  };

  nixos-lib = import (self.inputs.nixpkgs + "/nixos/lib") { };
  test = {
    name = "samba-basic";
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
        server.succeed("chown -R smb-public:users /pool/public")
        server.succeed("chown -R smb-public:users /pool/private")
        server.succeed("chown -R server-unix-user:users /pool/user-example")

      with subtest("testing public read access on existing file"):
        server.succeed("sudo -u smb-public sh -c 'echo __EXISTING_FILE__ > /pool/public/existing'")
        client.succeed("cat /public/existing | grep -e __EXISTING_FILE__")

      with subtest("testing public create/write/read/delete access for new file from client"):
        client.succeed("echo __SUCCESS_STRING__ > /public/newfile")
        server.succeed("cat /pool/public/newfile | grep -e __SUCCESS_STRING__")
        client.succeed("echo 'EDIT_SUCCESS' >> /public/newfile")
        server.succeed("cat /pool/public/newfile | grep -e EDIT_SUCCESS")
        client.succeed("cat /public/newfile | grep -e EDIT_SUCCESS")
        client.succeed("rm /public/newfile")
        client.fail("test -f /public/newfile")

      with subtest("testing private read access on existing file"):
        server.succeed("sudo -u smb-public sh -c 'echo __EXISTING_FILE__ > /pool/private/existing_private'")
        client.succeed("cat /private/existing_private | grep -e __EXISTING_FILE__")

      with subtest("testing private create/write/read/delete access for new file from client"):
        client.succeed("echo __SUCCESS_STRING__ > /private/newfile-private")
        server.succeed("cat /pool/private/newfile-private | grep -e __SUCCESS_STRING__")
        client.succeed("echo 'EDIT_SUCCESS' >> /private/newfile-private")
        server.succeed("cat /pool/private/newfile-private | grep -e EDIT_SUCCESS")
        client.succeed("cat /private/newfile-private | grep -e EDIT_SUCCESS")
        client.succeed("rm /private/newfile-private")
        client.fail("test -f /private/newfile-private")

      with subtest("testing user-example read access on existing file"):
        server.succeed("sudo -u server-unix-user sh -c 'echo __EXISTING_FILE__ > /pool/user-example/existing_user'")
        client.succeed("cat /user-example/existing_user | grep -e __EXISTING_FILE__")

      with subtest("testing user-example create/write/read/delete access for new file from client"):
        client.succeed("sudo -u mylocaluser sh -c 'echo __SUCCESS_STRING__ > /user-example/newfile-user'")
        server.succeed("cat /pool/user-example/newfile-user | grep -e __SUCCESS_STRING__")
        client.succeed("sudo -u mylocaluser sh -c 'echo EDIT_SUCCESS > /user-example/newfile-user'")
        server.succeed("cat /pool/user-example/newfile-user | grep -e EDIT_SUCCESS")
        client.succeed("cat /user-example/newfile-user | grep -e EDIT_SUCCESS")
        client.succeed("sudo -u mylocaluser sh -c 'rm /user-example/newfile-user'")
        client.fail("test -f /user-example/newfile-user")
    '';
  };
in
nixos-lib.runTest test
