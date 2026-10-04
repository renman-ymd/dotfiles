-- Small helpers shared by the other modules.
local U = {}

-- Dispatcher selector for one window.
function U.sel(w)
    return "address:" .. w.address
end

-- Tags set at runtime carry a trailing "*"; accept both forms.
function U.has_tag(w, tag)
    for _, t in ipairs(w.tags or {}) do
        if t == tag or t == tag .. "*" then return true end
    end
    return false
end

function U.tag(w, tag)   -- "+name" sets, "-name" clears
    hl.dispatch(hl.dsp.window.tag({ tag = tag, window = U.sel(w) }))
end

function U.focus(w)
    hl.dispatch(hl.dsp.focus({ window = U.sel(w) }))
end

function U.raise(w)
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = U.sel(w) }))
end

function U.notify(text)
    hl.notification.create({ text = text, timeout = 1200 })
end

-- Visible windows on a workspace, optionally filtered.
function U.windows_on(ws, keep)
    local out = {}
    if not ws then return out end
    for _, w in ipairs(hl.get_workspace_windows(ws)) do
        if not w.hidden and (keep == nil or keep(w)) then out[#out + 1] = w end
    end
    return out
end

function U.tiled_on(ws)
    return U.windows_on(ws, function(w) return not w.floating end)
end

function U.floating_on(ws)
    return U.windows_on(ws, function(w) return w.floating end)
end

-- Most recently focused window of a list (focus_history_id 0 = most recent, -1 = never).
function U.most_recent(list)
    local best
    for _, w in ipairs(list) do
        local id = w.focus_history_id
        if id >= 0 and (not best or id < best.focus_history_id) then best = w end
    end
    return best or list[1]
end

function U.last_tiled(ws)
    return U.most_recent(U.tiled_on(ws))
end

----------------------------------------------------------------------------
-- Animation: only workspace changes animate, and only swipes keep it.
----------------------------------------------------------------------------

-- Workspace slide used by swipes and the scripted history swipe.
U.workspace_animation = {
    leaf = "workspaces", enabled = true, speed = 2.5, bezier = "easeOutQuint", style = "slidevert",
}

-- Run `fn` with the workspace animation off, so a keyboard switch is instant.
function U.instant(fn)
    hl.animation({ leaf = "workspaces", enabled = false })
    local ok, err = pcall(fn)
    hl.timer(function() hl.animation(U.workspace_animation) end, { timeout = 60, type = "oneshot" })
    if not ok then error(err, 0) end
end

----------------------------------------------------------------------------
-- Geometry, for focus and wrap-around.
----------------------------------------------------------------------------

U.short = { left = "l", right = "r", up = "u", down = "d" }

function U.horizontal(dir)
    return dir == "left" or dir == "right"
end

local function box(w)
    return { x1 = w.at.x, y1 = w.at.y, x2 = w.at.x + w.size.x, y2 = w.at.y + w.size.y,
             cx = w.at.x + w.size.x / 2, cy = w.at.y + w.size.y / 2 }
end

-- How much a and b overlap across the direction of travel.
local function cross_overlap(a, b, dir)
    if U.horizontal(dir) then
        return math.min(a.y2, b.y2) - math.max(a.y1, b.y1)
    end
    return math.min(a.x2, b.x2) - math.max(a.x1, b.x1)
end

-- Nearest window from `from` in `dir`, or nil.
function U.nearest(from, list, dir)
    local f, best, best_score = box(from), nil, nil
    for _, w in ipairs(list) do
        if w.address ~= from.address then
            local b = box(w)
            local ahead =
                (dir == "right" and b.cx > f.cx) or (dir == "left" and b.cx < f.cx) or
                (dir == "down" and b.cy > f.cy) or (dir == "up" and b.cy < f.cy)
            if ahead then
                local along = U.horizontal(dir) and math.abs(b.cx - f.cx) or math.abs(b.cy - f.cy)
                local across = U.horizontal(dir) and math.abs(b.cy - f.cy) or math.abs(b.cx - f.cx)
                local score = along + across * (cross_overlap(f, b, dir) > 0 and 0.1 or 1.5)
                if not best_score or score < best_score then best, best_score = w, score end
            end
        end
    end
    return best
end

-- Wrap-around: the window farthest on the opposite side. With `aligned_only`, only windows
-- in the same row (left/right) or column (up/down) count, so a wrap never jumps sideways.
function U.farthest(from, list, dir, aligned_only)
    local f, best, best_key = box(from), nil, nil
    for _, w in ipairs(list) do
        if w.address ~= from.address then
            local b = box(w)
            local aligned = cross_overlap(f, b, dir) > 0
            if aligned or not aligned_only then
                local edge = ({ right = -b.cx, left = b.cx, down = -b.cy, up = b.cy })[dir]
                local key = (aligned and 1e9 or 0) + edge
                if not best_key or key > best_key then best, best_key = w, key end
            end
        end
    end
    return best
end

-- Which side of `n` window `w` sits on ("l", "r", "u", "d") and the gap between them,
-- when they share an edge; nil otherwise.
function U.side_of(n, w)
    local a, b = box(n), box(w)
    local tol = 40
    if cross_overlap(a, b, "left") > 0 then
        if b.x1 >= a.x2 - tol then return "r", b.x1 - a.x2 end
        if b.x2 <= a.x1 + tol then return "l", a.x1 - b.x2 end
    end
    if cross_overlap(a, b, "up") > 0 then
        if b.y1 >= a.y2 - tol then return "d", b.y1 - a.y2 end
        if b.y2 <= a.y1 + tol then return "u", a.y1 - b.y2 end
    end
    return nil
end

-- Rough direction from window a to window b.
function U.direction_to(a, b)
    local p, q = box(a), box(b)
    local dx, dy = q.cx - p.cx, q.cy - p.cy
    if math.abs(dx) >= math.abs(dy) then return dx >= 0 and "r" or "l" end
    return dy >= 0 and "d" or "u"
end

return U
