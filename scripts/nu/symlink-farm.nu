# source provision-helper.nu

export module symlink-farm {
  # replaces source paths with targets paths from input string
  export def rewritePath [
    source: path # source directory
    target: path # target directory
  ]: path -> path {
    str replace ($source | path expand) ($target | path expand)
  }

  # symlinks individual files from `source` to `target`, preserving directory structure
  # Example Usage:
  #   - Dry Run:        nu symlink-farm.nu ~/config/home/neovim ~/.config/nvim -d
  #   - Force Symlink:  nu symlink-farm.nu ~/config/home/neovim ~/.config/nvim -f
  export def main [
    source: path            # source directory
    target: path            # target directory
    --skipCreateDirs(-s)    # do not create directories if not exists at target
    --dryRun(-d)            # don't symlink targets, only show symlinks
    --force(-f)             # force symlinks if files exist in source and target
  ]: nothing -> list<string> {
    let allFiles = (listRec $source)
    $allFiles | each { |f|
      let newTarget = ($f.name | rewritePath $source $target)
      let successStr = $"Symlinked (ansi yellow)($f.name)(ansi reset) to (ansi blue)($newTarget)(ansi reset)"
      if $dryRun {
        $"(ansi red)Dry run...(ansi reset)\n($successStr)"
      } else {
        if not $skipCreateDirs {
          mkdir ($newTarget | path dirname)
        }
        if $force {
          ^ln -fs $f.name $newTarget
        } else {
          ^ln -s $f.name $newTarget
        }
        $successStr
      }
    }
  }
}

export use symlink-farm
