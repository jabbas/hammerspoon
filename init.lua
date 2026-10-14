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
      match  = {
        mini    = "1B5F0426-EFF5-4986-ABCE-67B1F3E2FF67",  -- lewy widziany z Miniego (DP, wejście 15)
        macbook = "F10F3853-1195-47E4-B1B9-EDA17BE38872",  -- lewy widziany z MacBooka (mini DP, wejście 16)
      },
      inputs = { mini = 15, macbook = 16 },
      home   = "mini",
    },
  },
})
spoon.DisplayKVM:start()
spoon.DisplayKVM:bindHotkeys({ claim = { { "ctrl", "alt", "cmd" }, "M" } })
