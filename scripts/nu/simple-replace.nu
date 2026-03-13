# simple find and replace on a given path similar to `rg | sed`
# requires ripgrep
def main [
  match : string # string to match in files
  replace : string # string to replace matches with
  path : path = "." # path to search files in
  --dryRun(-d) # add flag to print replaced files instead of saving in place
] {
  let matches = (rg $match --files-with-matches $path | complete)
  if $matches.exit_code == 0 {
    $matches.stdout | lines
    | each {|path|
      let str = (cat $path | str replace $match $replace)
      if $dryRun {
        print $str
      } else {
        # WORKAROUND(hang): related to: https://github.com/nushell/nushell/issues/16388
        # $str | save -f $path --raw
        $str | ^tee $path
      }
    }
  } else {
    print -e "Found no matches for $match"
    print -e $matches.stderr
  }
}
