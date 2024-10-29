module dest {

  # runs requests to specified domains, by default only to your default gateway/interface
  # you can provide interfaces to test as a space-separated list in your ENV
  #   `export INTERFACES= "default enp2s0 wlan0"`
  # or in nushell
  #   `$env.interfaces = "default enp2s0 wlan0"`
  export def main [
    --timeout(-t): string = "5" # timeout for each request
  ] {
    let interfaces = ($env
      | get -i INTERFACES
      | default "default"
      | split row " "
    )
    let res = ($interfaces | par-each { |name|
      let args = (
        if $name != default {
          echo "--interface" $name
        } else { null }
      )
      try {
        sh -c (echo curl https://ifconfig.co/json "-s" $args "--connect-timeout 5" | flatten | str join " ")
         | from json | merge { name: $name } | move name --before ip
      } catch {
        { name: $name, ip: null }
      }
    } | flatten)
    let defaultIP = ($res | where name == default | get 0.ip)
    let outbound = ($res | where ip != null | where ip == $defaultIP | where name != default)
    mut outboundStr = $"(ansi red)No outbound.(ansi reset)"
    mut country = $"(ansi red)No outbound.(ansi reset)"
    if ($outbound | length) > 0 {
      $outboundStr = ($outbound | get name.0)
      $country = ($outbound | get country.0)
    }
    print $"(ansi yellow)Default IP: (ansi red)($defaultIP)(ansi reset)"
    print $"(ansi yellow)Outbound Interface: (ansi red)($outboundStr)(ansi reset)"
    print $"(ansi yellow)Country: (ansi red)($country)(ansi reset)"
    $res
  }
}

use dest
