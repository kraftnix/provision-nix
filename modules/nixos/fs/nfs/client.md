# NFS Client

This client can be used to mount exports from a NFS Server.

This module generates an entry in `fileSystems` for each mount here.

Configuration options are provided to aid:
  - mounting remote exports
  - mount ordering (after/before/requires/requiredBy) of related systemd services

## Example Configuration

The below configuration shows a number of ways to configure a samba mount.

```nix
provision.fs.nfs.client = {
  enable = true;
  # a shared export endpoint is expected from the server
  exportDir = "/export";
  # you can set a local shared directory to be set mount defaults, i.e. `media` mount would be mounted at `/{localBase}/media`
  localBase = "/mnt";
  # can be a hostname, fqdn or IP address
  remoteUrl = "10.89.1.7";
  # you can set a remote shared directory to be set mount defaults, i.e. `media` mount would be mounted at `/{remoteBase}/media`
  remoteBase = "zpool";
  # mount a public share, automatically assumed to be public if `user` is not set
  mounts.public = {
    # default from above `localBase` and this mount `name` generates the below config
    hostPath = "/mnt/public";
    remoteUrl = "10.89.1.7";
    remotePath = "/export/public";

    # you change the default network online service 
    networkOnlineService = "network-online.target";
    # added to mount unit as an `after` entry of targets/services
    before = [ "jellyfin.service" ];
    requiredBy = [ "jellyfin.service" ];
  };
};
```

## Mount Commands

Mount
```sh
mount.nfs myserv:/public /mnt/public
```
