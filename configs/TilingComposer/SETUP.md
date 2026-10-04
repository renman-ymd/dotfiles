# Setup: what this config needs

What has to exist around the config before it works, the blanks to fill, and what to check on real hardware. [README.md](README.md) covers what the config does and its full key map.

## What NixOS must provide

The Hyprland NixOS module covers the core; add audio, an authentication agent, a keyring, fingerprint support and a notification daemon. `autostart.lua` only starts Ghostty so far: add the others there once chosen, or run them as systemd user services.

| Need | Why this config needs it | On NixOS |
| --- | --- | --- |
| Hyprland module | Installs Hyprland, its desktop portal, polkit, graphics drivers, fonts, dconf, XWayland and the login session entry | `programs.hyprland.enable = true;` |
| PipeWire + WirePlumber | Screen sharing doesn't work without PipeWire; the volume keys call `wpctl` | `services.pipewire.enable = true;` (option from memory; check) |
| Authentication agent | Pops up when an app needs your password; Bitwarden's fingerprint unlock asks through polkit | `hyprpolkitagent`, started at login |
| Keyring (secret service) | Apps that save logins use it (from memory); Bitwarden's fingerprint unlock itself only needs the authentication agent | GNOME Keyring: `services.gnome.gnome-keyring.enable = true;` (from memory; check) |
| Fingerprint reader | Fingerprint unlock for Bitwarden and for login | `services.fprintd.enable = true;` (from memory; check) |
| Notification daemon | Some apps, Discord among them, can freeze without one | dunst, mako, fnott or swaync |
| Qt Wayland, fonts | Qt apps on Wayland; text in tab bars and notifications | `qt5-wayland`, `qt6-wayland` (the wiki's names), a sans-serif font such as Noto |
| `brightnessctl` | The brightness keys call it | The `brightnessctl` package |
| Electron hint | Electron apps (Discord, Teams desktop) draw natively on Wayland | `environment.sessionVariables.NIXOS_OZONE_WL = "1";` |

Sources: Hyprland wiki, [Hyprland on NixOS](https://wiki.hypr.land/0.56.0/Nix/Hyprland-on-NixOS/) and [Must have](https://wiki.hypr.land/0.56.0/Useful-Utilities/Must-have/).

## Companion programs

Three things are already wired to keys and only need a value in `apps.lua`: the launcher, the quick terminal's shortcut ID and Zen's class. The rest have no binding yet. The recommendations come from the Hyprland wiki's lists plus judgment; none of them has been tested with this config.

| Role | What the config expects | Recommendation |
| --- | --- | --- |
| Launcher | `A.launcher`, run by Super+Space: type a few letters, Enter | hyprlauncher, the first-party launcher Hyprland's example config uses. fuzzel for something minimal. |
| Terminal and drop-down terminal | Ghostty running in the background (`autostart.lua`), with a global keybind for its quick terminal | Ghostty, which the Mac side uses too. Its quick terminal is a layer drawn above every window, pinned ones included; it needs the layer-shell protocol, which Hyprland has. |
| Bar | Lists the nine fixed workspaces even when empty, plus "temporary n of m" | Waybar: its `hyprland/workspaces` module, plus a small custom module that counts workspaces 10 and up from `hyprctl workspaces -j`. Click actions must use the Lua dispatch syntax, e.g. `hyprctl dispatch 'hl.dsp.focus({workspace="e+1"})'`. |
| Notifications | Any daemon (see the table above) | mako for a plain popup; swaync for a notification panel. |
| Lock and idle | Nothing bound yet; pick a lock key | hyprlock and hypridle, from the Hypr ecosystem. |
| Clipboard history | The `clipboard-history` floating rule in `apps.lua` | clipse: a terminal picker opened in a floating window. Add wl-clip-persist so copied text survives closing its app. |
| Screenshots | Nothing bound yet | grim + slurp, with satty or swappy to annotate; the wiki gives ready-made Lua bindings for Print. |

Ghostty registers the `global:` keybind from the README's install step with the desktop portal under the name `LOGO+Return`; Hyprland's `global` dispatcher then triggers it from Super+Return. Run `hyprctl globalshortcuts` while Ghostty runs and put the ID it lists into `A.quick_terminal`; the file's guess is `com.mitchellh.ghostty:LOGO+Return`. `quit-after-last-window-closed = false` keeps Ghostty running after its windows close, so the quick terminal stays available.

Sources: Hyprland wiki, [App launchers](https://wiki.hypr.land/0.56.0/Useful-Utilities/App-Launchers/), [Status bars](https://wiki.hypr.land/0.56.0/Useful-Utilities/Status-Bars/), [Clipboard managers](https://wiki.hypr.land/0.56.0/Useful-Utilities/Clipboard-Managers/), [Screenshots and recording](https://wiki.hypr.land/0.56.0/Useful-Utilities/Screenshots-and-Recording/), [Binds](https://wiki.hypr.land/0.56.0/Configuring/Basics/Binds/); Ghostty docs, [keybind actions](https://ghostty.org/docs/config/keybind/reference) and [options](https://ghostty.org/docs/config/reference).

## Blanks to fill and defaults to review

Six blanks and one ID to confirm before first login; read them with `hyprctl clients`, `hyprctl globalshortcuts` and `hyprctl monitors`. Six defaults are judgment calls: four marked "review" in `settings.lua`, two behaviours in the scripts.

| Where | Setting | Status | What to put or check |
| --- | --- | --- | --- |
| `apps.lua` | `A.launcher` | Blank | The launcher command |
| `apps.lua` | `A.quick_terminal` | Check | The ID `hyprctl globalshortcuts` lists for Ghostty's quick terminal; the guess is `com.mitchellh.ghostty:LOGO+Return` |
| `apps.lua` | `A.zen_class` | Blank | Zen's class, so its column stays at 100% |
| `apps.lua` | `A.floating` | Blank | Nine commented entries: settings, calculator, clipboard history, file manager, image viewer, pavucontrol, pinentry, password pop-up, picture-in-picture (by title) |
| `settings.lua` | `kb_variant` | Blank | `ergol`, or `ergol_iso` for Ergo-L's ISO (angle mod) variant |
| `settings.lua` | `hl.monitor` for `eDP-1` | Blank | The laptop's output name and scale; 1.5 gives 1707×1067 of space on a 2560×1600 panel |
| `settings.lua` | Border colours | Blank | Any colours |
| `settings.lua` | `follow_mouse = 2` | Review | Hovering doesn't move keyboard focus; clicking does |
| `settings.lua` | Touchpad | Review | Natural scrolling, two-finger click for right click, no tap-to-click |
| `settings.lua` | `misc.vrr = 2` | Review | Variable refresh rate in fullscreen only |
| `settings.lua` | `xwayland.force_zero_scaling` | Review | Keeps X11 apps sharp on a fractional scale |
| `layout.lua` | Vertical focus wrap in scrolling | Review | Up/down wraps inside a column; left/right deliberately doesn't |
| `floating.lua` | What hides behind tiles | Review | Only windows from the floating rules, Super+Alt+Space or Super+P; app dialogs never hide |

Picture-in-picture is in the floating list, so it hides when a tile gets focus. Press Super+P once to keep it on top, or change its rule's tag from `+stashable` to `+ontop` in `rules.lua`.

## Check on real hardware

Nothing here has run on a real Hyprland. Each behaviour was checked against Hyprland 0.56.0's source or AeroSpace's docs, and a mock run only proved the Lua has no errors. `hyprctl` has a Lua REPL for poking at the API.

- [ ] The config loads with no error pop-up.
- [ ] Fn+Up / Fn+Down send Page Up / Page Down on the laptop's keyboard.
- [ ] Keyboard workspace switches are instant.
- [ ] The three-finger vertical swipe follows your fingers and slides vertically. If it runs backwards, set `gestures.workspace_swipe_invert`.
- [ ] Four-finger swipes: right goes to the latest workspace on the left, and the slide plays after you lift your fingers.
- [ ] Super+, changes the workspace's layout immediately.
- [ ] With two monitors, Super+1 to Super+9 brings a workspace over from the other monitor, which gets a new temporary workspace.
- [ ] Unplugging and replugging the external monitor sends its workspaces back to it.
- [ ] Focusing a tile hides the floats; Super+Alt+arrows brings them back; app dialogs never hide.
- [ ] Super+P cycles floating, on top, and on top everywhere.
- [ ] Super+Return toggles Ghostty's quick terminal above every window, pinned ones included.
- [ ] Super+Alt+Space re-tiles a window next to its old neighbour, on the same side in dwindle.
- [ ] On 3-code and 4-term, new windows join one tab group, and Super+Shift+arrows pulls one out into a split.
- [ ] In scrolling, Super+Ctrl+Up/Down changes window heights, Super+Shift+Left/Right moves a window between columns, Super+/ fits the visible columns, and Zen stays at 100%.
- [ ] Super+Shift+F in scrolling restores roughly the previous width. The estimate assumes the monitor's `width` field is in physical pixels, which couldn't be confirmed.
- [ ] On the Mac, the workspace keys find `nu` and `aerospace` through the PATH set in `aerospace.toml`.

## Passwords and 2FA

The plan for these machines: Bitwarden apps everywhere, on a self-hosted Vaultwarden server, with 2FA codes split between the vault and a separate authenticator. Vaultwarden implements nearly all of Bitwarden's client API; setup guides report it unlocks the paid features, built-in 2FA codes included, so check that on the server you use.

| Accounts | 2FA codes live in | Autofill |
| --- | --- | --- |
| Everyday accounts | The Bitwarden vault | Yes: the browser extension fills the code, or copies it to the clipboard |
| Email, bank, the vault itself | A separate authenticator app | No |

For the separate app, Google Authenticator works, as does Bitwarden Authenticator. On Android, Bitwarden Authenticator can sync codes with the Bitwarden app, but synced codes also live in the vault, so leave the high-value ones unsynced.

Fingerprint unlock on Linux needs the authentication agent from the first table. For the browser extension to unlock with the fingerprint too, Bitwarden recommends its Flatpak or Snap builds. The extension supports Chromium-based browsers and Firefox 87+; Zen is Firefox-based, so check it works. Try nixpkgs' `bitwarden-desktop` first, and switch to the Flatpak if the extension can't use the fingerprint.

Sources: Bitwarden help, [Unlock with biometrics](https://bitwarden.com/help/biometrics/), [Integrated authenticator](https://bitwarden.com/help/integrated-authenticator/), [Authenticator sync](https://bitwarden.com/help/totp-sync/); [Vaultwarden README](https://github.com/dani-garcia/vaultwarden).

## The Mac side

The key map, Mac column included, is in the README. Workspace keys run `nu ~/.config/aerospace/workspace.nu`, which assumes at most two monitors; `aerospace.toml` gives it a PATH that finds `nu` and `aerospace`. Normalizations are on (AeroSpace's default), and the Mac floating rules are kept from the previous config.

Two Linux features come from other apps, on keys AeroSpace leaves free. Super+P becomes Floaty Lite's own "pin or unpin the active window" shortcut, set to Cmd+Alt+P in Floaty. That gives two states instead of three, and it's untested whether a pinned window survives an AeroSpace workspace switch, since AeroSpace hides other workspaces' windows.

The drop-down terminal is Ghostty's quick terminal on Cmd+Alt+Return (lines in the README's install section). Global keybinds need Accessibility permission, and the rule that tiles every Ghostty window might grab it, so check.

Still no Mac equivalent: focusing floats only, hiding floats behind tiles, and gestures. AeroSpace has no dwindle, so building splits by hand stays in service mode (Cmd+Alt+Shift+; then an arrow joins with that neighbour).

While AeroSpace runs, these keys replace some macOS shortcuts (from memory): Cmd+Opt+F, search in some apps, and Cmd+Opt+- and =, the zoom keys if accessibility zoom is on.

Sources: [Floaty Lite on the App Store](https://apps.apple.com/us/app/floaty-lite-pin-windows/id6755633285?mt=12); Ghostty docs, [keybind actions](https://ghostty.org/docs/config/keybind/reference) and [options](https://ghostty.org/docs/config/reference).
