# logging wrapper around journalctl
def main [
  ...userArgs               # user extra args, args beginning with "-" must be quoted
  --machine(-m) : string    # optional machine parameter (-M jellyfin)
  --microvm(-M) : string    # optionally view microvm logs (-u microvm@jellyfin)
  --container(-c) : string  # optional systemd-nspawn container paramater (-u systemd-nspawn@jellyfin)
  --service(-u) : string    # optional service paramater (-u systemd-networkd)
  --user(-s)                # optional user paramater (--user)
  --follow(-f)              # optional follow paramater (-f)
  --raw                     # disable piping logs into lnav
  --reverse(-r)             # optional reverse parameter (-r)
  --debug(-d)               # print command before running
] {
  let args = ($userArgs
    | append (if ($machine != null) { [ "-M" $machine ] } else { [] })
    | append (if ($microvm != null) { [ "-u" $"microvm@($microvm)" ] } else { [] })
    | append (if ($container != null) { [ "-u" $"systemd-nspawn@($container)" ] } else { [] })
    | append (if ($service != null) { [ "-u" $service ] } else { [] })
    | append (if $user { [ "--user" ] } else { [] })
    | append (if $follow { [ "-f" ] } else { [] })
    | append (if $reverse { [ "-r" ] } else { [] })
    | flatten
  )
  print $"Running Command: (ansi yellow)journalctl ($args | str join ' ')(ansi reset)"
  if $raw {
    journalctl ...$args
  } else {
    journalctl -a ...$args | lnav
  }
}
