# source provision-helper.nu
use std

export module mynft {

  def getCol [ name ] {
    select $name -o | get $name | where {|| $in != null}
  }

  export def "list" [
    type? : string = "ruleset" # type to list, can be counters, maps
    --json(-j)                 # return as json
  ] {
    sudo nft -j -a list $type | from json | get nftables | maybeJson $json
  }

  export def "parse rules" [
    which = "all"
    --short(-s) = false
  ] {
    let nftables = (nft get rules)
    if $which == all {
      return $nftables
    }
    let selection = ($nftables | getCol $which)
    if $which == rule {
      let rules = ($selection | update expr {|rule|
        $rule | get expr | reduce -f {} {|expr, acc|
          let r = ($expr | transpose name value | get 0)
          $acc | upsert $r.name {|row|
            let existing = ($row | get -o $r.name | default [])
            echo $existing $r.value | flatten
          }
        }
      })
      return ($rules | shorten $short)
    } else {
      return $selection
    }
  }

  export def shorten [ doShorten ] {
    let rules = $in
    if $doShorten {
      $rules | select family table chain handle comment -o
    } else {
      mut some = ($rules | default "" expr | default "" comment | move expr --before comment)
      if ($some | all {|| $in.expr == ""}) {
        $some = ($some | reject expr)
      }
      if ($some | all {|| $in.comment == ""}) {
        $some = ($some | reject comment)
      }
      $some
    }
  }

  def filterAll [
    key : string
    filter : string = "all"
  ] {
    let vals = $in
    if $filter == "all" {
      return $vals
    } else {
      return ($vals | where {|el| ($el | get $key) == $filter})
    }
  }

  export def getCmd [ cmd ] {
    { rules: rule,
      counters: counter,
      maps: map,
    } | get $cmd -o | default "all"
  }

  export def getExpr [
    family : string
    table : string
    chain : string
    handle : int
  ] {
    sudo nft -a list chain $family $table $chain
      | grep $"handle ($handle)"
      | str trim
      | split row " "
      | take until {|x| $x == comment }
      | str join " "
  }

  # Nftables helper / wrapper tool
  #
  # Example Usage:
  # `main rule`         # lists the rules in the filter table
  # `main table`        # lists the rules in the filter table
  export def main [
    cmd : string                # module to list (rules, counters, maps)
    table?:  string = "all"     # table to filter results to
    --short(-s)                 # don't show (elem), useful for summary
    --chain(-c): string = "all" # filter by chain
    --explore(-e)               # open results in nushell explore mode
  ] {
    let ruleset = (
      sudo nft --json -a list ruleset
      | from json
      | get nftables
    )
    let rulesets = (if $cmd == "all" {
      $ruleset
    } else {
      $ruleset | get $cmd -o
    })
    let results = ($rulesets
      | compact
      | filterAll table $table
      | filterAll chain $chain
      | each { |row|
        if ($row | get -o expr) != null {
          $row | update expr {|i| getExpr $i.family $i.table $i.chain $i.handle }
        } else {
          $row
        }
      }
      | shorten $short
    )
    if $explore {
      $results | explore
    } else {
      $results
    }
  }

  # Nftables helper / wrapper tool
  #
  # Example Usage:
  # `main rules filter`         # lists the rules in the filter table
  # `main list  filter`         # lists the rules in the filter table
  export def oldmain [
    cmd : string                # module to list (rules, counters, maps)
    table?:  string = "all"     # table to filter results to
    --short(-s)                 # don't show (elem), useful for summary
    --chain(-c): string = "all" # filter by chain
    --new
  ] {
    let cmdFilter = (getCmd $cmd)
    if $new {
      newmain $cmd $table --short $short --chain $chain
    } else {
      let res = (
        if ($cmd == "rules") {
          parseNft $cmdFilter --short $short
        # } else if ($cmd == "map" or $cmd == "counter") {
        } else {
          get rules $cmdFilter | getCol $cmdFilter
          # error make {msg: $"(ansi red)Unknown command `($cmd)` ran(ansi reset)"}
        }
      )
      $res | filterAll table $table | filterAll chain $chain
    }
  }

}

export use mynft
