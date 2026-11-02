$env.PATH = ($env.PATH | prepend [
  ($env.HOME + "/.nix-profile/bin")
  "@profileDirectory@/bin"
  "/run/current-system/sw/bin"
  "/nix/var/nix/profiles/default/bin"
] | uniq)

$env.BROWSER = "zen-beta"
$env.LESS = "-RFMiS --incsearch --use-color -j.5"

$env.MANPAGER = "sh -c 'col -bx | bat -l man -p'"
$env.MANROFFOPT = "-c"

# $env.NU_LIB_DIRS = (
#   $env.NU_LIB_DIRS? | default [] | append ($nu.default-config-dir | path join "completions")
# )
