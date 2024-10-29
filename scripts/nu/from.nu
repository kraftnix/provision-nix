export module from {
  def parseVirshRow [ ] {
    each { |row| $row | wrap removeThis | transpose }
  }
  def parseVirsh [ output ] {
    let parsed = ($output | lines | each { |it| ($it | split row "  " | str trim) } | where ($it | length) > 1)
    $parsed | parseVirshRow | flatten | headers | reject column removeThis
  }
  # usage: virsh vol-list default --details | from virsh | where Name =~ "arch"
  export def virsh [] {
    each { |it| parseVirsh $it } | flatten
  }
  export def zfs [] {
    let it = $in
    unwrapSpacedRows $it
  }
}
