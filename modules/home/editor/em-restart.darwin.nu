def em-restart [] {
    ^launchctl kickstart -k $"gui/(^id -u | str trim)/org.gnu.emacs.daemon"
}
