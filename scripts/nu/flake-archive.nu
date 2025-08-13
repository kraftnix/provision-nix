# given a `nix flake archive --json | from json`, returns all input source paths
def getAllPaths [ attrs ] {
  let path = ($attrs | get -o path)
  let paths = (
    if $path != null {
      [$path]
    } else {
      []
    }
  )
  let inputs = ($attrs | get -o inputs)
  if $inputs != null {
    $inputs
    | transpose input cfg
    | each { |i|
      getAllPaths $i.cfg
    }
    | append $paths
    | flatten --all
  } else {
    return $paths
  }
}

# archives flake and returns path (optionally nix copy to target)
def flake-archive [
  flakeUri : path = "."         # path to flake to archive
  --nixCopyUrl(-f): string = "" # nix copy url, like `ssh-ng://myuser@192.168.1.1`
  --noCheckSigs(-n)             # optionally add `--no-check-sigs` option
] {
  print $"Archiving flake at ($flakeUri)"
  let archive = (nix flake archive --json $flakeUri | from json)
  print $"Fetching all paths..."
  let paths = (getAllPaths $archive)
  print $"Found ($paths | length) paths"
  if $nixCopyUrl != "" {
    print $"(ansi yellow)Copying ($paths | length) paths to ($nixCopyUrl)(ansi reset)"
    if $noCheckSigs {
      print "(ansi red)Ignoring Sigs(ansi reset)"
      $paths | str join "\n" | nix copy --to $nixCopyUrl --stdin --no-check-sigs
    } else {
      $paths | str join "\n" | nix copy --to $nixCopyUrl --stdin
    }
  }
  return $paths
}
