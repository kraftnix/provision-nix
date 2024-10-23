# start / stop arion services
export module myarion {

  export def services [] {
    systemctl | lines | where $it =~ arion | split row " " | where $it =~ arion | every 2
  }

  export def "services stop" [] {
    $in | par-each { |it| systemctl stop $it }
  }

  export def "services start" [] {
    $in | par-each { |it| systemctl start $it }
  }

#def status [] {
#  $in | par-each { |it| systemctl status $it --no-pager }
#}

  def kvSplit [] {
    let str = $in
    let key = ($str | split chars | take until {|it| $it == "="} | str join "")
    let value = ($str | split chars | skip until {|it| $it == "="} | skip | str join "")
    { key: $key, value: $value }
  }

  export def status [ status? ] {
#def status [ ] {
    #let status = $in
    (if $status != null { systemctl show $status } else { systemctl show })
      | from tsv -n | get column1 | each { kvSplit }
  }

  export def statusS [] {
    $in | each { |it|
      let name = $it;
      echo $name;
      (status $name | wrap $name)
    } | flatten
  }

  export def statas [] {
    $in | systemctl show | from tsv -n | get column1 | split column "="
  }

  export def "containers prune" [] {
    podman container prune
  }

  export def "containers restartAll" [] {
    let services = (services)
    $services | (services stop)
    containers prune
    systemctl restart podman
    $services | (services start)
  }

  # commands
  export def main [] {
    listCustomCommands "myarion"
  }

}

export use myarion
