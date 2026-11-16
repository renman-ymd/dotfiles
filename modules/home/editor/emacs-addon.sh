# `direnv allow` covers an add-on's .envrc alone. Its pin line,
# `emacs_addon_pin <hash> <file>...`, extends that to the content of the
# files it lists; any other file in the folder is ignored.

_emacs_addon_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1
}

emacs_addon_hash() {
  local f
  if [ $# -eq 0 ]; then
    echo "emacs-addon: no file to pin" >&2
    return 1
  fi
  for f in "$@"; do
    case "/$f/" in
      //* | */../*)
        echo "emacs-addon: '$f' is absolute or leaves the add-on folder" >&2
        return 1
        ;;
      *$'\n'*)
        echo "emacs-addon: a file name holds a line break" >&2
        return 1
        ;;
    esac
    if [ -e "$f" ] && [ ! -f "$f" ]; then
      echo "emacs-addon: '$f' is not a regular file" >&2
      return 1
    fi
  done
  # One line per file, so content cannot move between files under the same
  # hash, and a missing file still counts.
  for f in "$@"; do
    if [ -f "$f" ]; then
      printf '%s  %s\n' "$(_emacs_addon_sha256 <"$f")" "$f"
    else
      printf 'missing  %s\n' "$f"
    fi
  done | _emacs_addon_sha256
}

emacs_addon_pin() {
  local want=${1-} got
  [ $# -gt 0 ] && shift
  got=$(emacs_addon_hash "$@") || exit 1
  watch_file "$@"
  if [ "$got" != "$want" ]; then
    log_error "emacs-addon: the pinned files changed (now $got). Review them, then put this hash on the pin line of .envrc"
    exit 1
  fi
}
