-- Always-on-top toggle via polling

local pinnedWindows = {}

local raiseTimer = hs.timer.new(0.1, function()
  for id in pairs(pinnedWindows) do
    local win = hs.window(id)
    if win then
      win:raise()
    else
      pinnedWindows[id] = nil -- clean up closed windows
    end
  end
end, true)

local function togglePin()
  local win = hs.window.focusedWindow()
  if not win then return end

  local id = win:id()
  local app = win:application():name() or "window"

  if pinnedWindows[id] then
    pinnedWindows[id] = nil
    hs.alert.show("Unpinned: " .. app)
  else
    pinnedWindows[id] = true
    win:raise()
    hs.alert.show("Pinned: " .. app)
  end

  -- Only poll while something is pinned
  if next(pinnedWindows) ~= nil then
    if not raiseTimer:running() then raiseTimer:start() end
  else
    raiseTimer:stop()
  end
end

hs.hotkey.bind({ "alt", "ctrl", "cmd" }, "T", togglePin)
