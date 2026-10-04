-- What the window keys do in each layout, and tab groups on 3-code and 4-term.
local D = require("user.defs")
local U = require("user.util")

local L = {}

local function layout_of(ws)
    return ws and ws.tiled_layout or D.temporary_layout
end

local function active()
    return hl.get_active_workspace(), hl.get_active_window()
end

----------------------------------------------------------------------------
-- Super+arrows: focus. Skips floating windows; wraps around, except left/right
-- in scrolling. From a floating window, goes back to the last tiled one.
----------------------------------------------------------------------------

function L.focus(dir)
    local ws, w = active()
    if not ws then return end
    if not w or w.floating then
        local t = U.last_tiled(ws)
        if t then U.focus(t) end
        return
    end

    local layout = layout_of(ws)
    if layout == "monocle" then
        hl.dispatch(hl.dsp.layout((dir == "left" or dir == "up") and "cycleprev" or "cyclenext"))
        return
    end
    if layout == "scrolling" and U.horizontal(dir) then
        hl.dispatch(hl.dsp.layout("focus " .. U.short[dir])) -- stops at the ends (wrap_focus = false)
        return
    end

    -- Hyprland's own directional focus (it also moves between tabs of a group).
    hl.dispatch(hl.dsp.focus({ direction = dir }))
    local now = hl.get_active_window()
    if now and now.address ~= w.address and not now.floating then return end
    if now and now.floating then U.focus(w) end -- never land on a float

    -- Nothing that way: wrap to the far side.
    local target = U.farthest(w, U.tiled_on(ws), dir, true)
    if target then U.focus(target) end
end

----------------------------------------------------------------------------
-- Super+Shift+arrows: move the window.
----------------------------------------------------------------------------

function L.move(dir)
    local ws, w = active()
    if not ws or not w or w.floating then return end
    local layout = layout_of(ws)
    if layout == "scrolling" then
        if U.horizontal(dir) then
            -- into the neighbouring column, or out into a new one if it shares its column
            hl.dispatch(hl.dsp.layout("consume_or_expel " .. (dir == "left" and "prev" or "next")))
        else
            hl.dispatch(hl.dsp.window.swap({ direction = dir }))
        end
    elseif layout == "dwindle" then
        -- lifts the window and re-inserts it in that direction; can enter and leave tab groups
        hl.dispatch(hl.dsp.window.move({ direction = dir, group_aware = true }))
    elseif layout == "master" then
        hl.dispatch(hl.dsp.window.swap({ direction = dir }))
    end
    -- monocle: windows have no positions to move between
end

----------------------------------------------------------------------------
-- Super+Shift+Alt+arrows: swap two windows (keeps the tree), or move the whole column.
----------------------------------------------------------------------------

function L.swap(dir)
    local ws, w = active()
    if not ws or not w or w.floating then return end
    local layout = layout_of(ws)
    if layout == "scrolling" and U.horizontal(dir) then
        hl.dispatch(hl.dsp.layout("swapcol " .. U.short[dir]))
    elseif layout ~= "monocle" then
        hl.dispatch(hl.dsp.window.swap({ direction = dir }))
    end
end

----------------------------------------------------------------------------
-- Super+Ctrl+arrows: resize. Right and down grow, left and up shrink.
----------------------------------------------------------------------------

local STEP_PX, STEP_FRACTION = 40, 0.05

function L.resize(dir)
    local ws, w = active()
    if not ws or not w then return end
    local layout = layout_of(ws)
    local grow = dir == "right" or dir == "down"
    local horizontal = U.horizontal(dir)

    if layout == "scrolling" and horizontal and not w.floating then
        hl.dispatch(hl.dsp.layout(string.format("colresize %+.2f", grow and STEP_FRACTION or -STEP_FRACTION)))
    elseif layout == "master" and horizontal and not w.floating then
        hl.dispatch(hl.dsp.layout(string.format("mfact %.2f", grow and STEP_FRACTION or -STEP_FRACTION)))
    elseif layout ~= "monocle" or w.floating then
        local d = grow and STEP_PX or -STEP_PX
        hl.dispatch(hl.dsp.window.resize({ x = horizontal and d or 0, y = horizontal and 0 or d, relative = true }))
    end
end

----------------------------------------------------------------------------
-- Super+/ : dwindle toggles the split, scrolling fits the visible columns to the
-- screen, master swaps with the master window.
----------------------------------------------------------------------------

function L.slash()
    local layout = layout_of(hl.get_active_workspace())
    if layout == "dwindle" then
        hl.dispatch(hl.dsp.layout("togglesplit"))
    elseif layout == "scrolling" then
        hl.dispatch(hl.dsp.layout("fit visible"))
    elseif layout == "master" then
        hl.dispatch(hl.dsp.layout("swapwithmaster"))
    end
end

-- Super+R: cycle column widths 1/3, 1/2, 2/3, 1 (scrolling only).
function L.widths()
    if layout_of(hl.get_active_workspace()) == "scrolling" then
        hl.dispatch(hl.dsp.layout("colresize +conf"))
    end
end

----------------------------------------------------------------------------
-- Super+Shift+F: maximize. In scrolling, toggles the column between 100% and its
-- previous width (estimated from the window's size); elsewhere, Hyprland's maximize.
----------------------------------------------------------------------------

local saved_width = {} -- window address -> column fraction before going full width

function L.maximize()
    local ws, w = active()
    if not ws or not w then return end
    if layout_of(ws) ~= "scrolling" or w.floating then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
        return
    end
    local previous = saved_width[w.address]
    if previous then
        saved_width[w.address] = nil
        hl.dispatch(hl.dsp.layout(string.format("colresize %.3f", previous)))
    else
        local fraction = 0.5
        local m = w.monitor
        if m and m.width and m.scale and m.width > 0 then
            fraction = math.max(0.1, math.min(1, w.size.x / (m.width / m.scale)))
        end
        saved_width[w.address] = fraction
        hl.dispatch(hl.dsp.layout("colresize 1.0"))
    end
end

hl.on("window.close", function(w)
    if w then saved_width[w.address] = nil end
end)

----------------------------------------------------------------------------
-- 3-code and 4-term: dwindle whose windows stack in one tab group.
-- group:auto_group adds new windows to the focused group; this starts the group
-- and catches windows opened while focus was elsewhere.
----------------------------------------------------------------------------

hl.on("window.open", function(w)
    if not w or w.floating then return end
    local ws = w.workspace
    if not ws or not D.stacked[ws.id] or w.group then return end
    local address = w.address
    hl.timer(function() -- let the layout place the window first
        local win = hl.get_window("address:" .. address)
        if not win or win.floating or win.group then return end
        for _, x in ipairs(U.tiled_on(win.workspace)) do
            if x.address ~= address and x.group then
                hl.dispatch(hl.dsp.window.move({ into_group = U.direction_to(win, x), window = U.sel(win) }))
                return
            end
        end
        hl.dispatch(hl.dsp.group.toggle({ window = U.sel(win) }))
    end, { timeout = 50, type = "oneshot" })
end)

return L
