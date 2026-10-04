-- Fixed and temporary workspaces, history, monitor memory, layout cycling.
local D = require("user.defs")
local U = require("user.util")

local W = {}

-- Smallest unused ID from 10 up: a new temporary workspace.
function W.free_temporary()
    local used = {}
    for _, ws in ipairs(hl.get_workspaces()) do used[ws.id] = true end
    local id = D.first_temporary
    while used[id] do id = id + 1 end
    return id
end

-- Show workspace `id` on the focused monitor. If another monitor is showing it, that monitor
-- first moves to a new temporary workspace, so nothing is swapped or swallowed.
local function pull_here(id)
    local here   = hl.get_active_monitor()
    local target = hl.get_workspace(id)
    if here and target and target.visible and target.monitor and target.monitor.id ~= here.id then
        hl.dispatch(hl.dsp.focus({ monitor = target.monitor.name }))
        hl.dispatch(hl.dsp.focus({ workspace = W.free_temporary() }))
        hl.dispatch(hl.dsp.focus({ monitor = here.name }))
    end
    hl.dispatch(hl.dsp.focus({ workspace = id, on_current_monitor = true }))
end

-- Keyboard: instant. animate = true for swipes.
function W.go(id, animate)
    if animate then pull_here(id) else U.instant(function() pull_here(id) end) end
end

function W.go_new()
    W.go(W.free_temporary())
end

-- Send the focused window to `id` and follow it there.
function W.send(id)
    local w = hl.get_active_window()
    if not w then return end
    hl.dispatch(hl.dsp.window.move({ workspace = id, follow = false, window = U.sel(w) }))
    W.go(id)
    U.focus(w)
end

function W.send_new()
    W.send(W.free_temporary())
end

-- Fn+Up / Fn+Down: previous or next workspace open on this monitor.
function W.step(delta)
    U.instant(function()
        hl.dispatch(hl.dsp.focus({ workspace = delta < 0 and "m-1" or "m+1" }))
    end)
end

-- Super+Tab and the four-finger vertical swipe: swap the two monitors' workspaces.
function W.swap_monitors(animate)
    local here = hl.get_active_monitor()
    if not here then return end
    local other
    for _, m in ipairs(hl.get_monitors()) do
        if m.id ~= here.id then other = m; break end
    end
    if not other then return end
    local run = function()
        hl.dispatch(hl.dsp.workspace.swap_monitors({ monitor1 = here.name, monitor2 = other.name }))
    end
    if animate then run() else U.instant(run) end
end

----------------------------------------------------------------------------
-- History, for the four-finger horizontal swipes.
----------------------------------------------------------------------------

local history = {} -- workspace IDs, most recent first

local function remember(id)
    for i = #history, 1, -1 do
        if history[i] == id then table.remove(history, i) end
    end
    table.insert(history, 1, id)
    if #history > 50 then table.remove(history) end
end

-- side "left": the most recent workspace with a smaller ID; "right": with a larger one.
-- Swiping right goes left and the other way round, so alternating swipes bounce between two.
-- A script can't follow your fingers, so the slide plays once the swipe ends.
function W.history_jump(side)
    local cur = hl.get_active_workspace()
    if not cur then return end
    for _, id in ipairs(history) do
        local wanted = (side == "left" and id < cur.id) or (side == "right" and id > cur.id)
        if wanted and hl.get_workspace(id) then
            W.go(id, true)
            return
        end
    end
end

----------------------------------------------------------------------------
-- Monitor memory: a workspace returns to its monitor when that monitor reconnects.
----------------------------------------------------------------------------

local home = {} -- workspace ID -> monitor key

local function monitor_key(m)
    if m.description and m.description ~= "" then return m.description end
    return m.name
end

local function connected(key)
    for _, m in ipairs(hl.get_monitors()) do
        if monitor_key(m) == key then return m end
    end
    return nil
end

----------------------------------------------------------------------------
-- Super+, : cycle the focused workspace's layout.
----------------------------------------------------------------------------

local temporary_rules = {} -- workspace ID -> rule handle, dropped when the workspace goes away

function W.cycle_layout()
    local ws = hl.get_active_workspace()
    if not ws then return end
    local index = 0
    for i, name in ipairs(D.layout_cycle) do
        if name == ws.tiled_layout then index = i end
    end
    local next_layout = D.layout_cycle[index % #D.layout_cycle + 1]
    -- A rule for the same workspace merges into the existing one and re-applies layouts live.
    local rule = hl.workspace_rule({ workspace = tostring(ws.id), layout = next_layout })
    if ws.id >= D.first_temporary then temporary_rules[ws.id] = rule end
    U.notify(ws.name .. ": " .. next_layout)
end

----------------------------------------------------------------------------
-- Events.
----------------------------------------------------------------------------

hl.on("workspace.active", function(ws)
    if ws and not ws.special then remember(ws.id) end
end)

hl.on("workspace.created", function(ws)
    if ws and not ws.special and ws.monitor and not home[ws.id] then
        home[ws.id] = monitor_key(ws.monitor)
    end
end)

hl.on("workspace.removed", function(ws)
    local ok, id = pcall(function() return ws.id end)
    if not ok or not id then return end
    home[id] = nil
    if temporary_rules[id] then
        temporary_rules[id]:set_enabled(false)
        temporary_rules[id] = nil
    end
end)

-- A user move updates a workspace's home. When a monitor unplugs, Hyprland moves its
-- workspaces away; waiting a moment tells the two apart: if the old home is gone by then,
-- it was an evacuation and the home is kept.
hl.on("workspace.move_to_monitor", function(ws, m)
    if not ws or ws.special or not m then return end
    local id, key = ws.id, monitor_key(m)
    hl.timer(function()
        local h = home[id]
        if h == nil or connected(h) then home[id] = key end
    end, { timeout = 300, type = "oneshot" })
end)

-- A monitor coming back takes its workspaces back; a new one starts on a new temporary workspace.
hl.on("monitor.added", function(m)
    local key, name = monitor_key(m), m.name
    hl.timer(function()
        local restored = false
        for id, h in pairs(home) do
            if h == key and hl.get_workspace(id) then
                hl.dispatch(hl.dsp.workspace.move({ workspace = id, monitor = name }))
                restored = true
            end
        end
        if not restored then
            local here = hl.get_active_monitor()
            hl.dispatch(hl.dsp.focus({ monitor = name }))
            hl.dispatch(hl.dsp.focus({ workspace = W.free_temporary() }))
            if here and here.name ~= name then hl.dispatch(hl.dsp.focus({ monitor = here.name })) end
        end
    end, { timeout = 300, type = "oneshot" })
end)

-- Seed state for what already exists (also after a config reload).
for _, ws in ipairs(hl.get_workspaces()) do
    if not ws.special and ws.monitor then home[ws.id] = monitor_key(ws.monitor) end
end
local start = hl.get_active_workspace()
if start then remember(start.id) end

return W
