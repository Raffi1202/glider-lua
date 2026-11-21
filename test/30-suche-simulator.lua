-- Makro für 30-suche-simulator.json: legt Sensoren per Lua an und lässt suche.lua darauf laufen (Ergebnis in test-zustand.json)
local function neu(n, id, phys, unit)
  local s = model.createSensor()
  s:name(n) s:appId(id) s:physId(phys) if unit then pcall(s.unit, s, unit) end
  return s
end
neu("Strom", 0x0028, 0, UNIT_AMPERE)
neu("Strom", 0x0200, 2, UNIT_AMPERE)
neu("ESC Spannung", 0x0B51, 3, UNIT_VOLT)
neu("ESC Spannung", 0x0B50, 3, UNIT_VOLT)
neu("RB Hoehe", 0x0F30, 5, UNIT_METER)
neu("RB Vario", 0x0F30, 5, UNIT_METER_PER_SECOND)
neu("RxBatt", 0xF104, 0, UNIT_VOLT)
neu("Kraftstoff", 0x0600, 1, UNIT_MILLIAMPERE_HOUR)
for i = 1, 92 do neu("DIY " .. i, 0x5100 + i, 9, UNIT_CELSIUS) end   -- auf 100 Sensoren auffüllen
local f = loadfile("/scripts/glider/suche.lua")
local w = { cfg = { a1Rolle = 1, a2Rolle = 2, a3Rolle = 3 } }
local schritt = f()
local ok, n, i = true, nil, 0
repeat ok, n = pcall(schritt, w) i = i + 1 until not ok or n ~= nil or i > 1000
local r = { '"ok":' .. tostring(ok), '"n":"' .. tostring(n) .. '"' }
for _, k in ipairs({ "hoehe", "vario", "a1", "a2", "aStrom", "aMah", "aProz", "swSchlepp", "swMotor", "gas" }) do
  local q = w.cfg[k]
  local t = "nil"
  if q then local a, b = pcall(q.name, q); local c2, d = pcall(q.appId, q); t = tostring(b) .. "@" .. string.format("%04X", (c2 and d) or 0) end
  r[#r + 1] = '"' .. k .. '":"' .. t .. '"'
end
for k, h in pairs(w.suchHinweis or {}) do r[#r + 1] = '"hinweis_' .. k .. '":"' .. tostring(h[1]) .. '"' end
local fo = io.open("/scripts/glider/test-zustand.json", "w") fo:write("{" .. table.concat(r, ",") .. "}") fo:close()
