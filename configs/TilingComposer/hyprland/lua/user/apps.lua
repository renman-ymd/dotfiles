-- Apps and window classes. Every TODO is yours to fill once you've picked the program.
-- Read a window's class with `hyprctl clients` while it's open. Classes are regexes.
local A = {}

-- Super+Space: the Spotlight-like launcher.
A.launcher = "TODO-launcher"

-- Super+Return toggles Ghostty's quick terminal through the global shortcut Ghostty
-- registers for `keybind = global:super+enter=toggle_quick_terminal` in its config.
-- TODO: confirm the ID with `hyprctl globalshortcuts` while Ghostty is running.
A.quick_terminal = "com.mitchellh.ghostty:LOGO+Return"

-- Started at login without a window, so the quick terminal is always available.
-- Needs `quit-after-last-window-closed = false` in Ghostty's config.
A.terminal_daemon = "ghostty --initial-window=false"

-- Zen keeps a 100% column in scrolling workspaces, so a second window never shrinks it.
A.zen_class = "^TODO-zen$"

-- Floating apps: your Mac list translated. Uncomment and fill each one.
-- They float, and floating.lua hides them when you focus a tiled window.
A.floating = {
    -- { name = "settings",           class = "^TODO$" },
    -- { name = "calculator",         class = "^TODO$" },
    -- { name = "clipboard-history",  class = "^TODO$" },
    -- { name = "file-manager",       class = "^TODO$" },
    -- { name = "image-viewer",       class = "^TODO$" },
    -- { name = "pavucontrol",        class = "^TODO$" },
    -- { name = "pinentry",           class = "^TODO$" },
    -- { name = "password-popup",     class = "^TODO$" },
    -- { name = "picture-in-picture", title = "^TODO$" },
}

-- Laptop keys (from Hyprland's example config; needs wpctl and brightnessctl).
A.volume_up       = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
A.volume_down     = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
A.volume_mute     = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
A.mic_mute        = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
A.brightness_up   = "brightnessctl -e4 -n2 set 5%+"
A.brightness_down = "brightnessctl -e4 -n2 set 5%-"

return A
