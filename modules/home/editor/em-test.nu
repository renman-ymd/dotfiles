# Tests the launcher against real servers: `nu em-test.nu`.
# Everything it creates, sockets included, lives in one scratch directory.
source em.nu

const here = (path self | path dirname)

def --env check [what: string, ok: bool] {
  print $"(if $ok { 'ok  ' } else { 'FAIL' }) ($what)"
  if not $ok { $env.EM_TEST_FAILED = true }
}

def ev [sock: path, form: string]: nothing -> string {
  ^emacsclient -s $sock -e $form | complete | get stdout | str trim
}

def refused [action: closure]: nothing -> bool {
  try { do $action; false } catch { true }
}

def pin-addon [addon: path, ...files: string] {
  let hash = (em-pin --dir $addon ...$files)
  $"emacs_addon_pin ($hash) ($files | str join ' ')\nexport EMACS_ADDON_INIT=\"$PWD/addon.el\"\n" | save --force ($addon | path join ".envrc")
  ^direnv allow $addon
}

def --env scenario [box: path] {
  let project = ($box | path join "project")
  let addon = ($project | path join ".emacs-addon")
  let workspace = ($box | path join "workspace")
  let other = ($box | path join "other")
  let outside = ($box | path join "outside")
  mkdir ($box | path join "config" "emacs") ($box | path join "config" "direnv" "lib")
  mkdir $addon ($project | path join ".jj" "repo") ($workspace | path join ".jj") $other $outside
  cp ($here | path join "emacs-addon.sh") ($box | path join "config" "direnv" "lib")
  '(when-let* ((file (getenv "EMACS_ADDON_INIT")) ((file-readable-p file))) (load file nil t))' | save ($box | path join "config" "emacs" "init.el")
  "export EM_TEST=project\n" | save ($project | path join ".envrc")
  "export EM_TEST=workspace\n" | save ($workspace | path join ".envrc")
  "export EM_TEST=other\n" | save ($other | path join ".envrc")
  "../../project/.jj/repo" | save ($workspace | path join ".jj" "repo")
  "(setq em-test-addon t)\n" | save ($addon | path join "addon.el")
  pin-addon $addon addon.el
  ^direnv allow $project
  ^direnv allow $workspace

  print "# a project server"
  let first = (em-start ($project | path join "src" "new.txt"))
  check "the first call starts a server for the project" ($first.started and $first.root == $project)
  check "it runs in the project's environment" ((ev $first.sock '(getenv "EM_TEST")') == '"project"')
  check "it loaded the add-on" ((ev $first.sock '(bound-and-true-p em-test-addon)') == "t")
  let second = (do { cd $outside; em-start $project })
  check "the second call reuses it, from any directory" ((not $second.started) and $second.sock == $first.sock)
  check "a file of the add-on belongs to the project" ((em-start ($addon | path join "addon.el")).sock == $first.sock)
  let secondary = (em-start $workspace)
  check "a secondary jj workspace gets its own server" ($secondary.started and $secondary.sock != $first.sock)
  check "with the primary workspace's add-on" ((ev $secondary.sock '(list (getenv "EM_TEST") (bound-and-true-p em-test-addon))') == '("workspace" t)')

  print "# the core server"
  let loaded = (do { cd $project; ^direnv export json | from json })
  let core = (do { cd $project; with-env $loaded { em-start } })
  check "a plain call starts the core server" ($core.started and $core.root == null)
  check "without the calling shell's project" ((ev $core.sock '(getenv "EM_TEST")') == "nil")
  check "a path outside any project uses it" ((em-start ($outside | path join "note.txt")).sock == $core.sock)
  check "--bare uses it for a project path" ((em-start --bare $project).sock == $core.sock)

  print "# refusals"
  check "paths of two projects" (refused { em-start $project $workspace })
  check "a project path with one outside any" (refused { em-start $project $outside })
  check "a project whose .envrc is not allowed" (refused { em-start $other })
  check "which leaves no socket" ((ls $env.EM_SOCKET_DIR | length) == 3)

  print "# the pin"
  em-stop $project
  check "em-stop stops the project's server" (not ($first.sock | path exists))
  let pinned = (em-pin --dir $addon)
  "(setq em-test-addon 'tampered)\n" | save --force ($addon | path join "addon.el")
  check "a tampered add-on is refused" (refused { em-start $project })
  check "and leaves no server" (not ($first.sock | path exists))
  check "em-pin reads the list from the pin line" ((em-pin --dir $addon) != $pinned and (em-pin --dir $addon) == (em-pin --dir $addon addon.el))
  "(setq em-test-extra t)\n" | save ($addon | path join "extra.el")
  pin-addon $addon addon.el extra.el
  check "a new pin, once allowed, starts it again" (em-start $project).started
  em-stop $project
  rm ($addon | path join "extra.el")
  check "a listed file that is missing is refused" (refused { em-start $project })
  check "a path leaving the add-on folder cannot be pinned" (refused { em-pin --dir $addon ../.envrc })
  check "nor an absolute path" (refused { em-pin --dir $addon /etc/hosts })
  pin-addon $addon addon.el

  print "# stopping and listing"
  let third = (em-start $project)
  let draft = ($project | path join "draft.txt")
  ev $third.sock ('(with-current-buffer (find-file-noselect ' + ($draft | to json) + ') (insert "x") t)')
  check "em-stop refuses a server with unsaved changes" (refused { em-stop $project })
  check "and leaves it running" ((ev $third.sock "t") == "t")
  let listed = (em-list)
  check "em-list shows each project's root" (($listed | get root | compact | sort) == ([$project $workspace] | sort))
  check "and the core server without one" (($listed | where root == null | get socket) == [$core.sock])
  check "and its memory" ($listed | all {|row| $row.memory > 1MB })
  check "em-stop --all refuses the same server" (refused { em-stop --all })
  check "and stops the others" ((em-list | get root) == [$project])
  em-stop --force $project
  check "--force stops it" (em-list | is-empty)
}

def main [] {
  # Under /tmp, because a socket path must stay under 64 bytes on macOS.
  let box = (^mktemp -d /tmp/em-test.XXXXXX | str trim | path expand)
  let result = (with-env {
    XDG_CONFIG_HOME: ($box | path join "config")
    XDG_DATA_HOME: ($box | path join "data")
    EM_SOCKET_DIR: ($box | path join "s")
    DIRENV_LOG_FORMAT: ""
    EM_TEST_FAILED: false
  } {
    try { scenario $box } catch {|e| print $e.rendered; $env.EM_TEST_FAILED = true }
    try { em-stop --all --force }
    $env.EM_TEST_FAILED
  })
  rm -rf $box
  if $result { exit 1 }
}
