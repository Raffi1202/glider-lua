-- Glider: Kern des Widgets. Liest die gewählten Quellen, erkennt Flug, Startart und Ausklinkhöhe, führt Thermik-
-- Hinweis, Warnungen, Ansagen und Flugliste und ruft die sichtbare Seite zum Zeichnen. Alles Rechnen passiert in
-- wecke(), zeichne() zeichnet nur.
-- Absturzsicher: jeder Wert wird geprüft (nil, Text, NaN, unendlich, riesig), jede Ethos-Abfrage läuft in pcall.
local K = {}
local Z = nil          -- zeichnen.lua
local SEITE = {}       -- geladene Seite (immer nur die sichtbare)
local SEITEN = 3       -- 1 Flug, 2 Elektrik, 3 Flüge
local KOMPAKT = nil    -- kompakt.lua (nur im Layout mit Kopf- und Fussleiste geladen)
local STUDIO = nil     -- studio.lua (nur beim Modellwechsel, solange die Studio-Datei gelesen wird)
local PLATZ = nil      -- platz.lua (nur wenn eine Studio-Ansicht zur Fenstergrösse passt)
local SITZUNG = {}     -- seit dem Laden des Skripts: zuletzt geschriebene Info-Dateien (studio.lua)
local HINWEIS_S = 8    -- s: Hinweis zur Studio-Datei unten, danach «!» oben rechts
local PLAETZE_JE_BILD = 4   -- Studio-Plätze, die je Bild-Takt (0,2 s) neu vorbereitet werden (Befehlsgrenze)

local TEST = nil  -- TESTHAKEN: der Simulator-Ablauf ersetzt genau diese Zeile (bauplan.md, Abschnitt Testhaken)
local ZUSTAND = nil  -- testzustand.lua, nur geladen mit TEST.zustand im Simulator

local DT_LESEN = 0.2   -- s: Werte lesen und rechnen
local DT_BILD = 0.2    -- s: Bild höchstens so oft auffrischen
local AN_S = 1.0       -- s: so lange muss eine Bedingung gelten, bis die Warnung kommt
local AUS_S = 3.0      -- s: so lange muss sie weg sein, bis die Warnung geht
local MON_JE = 12      -- Studio-Grenzen (sd.mon) je Durchlauf neu lesen (Befehlsgrenze, 0.4.0)
local MON_HEISS = 16   -- höchstens so viele Studio-Grenzen gleichzeitig gemeldet (Befehlsgrenze, 0.4.0)
local ANSAGE_ABSTAND = 3.0
local DAUER_S = 60     -- s: laufenden Flug höchstens so oft in die Datei schreiben
local MAX_FLUEGE = 40
local MAX_PHASEN = 8
local SLOP = 14        -- Pixel: ab hier gilt eine Bewegung als Wisch
local GROSS = 1e7      -- Werte darüber gelten als unplausibel
-- Glaubhafter Bereich je Messwert (Einheit des Sensors): ausserhalb gilt «kein Wert».
local BEREICH = { h = { -500, 10000 }, vs = { -100, 100 }, rssi = { 0, 100 }, speed = { 0, 1000 }, u = { 0, 100 },
  p = { 0, 100 }, mah = { 0, 100000 }, a = { -10, 500 } }
local MIN_W, MIN_H = 400, 250   -- kleineres Vollbild-Feld: nur Hinweis «Feld zu klein»
local MIN_KW, MIN_KH = 440, 200 -- Kompaktansicht (mit Leisten, kleinste gemessen 472 x 210)

local floor, abs, max, min = math.floor, math.abs, math.max, math.min

-- Akku-% aus der Spannung einer Zelle je Art (Ruhespannung, grob): { Volt, % }
local KURVE = {
  { { 3.30, 0 }, { 3.50, 5 }, { 3.68, 20 }, { 3.74, 40 }, { 3.80, 55 }, { 3.87, 70 }, { 3.95, 80 }, { 4.05, 90 }, { 4.20, 100 } },
  { { 2.80, 0 }, { 3.00, 5 }, { 3.15, 20 }, { 3.22, 40 }, { 3.26, 60 }, { 3.30, 80 }, { 3.35, 95 }, { 3.45, 100 } },
  { { 1.00, 0 }, { 1.10, 10 }, { 1.20, 40 }, { 1.25, 70 }, { 1.30, 90 }, { 1.40, 100 } },
}

local ansichtWaehlen, infoNach   -- weiter unten (R3/R4)
local function lade(datei)
  local f, e = loadfile(datei)
  if not f then error(e, 0) end
  return f()
end

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

-- Zahl prüfen: nil bei nil, Text, NaN, unendlich oder unplausibel gross.
local function gut(v)
  if type(v) ~= "number" or v ~= v or v > GROSS or v < -GROSS then return nil end
  return v
end

-- Wert einer Quelle als Zahl, sonst nil. Optionen (einzelne Zelle) nur als Tabelle (gemessen 26.1.2).
local function zahl(q, opt)
  if q == nil then return nil end
  local ok, v
  if opt ~= nil then ok, v = pcall(q.value, q, { options = opt }) else ok, v = pcall(q.value, q) end
  if not ok then return nil end
  return gut(v)
end

local function bereich(q)
  local ok1, lo = pcall(q.minimum, q)
  local ok2, hi = pcall(q.maximum, q)
  lo, hi = ok1 and gut(lo), ok2 and gut(hi)
  if lo and hi and hi > lo then return lo, hi end
  return nil
end

-- Stellung einer Quelle in Prozent ihres Bereichs (Kanal, Geber).
-- Gas in % (0 = Leerlauf, 100 = Vollgas). «Gas umkehren» (Gas Reverse, Vollgas = Knüppel hinten): 100 - Wert.
local function gasProzent(c, p)
  if p ~= nil and c.gasInv == true then return 100 - p end
  return p
end
K._gasProzent = gasProzent      -- für test/gas-faelle.lua

local function prozent(q)
  local v = zahl(q)
  if v == nil then return nil end
  local lo, hi = bereich(q)
  if lo == nil then lo, hi = -1024, 1024 end
  return clamp((v - lo) / (hi - lo) * 100, 0, 100)
end

-- Schalterartige Quelle: aktiv = über der Mitte ihres Bereichs. nil = keine Quelle.
local function aktiv(q, umkehren)
  local v = zahl(q)
  if v == nil then return nil end
  local lo, hi = bereich(q)
  local a = v > (lo and (lo + hi) / 2 or 0)
  if umkehren then a = not a end
  return a
end

-- Stellung eines 3-Stufen-Schalters: 1 oben, 2 Mitte, 3 unten. Ethos: oben = Minimum (gemessen 26.1.2).
local function stellung(q)
  local v = zahl(q)
  if v == nil then return nil end
  local lo, hi = bereich(q)
  if lo == nil then lo, hi = -1024, 1024 end
  local d = (hi - lo) / 3
  if v < lo + d then return 1 end
  if v > hi - d then return 3 end
  return 2
end

local function einheit(q)
  if q == nil then return "" end
  local ok, e = pcall(q.stringUnit, q)
  if ok and type(e) == "string" then return e end
  return ""
end

local function stellen(q, sonst)
  if q == nil then return sonst end
  local ok, d = pcall(q.decimals, q)
  if ok and type(d) == "number" and d >= 0 and d <= 3 then return floor(d) end
  return sonst
end

-- Akku-% aus Zellspannung und Art
local function kurve(u, typ)
  local k = KURVE[typ] or KURVE[1]
  if u == nil then return nil end
  if u <= k[1][1] then return 0 end
  for i = 2, #k do
    if u <= k[i][1] then
      local a, b = k[i - 1], k[i]
      return a[2] + (u - a[1]) / (b[1] - a[1]) * (b[2] - a[2])
    end
  end
  return 100
end

-- Sprache: 1 = Deutsch, 2 = English. Einstellung 0 heisst «wie der Sender».
local SENDER = nil
local function sprache(w)
  local sp = w.cfg.sprache
  if sp ~= 1 and sp ~= 2 then
    if SENDER == nil then
      SENDER = 2
      if system.getLocale then
        local ok, l = pcall(system.getLocale)
        if ok and type(l) == "string" and l:sub(1, 2):lower() == "de" then SENDER = 1 end
      end
    end
    sp = SENDER
  end
  if w.sp ~= sp or w.T == nil then
    w.sp = sp
    w.T = lade("texte.lua")(sp)
    w.hinweis = nil
  end
end

-- Sprachdatei abspielen: audio/de/<name>.wav oder audio/en/<name>.wav. false, wenn die Datei fehlt.
local AUDIO_DA = {}
local function sage(w, name)
  if not system.playFile or name == nil then return false end   -- Studio-Grenze ohne eigene WAV: Ton (0.4.0)
  local pfad = "audio/" .. (w.sp == 1 and "de" or "en") .. "/" .. name .. ".wav"
  local da = AUDIO_DA[pfad]
  if da == nil then
    local ok, f = pcall(io.open, pfad, "r")
    da = (ok and f ~= nil) or false
    if da then pcall(f.close, f) end
    AUDIO_DA[pfad] = da
  end
  if da then pcall(system.playFile, pfad) end
  return da
end

local function einheitNr(q, sonst)
  if q == nil then return sonst end
  local ok, e = pcall(q.unit, q)
  if ok and type(e) == "number" then return e end
  return sonst
end

local function imBereich(k, x)
  local b = BEREICH[k]
  if x == nil or (b and (x < b[1] or x > b[2])) then return nil end
  return x
end

-- Grenzwerte aus den Einstellungen als Zahlen; nil = nicht gesetzt (Warnung aus).
local function grenzen(w)
  local c, g = w.cfg, w.g
  if TEST and TEST.cfg then
    for k, x in pairs(TEST.cfg) do c[k] = x end
  end
  local function gz(k, teiler)
    local x = gut(c[k])
    if x and x > 0 then return x / (teiler or 1) end
    return nil
  end
  g.hWarn, g.hAlarm = gz("hWarn"), gz("hAlarm")
  g.pWarn, g.pAlarm = gz("pWarn"), gz("pAlarm")
  g.rssiWarn, g.rssiAlarm = gz("rssiWarn"), gz("rssiAlarm")
  g.vfrW, g.vfrA = gz("vfrW"), gz("vfrA")                     -- 0.7.2: VFR Warnung je Band, RX VFR Alarm
  for i = 1, 3 do
    g["z" .. i .. "Warn"], g["z" .. i .. "Alarm"] = gz("z" .. i .. "Warn", 100), gz("z" .. i .. "Alarm", 100)
  end
  g.zDiff = gz("zDiff", 100)
  g.pause = gut(c.pause) or 30
  g.thAb = gz("thAb", 10) or 1.0
  sprache(w)
end

-- Werte für Studio-Plätze und Studio-Grenzen (Lua-Studio-Format v1, 6.6). Rohwert des Luas, eines Sensors (über die
-- in studio.lua gesuchte Quelle) oder eines Kanals (%), danach die Anpassung nach 6.4.
local function phasenZeit(w)
  local f, pn = w.flug, w.phaseName
  if not (f and pn) then return nil end
  for _, p in ipairs(f.ph or {}) do if p[1] == pn then return p[2] end end
  return nil
end
local function akku(w, i, k) return i and w.ak[i] and w.ak[i][k] or nil end
-- Zelle eines Akkus nur, wenn ein Sensor zugewiesen ist (seit 0.3.1 auch der Antriebsakku bei jedem Modelltyp)
local function zelle(w, i)
  local a = w.ak[i]
  if not (a and a.da) then return nil end
  return a.tief
end
local ZST = { keine = 0, ok = 1, warnung = 2, alarm = 3 }
local MOT = { aus = 0, ein = 1, laeuft = 2 }
local LUAWERT = {
  vario = function(w) return w.v.vs end,
  hoehe = function(w) return w.v.h end,
  hoehe_max = function(w) return w.flug and w.flug.hmax end,
  ausklinkhoehe = function(w) return w.flug and w.flug.ak end,
  vario_mittel = function(w) return w.vMittel end,
  thermik_gewinn = function(w) return w.th and w.th.gew end,
  thermik_dauer = function(w) return w.th and w.th.dauer end,
  flugzeit = function(w) return w.flug and w.flug.t or 0 end,
  phase_zeit = phasenZeit,
  motorzeit = function(w) return w.flug and w.flug.mot end,
  antrieb_proz = function(w) return akku(w, w.v.antrieb, "p") end,
  antrieb_u = function(w) return akku(w, w.v.antrieb, "summe") end,
  empf_u = function(w) return akku(w, w.v.empf, "summe") end,
  empf_proz = function(w) return akku(w, w.v.empf, "p") end,
  akku1_zelle = function(w) return zelle(w, 1) end,
  akku2_zelle = function(w) return zelle(w, 2) end,
  akku3_zelle = function(w) return zelle(w, 3) end,
  empfang = function(w) return w.v.rssi end,
  rssi24 = function(w) return w.v.rssi24 end,
  rssi900 = function(w) return w.v.rssi900 end,
  vfr24 = function(w) return w.v.vfr24 end,
  vfr900 = function(w) return w.v.vfr900 end,
  rxvfr = function(w) return w.v.rxvfr end,
  speed = function(w) return w.v.speed end,
  strom = function(w) return w.v.strom end,
  verbrauch = function(w) return w.v.mah end,
  zustand = function(w) return ZST[w.zustand] end,
  motor = function(w) return MOT[w.v.motor] end,
}
local function wertVon(w, d, key)
  local x = nil
  if d.art == "lua" then
    local f = LUAWERT[d.s]
    if f then x = f(w) end
    if d.s == "zustand" or d.s == "motor" then return x end
  elseif d.q then
    local ok, v = pcall(d.q.value, d.q)
    if ok and gut(v) then x = d.art == "kanal" and v / 10.24 or v end
  end
  if type(x) ~= "number" then return nil end
  local a = w.sd and w.sd.werte and w.sd.werte[key]
  if a then x = x * a.faktor + a.versatz end
  return x
end
-- Zustand eines Werts für die Farbe: 2 Alarm, 1 Warnung, nil normal
local function zustandVon(w, key, d)
  local st = w.v.st or {}
  if d.art == "lua" then
    local s = d.s
    local e = nil
    if s == "hoehe" then e = st.h elseif s == "empfang" then e = st.rssi
    elseif s == "antrieb_proz" then e = w.v.antrieb and st["a" .. w.v.antrieb]
    elseif s == "akku1_zelle" then e = st.a1 elseif s == "akku2_zelle" then e = st.a2
    elseif s == "akku3_zelle" then e = st.a3 end
    if e then return e end
  end
  return w.gst and w.gst[key]
end
K._wertVon = wertVon

-- Studio-Ergebnis anwenden: Einstellungen und Grenzen (Werk + Studio + .funke.lua) über cfg legen.
local function studioAnwenden(w)
  local sd = w.sd
  if not (sd and sd.ueber) then return end
  -- eigene Werte merken: in die Datei des Modells kommen sie, nicht die der Studio-Datei (sonst bleiben Studio-Werte
  -- nach einem Layout-Wechsel oder ohne Studio-Datei stehen)
  if w.cfgEigen == nil then
    w.cfgEigen = {}
    for k in pairs(sd.ueber) do w.cfgEigen[k] = w.cfg[k] end
  end
  for k, v in pairs(sd.ueber) do w.cfg[k] = v end
  grenzen(w)
end

-- Hinweise zur Studio-Datei (Abschnitt 3): Band unten 8 s, danach «!» oben rechts bis zum Modellwechsel
local function studioHinweis(w, now)
  local sd, T, t = w.sd, w.T, {}
  w.sdZeile = nil
  if sd.status == "kaputt" or sd.status == "zuNeu" then   -- R4: Dauerzeile unten mit Grund
    w.sdZeile = string.format(T.sdDefekt, sd.status == "kaputt" and T.sdGrundKaputt or T.sdGrundZuNeu)
  elseif sd.status == "fehlt" and sd.wahlFehlt then w.sdZeile = T.sdWahlFehlt
  elseif sd.status == "geladen" and sd.fehler > 0 then t[#t + 1] = string.format(T.sdFehler, tostring(sd.fehler)) end
  if sd.funkeVerworfen then t[#t + 1] = T.sdFunkeWeg end
  w.sdHinweis0, w.sdNurBand = nil, nil
  if #t > 0 then w.sdHinweis, w.sdHinweisBis = table.concat(t, "  |  "), now + HINWEIS_S w.sdHinweis0 = w.sdHinweis end
end

function K.neu()
  local F = lade("felder.lua")
  local w = {
    cfg = F.standard(), g = {}, v = {}, eh = {}, dz = {}, un = {},
    meld = {}, aktiv = {}, nAktiv = 0, stufe = 0, zustand = "keine", meldText = "",
    seite = 1, ziele = {}, nZiele = 0,
    dauer = {}, liste = {}, flug = nil,
    ak = { {}, {}, {} }, akMin = {}, ring = {}, vl = {}, vlN = 0, anQ = {},
    gelesen = false, autoOffen = true, version = K.VERSION, name = K.NAME, lAb = 0,
    sdAuf = true, fenster = {}, zs = {}, gst = {}, wert = wertVon, zustandVon = zustandVon,
  }
  -- Datei des Modells gleich beim Anlegen lesen: Ethos ruft read() nur, wenn im Widget-Speicher schon etwas steht
  -- (gemessen im Simulator 26.2.0). read() liest später alles noch einmal, ohne etwas doppelt anzuhängen.
  local ok, g = pcall(F.lies, w, true)
  if ok and g then w.gelesen, w.autoOffen = true, false end
  grenzen(w)
  w.seite = clamp(w.cfg.startSeite or 1, 1, SEITEN)
  if CATEGORY_SYSTEM_EVENT and SYSTEM_EVENT_TELEMETRY_ACTIVE then
    local ok, q = pcall(system.getSource, { category = CATEGORY_SYSTEM_EVENT, member = SYSTEM_EVENT_TELEMETRY_ACTIVE })
    if ok then w.qTele = q end
  end
  if CATEGORY_FLIGHT then                         -- aktive Flugphase des Modells
    local m = FLIGHT_CURRENT_MODE or CURRENT_FLIGHT_MODE
    if m ~= nil then
      local ok, q = pcall(system.getSource, { category = CATEGORY_FLIGHT, member = m })
      if ok then w.qPhase = q end
    end
  end
  return w
end

-- Läuft die Telemetrie? Ohne Auskunft von Ethos gilt sie als vorhanden.
local function telemetrie(w)
  local q = w.qTele
  if q == nil then return true end
  local ok, v = pcall(q.value, q)
  if not ok then return true end
  if type(v) == "number" then return v > 0 end
  if type(v) == "boolean" then return v end
  return true
end

local function hinweis(w, text, now)
  w.hinweis = text
  w.hinweisBis = now + 3
end

-- Ansage in die Warteschlange (Ereignisse wie Ausklinkhöhe, Thermik, Höhe). Höchstens 4 warten.
local function ansage(w, wav, wert, einh, dez)
  if #w.anQ >= 4 then return end
  w.anQ[#w.anQ + 1] = { wav = wav, wert = wert, einh = einh, dez = dez }
end

-- Name der aktiven Flugphase (Text von Ethos, sonst «Phase n»)
local function phase(w)
  local q = w.qPhase
  if q == nil then return nil end
  local ok, s = pcall(q.stringValue, q)
  if ok and type(s) == "string" and s ~= "" then
    s = s:gsub("[,;|:]", "")
    return s
  end
  local n = zahl(q)
  if n then return (w.T.phase or "Phase") .. " " .. string.format("%.0f", n + 1) end
  return nil
end

-- Akku lesen. Echter Zellensensor (ganze Zellenzahl 1 bis 12, jede Zelle bis 5 V): Zellen einzeln, tiefste Zelle.
-- Sonst nur Gesamtspannung: mittlere Zelle = Gesamt / eingestellte Zellenzahl. Ohne Zellenzahl wird nicht
-- geschätzt (Hinweis «Zellenzahl einstellen»).
local function liesAkku(a, q, S, tele)
  a.da = q ~= nil
  a.n, a.summe, a.tief, a.diff, a.mittel, a.zellen = 0, nil, nil, nil, nil, false
  for k = 1, 12 do a[k] = nil end
  if q == nil or not tele then return end
  a.summe = imBereich("u", zahl(q))
  local function nurSumme()
    if S and S > 0 and a.summe and a.summe > 0 then
      a.n = S
      a.mittel = a.summe / S
      a.tief = a.mittel
    end
  end
  if OPTION_CELL_COUNT == nil or OPTION_CELL_INDEX == nil then return nurSumme() end
  local n = zahl(q, OPTION_CELL_COUNT)
  if n == nil or n < 1 or n ~= floor(n) or n > 12 then return nurSumme() end
  local m = (S and S > 0) and min(n, S) or n
  local lo, hi, summe = nil, nil, 0
  for i = 1, m do
    local ok, opt = pcall(OPTION_CELL_INDEX, i)
    local z = ok and zahl(q, opt) or nil
    if z and z > 5 then
      for k = 1, i - 1 do a[k] = nil end
      return nurSumme()
    end
    if z and z < 0 then z = nil end
    a[i] = z
    if z then
      summe = summe + z
      if lo == nil or z < lo then lo = z end
      if hi == nil or z > hi then hi = z end
    end
  end
  a.zellen, a.n, a.tief = true, m, lo
  if lo then a.diff = hi - lo end
  if a.summe == nil or a.summe <= 0 then a.summe = summe end
end

-- Werte lesen. Ohne Telemetrie gibt es keine Werte (nil = Strich in der Anzeige).
local function lesen(w)
  local c, v = w.cfg, w.v
  v.tele = telemetrie(w)
  local t = v.tele
  v.h = t and zahl(c.hoehe) or nil
  v.vs = t and zahl(c.vario) or nil
  v.rssi = t and zahl(c.rssi) or nil
  v.speed = t and zahl(c.speed) or nil
  v.pRegler = t and zahl(c.aProz) or nil
  v.mah = t and zahl(c.aMah) or nil
  v.strom = t and zahl(c.aStrom) or nil
  -- Schalter und Geber (auch ohne Telemetrie)
  v.gasP = gasProzent(c, prozent(c.gas))
  v.motorSw = c.swMotor and (stellung(c.swMotor) == c.motorPos) or nil
  v.ausgeklinkt = c.swSchlepp and (stellung(c.swSchlepp) == c.schleppPos) or nil
  v.sw1 = c.sw1 and aktiv(c.sw1, c.sw1Inv) or nil
  v.sw2 = c.sw2 and aktiv(c.sw2, c.sw2Inv) or nil
  v.swH = c.swHoehe and aktiv(c.swHoehe) or nil
  v.stumm = c.stumm and aktiv(c.stumm) or false
  for i = 1, 3 do
    local a = w.ak[i]
    a.rolle, a.typ = c["a" .. i .. "Rolle"] or 3, c["a" .. i .. "Typ"] or 1
    a.S = (c["a" .. i .. "S"] or 0) > 0 and c["a" .. i .. "S"] or nil
    liesAkku(a, c["a" .. i], a.S, t)
  end
  if TEST and (TEST.v or TEST.ohne or TEST.tele ~= nil) then   -- nur TEST.zustand: echte Werte bleiben
    v.tele = TEST.tele ~= false
    for k, x in pairs(TEST.v or {}) do
      if k == "ak" and type(x) == "table" then
        for i, ta in pairs(x) do
          local a = w.ak[i]
          if a then for kk, xx in pairs(ta) do a[kk] = xx end end
        end
      else
        v[k] = x
      end
    end
    for _, k in ipairs(TEST.ohne or {}) do v[k] = nil end
  end
  -- 0.7.2 (Issue #1): zwei Bänder (TD-Empfänger). v.rssi ist das bessere Band (Anzeige, bisherige Grenzen);
  -- Warnung je Band, Alarm auf RX VFR, ohne RX VFR auf das bessere VFR. 0 beim zweiten Band = nicht vorhanden.
  local band = c.rssi2 or c.vfr or c.vfr2 or c.rxvfr or (TEST and TEST.band)   -- ohne Band-Quellen nichts rechnen
  local r9 = band and t and zahl(c.rssi2) or nil
  if r9 == 0 then r9 = nil end
  v.vfr24, v.vfr900, v.rxvfr = nil, nil, nil
  if band and t then v.vfr24, v.vfr900, v.rxvfr = zahl(c.vfr), zahl(c.vfr2), zahl(c.rxvfr) end
  if v.vfr900 == 0 and r9 == nil then v.vfr900 = nil end
  if TEST and TEST.band then                        -- Testhaken: Werte beider Bänder vorgeben (Simulator ohne Telemetrie)
    r9 = TEST.band.rssi900
    for k, x in pairs(TEST.band) do v[k] = x end
    if TEST.band.rssi24 then v.rssi = TEST.band.rssi24 end
  end
  v.zweiBand = (r9 ~= nil or v.vfr900 ~= nil) or nil
  v.rssi900 = imBereich("rssi", r9)
  v.rssi24 = v.zweiBand and imBereich("rssi", v.rssi) or nil
  if v.rssi900 and (v.rssi == nil or v.rssi900 > v.rssi) then v.rssi = v.rssi900 end
  v.vfr24, v.vfr900, v.rxvfr = imBereich("p", v.vfr24), imBereich("p", v.vfr900), imBereich("p", v.rxvfr)
  v.vfrAlarm = v.rxvfr or ((v.vfr24 or v.vfr900) and max(v.vfr24 or -1, v.vfr900 or -1)) or nil
  v.h, v.vs, v.rssi, v.speed = imBereich("h", v.h), imBereich("vs", v.vs), imBereich("rssi", v.rssi), imBereich("speed", v.speed)
  v.pRegler, v.mah, v.strom = imBereich("p", v.pRegler), imBereich("mah", v.mah), imBereich("a", v.strom)
  -- Akku-% und Rollen
  v.antrieb, v.empf = nil, nil
  local eSegler = c.modell == 2
  for i = 1, 3 do
    local a = w.ak[i]
    a.p = nil
    if a.rolle == 2 then
      if v.antrieb == nil and a.da then v.antrieb = i end   -- jeder Modelltyp (Entscheid 21.11.2026)
      local pq = c.pQuelle or 1
      if pq == 1 and v.pRegler then
        a.p, a.quelle = v.pRegler, 1
      elseif pq == 2 and v.mah and (c.kap or 0) > 0 then
        a.p, a.quelle = clamp(100 - v.mah / c.kap * 100, 0, 100), 2
      else
        a.p, a.quelle = kurve(a.tief, a.typ), 3
      end
    else
      a.p = kurve(a.tief, a.typ)
      if a.rolle == 1 and v.empf == nil and a.da then v.empf = i end
    end
    if a.p then a.p = clamp(a.p, 0, 100) end
    if v.tele and a.summe and a.summe > 0.5 and (w.akMin[i] == nil or a.summe < w.akMin[i]) then w.akMin[i] = a.summe end
  end
  if v.tele and v.rssi and (w.rssiMin == nil or v.rssi < w.rssiMin) then w.rssiMin = v.rssi end
  if v.tele and v.speed and (w.speedMax == nil or v.speed > w.speedMax) then w.speedMax = v.speed end
  -- Motor (nur E-Segler): LÄUFT = nicht ausgeschaltet und Gas über der Schwelle
  if eSegler then
    local laeuft = v.motorSw ~= true and v.gasP ~= nil and v.gasP >= (c.gasAb or 10)
    v.laeuft = laeuft
    v.motor = laeuft and "laeuft" or (v.motorSw and "aus" or "ein")
  else
    v.laeuft, v.motor = false, nil
  end
  if v.tele then w.teleWar = true end
end

-- Einheiten und Kommastellen der Sensoren, Modellname, Flugphase (alle 0,5 s bzw. 2 s).
local function liesEinheiten(w)
  local c, eh, dz = w.cfg, w.eh, w.dz
  eh.h, eh.vs, eh.speed = einheit(c.hoehe), einheit(c.vario), einheit(c.speed)
  dz.h, dz.vs, dz.speed = stellen(c.hoehe, 0), stellen(c.vario, 1), stellen(c.speed, 0)
  w.un.h = einheitNr(c.hoehe, UNIT_METER)
  local ok, n = pcall(model.name)
  w.modell = (ok and type(n) == "string" and n ~= "") and n or nil
end

-- Ausklinkhöhe setzen und ansagen. art: 1 Schlepp, 2 Motor, 3 höchster Punkt (Hand/Winde).
local function setzeAk(w, f, hh, art, fest, now)
  if hh == nil then return end
  f.ak, f.art, f.akFest = hh, art, fest
  hinweis(w, string.format(w.T.ausgeklinkt, string.format("%.0f", hh)), now)
  if w.cfg.ansAk then ansage(w, "ausklinkhoehe", floor(hh + 0.5), UNIT_METER, 0) end
  w.dateiOffen = true
end

local function flugEnde(w, now)
  local f = w.flug
  if f == nil then return end
  w.flug = nil
  if w.th then w.th.an = false end
  if (f.t or 0) >= (w.cfg.minS or 0) then
    f.offen, f.peak, f.sinkT, f.ruhig, f.akFest, f.motorLief = nil, nil, nil, nil, nil, nil
    local L = w.liste
    L[#L + 1] = f
    while #L > MAX_FLUEGE do table.remove(L, 1) end
    hinweis(w, string.format(w.T.flugGespeichert, tostring(#L)), now)
    ansage(w, "flug_gespeichert")
  end
  w.dateiOffen, w.dateiJetzt = true, true
end

-- Thermik und Höhengewinn. Steigen ab «Ansage ab Steigen» (w.g.thAb) während thS Sekunden ist eine Thermik.
-- Der Gewinn zählt ab dem Beginn dieses Steigens. Die Thermik endet, wenn das Vario TH_AUS Sekunden ohne Unterbruch
-- unter 0 liegt oder der Motor läuft. Angezeigt werden der höchste Gewinn und die Zeit bis dahin, auch nach dem Ende
-- (w.th.an = false) bis zur nächsten Thermik. Kurze Dellen im Steigen beenden nichts und setzen nichts zurück:
-- vor der Erkennung gilt der Anfang, bis das Vario TH_DELLE Sekunden unter der Schwelle oder unter 0 liegt; danach
-- zählt für das Ende nur Steigen ab der Schwelle als Unterbruch (Rauschen um 0 hält das Ende nicht auf).
local TH_AUS, TH_DELLE = 10, 2
local function thermik(w, c, v, h, now, dt)
  local th = w.th
  local aktiv = th ~= nil and th.an
  local ab = w.g.thAb or 1
  w.thT = w.thT or 0                                 -- erster Durchlauf: Zähler noch leer
  if v.vs and not v.laeuft and v.vs >= ab then
    if w.thKand == nil and not aktiv then w.thKand = { h, now } end      -- Steigen beginnt: möglicher Anfang
    w.thT, w.thU = (w.thT or 0) + dt, 0
  else
    w.thU = (w.thU or 0) + dt
    if v.laeuft or v.vs == nil or v.vs < 0 or w.thU >= TH_DELLE then w.thT, w.thKand = 0, nil end
  end
  if not aktiv and w.thKand and w.thT >= (c.thS or 3) then
    th = { an = true, h0 = w.thKand[1] or h, t0 = w.thKand[2], sink = 0 }
    w.th, w.thKand = th, nil
  end
  if th and th.an then
    if h and th.h0 == nil then th.h0, th.t0 = h, now end              -- Höhe fehlte am Anfang
    if h and (th.gew == nil or h - th.h0 > th.gew) then th.gew, th.dauer = h - th.h0, now - th.t0 end
    if v.vs ~= nil and v.vs >= ab then th.sink = 0 elseif v.vs == nil or v.vs < ab * 0.5 then th.sink = th.sink + dt end
    if v.laeuft or th.sink >= TH_AUS then th.an = false end
  end
  -- Ansage: nach thS Sekunden Steigen, danach thRuhe Sekunden still
  if w.thT >= (c.thS or 3) and now - (w.tTh or -1e9) >= (c.thRuhe or 30) then
    w.tTh = now
    local tz = string.format("%+.1f", v.vs)
    if w.sp ~= 2 then tz = tz:gsub("%.", ",") end
    hinweis(w, string.format(w.T.thermik, tz), now)
    if c.ansTh then ansage(w, "thermik") end
  end
end
K._thermik = thermik      -- für test/thermik-faelle.lua

-- Flug, Startart, Ausklinkhöhe, Phasenzeiten, Thermik und Ereignis-Ansagen.
local function flugLogik(w, now, dt)
  local c, v = w.cfg, w.v
  local h = v.h
  local f = w.flug
  if w.sperreLandung and (h == nil or h < (c.endH or 5)) then w.sperreLandung = nil end
  if f == nil then
    if v.tele and not w.sperreLandung and ((h and h > (c.startH or 10)) or v.laeuft) then
      f = { t = 0, art = 0, mot = 0, ph = {}, hmax = h, peak = h, sinkT = 0, ruhig = 0 }
      w.flug = f
      w.th, w.thKand = nil, nil
      w.zs = {}
      w.zeitNaechste = nil
      w.dateiOffen = true
    end
  end
  if f == nil then
    w.ausAlt, w.laeuftAlt = v.ausgeklinkt, v.laeuft
    return
  end
  f.t = (f.t or 0) + dt
  if v.laeuft then f.mot = (f.mot or 0) + dt f.motorLief = true end
  local pn = phase(w)
  if pn then
    local e = nil
    for _, p in ipairs(f.ph) do if p[1] == pn then e = p break end end
    if e == nil and #f.ph < MAX_PHASEN then e = { pn, 0 } f.ph[#f.ph + 1] = e end
    if e then e[2] = e[2] + dt end
  end
  w.phaseName = pn
  if h then
    if f.hmax == nil or h > f.hmax then f.hmax = h end
  end
  if v.vs then
    if f.vmax == nil or v.vs > f.vmax then f.vmax = v.vs end
    if f.vmin == nil or v.vs < f.vmin then f.vmin = v.vs end
  end
  local ea = v.empf and w.ak[v.empf].summe
  if ea and ea > 0.5 and (f.rxmin == nil or ea < f.rxmin) then f.rxmin = ea end

  -- Ausklinkhöhe
  local mode = c.akQuelle or 1
  if v.ausgeklinkt and w.ausAlt == false and (mode == 1 or mode == 2) and f.art ~= 1 then
    setzeAk(w, f, h, 1, true, now)
  end
  if c.modell == 2 and w.laeuftAlt and not v.laeuft and (mode == 1 or mode == 3) and not f.akFest then
    setzeAk(w, f, h, 2, true, now)
  end
  local hoch = (mode == 4 and not f.akFest) or (mode == 1 and not f.motorLief and f.art == 0)
  if hoch and h then
    if f.peak == nil or h > f.peak then f.peak = h end
    local sinkt = (v.vs ~= nil and v.vs < -0.3) or (v.vs == nil and h < f.peak - 1)
    f.sinkT = sinkt and (f.sinkT or 0) + dt or 0
    if f.sinkT >= (c.sinkS or 3) and f.peak > (c.startH or 10) then
      setzeAk(w, f, f.peak, 3, mode == 4, now)
    end
  end
  w.ausAlt, w.laeuftAlt = v.ausgeklinkt, v.laeuft

  thermik(w, c, v, h, now, dt)

  -- Zeitansagen
  if (c.hoeheAlle or 0) > 0 and h and now - (w.tHA or now - c.hoeheAlle) >= c.hoeheAlle then
    w.tHA = now
    ansage(w, "hoehe", floor(h + 0.5), w.un.h or UNIT_METER, 0)
  end
  if (c.zeitAlle or 0) > 0 then
    w.zeitNaechste = w.zeitNaechste or c.zeitAlle * 60
    if f.t >= w.zeitNaechste then
      w.zeitNaechste = w.zeitNaechste + c.zeitAlle * 60
      ansage(w, "flugzeit", floor(f.t / 60), UNIT_MINUTE or UNIT_SECOND, 0)
    end
  end

  -- Flugende: unter endH, ruhig, Motor aus
  local ruhig = h and h < (c.endH or 5) and (v.vs == nil or abs(v.vs) < 0.5) and not v.laeuft
  f.ruhig = ruhig and (f.ruhig or 0) + dt or 0
  if f.ruhig >= (c.ruhigS or 10) then flugEnde(w, now) end
end

-- Höhe auf Schalter (steigende Flanke), unabhängig vom Flug
local function hoeheSchalter(w)
  local v = w.v
  if v.swH and w.swHAlt == false and v.h then ansage(w, "hoehe", floor(v.h + 0.5), w.un.h or UNIT_METER, 0) end
  w.swHAlt = v.swH
end

-- Vario-Mittel 20 s und Verlauf (60 Säulen über 1, 2 oder 5 min)
local function verlauf(w, now)
  local c, v = w.cfg, w.v
  if now - (w.tRing or -10) >= 1 then
    w.tRing = now
    local r = w.ring
    r[#r + 1] = v.vs or false
    if #r > 20 then table.remove(r, 1) end
    local s, n = 0, 0
    for _, x in ipairs(r) do if x then s, n = s + x, n + 1 end end
    w.vMittel = n > 0 and s / n or nil
  end
  local art, dauer = c.verlauf or 1, c.verlaufMin or 2
  if art == 0 then return end
  if w.vlArt ~= art or w.vlDauer ~= dauer then
    w.vl, w.vlN, w.vlArt, w.vlDauer, w.vlS, w.vlZ, w.tVl = {}, 0, art, dauer, 0, 0, now
  end
  local x = art == 1 and v.vs or v.h
  if x then w.vlS, w.vlZ = w.vlS + x, w.vlZ + 1 end
  if now - w.tVl >= dauer then                    -- dauer min / 60 Säulen = dauer s je Säule
    w.tVl = now
    local vl = w.vl
    vl[#vl + 1] = w.vlZ > 0 and w.vlS / w.vlZ or false
    if #vl > 60 then table.remove(vl, 1) end
    w.vlS, w.vlZ = 0, 0
  end
end

-- Eine Warnung führen: kommt nach AN_S, geht nach AUS_S.
local STILL = false     -- warnungen(): true = Haken «auch bei Motor aus» weg und Motor aus -> Meldung sofort beenden
local function melde(w, now, name, stufe, bed, text, wav, wert, einh, dez)
  local m = w.meld[name]
  if m == nil then
    m = { an = false, name = name }
    w.meld[name] = m
  end
  m.text = text
  if bed then
    m.weg = nil
    if not m.an then
      m.seit = m.seit or now
      if now - m.seit >= AN_S then
        m.an = true
        m.tAns = nil
      end
    end
  else
    m.seit = nil
    if STILL then m.an, m.weg = false, nil end      -- schweigt sofort, nicht erst nach AUS_S (Format 2, 3.5)
    if m.an then
      m.weg = m.weg or now
      if now - m.weg >= AUS_S then m.an = false end
    end
  end
  if m.an then
    m.stufe, m.wav, m.wert, m.einh, m.dez = stufe, wav, wert, einh, dez
    w.nAktiv = w.nAktiv + 1
    w.aktiv[w.nAktiv] = m
  end
  return m.an
end

local PAAR = { hW = "hA", pW = "pA", rW = "rA", z1W = "z1A", z2W = "z2A", z3W = "z3A" }
-- Meldung -> Gruppe der eingebauten Grenzen in der Studio-Datei (Ansage/Vibration je Wert)
local OPTGRUPPE = { vfA = "r", b24W = "r", b9W = "r", hA = "h", hW = "h", rA = "r", rW = "r", z1A = "z1", z1W = "z1", z2A = "z2", z2W = "z2", z3A = "z3", z3W = "z3" }

local function warnungen(w, now)
  local v, g, T, c = w.v, w.g, w.T, w.cfg
  w.nAktiv = 0
  local d = v.tele
  -- Startsperre: nach Beginn der Telemetrie erst nach «sperre» Sekunden warnen
  if d then w.tTeleSeit = w.tTeleSeit or now else w.tTeleSeit = nil end
  local frei = d and (now - (w.tTeleSeit or now) >= (c.sperre or 0))
  v.st = v.st or {}
  local st = v.st
  for k in pairs(st) do st[k] = nil end

  -- «Alarm auch bei Motor aus» (0.4.0, Format 2, 3.5): Haken aus und Schalter auf «Motor aus bei» = dieser Alarm
  -- schweigt (keine Meldung, kein Ton, keine Ansage, keine Vibration); die Farbe zeigt den Wert weiter.
  local motAus = v.motorSw == true
  local function still(k) return motAus and c[k] == false end
  local function farbe(a, wa) return a and 2 or (wa and 1 or nil) end

  local ha = frei and g.hAlarm and v.h and v.h > g.hAlarm
  local hw = frei and not ha and g.hWarn and v.h and v.h > g.hWarn
  local sH = still("hMot")
  STILL = sH
  if melde(w, now, "hA", 2, ha and not sH, T.hoeheHoch .. " " .. string.format("%.0f m", v.h or 0), "hoehe_alarm", v.h and floor(v.h + 0.5), UNIT_METER, 0) then st.h = 2
  elseif melde(w, now, "hW", 1, hw and not sH, T.hoeheHoch .. " " .. string.format("%.0f m", v.h or 0), "hoehe_warnung", v.h and floor(v.h + 0.5), UNIT_METER, 0) then st.h = 1
  elseif sH then st.h = farbe(ha, hw) end

  for i = 1, 3 do
    local a = w.ak[i]
    local nutzen = a.da                               -- jeder Akku mit Sensor, auch Antrieb beim reinen Segler
    local zw, za = g["z" .. i .. "Warn"], g["z" .. i .. "Alarm"]
    local text = a.rolle == 2 and T.antriebTief or (a.rolle == 1 and T.empfTief or T.akkuTief)
    local wav = a.rolle == 2 and "antriebsakku" or (a.rolle == 1 and "empfaengerakku" or "akku")
    local zA = frei and nutzen and za and a.tief and a.tief < za
    local zW = frei and nutzen and not zA and zw and a.tief and a.tief < zw
    local pA, pW = false, false
    if a.rolle == 2 and nutzen and a.p and frei then
      pA = g.pAlarm and a.p < g.pAlarm
      pW = not pA and g.pWarn and a.p < g.pWarn
    end
    local tx = text
    if a.rolle == 2 and a.p then tx = text .. " " .. string.format("%.0f %%", a.p) end
    local sZ, sP, sD = still("z" .. i .. "Mot"), still("pMot"), still("dMot")
    STILL = (sZ and (zA or zW)) or (sP and (pA or pW))
    local s = nil
    if melde(w, now, "z" .. i .. "A", 2, (zA and not sZ) or (pA and not sP), tx, wav .. "_alarm", a.p and floor(a.p + 0.5) or nil, a.p and UNIT_PERCENT or nil, 0) then s = 2
    elseif melde(w, now, "z" .. i .. "W", 1, (zW and not sZ) or (pW and not sP), tx, wav .. "_tief", a.p and floor(a.p + 0.5) or nil, a.p and UNIT_PERCENT or nil, 0) then s = 1
    elseif sZ or sP then s = farbe((zA and sZ) or (pA and sP), (zW and sZ) or (pW and sP)) end
    local dd = frei and nutzen and a.zellen and g.zDiff and a.diff and a.diff > g.zDiff
    STILL = sD
    if melde(w, now, "d" .. i, 1, dd and not sD, T.zellDiff, "zellenunterschied") and s == nil then s = 1
    elseif dd and sD and s == nil then s = 1 end
    st["a" .. i] = s
  end

  local ra = frei and g.rssiAlarm and v.rssi and v.rssi < g.rssiAlarm
  local rw = frei and not ra and g.rssiWarn and v.rssi and v.rssi < g.rssiWarn
  local sR = still("rMot")
  STILL = sR
  if melde(w, now, "rA", 2, ra and not sR, T.empfangSchwach, "empfang_alarm", v.rssi and floor(v.rssi + 0.5), UNIT_PERCENT, 0) then st.rssi = 2
  elseif melde(w, now, "rW", 1, rw and not sR, T.empfangSchwach, "empfang_schwach", v.rssi and floor(v.rssi + 0.5), UNIT_PERCENT, 0) then st.rssi = 1
  elseif sR then st.rssi = farbe(ra, rw) end
  -- 0.7.2: Alarm auf RX VFR (ohne RX VFR das bessere VFR); Warnung je Band (VFR, ohne VFR die RSSI-Warnung)
  local fa = frei and g.vfrA and v.vfrAlarm and v.vfrAlarm < g.vfrA
  if melde(w, now, "vfA", 2, fa and not sR, T.empfangSchwach, "empfang_alarm", v.vfrAlarm and floor(v.vfrAlarm + 0.5), UNIT_PERCENT, 0) then st.rssi = 2 end
  if v.zweiBand then
    local function schwach(rs, vf)
      if vf then return g.vfrW ~= nil and vf < g.vfrW end
      return g.rssiWarn ~= nil and rs ~= nil and rs < g.rssiWarn
    end
    local an = (w.meld.vfA and w.meld.vfA.an) or (w.meld.rA and w.meld.rA.an)
    local w24 = frei and not an and not sR and schwach(v.rssi24, v.vfr24)
    local w9 = frei and not an and not sR and schwach(v.rssi900, v.vfr900)
    if melde(w, now, "b24W", 1, w24, T.empfang24, "empfang_24") and st.rssi == nil then st.rssi = 1 end
    if melde(w, now, "b9W", 1, w9, T.empfang900, "empfang_900") and st.rssi == nil then st.rssi = 1 end
  end
  STILL = false
  melde(w, now, "tele", 1, w.teleWar and not d, T.teleWeg, "telemetrie_weg")

  -- Studio-Grenzen für Werte ohne eingebaute Grenze (Sensoren, Kanäle, übrige Lua-Werte). Ohne eigene Ansage: Ton.
  -- Befehlsgrenze (0.4.0): Werte im Kreis lesen, je Durchlauf höchstens MON_JE Grenzen (wie Elektro «grenzenExtra»).
  -- Das Ergebnis bleibt am Eintrag (m._a, m._w); gemeldet wird jeder Durchlauf, aber nur für Einträge, die über der
  -- Grenze sind oder deren Meldung noch läuft. So bleiben aktive Meldungen stehen, und wenige Befehle je wakeup.
  local mon = w.sd and w.sd.mon
  if mon then
    local n = #mon
    local von = w.monPos or 1
    if von > n then von = 1 end
    local bis = von + MON_JE - 1
    if bis > n then bis = n end
    for i = von, bis do
      local m = mon[i]
      local x = wertVon(w, m.d, m.key)
      local unter = m.richtung == "unter"
      m._a = x ~= nil and m.alarm ~= nil and ((unter and x < m.alarm) or (not unter and x > m.alarm))
      m._w = not m._a and x ~= nil and m.warn ~= nil and ((unter and x < m.warn) or (not unter and x > m.warn))
    end
    w.monPos = bis + 1
    -- «heiss» = über der Grenze oder Meldung läuft noch; nur diese Einträge gehen durch melde()
    local heiss = w.monHeiss
    if heiss == nil or w.monVon ~= mon then heiss, w.monVon, w.monNH = {}, mon, 0 w.monHeiss = heiss end
    -- höchstens MON_HEISS gleichzeitig (Befehlsgrenze); weitere kommen dran, sobald ein Platz frei wird
    local nh = w.monNH or 0
    for i = von, bis do
      if (mon[i]._a or mon[i]._w) and not heiss[i] and nh < MON_HEISS then heiss[i], nh = true, nh + 1 end
    end
    local meld, gst = w.meld, w.gst
    for i in pairs(heiss) do
      local m = mon[i]
      local mA, mW = meld["sA" .. i], meld["sW" .. i]
      if (frei and (m._a or m._w)) or (mA and (mA.an or mA.seit)) or (mW and (mW.an or mW.seit)) then
        local sS = motAus and ((m.mot and c[m.mot] == false) or (m.mot == nil and m.bma == false))
        local a, wa = frei and m._a, frei and m._w
        STILL = sS
        local s = nil
        if melde(w, now, "sA" .. i, 2, a and not sS, m.name, nil) then s = 2
        elseif melde(w, now, "sW" .. i, 1, wa and not sS, m.name, nil) then s = 1
        elseif sS then s = farbe(a, wa) end
        meld["sA" .. i].opt, meld["sW" .. i].opt = m, m
        STILL = false
        gst[m.key] = s
      else
        gst[m.key], heiss[i], nh = nil, nil, nh - 1
      end
    end
    w.monNH = nh
  end

  local n = 0
  for i = 1, w.nAktiv do
    local m = w.aktiv[i]
    local pa = PAAR[m.name] or (m.name:sub(1, 2) == "sW" and ("sA" .. m.name:sub(3)))
    local alarm = pa and w.meld[pa]
    if not (alarm and alarm.an) then
      n = n + 1
      w.aktiv[n] = m
    end
  end
  w.nAktiv = n
  local stu = 0
  for i = 1, n do
    if w.aktiv[i].stufe > stu then stu = w.aktiv[i].stufe end
  end
  w.stufe = stu
  if n > 0 then
    local t, nt = nil, 0
    for s = 2, 1, -1 do
      for i = 1, n do
        local m = w.aktiv[i]
        if m.stufe == s and nt < 6 then t, nt = t and (t .. "  |  " .. m.text) or m.text, nt + 1 end   -- Band: höchstens 6
      end
    end
    w.meldText = t
  end
  local irgend = v.h or v.vs or v.rssi or w.ak[1].summe or w.ak[2].summe or w.ak[3].summe
  if stu == 2 then
    w.zustand = "alarm"
  elseif stu == 1 then
    w.zustand = "warnung"
  elseif not d or not irgend then
    w.zustand = "keine"
  else
    w.zustand = "ok"
  end
end

K._warnungen = warnungen  -- für test/motoraus-faelle.lua

-- Ansagen: Alarme gehen vor, dann Ereignisse aus der Warteschlange. Mindestabstand 3 s.
-- Stumm-Schalter: keine Ereignisse und keine Warnungen; rote Alarme (Stufe 2) kommen trotzdem (Entscheid 21.11.2026).
local function ansagen(w, now)
  if w.tAnsage and now - w.tAnsage < ANSAGE_ABSTAND then return end
  local c = w.cfg
  local stumm = w.v.stumm
  if stumm then
    for i = #w.anQ, 1, -1 do w.anQ[i] = nil end
  end
  local wahl = nil
  for i = 1, w.nAktiv do
    local m = w.aktiv[i]
    if (m.stufe == 2 or (c.warnAnsage and not stumm)) and (m.tAns == nil or now - m.tAns >= w.g.pause)
      and (wahl == nil or m.stufe > wahl.stufe) then
      wahl = m
    end
  end
  if wahl then
    wahl.tAns, w.tAnsage = now, now
    w.nAnsage = (w.nAnsage or 0) + 1                 -- Zähler für den Testzustand (Alarm trotz Stumm)
    local opt = w.sd and w.sd.opt or {}
    local o = wahl.opt or opt[OPTGRUPPE[wahl.name] or ""]
    if o == nil and wahl.name:sub(1, 1) == "z" and w.ak[tonumber(wahl.name:sub(2, 2)) or 0].rolle == 2 then o = opt.p end
    local ans, vib = c.ansage and not (o and o.ans == false), c.vibration and not (o and o.vib == false)
    if c.ansage and not ans and wahl.stufe == 2 and system.playTone then
      pcall(system.playTone, 2200, 180, 60)          -- Studio «ansage = false»: Ton bleibt (Format 2, 7.5)
    elseif ans then
      if not sage(w, wahl.wav) and system.playTone then
        pcall(system.playTone, wahl.stufe == 2 and 2200 or 1500, 180, 60)
      end
      if c.zahl and wahl.wert and wahl.einh and system.playNumber then
        pcall(system.playNumber, wahl.wert, wahl.einh, wahl.dez or 0)
      end
    end
    if vib and wahl.stufe == 2 and system.playHaptic then pcall(system.playHaptic, "- . -") end
    return
  end
  local e = table.remove(w.anQ, 1)
  if e == nil then return end
  w.tAnsage = now
  if e.wav and not sage(w, e.wav) and system.playTone then pcall(system.playTone, 1200, 120, 40) end
  if e.wert and e.einh and system.playNumber then pcall(system.playNumber, e.wert, e.einh, e.dez or 0) end
end

K._ansagen = ansagen      -- für test/motoraus-faelle.lua

-- Flug löschen (nr = Platz in der Liste, 0 = laufender Flug). Spätere Nummern rücken lückenlos nach.
local function loesche(w, nr, now)
  if nr == 0 then
    if w.flug then
      w.flug = nil
      w.sperreLandung = true                       -- erst nach der Landung wieder einen Flug beginnen
    end
  elseif w.liste[nr] then
    table.remove(w.liste, nr)
  else
    return
  end
  hinweis(w, string.format(w.T.flugGeloescht, tostring(nr == 0 and (#w.liste + 1) or nr)), now)
  w.dateiOffen, w.dateiJetzt = true, true
end

-- «JA, ZURÜCKSETZEN»: einzige Stelle, an der Übersicht und Flugliste gelöscht werden.
local function zurueck(w, now)
  w.liste, w.dauer = {}, {}
  w.akMin, w.rssiMin, w.speedMax = {}, nil, nil
  if w.flug then
    w.flug = { t = w.flug.t, art = w.flug.art, ak = w.flug.ak, akFest = w.flug.akFest, mot = w.flug.mot,
      ph = w.flug.ph, hmax = w.v.h, peak = w.flug.peak, sinkT = 0, ruhig = 0, motorLief = w.flug.motorLief }
  end
  hinweis(w, w.T.zurueckgesetzt, now)
  w.dateiOffen, w.dateiJetzt = true, true
end

-- Testhaken: Zustand alle 0,5 s als JSON in test-zustand.json (nur Simulator, nur mit TEST.zustand).
local function testZustand(w, now)
  if now - (w.tZustand or -10) < 0.5 then return end
  w.tZustand = now
  if ZUSTAND == nil then
    local ok, v = pcall(system.getVersion)
    if not (ok and type(v) == "table" and v.simulation) then TEST.zustand = nil return end
    local okL, f = pcall(lade, "testzustand.lua")
    if not okL then TEST.zustand = nil print(tostring(w.name) .. ": Fehler: testzustand.lua " .. tostring(f)) return end
    ZUSTAND = f
  end
  local ak = {}
  for i = 1, 3 do
    local a = w.ak[i]
    ak[i] = { da = a.da, summe = a.summe, tief = a.tief, p = a.p, zellen = a.zellen, n = a.n, rolle = a.rolle }
  end
  w.testExtra = { flug = w.flug, nListe = #w.liste, ak = ak, phase = w.phaseName, vMittel = w.vMittel, th = w.th,
    sd = w.sd and { status = w.sd.status, fehler = w.sd.fehler, nA = #(w.sd.ansichten or {}), nMon = #(w.sd.mon or {}) },
    A = w.A and (w.A.breite .. "x" .. w.A.hoehe) or "",
    aG = w.aInfo and w.aInfo.genutzt or "", aP = w.aInfo and w.aInfo.angepasst or false, aWeg = w.aInfo and w.aInfo.weg or 0,
    zeile = w.sdZeile or "", fmt = w.fmtGelesen or 0, wahl = w.studioWahl or "", quelle = w.sd and w.sd.quelle or "",
    mem = floor(collectgarbage("count")),
    nVerlauf = #w.vl, motor = w.v.motor, dialog = w.dialog, detail = w.detail, nAnsage = w.nAnsage or 0,
    antrieb = w.v.antrieb or 0 }
  local ok, e = pcall(ZUSTAND, w, now, "test-zustand.json")
  if not ok or not e then print(tostring(w.name) .. ": Fehler: Testzustand konnte nicht geschrieben werden " .. tostring(e)) end
end

-- Datei schreiben in fünf Aufrufen (Befehlsgrenze): 1 felder.lua laden und Verzeichnis bauen, 2 und 3 je die Hälfte
-- der Einstellungen, 4 Zähler und Flüge, 5 schreiben. Ein Schritt je wakeup.
local function schreibeDatei(w, now)
  local s = w.schreibS or 1
  if s == 1 then
    w.dateiOffen, w.dateiJetzt, w.tDatei = false, false, now
    local ok, F = pcall(lade, "felder.lua")
    if ok then pcall(F.feld, "modell") end                -- Verzeichnis jetzt bauen
    w.schreibF, w.schreibS = ok and F or nil, 2
    if ok then return false end
  elseif s == 2 then
    local ok, z = pcall(w.schreibF.zeilen, w, 1)
    w.schreibZ, w.schreibS = ok and z or nil, 3
    if ok then return false end
  elseif s == 3 and w.schreibZ then
    local ok = pcall(w.schreibF.zeilen, w, 2, w.schreibZ)
    w.schreibS = ok and 4 or 5
    if ok then return false end
  elseif s == 4 and w.schreibZ then
    local ok = pcall(w.schreibF.zeilen, w, 5, w.schreibZ)          -- letztes Drittel der Einstellungen
    w.schreibS = ok and 6 or 7
    if ok then return false end
  elseif s == 6 and w.schreibZ then
    local ok, text = pcall(w.schreibF.zeilen, w, 3, w.schreibZ)
    w.schreibT, w.schreibS, w.schreibZ = ok and text or nil, 7, nil
    if ok then return false end
  end
  local okS, erfolg = false, false
  if w.schreibT then okS, erfolg = pcall(w.schreibF.schreibeText, w.schreibT) end
  w.schreibS, w.schreibF, w.schreibT, w.schreibZ = nil, nil, nil, nil
  if not (okS and erfolg) then
    if not w.dateiFehler then print(tostring(w.name) .. ": Fehler: Datei konnte nicht geschrieben werden") end
    w.dateiFehler = true
    w.fehler = "Datei schreiben"
  end
end

-- Ein Schritt der Sensorsuche; am Ende Hinweis und Grenzen neu.
local function sucheSchritt(w, now)
  if w.sucheFn == nil then
    local okL, f = pcall(lade, "suche.lua")
    if not okL then
      print(tostring(w.name) .. ": Fehler: suche.lua " .. tostring(f))
      w.fehler, w.sucheAktiv, w.autoOffen = "Suche: " .. tostring(f), false, false
      return
    end
    w.sucheFn = f
  end
  local ok, n = pcall(w.sucheFn, w)
  if not ok then
    print(tostring(w.name) .. ": Fehler in der Suche: " .. tostring(n))
    w.fehler = "Suche: " .. tostring(n)
    w.sucheFn, w.sz, w.sucheAktiv, w.autoOffen = nil, nil, false, false
    return
  end
  if n == nil then return end                       -- läuft noch
  w.sucheFn, w.sucheAktiv = nil, false
  if type(n) ~= "number" then n = 0 end
  print(tostring(w.name) .. ": Suche: " .. tostring(n) .. " neu zugewiesen")
  if n > 0 then
    grenzen(w)
    if model and model.dirty then pcall(model.dirty) end
  end
  if w.sucheQuelle == "auto" then
    if n > 0 then
      hinweis(w, string.format(w.T.autoSuche, tostring(n)), now)
      w.autoOffen = false
    end
  else
    hinweis(w, string.format(w.T.neuSuche, tostring(n)), now)
  end
end

function K.wecke(w)
  local now = os.clock()
  if w.tL == nil then w.tL, w.tE, w.tB = now - 1, now - 3, now - 1 end
  if now - w.tL >= DT_LESEN then
    local dt = clamp(now - w.tL, 0, 2)
    w.tL = now
    lesen(w)
    if now - w.tE >= 2 then
      w.tE = now
      liesEinheiten(w)
    end
    local pn = phase(w)
    w.phaseAnz = pn and pn:upper() or nil
    w.phaseText = pn
    flugLogik(w, now, dt)
    hoeheSchalter(w)
    verlauf(w, now)
    warnungen(w, now)
    ansagen(w, now)
    if TEST and TEST.zustand then testZustand(w, now) end
    if w.hinweis and now >= w.hinweisBis then w.hinweis = nil end
    -- laufenden Flug höchstens alle DAUER_S Sekunden sichern
    if w.flug and now - (w.tDauer or now) >= DAUER_S then w.dateiOffen = true end
    if w.schreibS then
      if not (w.sdAuf or w.sucheAktiv) then schreibeDatei(w, now) end   -- nie im selben Aufruf wie Studio/Suche
    elseif w.dateiOffen and (w.dateiJetzt or now - (w.tDatei or -100) >= 2) and not (w.sdAuf or w.sucheAktiv) then
      w.tDauer = now
      schreibeDatei(w, now)
    end
    w.tDauer = w.tDauer or now
    -- Studio-Datei beim Modellwechsel: je Durchlauf ein Schritt (nie in paint), danach wieder freigeben
    if w.sdAuf then
      STUDIO = STUDIO or lade("studio.lua")
      if STUDIO.schritt(w, function() return lade("felder.lua") end, SITZUNG) then
        w.sdAuf, STUDIO = nil, nil
        collectgarbage()
        studioAnwenden(w)
        studioHinweis(w, now)
        w.L, w.aGr = nil, nil                      -- passende Ansicht neu suchen (wakeup, R3)
      end
    end
    local A = w.A
    if A then
      for _, p in ipairs(A.plaetze) do
        if p.dar == "kurve" and now - (p.tk or -1e9) >= p.kurveS / 120 then
          p.tk = now
          p.buf = p.buf or {}
          local x = wertVon(w, p.d, p.key)
          p.buf[#p.buf + 1] = (x and PLATZ) and PLATZ.anteil(p, x) or false
          if #p.buf > 120 then table.remove(p.buf, 1) end
        end
        if p.zusatz ~= "keine" and w.flug then
          local x = wertVon(w, p.d, p.key)
          if x then
            local s = w.zs[p.key]
            if s == nil then s = { n = 0, sum = 0 } w.zs[p.key] = s end
            if s.min == nil or x < s.min then s.min = x end
            if s.max == nil or x > s.max then s.max = x end
            s.n, s.sum = s.n + 1, s.sum + x
          end
        end
      end
    end
    -- Sensorsuche in Schritten (Ethos begrenzt die Befehle je Aufruf): je Durchlauf ein Schritt.
    -- Erster Start ohne gespeicherte Einstellungen: automatisch starten, sobald Telemetrie da ist.
    if w.sdAuf then
      -- Studio-Schritt lief in diesem Aufruf: Suche erst im nächsten (Befehlsgrenze)
    elseif w.sucheAktiv then
      sucheSchritt(w, now)
    elseif w.autoOffen and w.v.tele and not (TEST and (TEST.v or TEST.ohne or TEST.tele ~= nil)) and now - (w.tAuto or -100) >= 5 then
      w.tAuto = now
      w.nAuto = (w.nAuto or 0) + 1
      if w.nAuto > 10 then w.autoOffen = false else w.sucheAktiv, w.sucheQuelle, w.sz = true, "auto", nil end
    end
  end

  if lcd.isVisible and not lcd.isVisible() then return end
  if now - w.tB >= DT_BILD then
    w.tB = now
    if Z == nil then Z = lade("zeichnen.lua") end
    local neuGewaehlt = false                     -- Umrechnen (R3) und Vorbereiten nie im selben Aufruf (Befehlsgrenze)
    if w.fW and w.aGr ~= w.fW .. "x" .. w.fH and not w.sdAuf then ansichtWaehlen(w, now) neuGewaehlt = true
    elseif w.infoNeu and w.aGr and not w.sdAuf then infoNach(w) end
    if w.A then PLATZ = PLATZ or lade("platz.lua") else PLATZ = nil end
    if PLATZ and w.A and w.L and Z.C and not neuGewaehlt then PLATZ.vorbereiten(w, w.L, Z, w.A, PLAETZE_JE_BILD) end
    local L = w.L
    if L and L.kompakt then                       -- Kompaktansicht: nur kompakt.lua, die Seiten freigeben
      if KOMPAKT == nil then
        for i = 1, SEITEN do SEITE[i] = nil end
        collectgarbage()
        KOMPAKT = lade("kompakt.lua")
      end
    elseif SEITE[w.seite] == nil then
      KOMPAKT = nil
      for i = 1, SEITEN do SEITE[i] = nil end
      collectgarbage()
      SEITE[w.seite] = lade("seite" .. w.seite .. ".lua")
    end
    w.blink = floor(now * 2) % 2 == 0
    w.seiten = SEITEN
    lcd.invalidate()
  end
end

-- R3: Ansicht zur Fenstergrösse wählen. Genau passend wie bisher, sonst ähnlichstes Seitenverhältnis (bei Gleichstand
-- grössere Fläche), Plätze einmal proportional umgerechnet (platz.lua). Läuft im wakeup, nie in paint.
ansichtWaehlen = function(w, now)
  local W, H, sd, T = w.fW, w.fH, w.sd, w.T
  w.aGr, w.A, w.aInfo = W .. "x" .. H, nil, { genutzt = "", angepasst = false, weg = 0 }
  w.sdHinweis, w.sdNurBand = w.sdHinweis0, nil
  if not (sd and sd.status == "geladen") then return end
  local best, bq, bf = nil, 0, 0
  for _, a in ipairs(sd.ansichten or {}) do
    if a.breite == W and a.hoehe == H then best, bq = a, -1 break end
    local q = math.abs(math.log((a.breite / a.hoehe) / (W / H)))
    local f = a.breite * a.hoehe
    if best == nil or q < bq - 1e-9 or (q <= bq + 1e-9 and f > bf) then best, bq, bf = a, q, f end
  end
  local leer = best == nil
  if best and bq ~= -1 then
    PLATZ = PLATZ or lade("platz.lua")
    local neu, weg = PLATZ.umrechnen(best, W, H)
    w.aInfo.angepasst, w.aInfo.weg = true, weg
    local vor = w.sdHinweis0
    w.sdHinweis = string.format(T.sdAngepasst, best.breite .. "x" .. best.hoehe) .. (weg > 0 and string.format(T.sdWeg, weg) or "")
      .. (vor and ("  |  " .. vor) or "")
    w.sdHinweisBis, w.sdNurBand = now + 5, vor == nil
    leer = #neu.plaetze == 0
    best = neu
  end
  if leer then
    w.sdZeile = T.sdKeineAnsicht
    w.sdHinweis = nil
  else
    w.A = best
    w.aInfo.genutzt = best.breite .. "x" .. best.hoehe
    if w.sdZeile == T.sdKeineAnsicht then w.sdZeile = nil end
  end
  w.infoNeu = true
end

-- Info-Datei mit den Feldern aus R4 am Ende schreiben (Kopf baut studio.lua beim Laden)
local function js(t)
  return '"' .. tostring(t or ""):gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
    return string.format("\\u%04X", c:byte())
  end) .. '"'
end
infoNach = function(w)
  w.infoNeu = nil
  local sd, a = w.sd, w.aInfo or {}
  if not (sd and sd.infoKopf) then return end
  local hinweis = w.sdZeile or (a.angepasst and w.sdHinweis) or ""
  local t = sd.infoKopf .. ',\n  "studioQuelle": ' .. js(sd.quelle) .. ',\n  "studioWahl": ' .. js(sd.wahl or "auto") ..
    ',\n  "ansichtGenutzt": ' .. js(a.genutzt) .. ',\n  "angepasst": ' .. tostring(a.angepasst == true) ..
    ',\n  "hinweis": ' .. js(hinweis) .. '\n}\n'
  local p = sd.infoPfad
  if SITZUNG[p] == t then return end
  pcall(os.mkdir, "SCRIPTS:/studio")
  local okO, f = pcall(io.open, p, "w")
  if okO and f then
    local okW = pcall(f.write, f, t)
    f:close()
    if okW then SITZUNG[p] = t return end
  end
  print("Glider Studio: Info-Datei nicht geschrieben")
end

-- Hinweis zur Studio-Datei (A1: verdeckt nie Werte). Er steht in der eigenen Kopfzeile: Kompakt in der Leiste oben
-- anstelle der Pillen, Vollbild in der Meldezeile unter der Statusleiste. Warnungen, Alarme und Ereignis-Hinweise gehen
-- vor. w.sdZeile (R4): Standardanzeige trotz Datei, Grund bleibt stehen. Danach «!» in der Kopfzeile.
local function studioBand(w, L)
  local C, s, W = Z.C, L.s, L.W
  local t = nil
  if w.sdZeile and not w.A then t = w.sdZeile
  elseif w.sdHinweis and (w.tL or 0) < (w.sdHinweisBis or 0) then t = w.sdHinweis end
  local frei = (w.nAktiv or 0) == 0 and not w.hinweis
  if t and frei then
    if L.kompakt then
      local sb = floor(36 * s)
      local x0, x1 = W * 0.22, W * 0.76                 -- zwischen Zustand und Empfang
      local ph = max(18, floor(sb - 10 * s))
      Z.rund(x0, floor((sb - ph) / 2), x1 - x0, ph, ph / 2, C.dunkel)
      Z.text(L, (x0 + x1) / 2, sb / 2, t, 15, C.orange, CENTERED, x1 - x0 - 12 * s)
    else
      Z.rund(L.gp, L.top, W - 2 * L.gp, L.mh, 8 * s, C.dunkel)
      Z.text(L, W / 2, L.top + L.mh / 2, t, 15, C.orange, CENTERED, W - 2 * L.gp - 16 * s)
    end
  elseif (t or (w.sdHinweis and not w.sdNurBand)) then
    local y = L.kompakt and floor(18 * s) or L.top + L.mh / 2
    Z.text(L, L.kompakt and W * 0.77 or W - 10 * s, y, "!", 16, C.orange, L.kompakt and LEFT or RIGHT)
  end
end

function K.zeichne(w)
  if Z == nil then return end
  local W, H = lcd.getWindowSize()
  local L = w.L
  if L == nil or L.W ~= W or L.H ~= H then
    L = Z.layout(W, H)
    w.L = L
    w.fenster[W .. "x" .. H] = true
    w.fW, w.fH = W, H                            -- Ansicht wählt und rechnet der wakeup (R3, einmal je Grösse)
  end
  Z.punkt = w.sp == 2            -- Englisch: Dezimalpunkt, Tausender mit Komma
  Z.grund(L)
  w.nZiele = 0
  local A = PLATZ and w.A
  if L.kompakt then
    if W < MIN_KW or H < MIN_KH then
      Z.zuKlein(w, L)
    elseif KOMPAKT then                          -- erstes Bild: kompakt.lua lädt erst im nächsten wakeup
      if A then
        PLATZ.zeichne(w, L, Z, A)
        KOMPAKT.leiste(w, L, Z)                  -- eigene Leiste liegt über den Plätzen (reserviert)
      else
        KOMPAKT.zeichne(w, L, Z)
      end
    end
    studioBand(w, L)
    return
  end
  if W < MIN_W or H < MIN_H then
    Z.zuKlein(w, L)
    return
  end
  local S = SEITE[w.seite]
  if A and w.seite == 1 then PLATZ.zeichne(w, L, Z, A)     -- Vollbild: die Ansicht ersetzt nur Seite 1
  elseif S then S.zeichne(w, L, Z) end
  Z.kopf(w, L)
  studioBand(w, L)
  if w.dialog then
    w.zielAb = w.nZiele + 1      -- bei offener Rückfrage zählen nur ihre eigenen Knöpfe
    if w.dialog == "detail" then
      if S and S.detail then S.detail(w, L, Z) end
    else
      Z.dialog(w, L)
    end
  end
end

local function treffer(w, x, y)
  local ab = w.dialog and (w.zielAb or 1) or 1
  for i = w.nZiele or 0, ab, -1 do         -- zuletzt gezeichnet liegt oben
    local z = w.ziele[i]
    if x >= z.x and x < z.x + z.b and y >= z.y and y < z.y + z.h then return z.id end
  end
  return nil
end

-- Ein Knopf wurde angetippt. Alles, was Daten löscht, geht nur über eine Rückfrage mit «JA, …».
local function knopf(w, id, now)
  local T = w.T
  if id == "reset" then
    w.dialog = "frage"
    w.dlg = { T.resetTitel, T.resetZeile, T.resetJa, "ja_reset" }
  elseif id == "abbrechen" or id == "schliessen" then
    w.dialog, w.detail, w.dlg = nil, nil, nil
  elseif id == "ja_reset" and w.dialog == "frage" then
    w.dialog, w.dlg = nil, nil
    zurueck(w, now)
  elseif type(id) == "string" and id:sub(1, 2) == "f_" then
    local nr = tonumber(id:sub(3))
    if nr then
      w.detail = nr
      w.dialog = "detail"
    end
  elseif id == "loeschen" and w.detail then
    local nr = w.detail
    local anzeige = nr == 0 and (#w.liste + 1) or nr
    w.dialog = "frage"
    w.dlg = { string.format(T.loeschTitel, anzeige), string.format(T.loeschZeile, anzeige), T.loeschJa, "ja_loesch" }
  elseif id == "ja_loesch" and w.dialog == "frage" and w.detail then
    local nr = w.detail
    w.dialog, w.dlg, w.detail = nil, nil, nil
    loesche(w, nr, now)
  elseif id == "auf" then
    w.lAb = max(0, (w.lAb or 0) - 1)
  elseif id == "ab" then
    w.lAb = (w.lAb or 0) + 1
  end
  w.tB = 0
end

-- Wisch nach links/rechts blättert zwischen den Seiten. Am Rand bleibt der Wisch bei Ethos.
-- Drehgeber: blättert ebenfalls (alle Drehungen behalten, sonst kommt keine mehr an, Lehre Heli RF 1.6.0).
function K.ereignis(w, kat, wert, x, y)
  if kat == EVT_KEY and (wert == KEY_ROTARY_RIGHT or wert == KEY_ROTARY_LEFT) then
    if not w.dialog then
      w.seite = clamp(w.seite + (wert == KEY_ROTARY_RIGHT and 1 or -1), 1, SEITEN)
      w.tB = 0
    end
    return true
  end
  if kat ~= EVT_TOUCH then return false end
  x, y = gut(x), gut(y)
  if x == nil or y == nil then return false end
  local t = w.touch
  if wert == TOUCH_START then
    w.touch = { x = x, y = y, id = treffer(w, x, y) }
    return w.dialog ~= nil
  elseif wert == TOUCH_MOVE and t then
    local dx, dy = x - t.x, y - t.y
    if abs(dx) > SLOP or abs(dy) > SLOP then t.id = nil end
    if w.dialog then return true end
    if not t.mein and not t.ethos and abs(dx) > SLOP and abs(dx) > abs(dy) then
      local hinein = (dx < 0 and w.seite < SEITEN) or (dx > 0 and w.seite > 1)
      if hinein then t.mein = true else t.ethos = true end
    end
    t.dx = dx
    return not t.ethos
  elseif wert == TOUCH_END and t then
    w.touch = nil
    if t.mein then
      if abs(t.dx or 0) >= 50 then
        w.seite = clamp(w.seite + ((t.dx < 0) and 1 or -1), 1, SEITEN)
        w.tB = 0
      end
      return true
    end
    if t.id and t.id == treffer(w, x, y) then
      knopf(w, t.id, os.clock())
      return true
    end
    return w.dialog ~= nil
  end
  return false
end

-- Änderung aus dem Menü mit Studio-Datei: in .funke.lua schreiben (nie in die Studio-Datei) und als Stand merken
local function studioMerken(w, F)
  local sd = w.sd
  if not (sd and sd.status == "geladen") then return end
  -- Grenzen, die im angezeigten Wert überwacht werden, kann das Menü nicht ändern: zurücksetzen, Hinweis
  local S = lade("studio.lua")
  local verworfen = false
  for key in pairs(sd.monKeys or {}) do
    local b = S.EINGEBAUT[key:sub(5)]
    if b then
      for i = 1, 2 do
        if w.cfg[b[i]] ~= sd.ueber[b[i]] then w.cfg[b[i]], verworfen = sd.ueber[b[i]], true end
      end
    end
  end
  if verworfen then grenzen(w) end
  for k in pairs(sd.ueber) do sd.ueber[k] = w.cfg[k] end
  local okN, name = false, nil
  if model and model.name then okN, name = pcall(model.name) end
  local ok, gut = pcall(lade("funkeschreib.lua"), w, S, F, lade("studiolad.lua"), S.kennung(okN and name or ""))
  if verworfen or not (ok and gut) then
    print("Glider Studio: Änderung nicht gespeichert " .. tostring(gut))
    w.sdHinweis, w.sdHinweisBis = w.T.sdNichtGespeichert, os.clock() + HINWEIS_S
  end
end

function K.menue(w)
  local F = lade("felder.lua")
  lade("menue.lua")(w, F, {
    fertig = function()
      grenzen(w)
      w.dateiOffen = true
      if model and model.dirty then pcall(model.dirty) end
      studioMerken(w, F)
    end,
    zurueckStd = function()                         -- Zurück auf Studio-Stand (mit Studio-Datei) bzw. Standard
      local sd = w.sd
      if sd and sd.status == "geladen" then
        -- .funke.lua löschen und die Studio-Datei neu laden (baut auch die Überwachung im angezeigten Wert neu)
        local S = lade("studio.lua")
        local okN, name = false, nil
        if model and model.name then okN, name = pcall(model.name) end
        pcall(os.remove, S.PFAD .. S.kennung(okN and name or "") .. "." .. S.LUA .. ".funke.lua")
        for k, v in pairs(sd.basis) do w.cfg[k] = v end
        w.sd, w.sdAuf, w.sz2 = nil, true, nil
      else
        local werk = F.standard()
        for _, g in ipairs(F.gruppen) do
          for _, f in ipairs(g[2]) do if f[2] ~= "q" then w.cfg[f[1]] = werk[f[1]] end end
        end
        w.dateiOffen = true
      end
      grenzen(w)
    end,
    suche = function()                               -- startet die Suche; sie läuft in den nächsten Durchläufen
      w.sucheAktiv, w.sucheQuelle, w.sz, w.sucheFn = true, "menue", nil, nil
      return "gestartet"
    end,
    studioWahl = function(p)                        -- R2: Wahl im Menü, gespeichert am Ende des Widget-Speichers
      if p == (w.studioWahl or "") then return end
      w.studioWahl = p
      -- alles vom bisherigen Layout zurücksetzen: Einstellungen und Grenzen auf den Stand ohne Studio (Datei des Modells),
      -- Sensoren und Schalter bleiben; Zustände, Min/Max, Kurven und Meldungen der Studio-Grenzen weg
      local werk = F.standard()
      for _, g in ipairs(F.gruppen) do
        for _, f in ipairs(g[2]) do if f[2] == "q" then werk[f[1]] = w.cfg[f[1]] end end
      end
      w.cfg, w.cfgEigen = werk, nil
      local flug, liste, dauer = w.flug, w.liste, w.dauer   -- laufender Flug, Flüge und Zähler bleiben unverändert
      pcall(F.lies, w, true)
      w.flug, w.liste, w.dauer = flug, liste, dauer
      grenzen(w)
      for k in pairs(w.meld) do if k:match("^s[AW]%d") then w.meld[k] = nil end end
      w.gst, w.zs, w.A, w.pVorb, w.aGr, w.L = {}, {}, nil, nil, nil, nil
      w.sdHinweis, w.sdHinweis0, w.sdNurBand = nil, nil, nil
      w.sd, w.sdAuf, w.sz2, w.sdZeile = nil, true, nil, nil
      if model and model.dirty then pcall(model.dirty) end
    end,
    reset = function() zurueck(w, os.clock()) end,
    loesche = function(nr) loesche(w, nr, os.clock()) end,
    beende = function()
      if w.flug then
        w.flug.t = max(w.flug.t or 0, w.cfg.minS or 0)   -- von Hand beendet: immer speichern
        flugEnde(w, os.clock())
        w.sperreLandung = true
      end
    end,
  })
end

function K.lies(w)
  local F = lade("felder.lua")
  local vorher = w.studioWahl or ""
  w.gelesen = F.lies(w)
  if (w.studioWahl or "") ~= vorher and not w.sdAuf then w.sd, w.sdAuf, w.sz2, w.sdZeile = nil, true, nil, nil end
  w.autoOffen = not w.gelesen
  w.cfgEigen = nil                                 -- frisch gelesen: das sind die eigenen Werte
  studioAnwenden(w)                                -- Studio-Datei vor Widget-Speicher und daten/ (Abschnitt 9)
  grenzen(w)
  w.seite = clamp(w.cfg.startSeite or 1, 1, SEITEN)
end

function K.schreibe(w)
  local F = lade("felder.lua")
  F.schreibe(w)
  -- Ethos speichert das Modell (Menü zu, Modellwechsel, Ausschalten): offenes Schreiben der Datei jetzt abschliessen
  if w.dateiOffen or w.schreibS then
    w.schreibS, w.schreibF, w.schreibT, w.schreibZ = nil, nil, nil, nil
    w.dateiOffen, w.dateiJetzt = false, false
    pcall(F.schreibeDatei, w)
  end
end

return K
