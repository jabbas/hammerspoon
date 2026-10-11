-- Część wspólna przełączania lewego monitora (obie role).
local M = {}

M.M1DDC      = "/opt/homebrew/bin/m1ddc"
M.PORT       = 8765
M.USER_IDLE  = 5    -- s: zdarzenie uznajemy za wywołane przez użytkownika
M.START_IDLE = 30   -- s: przy ładowaniu configu
M.log        = hs.logger.new("monitor", "info")

local EVENT_NAMES = {}
for k, v in pairs(hs.caffeinate.watcher) do
  if type(v) == "number" then EVENT_NAMES[v] = k end
end

function M.eventName(e)
  return tostring(EVENT_NAMES[e])
end

function M.haveScreen(uuid)
  for _, s in ipairs(hs.screen.allScreens()) do
    if s:getUUID() == uuid then return true end
  end
  return false
end

function M.setInput(uuid, input)
  hs.execute(M.M1DDC .. " display " .. uuid .. " set input " .. input)
end

return M
