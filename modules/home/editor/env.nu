if ("SSH_CONNECTION" in $env) {
  $env.EDITOR = "nano"
  $env.VISUAL = "nano"
} else {
  $env.EDITOR = (
    if ((^emacsclient -s main -e "t" | complete).exit_code) == 0 {
      "emacsclient -s main -nw"
    } else {
      "emacs -nw --init-dir ~/.config/emacs-light"
    }
  )
  $env.VISUAL = "emacsclient -s main -c"
}
