let filesizeCols = ($env | get -o zfs.filesizeCols | default [
  used
  usedbysnapshots
  usedbydataset
  usedbyrefreservation
  usedbychildren
  available
  referenced
])
let listCols = ($env | get -o zfs.listCols | default ([
  mountpoint
] | append $filesizeCols))

export module zft {

  def flattenList [ ] {
    mut list = $in
    let columns = $list | columns
    for col in $columns {
      # check if a value object
      if ($listCols | any {|el| $el == $col }) {
        $list = $list | update $col {|elem|
          # check if parseable as filesize
          # $elem | get value
          if ($filesizeCols | any {|el| $el == $col }) {
            let v = ($elem | get $col | get -o value | default "-")
            if $v == "-" { "0B" } else { $v } | into filesize
          } else {
            $elem | get $col |get value
          }
        }
      }
    }
    $list
  }

  export def --wrapped used [
    dataset? : string # dataset to list
    --snapshot(-s)    # list snapshots
    ...args
  ] {
    list $dataset --snapshot=$snapshot ...$args
      | select name used.value
      | rename dataset used
      | update used {into filesize}
  }

  # List datasets (optionally with snapshots)
  export def --wrapped list [
    dataset? : string # dataset to list
    --snapshot(-s)    # list snapshots
    --raw             # just print raw output of list
    --json(-j)        # return as json
    --noflat          # do not try to parse and flatten values
    ...args
  ] {
    let cmd = [
      zfs
      list
      (if $raw { [ ] } else { [ --json ] })
      (if $snapshot { [ -t snapshot ] } else { [ ] })
      ($dataset | default [ ])
      ...$args
    ] | flatten
    let out = run-external ...$cmd | complete
    if $out.exit_code != 0 {
      print -e $"(ansi red)Failed running zfs list command, exit code: ($out.exit_code)(ansi reset)"
      print "Stdout:" $out.stdout
      print $"(ansi red)Stderr:(ansi reset)"
      return $out.stderr
    }
    if $raw {
      let out = ($out | get -o stdout | default ($out | get -o stderr | default ""))
      if $json {
        return $out | to json
      }
      return $out
    }
    mut snapshots = ($out.stdout | from json | get datasets | transpose dataset info | get info | flatten | reject -o dataset snapshot_name)
    if not $noflat {
      $snapshots = $snapshots | flattenList
    }
    if $json {
      $snapshots = $snapshots | to json
    }
    $snapshots
  }

  # A ZFS wrapper tool for certain ZFS operations
  export def main [] {
    help zft
  }

}

export use zft
