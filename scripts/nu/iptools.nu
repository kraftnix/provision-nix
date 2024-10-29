export module iptools {

  def maybeJson [
    doParse
  ]: [table -> table, table -> string] {
    if $doParse {
      $in | to json
    } else {
      $in
    }
  }

  # returns a table all ip rules (per ip version)
  export def rules [
    table: string # route table name
    --v6          # whether to lookup IPv6 routes, otherwise IPv4
    --json(-j)    # return json result
  ] {
    let ver = if $v6 { "-6" } else { "-4" }
    (if $table == all {
      ip $ver --json rule list
    } else {
      ip $ver --json rule list table $table
    }) | from json
       | maybeJson $json
  }

  # monitor ip rules
  export def monitor [
    --v6          # whether to lookup IPv6 routes, otherwise IPv4
    --json(-j)    # return json result
  ] {
    let ver = if $v6 { "-6" } else { "-4" }
    ip $ver monitor
      | lines
      | split column " " ip scope interface type mac info nul
      | reject nul
      | maybeJson $json
  }

  # neighbour
  export def neighbour [
    --v6          # whether to lookup IPv6 routes, otherwise IPv4
    --json(-j)    # return json result
  ] {
    let ver = if $v6 { "-6" } else { "-4" }
    ip $ver neighbour
      | lines
      | split column " " ip scope interface type mac info nul
      | reject nul
      | maybeJson $json
  }

  # routes        : view routes with filtering options
  # returns a table all ip routes (per ip version)
  export def routes [
    table: string # route table name
    --v6          # whether to lookup IPv6 routes, otherwise IPv4
    --json(-j)    # return json result
  ] {
    let ver = if $v6 { "-6" } else { "-4" }
    let routes = (ip $ver --json route list table $table | from json)
    if $table == all {
      $routes | default main table # null values represent main table
    } else {
      $routes | default $table table
    } | maybeJson $json
  }

  def tableNamesFromIpRoutes [] {
    get table | uniq
  }

  export def parseRtTableFile [ file ] {
    cat $file
      | lines
      | where {|i| not ($i | str starts-with "#") }
      | parse -r '(?P<id>\w+)\s(?P<table>[\w-]+)'
      | into int id
      | sort-by id
      | move table --before id
  }

  # tableMap      : view table -> id map
  # returns parsed list mapping of table (name) -> id
  export def tableMap [
    --json(-j) # return json result
  ] {
    let normalPath = '/etc/iproute2/rt_tables'
    let normalExists = ($normalPath | path exists)
    mut res = []
    if $normalExists {
      $res = (parseRtTableFile $normalPath)
    }
    let multiPath = '/etc/iproute2/rt_tables.d'
    if ($multiPath | path exists) {
      let extras = (ls $multiPath
        | get name
        | each {|conf|
          parseRtTableFile $conf
        } | flatten)
      if $normalExists {
        $res = ($res | append $extras)
      } else {
        $res = $extras
      }
    }
    $res | maybeJson $json
  }

  # leases dnsmasq: view leases in dnsmasq file
  export def "leases dnsmasq" [
    --json(-j) # return as json
  ] {
    let leases = (
      cat /var/lib/dnsmasq/dnsmasq.leases
      | lines
      | parse "{expires} {mac} {ip} {hostname} {clientid}"
    )
    $leases
      | insert expires_ts {|row|
        $row.expires
        | into int
        | $in * 1_000_000_000
        | into datetime
      }
  }

  # allRoutes     : show all available routes on system
  export def allRoutes [
    --json(-j) # return as json
  ] {
    ip --json route list table all 
      | from json 
      | maybeJson $json
  }

  # edit dnsmasq  : open dnsmasq file with editor
  export def "edit dnsmasq" [ dnsmasqFile ] {
    run-external $env.EDITOR $dnsmasqFile
    return
  }

  # IP Tools Utility
  # Supported Commands:
  # - allRoutes     : show all available routes on system
  # - edit dnsmasq  : open dnsmasq file with editor
  # - leases        : view leases
  # - routes        : view routes with filtering options
  # - tableMap      : view table -> id map
  export def main [ ] {
    print $'(ansi yellow)IP Tools Utility(ansi reset)'
    listCustomCommands "iptools"
  }

}

use iptools
