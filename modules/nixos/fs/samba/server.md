# Samba Server

Samba is a free software re-implementation of the SMB networking protocol.

This integration provides a wrapper around the upstream nixpkgs module to create and manage
a Samba server declaratively, providing some easy to configure features such as:
    - define default options to set on all shares
    - define shares declaratively
    - configure and provision users with samba credentials
    - integration to emulate use of `openFirewall` options in upstream nixpkgs module, but on a per interface + source IP basis

## Example Configurations

Samba Module Options [Reference](../../../options/nixos-samba-options.md)

### Basic Public Share

This shows a simple Samba server with a single public share.

```nix
provision.fs.samba.server = {
  enable = true;
  firewall.enable = true; # open firewall for interfaces defined in `interfaces1
  interfaces = {
    localhost.subnet = "lo";
    eth0.subnet = "eth0"; # add external ethernet devices
  };
  global = {
    workgroup = "WORKGROUP";
    "bind interfaces only" = "yes";
    "server string" = "Samba %v on (%L)";
    "netbios name" = "SMBNIX";
    "security" = "user";
  };
  shares.public = {
    path = "/pool/public";
    browseable = true;
    read.only = false;
    guest.ok = true;
    create.mask = "0644";
    directory.mask = "0755";
    # force user permissions to a user we create inline below, you can set your own existing user in `users.users` instead
    force.user = "smb-public";
    force.group = "users";
  };
  # you can optionally generate a user in `users.users` inline here
  users.smb-public = {
    uid = 7991; # only required if user doesn't already exist in `users.users`
    configureUser = true; # only required if user doesn't already exist in `users.users`
    group.name = "users"; # optional
  };
};
```

You can then connect to the server by running
```sh
# on samba server
nix shell nixpkgs#cifs-utils
mount.cifs //localhost/public /mnt -o guest

# optionally force the local user/group to a local user on the guest mount
mount.cifs //localhost/public /mnt -o guest,uid=1000,gid=100
# or with username/group
mount.cifs //localhost/public /mnt -o guest,uid=myuser,gid=users

# on another machine accessible via network on eth0
mount.cifs //<samba-ip>/public /mnt -o guest
```

### User Authentication + Generated Passwords

You can also configure samba users, and their access to files.

You can also optionally provision samba users automatically by setting `provisionSamba` to true and `sambaPasswordFile` to a location
that is readable on the host (like `/root/samba-password`) or provisioned by a secrets management framework
like agenix and setting the value to `config.agenix.secrets.samba-password.path`.

If you don't use this option, then you will need to create your own samba users for users in `valid.users` with:
```sh
# on the samba server
smbpasswd -a smb-user
```

Example Configuration

```nix
users.users.media = {
  uid = 2000;
  group = "media";
};
users.grousp.media.gid = 2000;
provision.fs.samba.server = {
  enable = true;
  firewall.enable = true; # open firewall for interfaces defined in `interfaces1
  interfaces = {
    localhost.subnet = "lo";
    eth0.subnet = "eth0"; # add external ethernet devices
  };

  global = {
    workgroup = "WORKGROUP";
    "bind interfaces only" = "yes";
    "server string" = "Samba %v on (%L)";
    "netbios name" = "SMBNIX";
    "security" = "user";
  };

  shares.media = {
    path = "/media";
    browseable = true;
    read.only = false;
    create.mask = "0644";
    directory.mask = "0755";
    # force user permissions to a user we create inline below, you can set your own existing user in `users.users` instead
    force.user = "media";
    force.group = "media";
    valid.users = [ "smb-media" ];
  };

  users.smb-media = {
    uid = 7991; # only required if user doesn't already exist in `users.users`
    configureUser = true; # only required if user doesn't already exist in `users.users`
    group.name = "users"; # optional
    # choose to automatically provision samba
    provisionSamba = true;
    sambaPasswordFile = "/root/smb-media-password";
  };
};
```

You can then connect to the server by running
```sh
# on samba server
nix shell nixpkgs#cifs-utils
mount.cifs //localhost/media /mnt -o user=media,password=mypassword
```

### Define Shared Options

This is configuration equivalent with the above [Basic Public Share](#Basic-Public-Share) configuration

```nix
provision.fs.samba.server = {
  enable = true;
  firewall.enable = true; # open firewall for interfaces defined in `interfaces1
  interfaces = {
    localhost.subnet = "lo";
    eth0.subnet = "eth0"; # add external ethernet devices
  };

  global = {
    workgroup = "WORKGROUP";
    "bind interfaces only" = "yes";
    "server string" = "Samba %v on (%L)";
    "netbios name" = "SMBNIX";
    "security" = "user";
  };

  default.opts = {
    browseable = true;
    read.only = false;
    guest.ok = true;
    create.mask = "0644";
    directory.mask = "0755";
    # force user permissions to a user we create inline below, you can set your own existing user in `users.users` instead
    force.user = "smb-public";
    force.group = "users";
    hosts.allow = [ "127.0.0.1" "localhost" ];
  };

  shares.public.path = "/pool/public";
  # optionally override the default options from `default.opts`
  shares.public.force.user = "media";
  shares.public.force.group = "media";
  # NOTE: changing array values like `hosts.allow` doesn't merge the lists, but overrides
  shares.public.hosts.allow = [ "10.98.1.0/24" ]; # this would not allow localhost access from the samba server itself

  # you can optionally generate a user in `users.users` inline here
  users.smb-public = {
    uid = 7991; # only required if user doesn't already exist in `users.users`
    configureUser = true; # only required if user doesn't already exist in `users.users`
    group.name = "users"; # optional
  };
};
```

### Samba with Wireguard

I had some issues getting the Samba daemons to listen on wireguard interfaces when using the global `bind interfaces only = yes` setting.

Apparently this is due to Wireguard not supporting broadcast and not automatically listening on these interfaces.

You can get around this issue without setting `bind interfaces only = no` (so listening on all interfaces) by setting the global `interfaces`
to include the subnet of your wireguard network, I tend to use the exact wireguard IP for the samba server like `10.8.0.7/24` and it works
well.

A shorthand is provided via the `interfaces.<interface-name>.subnet` configuration which sets these values for you.

```nix
provision.fs.samba.server = {
  enable = true;
  firewall.enable = true; # open firewall for interfaces defined in `interfaces1
  interfaces = {
    localhost.subnet = "lo";
    eth0.subnet = "eth0"; # add external ethernet devices
    # use the exact wireguard interface name and set the subnet to the samba server's wireguard IP (with mask)
    vpn.subnet = "10.8.0.7/24";
  };
  default.opts = {
    # allow VPN subnet by default to shares
    hosts.allow = [ "10.8.0.0/24" "127.0.0.1" "localhost" ];
    # you can also whitelist specific IPs only if you wish
    # hosts.allow = [ "10.8.0.91" "10.8.0.103" "127.0.0.1" "localhost" ];
  };
};
```

### Test Configuration

The server + client integrations are tested in [`tests/samba/basic.nix`]({{git_file_base_url}}tests/samba/basic.nix)..

## Troubleshooting

The below is a miscellaneous list of tools you can use to debug issues, or comments on configurations:

- Use `testparm` on the Samba server to show config warnings.
- `smbclient -L localhost --user=smb-user` to list shares
- `smbstatus` to list current active connections
- **WARNING:** setting guest account to an existing user can create numerous weird permission issues that are hard to debug
