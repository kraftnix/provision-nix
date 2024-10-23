# adapter from comment in: https://github.com/nushell/nushell/issues/9051

# source provision-helper.nu

def main [...args] {
  ^ip link
    | str trim
    | lines
    | group 2
    | each {|it|
      # print ($it.0 | parse --regex '\d: (?<interface>.*): <(?<flags>.*)> (?<rest>.*)' | update rest { |i| $i | keyValListIntRecord });
      {
        interface: (
          $it.0
            # | parse --regex '\d: (?<interface>.*): <(?<flags>.*)> (?<rest>.*)'
            | parse --regex '\d: (?<interface>.*): <(?<flags>.*)> mtu (?<mtu>.*) qdisc (?<qdisc>.*) state (?<state>.*) mode (?<mode>.*) group (?<group>.*) qlen (?<qlen>.*)'
            # | update rest { |i| $i | keyValListIntRecord }
            | flatten
        )
        mac: ($it.1 | str trim | record from kvl | flatten --all)
      }
    } | flatten interface --all
}
