module project-server {
  # The nearest directory at or above a path that holds an `.envrc`, or null outside any project.
  def project-root [target: path]: nothing -> any {
    mut dir = ($target | path expand)
    while not ($dir | path exists) { $dir = ($dir | path dirname) }
    # Symlinks resolved, because direnv keeps its allow record under the real path.
    $dir = ($dir | path expand)
    if ($dir | path type) != "dir" { $dir = ($dir | path dirname) }
    loop {
      # An add-on has an `.envrc` of its own, but its files belong to the project around it.
      if ($dir | path join ".envrc" | path exists) and ($dir | path basename) != ".emacs-addon" { return $dir }
      let parent = ($dir | path dirname)
      if $parent == $dir { return null }
      $dir = $parent
    }
  }

  # In a secondary jj workspace, `.jj/repo` is a file holding the primary's `.jj/repo`, relative to `.jj`.
  def primary-root [ws: path]: nothing -> path {
    let repo = ($ws | path join ".jj" "repo")
    if ($repo | path exists) and (($repo | path type) == "file") {
      $ws | path join ".jj" ($repo | open --raw | str trim) | path expand | path dirname | path dirname
    } else { $ws }
  }

  def addon-dir [root: path]: nothing -> any {
    [$root (primary-root $root)] | each {|dir| $dir | path join ".emacs-addon" } | where {|dir| $dir | path exists } | get 0?
  }

  def socket-dir []: nothing -> path {
    # Absolute, because a dev shell may rewrite TMPDIR, where Emacs puts relative socket names.
    let dir = ($env.EM_SOCKET_DIR? | default ($env.HOME | path join ".local" "state" "emacs-servers"))
    mkdir $dir
    ^chmod 700 $dir
    $dir
  }

  # The server of a project root, or the core server for null.
  def server-of [root: any]: nothing -> record {
    # A daemon on macOS refuses a socket path of 64 bytes or more, hence the short name.
    let name = if $root == null { "em-core" } else { $"em-(($root | hash sha256) | str substring 0..9)" }
    { root: $root, sock: (socket-dir | path join $name) }
  }

  def up [sock: path]: nothing -> bool {
    (^emacsclient -s $sock -e t | complete | get exit_code) == 0
  }

  def config-home []: nothing -> path {
    $env.XDG_CONFIG_HOME? | default ($env.HOME | path join ".config")
  }

  def start [server: record] {
    # Emacs prefers an existing ~/.emacs.d, and creates it itself.
    let args = [$"--init-directory=(config-home | path join emacs)" $"--daemon=($server.sock)"]
    if $server.root == null {
      cd $env.HOME
      if "DIRENV_DIFF" in $env {
        # On a directory with no `.envrc` at or above it, direnv takes the calling shell's project back out of the environment.
        ^direnv exec / emacs ...$args
      } else {
        ^emacs ...$args
      }
      return
    }
    cd $server.root
    let addon = (addon-dir $server.root)
    with-env { EM_ROOT: $server.root } {
      if $addon == null {
        ^direnv exec $server.root emacs ...$args
      } else {
        # Without the project's DIRENV_* variables, the second direnv loads the add-on on top instead of unloading the project.
        ^direnv exec $server.root env -u DIRENV_DIFF -u DIRENV_DIR -u DIRENV_FILE -u DIRENV_WATCHES direnv exec $addon env $"SHELL=($env.SHELL)" emacs ...$args
      }
    }
  }

  def stop [server: record, force: bool] {
    if not (up $server.sock) { return }
    let form = if $force { "(kill-emacs)" } else {
      '(let ((unsaved (delq nil (mapcar (lambda (b) (and (buffer-modified-p b) (buffer-file-name b))) (buffer-list)))))
         (if unsaved (mapconcat (function identity) unsaved ", ") (kill-emacs)))'
    }
    let unsaved = (^emacsclient -s $server.sock -e $form | complete | get stdout | str trim)
    if ($unsaved | is-not-empty) {
      let name = if $server.root != null { $"the server of ($server.root)" } else if ($server.sock | path basename) == "em-core" { "the core server" } else { $"the server on ($server.sock)" }
      error make { msg: $"($name) has unsaved changes in ($unsaved | from json). Save them, or stop it anyway with --force" }
    }
  }

  # Start the server these paths belong to, unless it is running: their project's, or the core server outside any project and with no path.
  export def em-start [
    --bare  # the core server, whatever the paths
    ...paths: path
  ]: nothing -> record {
    let roots = if $bare { [] } else { $paths | each {|p| { root: (project-root $p) } } | uniq }
    if ($roots | length) > 1 {
      error make { msg: $"these paths belong to different projects: ($roots | each {|r| $r.root | default 'none' } | str join ', ')" }
    }
    let server = (server-of ($roots | get 0?.root))
    if (up $server.sock) { return ($server | insert started false) }
    let failed = (try { start $server; false } catch { true })
    if $failed or not (up $server.sock) {
      let hint = if $server.root == null { "the core server did not start" } else {
        $"no server started for ($server.root). If direnv or the pin refused, see its message above; `em --bare` opens the paths without the project's environment"
      }
      error make { msg: $hint }
    }
    $server | insert started true
  }

  # Open paths in Emacs: in the server of their project, or in the core server outside any project and with no path.
  export def em [
    --bare  # in the core server, without the project's environment
    ...paths: path
  ] {
    let server = (em-start --bare=$bare ...$paths)
    ^emacsclient -s $server.sock -nw ...$paths
  }

  def running []: nothing -> list<record> {
    ls (socket-dir) | where type == socket | get name | where {|sock| up $sock } | each {|sock|
      let root = (^emacsclient -s $sock -e '(getenv "EM_ROOT")' | str trim)
      { root: (if $root == "nil" or ($sock | path basename) == "em-core" { null } else { $root | from json }), sock: $sock }
    }
  }

  def tree-memory [processes: table, pid: int]: nothing -> filesize {
    mut level = [$pid]
    mut total = 0B
    while ($level | is-not-empty) {
      let pids = $level
      $total = $total + ($processes | where pid in $pids | get mem | append 0B | math sum)
      $level = ($processes | where ppid in $pids | get pid)
    }
    $total
  }

  # The running servers: the root of each (none for the core server), its socket, and its memory with the language servers it started.
  export def em-list []: nothing -> table {
    let processes = (ps)
    running | each {|server|
      let pid = (^emacsclient -s $server.sock -e "(emacs-pid)" | into int)
      { root: $server.root, socket: $server.sock, memory: (tree-memory $processes $pid) }
    }
  }

  # Stop the server a path belongs to, or the core server with no path.
  export def em-stop [
    --all    # every server
    --force  # even if a file has unsaved changes
    path?: path
  ] {
    if $all {
      let kept = (running | each {|server| try { stop $server $force; null } catch {|e| $e.msg } })
      if ($kept | is-not-empty) { error make { msg: ($kept | str join "\n") } }
      return
    }
    stop (server-of (if $path == null { null } else { project-root $path })) $force
  }

  # Print the hash for an add-on's pin line. The files are relative to the add-on folder; with none given, they are the ones its `.envrc` pins.
  export def em-pin [
    --dir (-d): path  # the add-on folder, the current directory by default
    ...files: string
  ]: nothing -> string {
    let dir = ($dir | default "." | path expand)
    let files = if ($files | is-not-empty) { $files } else {
      open --raw ($dir | path join ".envrc") | lines | parse --regex '^\s*emacs_addon_pin\s+\S+\s+(?<files>\S.*)$' | get files | str join " " | split row --regex '\s+' | where $it != ""
    }
    let lib = (config-home | path join "direnv" "lib" "emacs-addon.sh")
    ^bash -c '. "$1" && cd "$2" && shift 2 && emacs_addon_hash "$@"' em-pin $lib $dir ...$files | str trim
  }
}

use project-server *
