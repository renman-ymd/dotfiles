def em-kill [] {
  ^emacsclient -s main --eval "(kill-emacs)"
}

def em-restart [] {
    ^launchctl kickstart -k $"gui/(^id -u | str trim)/org.gnu.emacs.daemon"
}
