let exit_codes = ($env.disks | par-each { |it|
  print $"Unlocking ($it.device) -> ($it.label)";
  (if (echo $"/dev/mapper/($it.label)" | path exists) {
    print $"There already exists an open LUKS device at /dev/mapper/($it.label), skipping..."
    0
  } else {
    print $"Unlocking with key-file at `($env.keyfile)`"
    let status = (^cryptsetup luksOpen $it.device $it.label --key-file $env.keyfile | complete)
    print $"Finished unlocking ($it.device)" $status
    $status.exit_code
  });
})
let some_fail = ($exit_codes | any { |exit_code| $exit_code != 0})
let allow_fail = ($env | get -o ZFS_UNLOCK_ALLOW_FAIL | default false | into bool)
if $some_fail {
  print "There was a non-zero exit code while unlocking the disks."
  if not $allow_fail {
    exit 1
  }
}
exit 0
