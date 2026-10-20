-- Punkt wejścia. Przełączanie monitorów: Spoon DisplayKVM (submoduł Spoons/DisplayKVM.spoon).
-- Nazwa węzła i sekret grupy: localconfig.lua (poza gitem).
require("hs.ipc")  -- zawsze pierwsze, żeby działało `hs -c`

local log = hs.logger.new("config", "info")

local function fail(msg)
  log.e(msg)
  hs.notify.new({ title = "Hammerspoon", informativeText = msg }):send()
end

local ok, lc = pcall(dofile, hs.configdir .. "/localconfig.lua")
if not ok or type(lc) ~= "table" then
  fail("localconfig.lua: brak lub błąd (" .. tostring(lc) .. "); skopiuj localconfig.example.lua")
  return
end
if type(lc.node) ~= "string" or lc.node == "" or lc.node:find("__", 1, true) then
  fail("localconfig.lua: brak pola 'node' (\"mini\" albo \"macbook\")")
  return
end

local loaded, err = pcall(hs.loadSpoon, "DisplayKVM")
if not loaded or not spoon.DisplayKVM then
  fail("brak Spoons/DisplayKVM.spoon (" .. tostring(err)
    .. "); uruchom: git -C ~/.hammerspoon submodule update --init")
  return
end

log.i("węzeł: " .. lc.node)
spoon.DisplayKVM:configure({
  node    = lc.node,
  secret  = lc.secret,     -- walidację (64 znaki hex) robi DisplayKVM:configure()
  backend = "m1ddc",
  displays = {
    left = {
      match    = {
        mini    = "E321F73C-9A55-44D8-A1E1-FEED1B9C4EE0",  -- lewy widziany z Miniego (HDMI, wejście 17)
        macbook = "EE2BE0B3-F2B2-4ECF-94B2-723446299A1C",  -- lewy widziany z MacBooka (USB-C, wejście 21)
      },
      inputs   = { mini = 17, macbook = 21 },
      home     = "mini",
      control  = { "macbook" },          -- HDMI w Mac mini M1 nie ma DDC (pomiar 2026-10-20)
      whenAway = { mini = "mirror" },    -- gdy lewy pokazuje MacBooka, Mini dubluje na nim prawy
    },
  },
})
spoon.DisplayKVM:start()
spoon.DisplayKVM:bindHotkeys({ claim = { { "ctrl", "alt", "cmd" }, "M" } })
