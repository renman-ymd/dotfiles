-- Constants shared by the other modules.
local D = {}

-- The nine fixed workspaces, on keys 1-9. Temporary workspaces start at ID 10.
D.fixed = {
    { id = 1, name = "1-Claude", layout = "master" },
    { id = 2, name = "2-web",    layout = "scrolling" },
    { id = 3, name = "3-code",   layout = "dwindle", stacked = true }, -- windows join one tab group
    { id = 4, name = "4-term",   layout = "dwindle", stacked = true }, -- windows join one tab group
    { id = 5, name = "5-chat",   layout = "scrolling" },
    { id = 6, name = "6-media",  layout = "scrolling" },
    { id = 7, name = "7-notes",  layout = "monocle" },
    { id = 8, name = "8-misc",   layout = "dwindle" },
    { id = 9, name = "9-Gaming", layout = "monocle" },
}

D.first_temporary = 10
D.temporary_layout = "scrolling" -- also general.layout: any workspace without a rule uses it

-- Order of Super+, (cycle the focused workspace's layout).
D.layout_cycle = { "scrolling", "dwindle", "master", "monocle" }

D.stacked = {}
for _, w in ipairs(D.fixed) do
    if w.stacked then D.stacked[w.id] = true end
end

-- Physical key positions (xkb keycodes), named after the QWERTY key at that spot.
-- Binding by position keeps every shortcut in place whatever layout you type in.
D.keycode = {
    ["1"] = 10, ["2"] = 11, ["3"] = 12, ["4"] = 13, ["5"] = 14,
    ["6"] = 15, ["7"] = 16, ["8"] = 17, ["9"] = 18, ["0"] = 19,
    minus = 20, equal = 21,
    w = 25, r = 27, p = 33, f = 41,
    comma = 59, slash = 61,
}

function D.code(name)
    return "code:" .. D.keycode[name]
end

return D
