-- Befehle beim Zeichnen einer vollen Studio-Ansicht (16 Plätze, alle Darstellungen, 2 Kurven mit 120 Punkten,
-- Zusatzzeilen) zählen, auf dem Mac ohne Simulator. Gezählt werden nur Befehle aus den Lua-Dateien des Widgets.
-- Aufruf im Skriptordner: cd src/glider && /opt/homebrew/opt/lua@5.4/bin/lua ../../test/platz-befehle.lua
local TMP = os.tmpname()
os.remove(TMP)
os.execute('mkdir -p "' .. TMP .. '"')
local function nichts() end
local HOEHE = { 12, 14, 16, 20, 26, 34, 46 }
FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL = 1, 2, 3, 4, 5, 6, 7
local schrift = 4
lcd = setmetatable({
  RGB = function(r, g, b) return r * 65536 + g * 256 + b end,
  font = function(f) schrift = f end,
  getTextSize = function(t) return #tostring(t) * HOEHE[schrift] * 0.55, HOEHE[schrift] end,
}, { __index = function() return nichts end })
CENTERED, LEFT, RIGHT = 1, 0, 2
CATEGORY_CHANNEL, CATEGORY_TELEMETRY_SENSOR = 1, 2
model = { name = function() return "Test" end }
local function q(v) return { value = function() return v end, physId = function() return 7 end, appId = function() return 256 end,
  subId = function() return 0 end, name = function() return "S" end } end
system = { getSource = function() return q(12.5) end, getSources = function() return { q(1) } end, getVersion = function() return {} end }
os.mkdir = os.mkdir or function() return true end

local S = assert(loadfile("studio.lua"))()
S.PFAD = TMP .. "/"
local F = assert(loadfile("felder.lua"))()
local a = io.open("../../test/studio/voll.lua", "rb")
local t = a:read("a")
a:close()
local b = io.open(S.PFAD .. "Test.glider.lua", "wb")
b:write(t)
b:close()
local w = { cfg = F.standard(), sp = 1, version = "0.3.0", fenster = {}, T = { zMin = "Min", zMax = "Max", zMittel = "Ø" },
  phaseName = "Thermik" }
repeat until S.schritt(w, function() return F end, {})
os.remove(S.PFAD .. "Test.glider.lua")
os.remove(S.PFAD .. "Test.glider.info.json")
os.execute('rmdir "' .. TMP .. '"')

local Z = assert(loadfile("zeichnen.lua"))()
local P = assert(loadfile("platz.lua"))()
w.wert = function(_, d) return d.art == "lua" and (d.s == "zustand" and 2 or d.s == "motor" and 1 or 123.4) or 45.6 end
w.zustandVon = function(_, key) return key == "lua:hoehe" and 2 or nil end
w.zs = {}
for _, an in ipairs(w.sd.ansichten) do
  for _, p in ipairs(an.plaetze) do
    if p.dar == "kurve" then
      p.buf = {}
      for i = 1, 120 do p.buf[i] = (i % 7 == 0) and false or ((i % 30) / 30) end
    end
    w.zs[p.key] = { n = 10, sum = 500, min = 1, max = 99 }
  end
end
local fehler, hoechst = 0, 0
-- 0.6.0 (R3): jede Ansicht auch auf andere Fenstergrössen umgerechnet; Befehle für umrechnen (wakeup) messen
local liste = {}
for _, an in ipairs(w.sd.ansichten) do
  liste[#liste + 1] = { an, an.breite, an.hoehe }
  for _, g in ipairs({ { 800, 480 }, { 784, 316 }, { 640, 360 }, { 630, 258 }, { 480, 320 }, { 472, 210 }, { 480, 272 } }) do
    if g[1] ~= an.breite or g[2] ~= an.hoehe then
      local zu = 0
      debug.sethook(function()
        local i = debug.getinfo(2, "S")
        if i and i.source:match("^@[%w_]+%.lua$") then zu = zu + 1 end
      end, "", 1)
      local neu, weg = P.umrechnen(an, g[1], g[2], Z)
      debug.sethook()
      print(string.format("        umrechnen %dx%d -> %dx%d: %d Befehle, %d Plätze, %d weggelassen", an.breite, an.hoehe,
        g[1], g[2], zu, #neu.plaetze, weg))
      if zu >= 5000 then fehler = fehler + 1 end
      for _, p in ipairs(neu.plaetze) do
        if p.x < 0 or p.y < 0 or p.x + p.b > g[1] or p.y + p.h > g[2] then
          print("FEHLER  Platz ausserhalb der Fläche") fehler = fehler + 1
        end
      end
      liste[#liste + 1] = { neu, g[1], g[2] }
    end
  end
end
for _, eg in ipairs(liste) do
  local an = eg[1]
  local L = Z.layout(eg[2], eg[3])
  Z.punkt = false
  P.vorbereiten(w, L, Z, an, 16)
  local z = 0
  debug.sethook(function()
    local i = debug.getinfo(2, "S")
    if i and i.source:match("^@[%w_]+%.lua$") then z = z + 1 end
  end, "", 1)
  local ok, e = pcall(P.zeichne, w, L, Z, an)
  debug.sethook()
  -- Vorbereiten: 4 Plätze je Aufruf (wie im Kern), höchster Aufruf zählt
  local vz = 0
  for _ = 1, 4 do
    local z2 = 0
    debug.sethook(function()
      local i = debug.getinfo(2, "S")
      if i and i.source:match("^@[%w_]+%.lua$") then z2 = z2 + 1 end
    end, "", 1)
    local ok2, e2 = pcall(P.vorbereiten, w, L, Z, an, 4)
    debug.sethook()
    if not ok2 then ok, e = false, e2 end
    if z2 > vz then vz = z2 end
  end
  print(string.format("        vorbereiten je Aufruf (4 Plätze): höchstens %d Befehle", vz))
  if vz > hoechst then hoechst = vz end
  print(string.format("%s  Ansicht %d x %d in %d x %d, %d Plätze: %d Befehle%s", ok and "OK    " or "FEHLER", an.breite, an.hoehe, eg[2], eg[3],
    #an.plaetze, z, ok and "" or ("  " .. tostring(e))))
  if not ok then fehler = fehler + 1 end
  if z > hoechst then hoechst = z end
end
print("Höchste Befehlszahl beim Zeichnen: " .. hoechst .. " (Ziel unter 5'000)")
if hoechst >= 5000 then fehler = fehler + 1 end
print(fehler == 0 and "ERGEBNIS: kein Fehler" or ("ERGEBNIS: " .. fehler .. " Fehler"))
os.exit(fehler == 0 and 0 or 1)
