# NFS

NFS (Network File System) is a distribute filesystem protocol to access directories and files over a network.

An integration is provided for both running NFS servers and connecting to NFS servers from clients:
- [Server](./server.md)
- [Client](./client.md)

## NFS and UIDs

In general, it is somewhat difficult to use NFS without keeping `uid`s and `gid`s synced between clients and the server.

It is possible for the server to squash all `uid`s and `gid`s with `anonuid` and `anongid`, but these ids must still be valid
ids on your clients for any user other than root to be able to access them.

> It is possible to set up bind mounts on clients, that bind the NFS client mount location to a new location with
> a new `uid` and `gid`, but this is quite _hacky_. It's why I've mostly moved to Samba for network shares where I cannot keep
> uids consistent between servers and clients.
