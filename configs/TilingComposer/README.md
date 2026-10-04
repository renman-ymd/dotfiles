# Keyboard-first tiling on NixOS and macOS

A [Hyprland](https://hypr.land) configuration for NixOS, written in Hyprland's Lua config format, plus an [AeroSpace](https://github.com/nikitabobko/AeroSpace) configuration that gives the Mac the same keys. Each workspace has its own layout (scrolling, dwindle, master or monocle), there are nine fixed workspaces plus temporary ones, and every shortcut is bound to a physical key position, so it stays put whatever keyboard layout you type in.

> **Status: not yet run on real hardware.** The Lua was loaded against a mock of Hyprland's API, `workspace.nu` was run against a fake `aerospace` command, and `aerospace.toml` was parsed. [SETUP.md](SETUP.md) lists what to check on a real machine.

## Contents

```
.
├── README.md
├── SETUP.md               What NixOS must provide, companion programs, blanks to fill, hardware checks
├── hyprland/
│   ├── default.nix        Home Manager module installing the Lua files below
│   └── lua/user/
│       ├── init.lua       Loads the other modules in order
│       ├── apps.lua       App commands, window classes and shortcut IDs (placeholders to fill)
│       ├── defs.lua       Fixed workspaces, their layouts, the layout cycle, key positions
│       ├── util.lua       Helpers: window lookups, geometry, instant workspace switches
│       ├── settings.lua   Options: gaps, input, layouts, animations, monitors
│       ├── rules.lua      Workspace rules and window rules
│       ├── workspaces.lua Fixed and temporary workspaces, history, monitor memory, layout cycling
│       ├── floating.lua   Floats behind tiles, the on-top cycle, float toggle, focus among floats
│       ├── layout.lua     What each key does per layout; tab groups on 3-code and 4-term
│       ├── keys.lua       Every key binding
│       ├── gestures.lua   Trackpad gestures
│       └── autostart.lua  Programs started at login (Ghostty, for its quick terminal)
└── aerospace/
    ├── aerospace.toml     AeroSpace config mirroring the Hyprland keys
    └── workspace.nu       Nushell helper behind the workspace keys
```

## Requirements

| Machine | Needs |
| --- | --- |
| Linux | NixOS with `programs.hyprland.enable = true;`, Hyprland 0.56 (Lua config), and Home Manager recent enough to have `wayland.windowManager.hyprland.configType`. |
| Linux | [Ghostty](https://ghostty.org), for the drop-down terminal. |
| macOS | AeroSpace, [Nushell](https://www.nushell.sh), Ghostty, and optionally [Floaty Lite](https://apps.apple.com/us/app/floaty-lite-pin-windows/id6755633285?mt=12) for pinning windows on top. |

[SETUP.md](SETUP.md) covers the rest: audio, an authentication agent, a notification daemon, a bar, and so on.

## Install

### Linux (NixOS and Home Manager)

1. Copy `hyprland/` into your Home Manager configuration and import `hyprland/default.nix`. It sets `configType = "lua"` and leaves `package` and `portalPackage` null, so the NixOS module's Hyprland is used.
2. Fill the `TODO`s in `apps.lua` and `settings.lua`; [SETUP.md](SETUP.md) lists each one.
3. Add these lines to Ghostty's config:

   ```
   keybind = global:super+enter=toggle_quick_terminal
   quick-terminal-position = center
   quick-terminal-size = 90%,90%
   quit-after-last-window-closed = false
   ```

4. Log in, then run `hyprctl globalshortcuts` and copy the ID it lists for Ghostty into `A.quick_terminal` in `apps.lua`.

### macOS (AeroSpace)

1. Put `aerospace.toml` and `workspace.nu` in `~/.config/aerospace/`.
2. Add these lines to Ghostty's config (Ghostty needs Accessibility permission for global keys):

   ```
   keybind = global:cmd+alt+enter=toggle_quick_terminal
   quick-terminal-position = center
   quick-terminal-size = 90%,90%
   ```

3. In Floaty Lite's settings, set the "pin or unpin the active window" shortcut to Cmd+Alt+P.

## How it works

### Keys by position

Letters, digits and punctuation are bound to physical keys: Hyprland's `code:` keycodes on Linux; on the Mac, AeroSpace reads bindings as QWERTY positions. The tables below name keys after the QWERTY label at that position. Arrows, Page Up/Down, Tab, Return and Space are the same on every layout.

On the Mac, Linux's Super becomes Cmd+Alt, because Cmd alone belongs to macOS and its apps. Shift and Ctrl keep their roles.

### Workspaces

| Key | Workspace | Layout | Notes |
| --- | --- | --- | --- |
| 1 | `1-Claude` | master | |
| 2 | `2-web` | scrolling | Zen keeps a full-width column |
| 3 | `3-code` | dwindle | New windows join one tab group |
| 4 | `4-term` | dwindle | New windows join one tab group |
| 5 | `5-chat` | scrolling | |
| 6 | `6-media` | scrolling | |
| 7 | `7-notes` | monocle | |
| 8 | `8-misc` | dwindle | |
| 9 | `9-Gaming` | monocle | |
| 0 | `10`, `11`, … | scrolling | Temporary: Super+0 makes a new one |

- Empty workspaces disappear, so Fn+Up/Down and swipes only visit workspaces that have windows on the current monitor.
- Going to a workspace that the other monitor is showing brings it to your monitor; the other monitor moves to a new temporary workspace, so nothing is swapped away.
- When a monitor is unplugged, its workspaces move to the remaining one, then go back when it reconnects.
- Super+, cycles the current workspace's layout through scrolling, dwindle, master and monocle. A config reload resets it.
- On the Mac the nine names are the same, but AeroSpace only has its tiles and accordion layouts.

### Floating windows

- When you focus a tiled window, floating windows from your floating rules, or that you floated yourself, are hidden. Super+Alt+arrows brings them back and moves between them. Dialogs that apps float on their own never hide.
- Super+P cycles a window through floating, on top in this workspace, and on top on every workspace (pinned).
- Super+Alt+Space floats a tiled window, and puts it back next to its old neighbour when you tile it again.

### Drop-down terminal

Super+Return toggles Ghostty's quick terminal, drawn above every window, pinned ones included. Ghostty registers its global keybind with the desktop portal, and Hyprland's `global` dispatcher triggers it. On the Mac it's Cmd+Alt+Return, handled by Ghostty itself.

### Animations

Everything is instant except workspace changes made with the trackpad: the three-finger swipe follows your fingers, and the four-finger history swipe slides once you lift them.

## Key map

### Everywhere

| Action | Linux (Hyprland) | macOS (AeroSpace) |
| --- | --- | --- |
| Focus a window, skipping floating ones (wrapping depends on the layout on Linux; always on the Mac) | Super+arrows | Cmd+Alt+arrows |
| Focus floating windows only | Super+Alt+arrows | — |
| Move the window | Super+Shift+arrows | Cmd+Alt+Shift+arrows |
| Swap two windows, or move a whole column | Super+Shift+Alt+arrows | Cmd+Alt+Ctrl+Shift+arrows (swap) |
| Resize: right and down grow, left and up shrink | Super+Ctrl+arrows | Cmd+Alt+Ctrl+arrows |
| Go to workspace 1–9 | Super+1–9 | Cmd+Alt+1–9 |
| Send the window to workspace 1–9 and follow it | Super+Shift+1–9 | Cmd+Alt+Shift+1–9 |
| New temporary workspace | Super+0 | Cmd+Alt+0 |
| Send the window to a new temporary workspace | Super+Shift+0 | Cmd+Alt+Shift+0 |
| Previous / next workspace with windows on this monitor | Super+Page Up / Page Down (Fn+Up / Fn+Down) | Cmd+Alt+Page Up / Page Down |
| Swap the two monitors' workspaces | Super+Tab | Cmd+Alt+Tab |
| Focus the previous / next monitor | Super+- / Super+= | Cmd+Alt+- / Cmd+Alt+= |
| Send the window to the previous / next monitor | Super+Shift+- / Super+Shift+= | Cmd+Alt+Shift+- / Cmd+Alt+Shift+= |
| Cycle the workspace's layout | Super+, | Cmd+Alt+, (tiles and accordion) |
| Layout action (see below) | Super+/ | Cmd+Alt+/ (horizontal and vertical) |
| Cycle column widths | Super+R | Cmd+Alt+R (even out sizes) |
| Fullscreen | Super+F | Cmd+Alt+F |
| Maximize | Super+Shift+F | Cmd+Alt+Shift+F |
| Floating, on top, on top everywhere | Super+P | Cmd+Alt+P (Floaty Lite: pin or unpin) |
| Float or tile | Super+Alt+Space | Cmd+Alt+Space |
| Close the window | Super+W | Cmd+W (macOS) |
| App launcher | Super+Space | Cmd+Space (Spotlight) |
| Drop-down terminal | Super+Return | Cmd+Alt+Return (Ghostty) |
| Move / resize with the pointer | Super+left drag / Super+right drag | — |

### Keys that depend on the layout (Linux)

| Keys | dwindle | scrolling | master | monocle |
| --- | --- | --- | --- | --- |
| Super+arrows | Focus; wraps within the same row or column | Left/Right: previous or next column, stopping at the ends. Up/Down: within the column, wrapping | Focus; wraps | Left/Up: previous window. Right/Down: next |
| Super+Shift+arrows | Lift the window and re-insert it in that direction; enters and leaves tab groups | Left/Right: into the neighbouring column, or out into a new column if it shares one. Up/Down: swap within the column | Swap with the neighbour | — |
| Super+Shift+Alt+arrows | Swap two windows, keeping the tree | Left/Right: move the whole column. Up/Down: swap | Swap | — |
| Super+Ctrl+arrows | Resize | Left/Right: column width ±5%. Up/Down: window height | Left/Right: master width ±5%. Up/Down: window height | Floating windows only |
| Super+/ | Toggle the split | Fit the visible columns to the screen | Swap with the master | — |
| Super+R | — | Cycle widths ⅓, ½, ⅔, 1 | — | — |
| Super+Shift+F | Maximize | Column to 100%, and back | Maximize | Maximize |

### Trackpad (Linux)

| Gesture | Action |
| --- | --- |
| Three fingers, vertical | Previous / next workspace with windows on this monitor, following your fingers |
| Three fingers, horizontal | Scroll the strip on scrolling workspaces |
| Four fingers, right | The most recent workspace with a lower number |
| Four fingers, left | The most recent workspace with a higher number |
| Four fingers, vertical | Swap the two monitors' workspaces |

Alternating four-finger swipes left and right bounces between two workspaces.

### Laptop keys (Linux)

Volume up, down and mute, microphone mute, and brightness up and down call `wpctl` and `brightnessctl`. They also work on the lock screen.

### Mac only

| Keys | Action |
| --- | --- |
| Cmd+Alt+Shift+C | Reload the config |
| Cmd+Alt+Shift+; | Service mode, then: Esc to leave, R to reset the layout, F to float or tile, Backspace to close every other window, arrows to join with that neighbour |

## Known limits

- Nothing has run on real hardware yet; see the checklist in [SETUP.md](SETUP.md).
- A config reload resets layouts changed with Super+, and forgets which monitor each workspace belongs to.
- In scrolling, Super+Shift+F restores an estimated width, not the exact one.
- On the Mac there's no floating-only focus, no hiding floats behind tiles, and no gestures. Floaty Lite has two states instead of three, and whether its pinned window survives an AeroSpace workspace switch is untested. `workspace.nu` assumes at most two monitors.

## Built against

Hyprland 0.56.0's source and [wiki](https://wiki.hypr.land/0.56.0/), Home Manager's Hyprland module (master), AeroSpace's [documentation](https://github.com/nikitabobko/AeroSpace/tree/main/docs), Ghostty 1.3.1's [docs](https://ghostty.org/docs) and source, and Nushell 0.115.1.
