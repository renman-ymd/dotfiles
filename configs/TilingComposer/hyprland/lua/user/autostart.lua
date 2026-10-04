-- Programs started at login. Add your bar, notification daemon, polkit agent and
-- the rest here once you've chosen them (see the doc).
local A = require("user.apps")

hl.on("hyprland.start", function()
    hl.dispatch(hl.dsp.exec_cmd(A.terminal_daemon)) -- Ghostty, for its quick terminal
end)
