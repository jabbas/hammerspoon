-- Rola Mac mini: arbiter "ostatnio wybudzony wygrywa", serwer HTTP.
local m   = require("lib.monitor")
local log = m.log

local LEFT = "1B5F0426-EFF5-4986-ABCE-67B1F3E2FF67"  -- lewy widziany z Miniego (DP, input 15)

return function(cfg)
  local TOKEN = cfg.token

  local function setOwner(who, why)
    if monitorOwner ~= who then
      log.i(string.format("owner %s -> %s (%s)", tostring(monitorOwner), who, why))
    end
    monitorOwner = who
  end

  local function giveToMacBook()
    log.i("oddaję lewy MacBookowi (input 16)")
    m.setInput(LEFT, 16)
  end

  monitorServer = hs.httpserver.new(false, false)
  monitorServer:setPort(m.PORT)
  monitorServer:setCallback(function(method, path)
    local route, tok = path:match("^([^?]+)%?token=(.+)$")
    if tok ~= TOKEN then return "nope", 403, {} end
    if route == "/owner" then
      return monitorOwner, 200, {}
    elseif route == "/claim/macbook" then
      setOwner("macbook", "MacBook przejmuje")
      giveToMacBook()
      return "ok", 200, {}
    elseif route == "/claim/mini" then
      setOwner("mini", "MacBook oddał")
      return "ok", 200, {}
    end
    return "not found", 404, {}
  end)
  monitorServer:start()

  monitorWatcher = hs.caffeinate.watcher.new(function(e)
    local w = hs.caffeinate.watcher
    if e == w.screensDidWake or e == w.screensDidUnlock or e == w.systemDidWake then
      local idle = hs.host.idleTime()
      if idle < m.USER_IDLE then
        setOwner("mini", "Mini: " .. m.eventName(e))
      else
        log.i(string.format("ignoruję %s (idle %.0fs, brak aktywności użytkownika)", m.eventName(e), idle))
      end
    end
  end)
  monitorWatcher:start()

  if hs.host.idleTime() < m.START_IDLE then
    setOwner("mini", "start Hammerspoona")
  else
    setOwner(m.haveScreen(LEFT) and "mini" or "macbook", "przeładowanie bez aktywności (stan faktyczny)")
  end
end
