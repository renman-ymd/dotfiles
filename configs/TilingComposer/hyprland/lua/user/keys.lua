-- Key bindings. Letters, digits and punctuation are bound by physical position (code:N),
-- named after the QWERTY key there. Arrows, Page Up/Down, Tab, Return and Space use names.
local A = require("user.apps")
local D = require("user.defs")
local F = require("user.floating")
local L = require("user.layout")
local W = require("user.workspaces")

local function bind(keys, action, opts)
    hl.bind(keys, action, opts)
end

-- Arrows: focus, floating-only focus, move, swap / move column, resize.
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    bind("SUPER + " .. dir,               function() L.focus(dir) end)
    bind("SUPER + ALT + " .. dir,         function() F.focus_floating(dir) end)
    bind("SUPER + SHIFT + " .. dir,       function() L.move(dir) end)
    bind("SUPER + SHIFT + ALT + " .. dir, function() L.swap(dir) end)
    bind("SUPER + CTRL + " .. dir,        function() L.resize(dir) end, { repeating = true })
end

-- Fixed workspaces 1-9; 0 makes a new temporary one. Shift sends the window and follows it.
for n = 1, 9 do
    bind("SUPER + " .. D.code(tostring(n)),         function() W.go(n) end)
    bind("SUPER + SHIFT + " .. D.code(tostring(n)), function() W.send(n) end)
end
bind("SUPER + " .. D.code("0"),         W.go_new)
bind("SUPER + SHIFT + " .. D.code("0"), W.send_new)

-- Fn+Up / Fn+Down send Page Up / Page Down: previous / next workspace on this monitor.
bind("SUPER + Page_Up",   function() W.step(-1) end)
bind("SUPER + Page_Down", function() W.step(1) end)

-- Monitors: Tab swaps their workspaces; - and = focus, Shift sends the window over.
bind("SUPER + Tab",                       function() W.swap_monitors(false) end)
bind("SUPER + " .. D.code("minus"),         hl.dsp.focus({ monitor = "-1" }))
bind("SUPER + " .. D.code("equal"),         hl.dsp.focus({ monitor = "+1" }))
bind("SUPER + SHIFT + " .. D.code("minus"), hl.dsp.window.move({ monitor = "-1", follow = true }))
bind("SUPER + SHIFT + " .. D.code("equal"), hl.dsp.window.move({ monitor = "+1", follow = true }))

-- Layouts.
bind("SUPER + " .. D.code("comma"), W.cycle_layout)
bind("SUPER + " .. D.code("slash"), L.slash)
bind("SUPER + " .. D.code("r"),     L.widths)

-- Windows.
bind("SUPER + " .. D.code("w"),         hl.dsp.window.close())
bind("SUPER + " .. D.code("f"),         hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
bind("SUPER + SHIFT + " .. D.code("f"), L.maximize)
bind("SUPER + " .. D.code("p"),         F.cycle_on_top)
bind("SUPER + ALT + space",             F.toggle_float)

-- Apps.
bind("SUPER + space",  hl.dsp.exec_cmd(A.launcher))
bind("SUPER + Return", hl.dsp.global(A.quick_terminal)) -- Ghostty's quick terminal

-- Mouse: Super + left drag moves, Super + right drag resizes.
bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true })
bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop keys. They also work on the lock screen.
bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(A.volume_up),       { locked = true, repeating = true })
bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(A.volume_down),     { locked = true, repeating = true })
bind("XF86AudioMute",         hl.dsp.exec_cmd(A.volume_mute),     { locked = true })
bind("XF86AudioMicMute",      hl.dsp.exec_cmd(A.mic_mute),        { locked = true })
bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(A.brightness_up),   { locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(A.brightness_down), { locked = true, repeating = true })
