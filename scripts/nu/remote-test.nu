# runs a nixos-test-driver on a remote server
export def main [
  storeLink                 # /nix/store/asd... to test-driver root
  --host(-h): string = ""   # host to waypipe/ssh into, defaults to `$env.REMOTE_HOST` or `localhost`
  --disableAutoStart(-a)    # whether to use wezterm to autostart machines + test
  --disableStdout(-s)       # whether to disable stdOut
  --forceLocal(-l)          # don't ssh at all
] {
  print $"Running on (ansi green)($storeLink)(ansi reset)"
  let host = (if $host == "" { $env.REMOTE_HOST | default "localhost" } else { $host })
  let hasWezterm = ((which wezterm | length) > 0)
  # base case (no wezterm / old)
  let testBinary = $"($storeLink)/bin/nixos-test-driver"
  if not $hasWezterm {
    print $"(ansi yellow)Running basic version - no wezterm integration/autostart(ansi reset)"
    if $forceLocal {
      run-external $testBinary
    } else {
      waypipe ssh $host $"dbus-launch ($testBinary)"
    }
  } else {
    # use wezterm to autostart tests
    print $"(ansi yellow)Running wezterm version:
autoStart: (not $disableAutoStart)
stdoutEnabled: (not $disableStdout)
local: ($forceLocal)(ansi reset)"
    let start = (if $forceLocal {
      $"   ($testBinary) \n"
    } else {
      $"   waypipe ssh ($host) dbus-launch ($storeLink)/bin/nixos-test-driver \n"
    })
    if not $disableAutoStart {
      let curr = (echo $start "start_all() \n" | str join " ")
      let mid = (if $disableStdout {
        echo $curr "serial_stdout_off() \n" | str join " "
      } else {
        $curr
      })
      let final = (echo $mid "run_tests() \n" | str join " ")
      # print $"(ansi blue)Running command:(ansi reset)\n($final)"
      wezterm cli send-text $final
    } else {
      # print $"(ansi blue)Running command:(ansi reset)\n($start)"
      wezterm cli send-text $start
    }
  }
}
