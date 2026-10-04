-- Floating windows: hiding them behind tiles, the Super+P cycle, the float toggle
-- that returns a window to its spot, and focus among floats.
-- (The scratch terminal is Ghostty's quick terminal: a layer above every window, see keys.lua.)
local U = require("user.util")

local F = {}

local STASH = "special:float-stash" -- hidden floats wait here

local origin     = {}    -- window address -> workspace ID it was hidden from
local home_spot  = {}    -- window address -> where to re-tile it
local busy       = false -- our own moves fire focus events; ignore them

----------------------------------------------------------------------------
-- Hiding: focusing a tiled window hides the workspace's ordinary floats.
-- Only "stashable" windows (your floating rules, Super+Alt+Space) are hidden,
-- never app dialogs; "on top" and pinned windows stay.
----------------------------------------------------------------------------

local function stash(ws)
    busy = true
    for _, x in ipairs(U.floating_on(ws)) do
        if U.has_tag(x, "stashable") and not U.has_tag(x, "ontop") and not x.pinned then
            origin[x.address] = ws.id
            hl.dispatch(hl.dsp.window.move({ workspace = STASH, follow = false, window = U.sel(x) }))
        end
    end
    busy = false
end

function F.unstash(ws)
    busy = true
    for _, x in ipairs(hl.get_windows()) do
        if origin[x.address] == ws.id then
            origin[x.address] = nil
            hl.dispatch(hl.dsp.window.move({ workspace = ws.id, follow = false, window = U.sel(x) }))
        end
    end
    busy = false
end

-- Keep "on top" floats above the others.
local function restack(ws)
    busy = true
    for _, x in ipairs(U.floating_on(ws)) do
        if U.has_tag(x, "ontop") and not x.pinned then U.raise(x) end
    end
    busy = false
end

hl.on("window.active", function(w)
    if busy or not w then return end
    local ws = w.workspace
    if not ws or ws.special then return end
    if not w.floating then stash(ws) end
    restack(ws)
end)

hl.on("window.close", function(w)
    if not w then return end
    origin[w.address], home_spot[w.address] = nil, nil
end)

----------------------------------------------------------------------------
-- Super+Alt+arrows: focus among floating windows only (brings hidden ones back first).
----------------------------------------------------------------------------

function F.focus_floating(dir)
    local ws = hl.get_active_workspace()
    if not ws then return end
    F.unstash(ws)
    local floats = U.floating_on(ws)
    if #floats == 0 then return end
    local cur = hl.get_active_window()
    local target
    if cur and cur.floating then
        target = U.nearest(cur, floats, dir) or U.farthest(cur, floats, dir)
    else
        target = (cur and U.nearest(cur, floats, dir)) or U.most_recent(floats)
    end
    if target then
        U.focus(target)
        U.raise(target)
    end
end

----------------------------------------------------------------------------
-- Super+P: floating -> on top (this workspace) -> on top everywhere (pinned) -> floating.
-- On a tiled window, the first press floats it straight into "on top".
----------------------------------------------------------------------------

function F.cycle_on_top()
    local w = hl.get_active_window()
    if not w then return end
    local s = U.sel(w)
    if not w.floating then
        hl.dispatch(hl.dsp.window.float({ action = "enable", window = s }))
        U.tag(w, "+stashable")
        U.tag(w, "+ontop")
        U.raise(w)
        U.notify("On top")
    elseif w.pinned then
        hl.dispatch(hl.dsp.window.pin({ action = "disable", window = s }))
        U.tag(w, "-ontop")
        U.notify("Floating")
    elseif U.has_tag(w, "ontop") then
        hl.dispatch(hl.dsp.window.pin({ action = "enable", window = s }))
        U.notify("On top on every workspace")
    else
        U.tag(w, "+ontop")
        U.raise(w)
        U.notify("On top")
    end
end

----------------------------------------------------------------------------
-- Super+Alt+Space: float or tile. Re-tiling goes back next to the neighbour the
-- window had (dwindle: same side, via preselect; other layouts: next to it).
----------------------------------------------------------------------------

local function spot_of(w)
    local best, best_gap, best_side
    for _, n in ipairs(U.tiled_on(w.workspace)) do
        if n.address ~= w.address then
            local side, gap = U.side_of(n, w)
            if side and (not best_gap or gap < best_gap) then best, best_gap, best_side = n, gap, side end
        end
    end
    if best then return { neighbour = best.address, side = best_side, ws = w.workspace.id } end
    return nil
end

function F.toggle_float()
    local w = hl.get_active_window()
    if not w then return end
    if not w.floating then
        home_spot[w.address] = spot_of(w)
        hl.dispatch(hl.dsp.window.float({ action = "enable", window = U.sel(w) }))
        U.tag(w, "+stashable")
        return
    end
    local spot = home_spot[w.address]
    home_spot[w.address] = nil
    busy = true
    if spot and w.workspace and spot.ws == w.workspace.id then
        local n = hl.get_window("address:" .. spot.neighbour)
        if n and not n.floating then
            U.focus(n)
            if w.workspace.tiled_layout == "dwindle" then
                hl.dispatch(hl.dsp.layout("preselect " .. spot.side))
            end
        end
    end
    if w.pinned then hl.dispatch(hl.dsp.window.pin({ action = "disable", window = U.sel(w) })) end
    U.tag(w, "-stashable")
    U.tag(w, "-ontop")
    hl.dispatch(hl.dsp.window.float({ action = "disable", window = U.sel(w) }))
    U.focus(w)
    busy = false
end

return F
