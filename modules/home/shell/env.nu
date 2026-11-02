$env.PATH = ($env.PATH | prepend [
  ($env.HOME + "/.nix-profile/bin")
  "/etc/profiles/per-user/renman-ymd/bin"
  "/run/current-system/sw/bin"
  "/nix/var/nix/profiles/default/bin"
] | uniq)

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
$env.BROWSER = "zen-beta"
$env.LESS = "-RFMiS --incsearch --use-color -j.5"
$env.DELTA_PAGER = "less -RFEX --mouse --wheel-lines=3"

$env.MANPAGER = "sh -c 'col -bx | bat -l man -p'"
$env.MANROFFOPT = "-c"

# $env.NU_LIB_DIRS = (
#   $env.NU_LIB_DIRS? | default [] | append ($nu.default-config-dir | path join "completions")
# )
