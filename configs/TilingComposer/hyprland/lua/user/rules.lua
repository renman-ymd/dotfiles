-- Workspace and window rules.
local D = require("user.defs")
local A = require("user.apps")

-- Fixed workspaces: names and starting layouts. They aren't persistent, so empty ones
-- disappear and Fn+arrows and swipes skip them; your bar can still list all nine.
for _, w in ipairs(D.fixed) do
    hl.workspace_rule({ workspace = tostring(w.id), default_name = w.name, layout = w.layout })
end

-- Zen keeps a full-width column, so opening a second window never shrinks it.
hl.window_rule({ name = "zen-full-width", match = { class = A.zen_class }, scrolling_width = 1.0 })

-- Your floating apps. "stashable" lets floating.lua hide them when you focus a tiled window;
-- app dialogs never get it, so they never vanish.
for _, f in ipairs(A.floating) do
    local match = {}
    if f.class then match.class = f.class end
    if f.title then match.title = f.title end
    hl.window_rule({ name = "float-" .. f.name, match = match, float = true, tag = "+stashable" })
end

-- From Hyprland's example config: ignore apps that ask to maximize themselves,
-- and fix XWayland drag-and-drop leaving invisible windows behind.
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})
