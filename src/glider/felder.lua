-- Glider: Liste aller Einstellungen (für Menü, Werkwerte und Speicher). Wird nur bei Bedarf geladen und wieder
-- freigegeben. Eine Einstellung steht nur hier: Menü, Prüfung und Speichern richten sich nach dieser Liste.
-- Art: q = Quelle (Sensor, Kanal, Schalter), z = Zahl, b = Ja/Nein, w = Auswahl, t = Text.
-- Jeder Text steht in zwei Sprachen: { "deutsch", "english" }. Ein einfacher Text gilt für beide.
-- q: { name, "q", Text }
-- z: { name, "z", Text, Werkwert, min, max, Kommastellen, Einheit, Schritt }. Zahlen mit Kommastellen sind als ganze
--    Zahl gespeichert (Kommastellen 2: 350 bedeutet 3,50).
-- b: { name, "b", Text, Werkwert }
-- w: { name, "w", Text, Werkwert, { { "Text", 1 }, { "Text", 2 } } }
-- t: { name, "t", Text, Werkwert } (höchstens 12 Zeichen)
-- Werkwerte nach dem freigegebenen Konzept vom 19.11.2026. Zellgrenzen setzt die Akkuart (ART_GRENZE).
local M = {}

local POS = { { { "oben", "up" }, 1 }, { { "Mitte", "middle" }, 2 }, { { "unten", "down" }, 3 } }
local ROLLE = { { { "Empfänger", "Receiver" }, 1 }, { { "Antrieb", "Motor" }, 2 }, { { "Akku", "Battery" }, 3 } }
local ART = { { "LiPo", 1 }, { "LiFe", 2 }, { "NiMH", 3 } }
local ZELLEN = { { { "automatisch", "automatic" }, 0 } }
for i = 1, 12 do ZELLEN[i + 1] = { i .. "S", i } end
local KACHEL = { { "Vario", 1 }, { { "Höhe", "Altitude" }, 2 }, { { "Flugzeit", "Flight time" }, 3 },
  { { "Antriebsakku", "Motor battery" }, 4 }, { { "Empfängerakku", "Receiver battery" }, 5 },
  { { "Empfang", "Link" }, 6 }, { { "Geschwindigkeit", "Speed" }, 7 },
  { { "Thermik-Gewinn", "Thermal gain" }, 8 } }
local LEISTE = { { { "leer", "empty" }, 0 } }
for i, k in ipairs(KACHEL) do LEISTE[i + 1] = k end

-- Akkuart: Zelle Warnung, Alarm, Balken leer, Balken voll (in 0,01 V). Wechselt man im Menü die Art, setzt das Menü
-- die Grenzen dieses Akkus auf die Werte der Art.
M.ART_GRENZE = { { 350, 330, 330, 420 }, { 310, 290, 280, 360 }, { 115, 105, 100, 145 } }

M.gruppen = {
  { { "Modell", "Model" }, {
    { "modell", "w", { "Modellart", "Model type" }, 1, { { { "Segler", "Glider" }, 1 }, { { "E-Segler", "E-glider" }, 2 } } },
  } },
  { { "Sensoren", "Sensors" }, {
    { "hoehe", "q", { "Höhe", "Altitude" } },
    { "vario", "q", "Vario" },
    { "rssi", "q", { "Empfang (RSSI/LQ)", "Link (RSSI/LQ)" } },
    { "speed", "q", { "Geschwindigkeit", "Speed" } },
  } },
  { { "Akkus", "Batteries" }, {
    { "a1", "q", { "Akku 1 Sensor", "Battery 1 sensor" } },
    { "a1Rolle", "w", { "Akku 1 ist", "Battery 1 is" }, 1, ROLLE },
    { "a1S", "w", { "Akku 1 Zellen", "Battery 1 cells" }, 0, ZELLEN },
    { "a1Typ", "w", { "Akku 1 Art", "Battery 1 type" }, 2, ART, art = 1 },
    { "z1Warn", "z", { "Akku 1 Zelle Warn. unter", "Batt. 1 cell warn below" }, 310, 0, 500, 2, " V" },
    { "z1Alarm", "z", { "Akku 1 Zelle Alarm unter", "Batt. 1 cell alarm below" }, 290, 0, 500, 2, " V" },
    { "a2", "q", { "Akku 2 Sensor", "Battery 2 sensor" } },
    { "a2Rolle", "w", { "Akku 2 ist", "Battery 2 is" }, 2, ROLLE },
    { "a2S", "w", { "Akku 2 Zellen", "Battery 2 cells" }, 0, ZELLEN },
    { "a2Typ", "w", { "Akku 2 Art", "Battery 2 type" }, 1, ART, art = 2 },
    { "z2Warn", "z", { "Akku 2 Zelle Warn. unter", "Batt. 2 cell warn below" }, 350, 0, 500, 2, " V" },
    { "z2Alarm", "z", { "Akku 2 Zelle Alarm unter", "Batt. 2 cell alarm below" }, 330, 0, 500, 2, " V" },
    { "a3", "q", { "Akku 3 Sensor", "Battery 3 sensor" } },
    { "a3Rolle", "w", { "Akku 3 ist", "Battery 3 is" }, 3, ROLLE },
    { "a3S", "w", { "Akku 3 Zellen", "Battery 3 cells" }, 0, ZELLEN },
    { "a3Typ", "w", { "Akku 3 Art", "Battery 3 type" }, 1, ART, art = 3 },
    { "z3Warn", "z", { "Akku 3 Zelle Warn. unter", "Batt. 3 cell warn below" }, 350, 0, 500, 2, " V" },
    { "z3Alarm", "z", { "Akku 3 Zelle Alarm unter", "Batt. 3 cell alarm below" }, 330, 0, 500, 2, " V" },
    { "zDiff", "z", { "Zellenunterschied über", "Cell difference above" }, 15, 0, 100, 2, " V" },
    { "pQuelle", "w", { "Antrieb: Akku-% aus", "Motor: battery % from" }, 1,
      { { { "Regler-Sensor", "ESC sensor" }, 1 }, { { "Verbrauch + Kapazität", "Used + capacity" }, 2 },
        { { "Spannung", "Voltage" }, 3 } } },
    { "aProz", "q", { "Antrieb: Akku-% Sensor", "Motor: battery % sensor" } },
    { "aMah", "q", { "Antrieb: Verbrauch", "Motor: consumption" } },
    { "aStrom", "q", { "Antrieb: Strom", "Motor: current" } },
    { "kap", "z", { "Antrieb: Kapazität", "Motor: capacity" }, 0, 0, 20000, 0, " mAh", 50 },
  } },
  { { "Grenzwerte (0 = aus)", "Limits (0 = off)" }, {
    { "hWarn", "z", { "Höhe Warnung über", "Altitude warning above" }, 0, 0, 2000, 0, " m", 10 },
    { "hAlarm", "z", { "Höhe Alarm über", "Altitude alarm above" }, 0, 0, 2000, 0, " m", 10 },
    { "pWarn", "z", { "Antrieb % Warn. unter", "Motor % warning below" }, 30, 0, 100, 0, " %" },
    { "pAlarm", "z", { "Antrieb % Alarm unter", "Motor % alarm below" }, 20, 0, 100, 0, " %" },
    { "rssiWarn", "z", { "Empfang Warnung unter", "Link warning below" }, 0, 0, 100, 0 },
    { "rssiAlarm", "z", { "Empfang Alarm unter", "Link alarm below" }, 0, 0, 100, 0 },
  } },
  { { "Startart und Ausklinkhöhe", "Launch and release height" }, {
    { "akQuelle", "w", { "Ausklinkhöhe aus", "Release height from" }, 1,
      { { { "automatisch", "automatic" }, 1 }, { { "Schleppkupplung", "Tow release" }, 2 },
        { { "Motor aus", "Motor off" }, 3 }, { { "höchster Punkt", "highest point" }, 4 } } },
    { "swSchlepp", "q", { "Schleppkupplung", "Tow release" } },
    { "schleppPos", "w", { "Ausgeklinkt bei", "Released at" }, 3, POS },
    { "swMotor", "q", { "Motor aus (Schalter)", "Motor off (switch)" } },
    { "motorPos", "w", { "Motor aus bei", "Motor off at" }, 1, POS },
    { "gas", "q", { "Gas (Geber oder Kanal)", "Throttle (control/ch.)" } },
    { "gasAb", "z", { "Motor läuft ab Gas", "Motor runs from throttle" }, 10, 0, 100, 0, " %" },
    { "sinkS", "z", { "Höchster Punkt nach Sinken", "Highest point after sink" }, 3, 1, 10, 0, " s" },
  } },
  { { "Flug erkennen", "Flight detection" }, {
    { "startH", "z", { "Flug beginnt ab Höhe", "Flight starts above" }, 10, 1, 100, 0, " m" },
    { "endH", "z", { "Flug endet unter Höhe", "Flight ends below" }, 5, 0, 50, 0, " m" },
    { "ruhigS", "z", { "und ruhig während", "and calm for" }, 10, 3, 60, 0, " s" },
    { "minS", "z", { "Kürzere Flüge weglassen", "Skip flights shorter" }, 30, 0, 300, 0, " s", 5 },
  } },
  { { "Thermik", "Thermal" }, {
    { "thAb", "z", { "Ansage ab Steigen", "Announce from climb" }, 10, 1, 50, 1, " m/s" },
    { "thS", "z", { "während", "for" }, 3, 1, 10, 0, " s" },
    { "thRuhe", "z", { "danach Ruhe", "then quiet for" }, 30, 10, 300, 0, " s", 5 },
  } },
  { { "Schalter in der Statusleiste", "Switches in status bar" }, {
    { "sw1", "q", { "Schalter 1", "Switch 1" } },
    { "sw1Name", "t", { "Schalter 1 Name", "Switch 1 name" }, "" },
    { "sw1Inv", "b", { "Schalter 1 umkehren", "Switch 1 invert" }, false },
    { "sw2", "q", { "Schalter 2", "Switch 2" } },
    { "sw2Name", "t", { "Schalter 2 Name", "Switch 2 name" }, "" },
    { "sw2Inv", "b", { "Schalter 2 umkehren", "Switch 2 invert" }, false },
  } },
  { { "Ansagen", "Announcements" }, {
    { "ansAk", "b", { "Ausklinkhöhe ansagen", "Announce release height" }, true },
    { "ansTh", "b", { "Thermik ansagen", "Announce thermal" }, true },
    { "swHoehe", "q", { "Höhe ansagen (Schalter)", "Announce alt. (switch)" } },
    { "hoeheAlle", "z", { "Höhe ansagen alle", "Announce alt. every" }, 0, 0, 600, 0, " s", 10 },
    { "zeitAlle", "z", { "Flugzeit ansagen alle", "Announce time every" }, 0, 0, 30, 0, " min" },
  } },
  { { "Warnungen", "Warnings" }, {
    { "ansage", "b", { "Ton und Ansage bei Alarm", "Sound and voice on alarm" }, true },
    { "warnAnsage", "b", { "Warnung auch ansagen", "Announce warnings too" }, false },
    { "zahl", "b", { "Wert mit ansagen", "Announce value" }, true },
    { "vibration", "b", { "Vibration bei Alarm", "Vibration on alarm" }, true },
    { "pause", "z", { "Wiederholung alle", "Repeat every" }, 30, 5, 600, 0, " s", 5 },
    { "sperre", "z", { "Startsperre", "Start delay" }, 10, 0, 120, 0, " s" },
    { "stumm", "q", { "Stumm (Schalter)", "Mute (switch)" } },
  } },
  -- 0.4.0: je Grenzwert-Alarm, ob er auch kommt, solange «Motor aus (Schalter)» auf «Motor aus bei» steht. Standard ja
  -- (Regel «Alarme trotz Motor-aus-Schalter», Lua-Studio-Format 2, 3.5). Aus = Ton, Ansage, Vibration und Meldung
  -- schweigen nur, solange der Motor aus ist; die Farbe zeigt den Wert weiter.
  { { "Alarm auch bei Motor aus", "Alarm also with motor off" }, {
    { "hMot", "b", { "Höhe", "Altitude" }, true },
    { "pMot", "b", { "Antrieb %", "Motor %" }, true },
    { "rMot", "b", { "Empfang", "Link" }, true },
    { "z1Mot", "b", { "Akku 1 Zelle", "Battery 1 cell" }, true },
    { "z2Mot", "b", { "Akku 2 Zelle", "Battery 2 cell" }, true },
    { "z3Mot", "b", { "Akku 3 Zelle", "Battery 3 cell" }, true },
    { "dMot", "b", { "Zellenunterschied", "Cell difference" }, true },
  } },
  { { "Anzeige", "Display" }, {
    { "sprache", "w", "Sprache / Language", 0,
      { { { "wie der Sender", "as the radio" }, 0 }, { "Deutsch", 1 }, { "English", 2 } } },
    { "startSeite", "w", { "Startseite", "Start page" }, 1, { { "1", 1 }, { "2", 2 }, { "3", 3 } } },
    { "k1", "w", { "Kachel 1", "Tile 1" }, 1, KACHEL },
    { "k2", "w", { "Kachel 2", "Tile 2" }, 2, KACHEL },
    { "k3", "w", { "Kachel 3", "Tile 3" }, 3, KACHEL },
    { "verlauf", "w", { "Verlauf", "History" }, 1,
      { { { "aus", "off" }, 0 }, { "Vario", 1 }, { { "Höhe", "Altitude" }, 2 } } },
    { "verlaufMin", "w", { "Verlauf Dauer", "History length" }, 2,
      { { "1 min", 1 }, { "2 min", 2 }, { "5 min", 5 } } },
    { "l1", "w", { "Leiste unten Feld 1", "Bottom bar field 1" }, 5, LEISTE },
    { "l2", "w", { "Leiste unten Feld 2", "Bottom bar field 2" }, 4, LEISTE },
    { "l3", "w", { "Leiste unten Feld 3", "Bottom bar field 3" }, 6, LEISTE },
    { "skala", "z", { "Vario-Skala ±", "Vario scale ±" }, 5, 2, 10, 0, " m/s" },
  } },
}

-- Text in der Sprache sp (1 = Deutsch, 2 = English).
function M.text(t, sp)
  if type(t) == "table" then return t[sp] or t[1] end
  return t
end

-- Reihenfolge im Speicher. Ethos speichert Quellen nach Reihenfolge, nicht nach Namen:
-- neue Einstellungen kommen immer ANS ENDE dieser Liste, nie dazwischen. Jede Einstellung aus M.gruppen steht hier.
M.folge = {
  "hoehe", "vario", "rssi", "speed", "a1", "a2", "a3", "aProz", "aMah", "aStrom",
  "swSchlepp", "swMotor", "gas", "sw1", "sw2", "swHoehe", "stumm",
  "modell", "a1Rolle", "a1S", "a1Typ", "z1Warn", "z1Alarm", "a2Rolle", "a2S", "a2Typ", "z2Warn", "z2Alarm",
  "a3Rolle", "a3S", "a3Typ", "z3Warn", "z3Alarm", "zDiff", "pQuelle", "kap",
  "hWarn", "hAlarm", "pWarn", "pAlarm", "rssiWarn", "rssiAlarm",
  "akQuelle", "schleppPos", "motorPos", "gasAb", "sinkS", "startH", "endH", "ruhigS", "minS",
  "thAb", "thS", "thRuhe", "sw1Name", "sw1Inv", "sw2Name", "sw2Inv",
  "ansAk", "ansTh", "hoeheAlle", "zeitAlle",
  "ansage", "warnAnsage", "zahl", "vibration", "pause", "sperre",
  "sprache", "startSeite", "k1", "k2", "k3", "verlauf", "verlaufMin", "l1", "l2", "l3", "skala",
  "hMot", "pMot", "rMot", "z1Mot", "z2Mot", "z3Mot", "dMot",                     -- 0.4.0, Speicher-FORMAT 2
}

-- Kennung des Speicherformats: erhöhen, wenn sich die Reihenfolge der Quellen in M.folge doch einmal ändert.
-- 2 (0.4.0): «Alarm auch bei Motor aus» am Ende von M.folge. Die Quellen im Widget-Speicher sind unverändert, darum
-- liest das Lua FORMAT 1 (0.3.x) weiter ohne Verlust; die neuen Ja/Nein-Werte stehen mit Namen in daten/ (fehlen = ja).
M.FORMAT = 2
local FORMAT_ALT = { [1] = true, [2] = true }

-- Feld zu einem Namen (Verzeichnis einmal aufbauen: Ethos begrenzt die Befehle je Aufruf).
local INDEX = nil
function M.feld(name)
  if INDEX == nil then
    INDEX = {}
    for _, g in ipairs(M.gruppen) do
      for _, f in ipairs(g[2]) do INDEX[f[1]] = f end
    end
  end
  return INDEX[name]
end

function M.standard()
  local c = {}
  for _, g in ipairs(M.gruppen) do
    for _, f in ipairs(g[2]) do
      if f[2] ~= "q" then c[f[1]] = f[4] end
    end
  end
  return c
end

local function istQuelle(v)
  local t = type(v)
  if not (t == "userdata" or (t == "table" and type(v.value) == "function")) then return false end
  if CATEGORY_NONE then
    local ok, k = pcall(v.category, v)
    if ok and k == CATEGORY_NONE then return false end
  end
  return true
end
M.istQuelle = istQuelle

-- Freitext (Schalternamen): nur Buchstaben, Ziffern, Leerzeichen, Punkt, Bindestrich, Umlaute; höchstens 12 Zeichen.
function M.textWert(v)
  if type(v) ~= "string" then return "" end
  v = v:gsub("[^%w %.%-\128-\255]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if #v > 12 then
    local n = 12
    while n > 0 and v:byte(n + 1) and v:byte(n + 1) >= 128 and v:byte(n + 1) < 192 do n = n - 1 end
    v = v:sub(1, n)
  end
  return v
end

-- Gespeicherten Wert prüfen; passt er nicht, gilt der Wert ab Werk.
local function pruefe(f, v)
  local art = f[2]
  if art == "q" then
    if istQuelle(v) then return v end
    return nil
  elseif art == "b" then
    if type(v) == "boolean" then return v end
  elseif art == "t" then
    if type(v) == "string" then return M.textWert(v) end
  elseif art == "z" then
    if type(v) == "number" and v == v and v >= f[5] and v <= f[6] then return math.floor(v) end
  elseif art == "w" then
    if type(v) == "number" then
      for _, a in ipairs(f[5]) do
        if a[2] == v then return v end
      end
    end
  end
  return f[4]
end

-- Speicher (gemessen 26.1.2): der Widget-Speicher fasst rund 256 Byte und arbeitet nach Reihenfolge. Darum nur die
-- Quellen dorthin (mit Rahmen fmt/ende), alles andere in die Datei daten/<Modell>.txt nach Namen.
local function quellen()
  local r = {}
  for _, name in ipairs(M.folge) do
    local f = M.feld(name)
    if f and f[2] == "q" then r[#r + 1] = name end
  end
  return r
end

-- Dateiname zum aktuellen Modell (Ordner und Name, nur Buchstaben, Ziffern, _ und -).
function M.datei()
  local ok, p = pcall(model.path)
  if not ok or type(p) ~= "string" or p == "" then
    local ok2, n = pcall(model.name)
    p = (ok2 and type(n) == "string" and n ~= "") and n or "modell"
  end
  p = p:gsub("%.bin$", ""):gsub("[^%w%-]", "_")
  return "daten/" .. p .. ".txt"
end

-- Datei ganz lesen (Ethos liest nur in Stücken), höchstens 24 KB (Flugliste bis 40 Flüge).
local function liesDatei(pfad)
  local ok, f = pcall(io.open, pfad, "r")
  if not ok or not f then return nil end
  local teile, n = {}, 0
  while n < 24576 do
    local ok2, s = pcall(f.read, f, 512)
    if not ok2 or type(s) ~= "string" or s == "" then break end
    teile[#teile + 1] = s
    n = n + #s
  end
  pcall(f.close, f)
  return table.concat(teile)
end

-- Ein Flug als Text: t,art,ak,hmax,vmax,vmin,mot,rxmin;Phase:s|Phase:s
-- art: 0 unbekannt, 1 Schlepp, 2 Motor, 3 Hand/Winde. Fehlende Werte als leeres Feld.
local function zz(x, d)
  if type(x) ~= "number" or x ~= x then return "" end
  return string.format("%." .. (d or 0) .. "f", x)
end
function M.flugText(f)
  local t = table.concat({ zz(f.t), zz(f.art), zz(f.ak, 1), zz(f.hmax, 1), zz(f.vmax, 2), zz(f.vmin, 2), zz(f.mot),
    zz(f.rxmin, 2) }, ",")
  local ph = {}
  for _, p in ipairs(f.ph or {}) do
    if type(p[1]) == "string" and type(p[2]) == "number" then
      ph[#ph + 1] = M.textWert(p[1]):gsub("[,;|:]", "") .. ":" .. zz(p[2])
    end
  end
  return t .. ";" .. table.concat(ph, "|")
end

local function zahlOder(s, lo, hi)
  local x = tonumber(s)
  if x and x == x and x >= lo and x <= hi then return x end
  return nil
end
function M.flugLies(s)
  if type(s) ~= "string" then return nil end
  local a, b = s:match("^([^;]*);?(.*)$")
  local f = {}
  local teile = {}
  for x in (a .. ","):gmatch("([^,]*),") do teile[#teile + 1] = x end
  f.t = zahlOder(teile[1], 0, 360000)
  if f.t == nil then return nil end
  f.art = zahlOder(teile[2], 0, 3) or 0
  f.ak = zahlOder(teile[3], -500, 10000)
  f.hmax = zahlOder(teile[4], -500, 10000)
  f.vmax = zahlOder(teile[5], -100, 100)
  f.vmin = zahlOder(teile[6], -100, 100)
  f.mot = zahlOder(teile[7], 0, 360000)
  f.rxmin = zahlOder(teile[8], 0, 100)
  f.ph = {}
  for n, sek in (b or ""):gmatch("([^|:]+):([%d%.]+)") do
    local x = zahlOder(sek, 0, 360000)
    if x and #f.ph < 8 then f.ph[#f.ph + 1] = { n, x } end
  end
  return f
end

-- Einstellungen lesen. Gibt true zurück, wenn schon etwas gespeichert war (sonst läuft die automatische Suche).
function M.lies(w, nurDatei)
  local c = M.standard()
  w.cfg = c
  local gefunden = false
  if not nurDatei and storage and storage.read then
    local function hol(name)
      local ok, v = pcall(storage.read, name)
      if ok then return v end
      return nil
    end
    local q = quellen()
    local fmt = hol("fmt")
    if FORMAT_ALT[fmt] then
      local werte = {}
      for i = 1, #q do werte[i] = hol("q" .. i) end
      if hol("ende") == fmt then
        gefunden = true
        for i, name in ipairs(q) do c[name] = istQuelle(werte[i]) and werte[i] or nil end
      else
        print(tostring(w.name) .. ": gespeicherte Sensoren unlesbar, bitte neu zuweisen")
      end
    end
  end
  local text = liesDatei(M.datei())
  if text then
    gefunden = true
    w.dauer, w.liste, w.flug = {}, {}, nil           -- ein zweites Lesen darf nichts doppelt anhängen
    for zeile in text:gmatch("[^\r\n]+") do
      local k, v = zeile:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
      if k == "f" then
        local fl = M.flugLies(v)
        if fl and #w.liste < 40 then w.liste[#w.liste + 1] = fl end
      elseif k == "o" then
        w.flug = M.flugLies(v)
        if w.flug then w.flug.offen = true end
      elseif k and k:sub(1, 2) == "d_" then
        local x = tonumber(v)
        if x and x == x and x > -1e7 and x < 1e7 then w.dauer[k:sub(3)] = x end
      elseif k then
        local f = M.feld(k)
        if f and f[2] == "b" then
          c[k] = pruefe(f, v == "1")
        elseif f and f[2] == "t" then
          c[k] = pruefe(f, v)
        elseif f and (f[2] == "z" or f[2] == "w") then
          c[k] = pruefe(f, tonumber(v))
        end
      end
    end
  end
  return gefunden
end

-- Quellen in den Widget-Speicher (Ethos ruft das beim Speichern des Modells auf).
function M.schreibe(w)
  if not (storage and storage.write) then return end
  local c = w.cfg
  local q = quellen()
  pcall(storage.write, "fmt", M.FORMAT)
  for i, name in ipairs(q) do
    local v = c[name]
    pcall(storage.write, "q" .. i, istQuelle(v) and v or 0)
  end
  pcall(storage.write, "ende", M.FORMAT)
end

-- Zahlen, Texte, dauerhafte Werte, Flugliste und laufender Flug in die Datei. Gibt true zurück, wenn geschrieben.
function M.schreibeDatei(w)
  local c = w.cfg
  local z = { "# " .. tostring(w.name) .. ": Einstellungen, Flugliste und laufender Flug dieses Modells" }
  for _, name in ipairs(M.folge) do
    local f = M.feld(name)
    local v = c[name]
    if f and f[2] == "b" then
      z[#z + 1] = name .. "=" .. (v and "1" or "0")
    elseif f and f[2] == "t" then
      z[#z + 1] = name .. "=" .. M.textWert(v)
    elseif f and f[2] ~= "q" and type(v) == "number" then
      z[#z + 1] = name .. "=" .. string.format("%d", math.floor(v))
    end
  end
  local namen = {}
  for k, x in pairs(w.dauer or {}) do
    if type(k) == "string" and type(x) == "number" and x == x then namen[#namen + 1] = k end
  end
  table.sort(namen)
  for _, k in ipairs(namen) do z[#z + 1] = "d_" .. k .. "=" .. string.format("%.2f", w.dauer[k]) end
  for _, fl in ipairs(w.liste or {}) do z[#z + 1] = "f=" .. M.flugText(fl) end
  if w.flug then z[#z + 1] = "o=" .. M.flugText(w.flug) end
  if os and os.mkdir then pcall(os.mkdir, "daten") end
  local ok, f = pcall(io.open, M.datei(), "w")
  if not ok or not f then return false end
  local okw = pcall(f.write, f, table.concat(z, "\n") .. "\n")
  pcall(f.close, f)
  return okw
end

return M
