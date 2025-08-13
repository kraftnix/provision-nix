# Samba Client

This client can be used to mount shares from a Samba Server.

This module generates an entry in `fileSystems` for each mount here.

Configuration options are provided to aid:
  - mounting remote share with specific local user/group (uid/gid)
  - mount ordering (after/before/requires/requiredBy) of related systemd services
  - samba credential file location (`credentials=` compatible file path)
  - samba password file location (generated a `credentials` compatible file path containing `password=<password-file>`)

## Example Configuration

The below configuration shows a number of ways to configure a samba mount.

```nix
users.users.mylocaluser = {
  uid = 6000;
  isNormalUser = true;
};
provision.fs.samba.client = {
  enable = true;
  remoteUrl = "10.89.1.7";
  # mount a public share, automatically assumed to be public if `user` is not set
  mounts.public = {
    hostPath = "/public";
    # added to mount unit as an `after` entry of targets/services
    networkOnlineService = "network-online.target";
  };
  mounts.private = {
    hostPath = "/private";
    networkOnlineService = "network-online.target";
    # you can also add your own requires/requiredBy/after/before entries for each mount
    requires = [ "firewall.service" ];
    # use this samba user for login to the samba server
    user = "smb-generated-user";
    # you can specify a samba credentials file that must be a valid file for the CIFS `credentials` mount option
    credentialsFile = "/root/smb-generated-user-creds";
  };
  mounts.user-example = {
    hostPath = "/user-example";
    networkOnlineService = "network-online.target";
    # you can specify a local uid/user and gid/group to force local user permissions
    uid = "mylocaluser";
    gid = "users";
    user = "smb-generated-user";
    passwordFile = snakeoilPasswordFile;
    # it can be useful to use this with agenix/sops-nix
    # passwordFile = config.age.secrets.smb-generated-user-password.path;
  };
};
```

## Mount Commands

Mount as guest
```sh
mount.cifs //myserv/public /mnt/public -o guest
```

Mount as authenticated user (inline credentials)
```sh
mount.cifs //myserv/private /mnt/private -o user=smb-user,password=mysambapassword
```

Mount as authenticated user (credentials files)
```sh
mount.cifs //myserv/private /mnt/private -o credentials=/root/samba-creds
```

Mount as with local user permissions
```sh
mount.cifs //myserv/media /mnt/media -o credentials=/root/media-creds,uid=1000,gid=100
# you can also just use user/group names
mount.cifs //myserv/media /mnt/media -o credentials=/root/media-creds,uid=myuser,gid=users
```

## Troubleshooting

- errors often appear in `dmesg`
- `mount` with `-vvv` can also give extra information
- permission issues
    - often stem from combination of server-side `user force` and `group force` not aligning with actual files on disk
    - can also be related to local unix user perms, can often be avoided by setting `uid=x,gid=y`
