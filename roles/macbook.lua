-- Rola MacBook: oddaje lewy przy blokadzie/uśpieniu/zamknięciu klapy,
-- przejmuje przy odblokowaniu/wybudzeniu, odpytuje arbitra (Mini).
local m   = require("lib.monitor")
local log = m.log

local LEFT             = "F10F3853-1195-47E4-B1B9-EDA17BE38872"  -- lewy widziany z MacBooka (mini DP, input 16)
local POLL             = 2
local INFLIGHT_TIMEOUT = 15
local LID_DEBOUNCE     = 1.5

return function(cfg)
  local BASE, TOKEN = cfg.mini_url, cfg.token

  monitorActive = false
  local claimRetries = 0
  local inflight, inflightSince = false, 0

  local function haveLeft() return m.haveScreen(LEFT) end

  local function isLocked()
    local p = hs.caffeinate.sessionProperties()
    return p ~= nil and p.CGSSessionScreenIsLocked == true
  end

  local function get(path, cb)
    hs.http.asyncGet(BASE .. path .. "?token=" .. TOKEN, nil, function(status, body)
      if cb then cb(status, body) end
    end)
  end

  local function giveToMini(why)
    log.i("oddaję lewy Mini (input 15): " .. why)
    m.setInput(LEFT, 15)
  end

  local function claim(why)
    monitorActive = true
    claimRetries = 5
    log.i("przejmuję lewy: " .. why)
    get("/claim/macbook", function(s) log.i("claim/macbook -> " .. tostring(s)) end)
  end

  local function release(why)
    monitorActive = false
    claimRetries = 0
    giveToMini(why)
    get("/claim/mini", function(s) log.i("claim/mini -> " .. tostring(s)) end)
  end

  monitorWatcher = hs.caffeinate.watcher.new(function(e)
    local w = hs.caffeinate.watcher
    local name = m.eventName(e)
    if e == w.screensDidLock or e == w.screensDidSleep or e == w.systemWillSleep then
      release(name)
    elseif e == w.screensDidUnlock then
      claim(name)
    elseif e == w.screensDidWake or e == w.systemDidWake then
      local idle = hs.host.idleTime()
      if not isLocked() and idle < m.USER_IDLE then
        claim(name .. " bez blokady")
      else
        log.i(string.format("ignoruję %s (locked=%s, idle %.0fs)", name, tostring(isLocked()), idle))
      end
    end
  end)
  monitorWatcher:start()

  monitorPoll = hs.timer.doEvery(POLL, function()
    local now = hs.timer.secondsSinceEpoch()
    if inflight and (now - inflightSince) < INFLIGHT_TIMEOUT then return end
    inflight, inflightSince = true, now
    get("/owner", function(status, body)
      inflight = false
      if status ~= 200 then return end
      if body == "mini" and monitorActive and haveLeft() then
        monitorActive = false
        claimRetries = 0
        giveToMini("Mini wybudzony (owner=mini)")
      elseif body == "macbook" and monitorActive and claimRetries > 0 and not haveLeft() then
        claimRetries = claimRetries - 1
        log.i("ponawiam claim, zostało prób: " .. claimRetries)
        get("/claim/macbook")
      end
    end)
  end)

  local function lidClosed()
    local out = hs.execute("/usr/sbin/ioreg -r -k AppleClamshellState -d 1")
    return out:match('"AppleClamshellState" = Yes') ~= nil
  end

  monitorLidClosed = lidClosed()
  local lidCheckTimer = nil

  local function checkLid()
    local closed = lidClosed()
    if closed == monitorLidClosed then return end
    monitorLidClosed = closed
    if closed then
      release("klapa zamknięta")
    elseif not isLocked() then
      claim("klapa otwarta")
    else
      log.i("klapa otwarta, ekran zablokowany - czekam na odblokowanie")
    end
  end

  -- Zmiana konfiguracji ekranów przy zamknięciu/otwarciu klapy; ioreg potrafi
  -- się spóźnić względem zmiany ekranów, więc sprawdzamy z opóźnieniem (debounce).
  monitorScreenWatcher = hs.screen.watcher.new(function()
    if lidCheckTimer then lidCheckTimer:stop() end
    lidCheckTimer = hs.timer.doAfter(LID_DEBOUNCE, checkLid)
  end)
  monitorScreenWatcher:start()
  log.i("klapa przy starcie: " .. (monitorLidClosed and "zamknięta" or "otwarta"))

  if not isLocked() and hs.host.idleTime() < m.START_IDLE then
    claim("start Hammerspoona")
  else
    monitorActive = haveLeft() and not isLocked()
    log.i("przeładowanie bez aktywności: monitorActive=" .. tostring(monitorActive))
  end
end
