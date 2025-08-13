use std

export module record {
  # returns true if input record contains `field`
  #
  # Example Usage:
  # { key1: 123, key2: 456 } | record has key1
  # true
  export def has [
    field: string # field to check
  ]: record -> bool {
    ($in | transpose | where column0 == $field | length) > 0
  }

  # returns true if input record doesn't contain `field`
  #
  # Example Usage:
  # { key1: 123, key2: 456 } | record has-not key1
  # false
  export def has-not [
    field: string # field to check
  ]: record -> bool {
    not ($in | has $field)
  }

  # maps a key value list into a record
  #
  # Example Usage:
  # "key1 val1 key2 val2" | record from kvl
  export def "from kvl" []: string -> record {
    split row " " | group 2 | each { |i| $i | into record } | transpose -r | into record
  }

  # overrides a record's value if the field exists
  # same as `upsert field value` except:
  #   - is a NOOP if `value` == `null` (not field added nor update applied)
  #
  # Example Usage:
  # 1. don't add a field if value is null
  #   { key1: 123, key2: 456 } | record override key3 null
  #     -->
  #   { key1: 123, key2: 456 }
  #
  # 2. don't override a field's value if null
  #   { key1: 123, key2: 456 } | record override key1 null
  #     -->
  #   { key1: 123, key2: 456 }
  export def override [
    field: string   # field to match
    value           # value to override
  ]: record -> record {
    if $value == null { $in } else { $in | upsert $field $value }
  }
}
export use record


# Returns all files within `dir` in a flat list
export def listRec [
  dir: path
  --hidden(-h)
]: nothing -> table<name: string, type: string, size: filesize, ...> {
  let cmd = (if $hidden {{
    ls: (ls $dir -f -a)
    rec: {|name| listRec $name -h}
  }} else {{
    ls: (ls $dir -f)
    rec: {|name| listRec $name}
  }})
  $cmd.ls | each { |it|
    if $it.type == dir {
      do $cmd.rec $it.name
    } else {
      $it
    }
  } | flatten
}

#################
# Help Commands #
#################
export def listCustomCommands [ module ] {
  # std help $module
  std log info $"Available commands for ($module)"
  let customCmds = (help commands | where command_type == custom)
  help modules
    | where name == $module
    | get commands
    | flatten
    | get name
    | each {|name|
      let custom = ($customCmds | where name == $name)
      let description = (if ($custom | length) == 0 {
        $"Run `--help` for more info"
      } else {
        $custom | first | get -o usage | default ""
      })
      {
        command: $name
        description: $description
        # other: ($custom.params | flatten | str join "\n")
      }
    }
}

#####################
# String Operations #
#####################
# wraps `val` into quoted string: 'val'
def quote [ val : string ]: string -> string { $"'($val | into string)'" }


#########
# Other #
#########
# checks if environment contains `name`
def envHas [ name: string ]: nothing -> bool { $env | record has $name }

# returns full path of nix iso (built from current dir)
def getIso []: nothing -> path { ls ./result/iso | get name | path expand | get 0 }

# return json if true, else no-op
def maybeJson [
  doParse
]: [table -> table, table -> string] {
  if $doParse {
    $in | to json
  } else {
    $in
  }
}

