# simple find and replace on a given path similar to `rg | sed`
# requires ripgrep
def main [
  match : string # string to match in files
  replace : string # string to replace matches with
  path : path # path to search files in
  --dryRun(-d) # add flag to print replaced files instead of saving in place
] {
  rg $match --files-with-matches
    | lines
    | each {|path|
      let str = (open $path --raw | str replace $match $replace)
      if $dryRun {
        print $str
      } else {
        $str | save -f $path
      }
    }
  exit 0
}
