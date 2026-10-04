#!/usr/bin/env nu
# Workspace helper for AeroSpace, mirroring the Hyprland config's workspace model.
#
#   nu workspace.nu go <name>        show <name> on the focused monitor
#   nu workspace.nu send <name>      move the focused window to <name> and follow it
#   nu workspace.nu new              go to a new temporary workspace (10, 11, ...)
#   nu workspace.nu send-new         move the focused window to a new temporary workspace
#   nu workspace.nu step prev|next   previous/next workspace with windows on this monitor
#   nu workspace.nu swap             swap the two monitors' workspaces
#
# Assumes at most two monitors, like the Hyprland config's monitor swap.
# Written for Nushell 0.115.1 (nixpkgs-unstable).

# Workspace names printed by `aerospace list-workspaces <flags>`.
def --wrapped workspaces [...flags: string]: nothing -> list<string> {
    ^aerospace list-workspaces ...$flags | lines | where $it != ""
}

# Smallest unused number from 10 up.
def free-temporary []: nothing -> string {
    let used = (workspaces --all)
    mut n = 10
    while ($n | into string) in $used {
        $n += 1
    }
    $n | into string
}

# Bring <name> to the focused monitor. If the other monitor is showing it, that monitor
# first moves to a new temporary workspace, so nothing gets swapped or swallowed.
def "main go" [name: string] {
    if (workspaces --focused | str join "") == $name {
        return
    }
    if $name in (workspaces --monitor all --visible) {
        let tmp = (free-temporary)
        ^aerospace focus-monitor --wrap-around next
        ^aerospace workspace $tmp
        ^aerospace focus-monitor --wrap-around prev
    }
    ^aerospace summon-workspace $name
}

# Move the focused window to <name>, then follow it there.
def "main send" [name: string] {
    ^aerospace move-node-to-workspace $name
    main go $name
}

# Go to a new temporary workspace.
def "main new" [] {
    ^aerospace workspace (free-temporary)
}

# Move the focused window to a new temporary workspace and follow it.
def "main send-new" [] {
    let tmp = (free-temporary)
    ^aerospace move-node-to-workspace $tmp
    ^aerospace workspace $tmp
}

# Previous or next workspace with windows on this monitor (Hyprland's m-1 / m+1).
def "main step" [direction: string] {
    if $direction not-in [prev next] {
        error make {msg: $"direction must be prev or next, not ($direction)"}
    }
    workspaces --monitor focused --empty no
    | str join "\n"
    | ^aerospace workspace --stdin $direction
}

# summon-workspace behaves like xmonad: pulling the other monitor's workspace here
# sends this one over there.
def "main swap" [] {
    let here = (workspaces --focused | str join "")
    let others = (workspaces --monitor all --visible | where $it != $here)
    if ($others | is-not-empty) {
        ^aerospace summon-workspace ($others | first)
    }
}

def main [] {
    help main
}
