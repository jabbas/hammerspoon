-- Punkt wejścia. Rola i sekrety maszyny: localconfig.lua (poza gitem).
require("hs.ipc")  -- zawsze, żeby działało `hs -c`

local log = hs.logger.new("config", "info")

local function fail(msg)
  log.e(msg)
  hs.notify.new({ title = "Hammerspoon", informativeText = msg }):send()
end

local REQUIRED = {
  mini    = { "role", "token" },
  macbook = { "role", "token", "mini_url" },
}

local ok, cfg = pcall(dofile, hs.configdir .. "/localconfig.lua")
if not ok then
  fail("localconfig.lua: brak lub błąd (" .. tostring(cfg) .. "); skopiuj localconfig.example.lua")
  return
end

local keys = type(cfg) == "table" and REQUIRED[cfg.role] or nil
if not keys then
  local role = type(cfg) == "table" and tostring(cfg.role) or "?"
  fail("localconfig.lua: nieznana rola '" .. role .. "' (dozwolone: mini, macbook)")
  return
end

for _, k in ipairs(keys) do
  local v = cfg[k]
  if type(v) ~= "string" or v == "" or v:find("__", 1, true) then
    fail("localconfig.lua: brak wartości lub placeholder w polu '" .. k .. "'")
    return
  end
end

log.i("rola: " .. cfg.role)
require("roles." .. cfg.role)(cfg)
