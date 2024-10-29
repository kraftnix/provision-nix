module mynix-diff {

  # Compare home path against home generation (negative index)
  # Usage: pass in a path relative to your home directory
  export def home-rela [
    filePath      # file path/dir relative to home to compare
    index : int   # (negative) index to lookback generations
    --impure(-i)  # when false, use curr home dir, when true, use current hm generation
  ] {
    let filePathStr = ($filePath | into string)
    print $"Comparing ($filePathStr) with current home manager generation"
    let current = (home-current-gen gen)
    let newGen = ($current - $index)
    let profilePath = (home-get-gen $newGen name)
    print {
      "Current Gen": $current
      "Relative Gen": $newGen
      "Relative Profile Path": $profilePath
    }
    let currHomePath = (^readlink -f $"($profilePath)/home-files")
    let homePath = (if $impure {
      echo "~" / $filePathStr | str join | path expand
    } else {
      echo (home-current-gen name) / home-files / $filePathStr | str join | path expand
    })
    let hmPath = (echo $currHomePath / $filePathStr | str join)
    print $"Home Path: ($homePath)"
    print $"Rela Path: ($hmPath)"
    difft $homePath $hmPath
  }

  # Compare a home file path against the current home-manager generation
  # Usage: pass in a path relative to your home directory
  export def home [ filePath ] {
    home-rela $filePath 0 --impure
  }

  # Returns a diff between two home-manager generations
  # Usage: pass in a path relative to your home directory
  export def home-gens [
    first   : int           # first home-manager generation
    second  : int           # second home-manager generation
    field?  : string = name # field to compare (default: name), probably don't change this.
  ] {
    print $"Comparing ($first) and ($second) home-manager generations."
    let firstPath = (home-get-gen $first $field)
    let secondPath = (home-get-gen $second $field)
    print $"first   Path: ($firstPath | path expand)"
    print $"second  Path: ($secondPath | path expand)"
    difft $firstPath $secondPath
  }

  # Parse a generation number from a list of home-manager profile directory links
  export def parse-home-gen [ ] {
    parse $"/nix/var/nix/profiles/per-user/($env.USER)/home-manager{s}"
      | each { |x| if $x.s == "" { 0 } else { $x.s | parse "-{gen}-link" | get gen.0 | into int} }
      | wrap gen
  }

  # Parses generation numbers from a provided $root or input
  # has two operational modes:
  #   - if <input> is passed, then run parse, and merge back into input
  #   - if $root is defined, then ls $root, run parse and merge into ls output
  export def home-generations [ root? ] {
    let inp = $in
    (if ($root == null) {
      let gens = ($inp | get name | parse-home-gen)
      $inp | merge $gens
    } else {
      let profiles = (ls $root)
      let gens = ($profiles | get name | parse-home-gen)
      $profiles | merge $gens
    })
      | move gen --before name
      | sort-by gen --natural
  }

  # Add a (`storePath`) column with the path names expanded
  export def expand-names [ ] {
    let original = $in
    let expanded = ($original | get name | path expand | wrap storePath)
    $original | merge $expanded
  }

  # Returns the current generation given a root
  export def get-curr-gen [ root ] {
    let root = $"/nix/var/nix/profiles/per-user/($env.USER)"
    let full = (home-generations $root | expand-names)
    let current = ($full | where gen == 0 | first)
    $full
      | where storePath == $current.storePath
      | where gen != 0
  }

  # Returns a field from a home-manager generation
  export def home-get-gen [ gen field ] {
     home-generations $"/nix/var/nix/profiles/per-user/($env.USER)/" | where gen == $gen | get $field | first
  }

  # Returns a field from the latest home-manager generation
  export def home-latest-gen [ field ] {
     home-generations $"/nix/var/nix/profiles/per-user/($env.USER)/" | last | get $field
  }

  # Returns a field from the current home-manager generation
  export def home-current-gen [ field ] {
     get-curr-gen $"/nix/var/nix/profiles/per-user/($env.USER)/" | get $field | first
  }

  # Compare a home .config path against the current home-manager generation
  # Usage: pass in a path relative to your home directory
  export def home-rela-conf [
    filePath      # file path/dir relative to home to compare
    index : int   # (negative) index to lookback generations
    --impure(-i)  # when false, use curr home dir, when true, use current hm generation
  ] {
    home-rela $".config/($filePath)" $index --impure=$impure
  }

  # Compare a home file path against the current home-manager generation
  # Usage: pass in a path relative to your home directory
  export def home-legacy [ filePath ] {
    print $"Comparing ($filePath) with current home manager generation."
    let currHomePath = (^readlink -f $"/nix/var/nix/profiles/per-user/($env.USER)/home-manager/home-files")
    let homePath = (echo "~" / $filePath | str join | path expand)
    let hmPath = (echo $currHomePath / $filePath | str join)
    print $"Home Path: ($filePath | path expand)"
    print $"H-M  Path: ($hmPath | path expand)"
    difft $homePath $hmPath
  }

  export def main [] {
    std log info "Available commands"
    let customCmds = (help commands | where command_type == custom)
    help modules
      | where name == mynix-diff
      | get commands
      | flatten
      | get name
      | each {|name|
        let custom = ($customCmds | where name == $name)
        let description = (if ($custom | length) == 0 {
          $"Run `--help` for more info"
        } else {
          $custom | first | get usage
        })
        {
          command: $name
          description: $description
        }
      }
  }
}

use mynix-diff
