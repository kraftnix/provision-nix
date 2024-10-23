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
if ($exit_codes | any { |exit_code| $exit_code != 0}) {
  print "There was a non-zero exit code while unlocking the disks."
  exit 1
} else { exit 0 }
