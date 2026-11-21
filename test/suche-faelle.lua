-- Feste Fälle für die automatische Sensorzuordnung (Vorgaben Sensorzuordnung, 20.11.2026), auf dem Mac ohne Simulator.
-- Aufruf im Skriptordner: cd src/glider && /opt/homebrew/opt/lua@5.4/bin/lua ../../test/suche-faelle.lua
-- Bildet system.getSources mit Sensoren nach (Name, AppID, Teilwert, Physical ID, Einheit, Wert) und prüft das Ergebnis.
UNIT_PERCENT, UNIT_MILLIAMPERE_HOUR, UNIT_AMPERE, UNIT_VOLT, UNIT_METER, UNIT_METER_PER_SECOND = 13, 14, 2, 1, 9, 10
CATEGORY_TELEMETRY_SENSOR = 1
local QUELLEN = {}
system = {
  getSources = function() return QUELLEN end,
  getSource = function() return nil end,
}
local function sensor(name, id, teil, phys, einheit, wert)
  return { _n = name, _id = id, _t = teil, _p = phys, _e = einheit, _w = wert,
    name = function(s) return s._n end, appId = function(s) return s._id end, subId = function(s) return s._t end,
    physId = function(s) return s._p end, unit = function(s) return s._e end, value = function(s) return s._w end }
end
local suche = assert(loadfile("suche.lua"))()
local fehler = 0
MAXBEFEHLE = 0
local function fall(titel, sensoren, erwartet, hinweis)
  QUELLEN = sensoren
  local w = { cfg = { a1Rolle = 1, a2Rolle = 2, a3Rolle = 3 } }
  -- schrittweise aufrufen wie der Kern; Befehle je Aufruf zählen (debug.sethook, je 1 Befehl)
  local ok, n, schritte = true, nil, 0
  repeat
    local zaehler = 0
    debug.sethook(function() zaehler = zaehler + 1 end, "", 1)
    ok, n = pcall(suche, w)
    debug.sethook()
    schritte = schritte + 1
    if zaehler > MAXBEFEHLE then MAXBEFEHLE = zaehler end
  until not ok or n ~= nil or schritte > 1000
  local gut = ok
  if ok then
    for feld, nm in pairs(erwartet) do
      local q = w.cfg[feld]
      local ist = q and q._n .. "@" .. string.format("%04X/%s", q._id or 0, tostring(q._p)) or "nil"
      if ist ~= nm then gut = false print("  " .. feld .. ": erwartet " .. nm .. ", ist " .. ist) end
    end
    for feld, anz in pairs(hinweis or {}) do
      local h = w.suchHinweis[feld]
      if not h or h[1] ~= anz then gut = false print("  Hinweis " .. feld .. " fehlt oder falsch") end
    end
  else
    print("  Laufzeitfehler: " .. tostring(n))
  end
  print((gut and "OK    " or "FEHLER") .. "  " .. titel)
  if not gut then fehler = fehler + 1 end
end

-- (a) gleichnamige Sensoren verschiedener Geräte: «Strom» bei 0x0028 (D-Hub), 0x0200 (FAS) und 0x0F10 (RB25)
fall("(a) gleichnamig verschiedene Geräte", {
  sensor("Strom", 0x0F10, 2, 10, UNIT_AMPERE, 1.0),
  sensor("Strom", 0x0028, nil, 0, UNIT_AMPERE, 2.0),
  sensor("Strom", 0x0200, 0, 2, UNIT_AMPERE, 3.0),
}, { aStrom = "Strom@0200/2" })
-- (b) zwei Instanzen derselben AppID (Regler 0x0B50 und 0x0B51): niedrigere Instanz, Hinweis 2
fall("(b) zwei Instanzen", {
  sensor("ESC Spannung", 0x0B51, 0, 3, UNIT_VOLT, 12.1),
  sensor("ESC Spannung", 0x0B50, 0, 3, UNIT_VOLT, 12.0),
}, { a2 = "ESC Spannung@0B50/3" }, { a2 = 2 })
-- (c) gleiche AppID auf zwei Physical IDs: der mit gültigem Wert gewinnt, Hinweis 2
fall("(c) gleiche AppID auf zwei Physical IDs", {
  sensor("Höhe", 0x0100, 0, 4, UNIT_METER, nil),
  sensor("Höhe", 0x0100, 0, 7, UNIT_METER, 120),
}, { hoehe = "Höhe@0100/7" }, { hoehe = 2 })
-- (d) nur Gesamtspannung ohne Zellen (FAS-Spannung 0x0210) für den Antrieb; Empfänger über RxBatt
fall("(d) nur Gesamtspannung", {
  sensor("VFAS", 0x0210, 0, 2, UNIT_VOLT, 11.4),
  sensor("RxBatt", 0xF104, 0, 0, UNIT_VOLT, 6.6),
}, { a2 = "VFAS@0210/2", a1 = "RxBatt@F104/0" })
-- (e) Betaflight «Kraftstoff» 0x0600 mit mAh: wird Verbrauch, nicht Akku-%
fall("(e) Kraftstoff = mAh", {
  sensor("Kraftstoff", 0x0600, 0, 1, UNIT_MILLIAMPERE_HOUR, 850),
}, { aMah = "Kraftstoff@0600/1", aProz = "nil" })
-- (f) leeres Modell: nichts zugewiesen, kein Fehler
fall("(f) leeres Modell", {}, { hoehe = "nil", a1 = "nil", a2 = "nil" })
-- (g) 100 Sensoren: Rangfolge Höhe vor RB35-Höhe vor GPS-Höhe, Zellen vor ESC-Spannung, Namen zählen nicht
local viele = {}
for i = 1, 94 do viele[#viele + 1] = sensor("Altitude " .. i, 0x5100 + i, 0, 9, UNIT_METER, i) end
viele[#viele + 1] = sensor("GPS Alt", 0x0820, 0, 3, UNIT_METER, 300)
viele[#viele + 1] = sensor("RB35 Höhe", 0x0F30, 0, 5, UNIT_METER, 200)
viele[#viele + 1] = sensor("Höhe", 0x0100, 0, 4, UNIT_METER, 100)
viele[#viele + 1] = sensor("ESC Spannung", 0x0B50, 0, 3, UNIT_VOLT, 12.0)
viele[#viele + 1] = sensor("Zellen", 0x0300, 0, 1, UNIT_VOLT, 11.4)
viele[#viele + 1] = sensor("VSpd", 0x0110, 0, 4, UNIT_METER_PER_SECOND, 1.2)
fall("(g) 100 Sensoren, Rangfolge", viele, { hoehe = "Höhe@0100/4", a2 = "Zellen@0300/1", vario = "VSpd@0110/4" })
-- ohne Teilwert (Simulator, per Lua angelegt): gepackte AppID 0x0F30 nach Einheit, Höhe m / Vario m/s
fall("ohne Teilwert: RB35 0x0F30 nach Einheit", {
  sensor("RB Vario", 0x0F30, nil, 5, UNIT_METER_PER_SECOND, 0.8),
  sensor("RB Höhe", 0x0F30, nil, 5, UNIT_METER, 150),
}, { hoehe = "RB Höhe@0F30/5", vario = "RB Vario@0F30/5" })
-- Rückfall Stufe 2: DIY-Sensor ohne Kennung nach Name
fall("Rückfall ohne Kennung (DIY 0x5xxx)", {
  sensor("Vario", 0x5200, 0, 9, UNIT_METER_PER_SECOND, 0.5),
}, { vario = "Vario@5200/9" })

print("Höchste Befehlszahl je Aufruf: " .. MAXBEFEHLE .. " (Ziel unter 5'000)")
if MAXBEFEHLE >= 5000 then fehler = fehler + 1 end
print(fehler == 0 and "ERGEBNIS: kein Fehler" or ("ERGEBNIS: " .. fehler .. " Fehler"))
os.exit(fehler == 0 and 0 or 1)
