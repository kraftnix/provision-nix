# skke = ''ln -sf $(nu -c "ls (ls /tmp/ | where name =~ "ssh-" | sort-by modified -r | get name | get 0) | get name.0") ~/.ssh/auth_sock'';

# use provision-helper.nu

export module sanu {

  # gets the ssh agents
  # (default) all agents in `/tmp/` or provided path
  export def "get agents" [
    location : path = "/tmp/"   # path to search for agents (`/tmp/` by default)
  ] -> list<string> {
    ls /tmp/ | where name =~ "ssh-" | sort-by modified -r
  }

  # gets the most recently created ssh agent
  export def "get latest" [
    location : path = "/tmp/"   # path to search for agents (`/tmp/` by default)
  ] -> string {
    get agents $location | first | get name
  }

  # take a base dir/path and returns the ssh auth sock in it
  # input: basePath : path   # base path like `/tmp/ssh-XXXXXXHvXKja`
  def getAgentFromBasePath [ ]: {
    $in | first | get name
  }

  # set ssh auth sock locally (only works in nushell)
  export def "set authsock" []: string -> string {
    let sock = $in
    $env.SSH_AUTH_SOCK = $sock
    $sock
  }

  # update `~/.ssh/auth_sock` symlink
  export def "update authsock symlink" [
    symlink : path = "~/.ssh/auth_sock"   # path to change symlink of
  ]: path -> nothing {
    let sock = $in
    ln -sf ($sock | path expand) ($symlink | path expand)
    $sock
  }

  # get a posix runable command to set `SSH_AUTH_SOCK`
  export def getPosixExportAuthSock [] {
    let sock = $in
    return $"export SSH_AUTH_SOCK=($sock)";
  }
  
  # get a posix runable command to update symlink `~/.ssh/auth_sock`
  export def getPosixExportAuthSockSymlink [
    symlink : path = "~/.ssh/auth_sock"   # path to change symlink of
  ] {
    let sock = $in
    # return $"ln -sf ($sock | path expand) (echo $symlink | path expand)"
    return $"ln -sf ($sock | path expand) (echo $symlink)"
  }
  
  # searchs agents and asks for user input to select an agent
  # def chooseAgent [ ]: table<name: string, type: string, size: filesize, modified: datetime> -> string {
  export def "set agent" [ ] {
    let agents = $in
    print $"(ansi yellow)Found the following keys:(ansi reset)" $agents
    print "Select agent by number or `q` to quit:"
    mut choice = (input | str trim)
    if $choice == q {
      print "Exiting."
      exit 0
    }
    let choiceIndex = ($choice | into int)
    if ($choiceIndex < 0) or ($choiceIndex > ($agents | length)) {
      print $"(ansi red)Invalid index passed, please try again.(ansi reset)"
      exit 1
    } else {
      return ($agents | get $choiceIndex | get name)
    }
  }

  export def "get sock" [] {
    $env.SSH_AUTH_SOCK
  }

  # return where `~/.ssh/auth_sock` or `--symlink` is pointing to
  export def "get symlink" [
    --symlink(-l): path = "~/.ssh/auth_sock"  # path to change symlink of
  ] {
    readlink -f ($symlink | path expand) | str trim | getAgentFromBasePath
  }

  # Update SSH_AUTH_SOCK symlink (default) or set the SSH auth sock (`--set` / `-s`)
  # You can pass `--posix` or `-p` to pass back a posix compatible command string that can be run
  # You can pass in (`--choose` / `-c`), to ask the user to choose the socket to set/update
  #
  # Defaults:
  #   - uses latest created ssh auth sock in `/tmp/`
  #   - updates the `~/.ssh/auth-sock` symlink
  #
  # Example Usage:
  #   1. `nu ssh-agent.nu`: updates ~/.ssh/auth_sock symlink to latest agent
  #   2. `nu ssh-agent.nu -c`: updates ~/.ssh/auth_sock symlink to user chosen agent
  #   3. `nu ssh-agent.nu -p`: returns a posix compatible export command to latest agent
  #   4. `nu ssh-agent.nu get`: get the SSH agents in `/tmp/`
  #   5. `nu ssh-agent.nu get symlink`: show the current location of where `~/.ssh/auth_sock` points to
  export def setter [
    --symlink(-l): path = "~/.ssh/auth_sock"  # path to change symlink of
    --agentsPath(-a): path = "/tmp/"          # default path for SSH sockets (`/tmp/` if unset)
    --posix(-p)                               # generate posix compatible command
    --set(-s)                                 # if set, then sets sets (nushell) or returns $SSH_AUTH_SOCK env var (posix)
    --choose(-c)                              # if set, asks user to choose an SSH agent
    --agent(-g) : string = ""                 # if set, sets that agent specifically
  ]: nothing -> path {
    let agent = (if $choose { # ask user to choose
      get agents $agentsPath | set agent | getAgentFromBasePath
    } else if ($agent != "") {
      $agent
    } else { # choose latest modified
      get latest $agentsPath
    })
    # POSIX compatible string commands returned
    if $posix {
      if $set { # POSIX export command
        $agent | getPosixExportAuthSock
      } else { # update symlink command
        $agent | getPosixExportAuthSockSymlink $symlink
      }
    } else { # Nushell native updates run
      if $set {
        $agent | set authsock
      } else { # update symlink command
        $agent | update authsock symlink $symlink
      }
    }
  }

  # commands
  export def main [] {
    listCustomCommands "sanu"
  }
}

export use sanu
