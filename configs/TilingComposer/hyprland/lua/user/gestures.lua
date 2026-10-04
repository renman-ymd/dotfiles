-- Trackpad gestures.
local W = require("user.workspaces")

-- Three fingers, vertical: previous / next workspace open on this monitor, following
-- your fingers (Hyprland's own swipe). Swap the direction with gestures.workspace_swipe_invert.
hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })

-- Three fingers, horizontal: scroll the strip on scrolling workspaces; nothing elsewhere.
hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })

-- Four fingers, horizontal: history. Swiping right goes to the latest workspace to the left
-- of this one, swiping left to the latest one to the right, so alternating bounces between two.
hl.gesture({ fingers = 4, direction = "right", action = function() W.history_jump("left") end })
hl.gesture({ fingers = 4, direction = "left",  action = function() W.history_jump("right") end })

-- Four fingers, vertical: swap the two monitors' workspaces.
hl.gesture({ fingers = 4, direction = "vertical", action = function() W.swap_monitors(true) end })
