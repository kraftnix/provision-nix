# source provision-helper.nu

use std

# use `jc` to transform many things into native nu
export module misc {

  export def dig [
    ...host
    --server(-s): string = ""
    --json(-j)
  ] {
    if $server != "" {
      dig $"@($server)" ...$host | jc --dig | from json
    } else {
      dig ...$host | jc --dig | from json
    } | maybeJson $json
  }

  export def acpi [ --json(-j) ] { ^acpi --everything | jc --acpi | from json | maybeJson $json }
  export def xrandr [ --json(-j) ] { generic xrandr | maybeJson $json }
  export def bluetooth [...args --json(-j) ] { generic bluetoothctl ...$args | maybeJson $json }

  export def groups [ --json(-j) ] { cat /etc/group | jc --group | from json | maybeJson $json }
  export def users [ --json(-j) ] { cat /etc/passwd | jc --passwd | from json | maybeJson $json }
  export def lspci [ --json(-j) ] { ^lspci -mmv | jc --lspci | from json | explore | maybeJson $json }
  export def hosts [ --json(-j) ] { cat /etc/hosts | jc --hosts | from json | maybeJson $json }
  export def ss [ --json(-j) ] { generic ss | maybeJson $json }
  export def uptime [ --json(-j) ] { generic uptime | maybeJson $json }
  export def datetime [ --json(-j) ] { generic timedatectl status | maybeJson $json }
  export def "git log" [ --json(-j) ] { generic git log | maybeJson $json }
  export def finger [ --json(-j) ] { generic finger | maybeJson $json }
  export def lusb [ --verbose(-v) --json(-j) ] {
    if not $verbose {
      generic lusb | maybeJson $json
    } else {
      lsusb -vv | jc --lsusb | from json | maybeJson $json
    }
  }
  export def ifconfig [ --json(-j) ] { generic ifconfig | maybeJson $json }
  export def id [ --json(-j) ] { generic id | maybeJson $json }
  export def ethtool [ eth --json(-j) ] { generic ethtool $eth | maybeJson $json }
  export def eths [ eth --json(-j) ] {
    ifconfig
      | jc --ifconfig
      | from json
      | select name type
      | where type == Ethernet
      | get name
      | each {|| sudo ethtool $in | jc --ethtool | from json}
      | maybeJson $json
  }

  export def dmidecode [ --json(-j) ] { generic dmidecode | maybeJson $json }
  export def pidstat [ --json(-j) ] { jc --pretty pidstat -h | from json | maybeJson $json }
  export def iostat [ --json(-j) ] { generic iostat | maybeJson $json }

  export def systemctl [ --json(-j) ] { generic systemctl | maybeJson $json }
  export def "systemctl jobs" [ --json(-j) ] { generic systemctl list-jobs | maybeJson $json }
  export def "systemctl sockets" [ --json(-j) ] { generic systemctl list-sockets | maybeJson $json }
  export def "systemctl units files" [ --json(-j) ] { generic systemctl list-unit-files | maybeJson $json }

  # generic wrapper around `jc`
  export def generic [
    command     # generic jc wrppare
    --json(-j)  # to json
    ...args     # args to pass in
  ] {
    jc --pretty $command ...$args | from json | maybeJson $json
  }

  # returns the nix store path given a binary command to look up
  export def nixlink [
    cmd         # binary to look up
  ] {
    if (binaryMissing $cmd) {
      return $'No binary found for `($cmd)`'
    }
    readlink -f (^which $cmd)
  }

  # checks if binary exists for
  export def binaryMissing [ cmd ] {
    ^which $cmd o+e>| str contains $": no ($cmd) in \("
  }

  # dumps information on an otf font, by default into a nushell explore
  export def inspect-otf-font [
    otfFile     # opentype file (.otf)
    --json(-j)  # to json
  ] {
    if (binaryMissing "otfccdump") {
      return $'No binary found for `otfccdump`, use `nix shell nixpkgs#otfcc`'
    }
    let otf = (otfccdump $otfFile)
    if $json { $otf } else { $otf | from json | explore }
  }

  export def main [] {
    listCustomCommands "misc"
  }

}

export use misc
