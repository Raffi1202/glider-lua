-- Glider: Studio-Datei (Lua-Studio-Format v1) beim Modellwechsel laden, jedes Feld nach Abschnitt 6 prüfen und das
-- Ergebnis in w.sd ablegen. Läuft in Schritten (je wakeup ein Schritt, Befehlsgrenze am Sender) und wird danach
-- wieder freigegeben. Liest nie in paint. Fehlt die Datei, bleibt alles wie ohne Studio (Grundsatz 6).
-- Ergebnis w.sd:
--   status   "fehlt" | "geladen" | "kaputt" | "zuNeu"; fehler = Zahl ungültiger Felder
--   ueber    Einstellungen und Grenzen (Schlüssel aus felder.lua, gespeicherte Form) = Werk + Studio + .funke.lua
--   basis    dasselbe ohne .funke.lua (für das Schreiben der Änderungen an der Funke)
--   werte    [Wert-Schlüssel] = { faktor, versatz, einheit, stellen, name }   (6.4)
--   mon      Grenzen, die nicht im Lua eingebaut sind: { key, richtung, warn, alarm, ans, vib, bma, mot }   (6.5)
--   opt      Ansage/Vibration der eingebauten Grenzen: opt.h, opt.r, opt.p, opt.z1 … = { ans, vib }
--   ansichten { breite, hoehe, plaetze = { … } }   (6.2, 6.3), d = [Wert-Schlüssel] = Beschreibung der Quelle
local S = {}
S.PFAD = "SCRIPTS:/studio/"
S.LUA = "glider"
S.FORMAT = 1
local floor, mtype, huge = math.floor, math.type, math.huge

local studioLaden = nil   -- studiolad.lua (Referenz, wörtlich übernommen)
local WERTE = nil         -- werte.lua

-- Modellkennung nach 2.1, byteweise
function S.kennung(name)
  local k = (type(name) == "string" and name or ""):gsub("[^%w]", "_"):sub(1, 32)
  if k == "" then k = "modell" end
  return k
end

local function endlich(v) return type(v) == "number" and v == v and v ~= huge and v ~= -huge end
local function ganz(v) return mtype(v) == "integer" end

-- Text auf n Byte kürzen, nur vor einem Byte, das ein Zeichen beginnt
local function kurz(t, n)
  if #t <= n then return t end
  local i = n
  while i > 0 do
    local b = t:byte(i + 1)
    if b and b >= 0x80 and b < 0xC0 then i = i - 1 else break end
  end
  return t:sub(1, i)
end
S.kurz = kurz

local function fehler(z, wo, grund)
  z.sd.fehler = z.sd.fehler + 1
  if not z.stumm then print("Glider Studio: " .. wo .. ": " .. grund) end
end

-- Wert-Schlüssel nach 6.6. Rückgabe: Beschreibung oder nil (ungültig).
local function schluessel(k)
  if type(k) ~= "string" or #k > 40 then return nil end
  if k == "leer" then return { art = "leer" } end
  local s = k:match("^lua:([%w_]+)$")
  if s then
    if WERTE[s] then return { art = "lua", s = s } end
    return nil
  end
  local a, sub, ph = k:match("^sensor:(%x%x%x%x):(%d%d?%d?)$")
  if not a then a, sub, ph = k:match("^sensor:(%x%x%x%x):(%d%d?%d?):(%d%d?)$") end
  if a then
    if a:find("%l") then return nil end              -- AppID nur mit Grossbuchstaben
    ph = ph and tonumber(ph)
    if ph and ph > 27 then return nil end
    return { art = "sensor", app = tonumber(a, 16), sub = tonumber(sub), phys = ph }
  end
  local n = k:match("^kanal:(%d%d?)$")
  if n then
    n = tonumber(n)
    if n >= 1 and n <= 64 then return { art = "kanal", n = n } end
  end
  return nil
end
S.schluessel = schluessel

local function farbe(f)
  if type(f) ~= "table" or #f ~= 3 then return nil end
  for i = 1, 3 do
    if not ganz(f[i]) or f[i] < 0 or f[i] > 255 then return nil end
  end
  return lcd.RGB(f[1], f[2], f[3])
end

local function text(t, n)
  if type(t) ~= "string" then return nil end
  return kurz(t, n)
end

-- Felder aus felder.lua, die eine Studio-Datei setzen darf: snake_case-Name -> Feld. Grenzwerte gehen über «grenzen».
local GRENZFELD = { hWarn = 1, hAlarm = 1, pWarn = 1, pAlarm = 1, rssiWarn = 1, rssiAlarm = 1, z1Warn = 1, z1Alarm = 1,
  z2Warn = 1, z2Alarm = 1, z3Warn = 1, z3Alarm = 1,
  hMot = 1, rMot = 1, pMot = 1, z1Mot = 1, z2Mot = 1, z3Mot = 1 }   -- «auch bei Motor aus» über grenzen (Format 2, 3.5)
local function einstellFelder(F)
  local m = {}
  for _, g in ipairs(F.gruppen) do
    for _, f in ipairs(g[2]) do
      if f[2] ~= "q" and not GRENZFELD[f[1]] then
        m[(f[1]:gsub("%u", function(c) return "_" .. c:lower() end))] = f
      end
    end
  end
  return m
end
S.einstellFelder = einstellFelder

-- Einstellung prüfen und in die gespeicherte Form bringen (z: ganze Zahl mit Kommastellen). nil = ungültig.
local function einstellung(f, v)
  local art = f[2]
  if art == "z" then
    if not endlich(v) then return nil end
    local d = 10 ^ (f[7] or 0)
    local x = floor(v * d + 0.5)
    if x < f[5] or x > f[6] then return nil end
    return x
  elseif art == "b" then
    if type(v) == "boolean" then return v end
  elseif art == "w" then
    if ganz(v) then
      for _, a in ipairs(f[5]) do if a[2] == v then return v end end
    end
  elseif art == "t" then
    if type(v) == "string" then return S.textWert and S.textWert(v) or kurz(v, 12) end
  end
  return nil
end
S.einstellung = einstellung

-- Eingebaute Grenzen: Wert -> Felder in cfg, Teiler der gespeicherten Form, Gruppe für Ansage/Vibration
local EINGEBAUT = {
  -- Warnung, Alarm (gespeicherte Form), Teiler, Gruppe für Ansage/Vibration, Einstellung «Alarm auch bei Motor aus»
  hoehe = { "hWarn", "hAlarm", 1, "h", "hMot" },
  empfang = { "rssiWarn", "rssiAlarm", 1, "r", "rMot" },
  antrieb_proz = { "pWarn", "pAlarm", 1, "p", "pMot" },
  akku1_zelle = { "z1Warn", "z1Alarm", 100, "z1", "z1Mot" },
  akku2_zelle = { "z2Warn", "z2Alarm", 100, "z2", "z2Mot" },
  akku3_zelle = { "z3Warn", "z3Alarm", 100, "z3", "z3Mot" },
}
S.EINGEBAUT = EINGEBAUT

-- Richtung eines Lua-Werts im angezeigten Wert: ein negativer Faktor (6.4) dreht sie um
function S.richtung(z, key, s)
  local r = WERTE[s][8]
  local a = z.sd.werte and z.sd.werte[key]
  if r and a and a.faktor < 0 then r = r == "unter" and "ueber" or "unter" end
  return r
end

-- Grenze (6.5) prüfen. Gibt { richtung, warn, alarm, ans, vib, bma, aus } oder nil zurück.
-- bma = «auch bei Motor aus» (Format 2, 3.5): fehlt das Feld oder hat es einen falschen Typ, gilt true.
local function grenze(z, key, g, d)
  local wo = "grenzen[" .. key .. "]"
  if type(g) ~= "table" then fehler(z, wo, "keine Tabelle") return nil end
  local r = g.richtung
  if r ~= nil and r ~= "unter" and r ~= "ueber" then fehler(z, wo, "richtung") return { aus = true } end
  if r == nil and d.art == "lua" then r = S.richtung(z, key, d.s) end
  if r == nil then fehler(z, wo, "richtung fehlt") return { aus = true } end
  local e = { richtung = r, ans = true, vib = true, bma = true }
  if g.aus == true then e.aus = true
  elseif g.aus ~= nil and type(g.aus) ~= "boolean" then fehler(z, wo, "aus") end
  -- false = diese Stufe ausdrücklich aus (Entscheid Lua Studio 20.11.); falscher Typ = Feld nicht vorhanden plus Hinweis
  if g.warnung ~= nil and g.warnung ~= false then if endlich(g.warnung) then e.warn = g.warnung else fehler(z, wo, "warnung") end end
  if g.alarm ~= nil and g.alarm ~= false then if endlich(g.alarm) then e.alarm = g.alarm else fehler(z, wo, "alarm") end end
  if g.ansage ~= nil then if type(g.ansage) == "boolean" then e.ans = g.ansage else fehler(z, wo, "ansage") end end
  if g.vibration ~= nil then if type(g.vibration) == "boolean" then e.vib = g.vibration else fehler(z, wo, "vibration") end end
  if g.beiMotorAus ~= nil then if type(g.beiMotorAus) == "boolean" then e.bma = g.beiMotorAus else fehler(z, wo, "beiMotorAus") end end
  if e.warn and e.alarm and ((r == "unter" and e.alarm >= e.warn) or (r == "ueber" and e.alarm <= e.warn)) then
    fehler(z, wo, "Reihenfolge, nur alarm gilt")
    e.warn = nil
  end
  return e
end

-- Anzeige eines Werts: Name, Einheit, Stellen, Zeit, Zustände. Anpassung (6.4) geht vor den Angaben des Luas.
local function anzeige(z, key, d)
  local W = d.art == "lua" and WERTE[d.s] or nil
  local a = z.sd.werte[key]
  local sp = z.w.sp == 2 and 2 or 1
  local r = { name = W and W[sp] or key, einheit = W and W[3] or "", stellen = W and W[4] or 0, zeit = W and W[9] or false,
    lauf = W and W.lauf or nil }
  if W and W.zst then
    r.zst = {}
    for k, s in pairs(W.zst) do r.zst[k] = { s[sp], lcd.RGB(s[3][1], s[3][2], s[3][3]) } end
  end
  if d.art == "kanal" then r.einheit = "%" end
  if a then
    if a.name then r.name = a.name end
    if a.einheit then r.einheit = a.einheit end
    if a.stellen then r.stellen = a.stellen end
  end
  return r
end

-- Platz (6.3) prüfen. Gibt den geprüften Platz oder nil (verworfen) zurück.
local MIN = { zahl = { 90, 50 }, ring = { 110, 110 }, balken_w = { 140, 40 }, balken_s = { 50, 110 }, kurve = { 180, 90 },
  status = { 120, 40 } }
local ZUSATZ = { keine = true, min = true, max = true, mittel = true }
local function platz(z, p, br, ho, wo, nKurven)
  if type(p) ~= "table" then fehler(z, wo, "keine Tabelle") return nil end
  local x, y, b, h = p.x, p.y, p.b, p.h
  if not (ganz(x) and ganz(y) and ganz(b) and ganz(h)) or x < 0 or y < 0 or b < 1 or h < 1 or x + b > br or y + h > ho then
    fehler(z, wo, "Lage/Grösse") return nil
  end
  local d = schluessel(p.w)
  if d == nil then fehler(z, wo, "w") return nil end
  local q = { x = x, y = y, b = b, h = h, key = p.w, d = d, a = anzeige(z, p.w, d) }
  local W = d.art == "lua" and WERTE[d.s] or nil
  local dar = p.darstellung
  if dar == nil then dar = (W and W.zst) and "status" or "zahl" end
  if type(dar) ~= "string" or MIN[dar] == nil or (W and not W[7][dar]) or (not W and dar == "status") then
    fehler(z, wo, "darstellung")
    dar = (W and W.zst) and "status" or "zahl"
  end
  if dar == "kurve" and nKurven >= 2 then fehler(z, wo, "mehr als 2 Kurven") dar = "zahl" end
  local m = MIN[dar]
  -- Mindestgrösse im Verhältnis zur Fensterbreite, Bezug immer 800 (Entscheid Lua Studio 20.11.)
  if b < floor(m[1] * br / 800 + 0.5) or h < floor(m[2] * br / 800 + 0.5) then
    fehler(z, wo, "zu klein für " .. dar) return nil, nKurven
  end
  if dar == "kurve" then nKurven = nKurven + 1 end
  q.dar = dar
  if p.titel ~= nil then q.titel = text(p.titel, 24) if q.titel == nil then fehler(z, wo, "titel") end end
  q.min, q.max = W and W[5] or 0, W and W[6] or 100
  if p.min ~= nil or p.max ~= nil then
    local a, e = p.min ~= nil and p.min or q.min, p.max ~= nil and p.max or q.max
    if endlich(a) and endlich(e) and e > a then q.min, q.max = a, e else fehler(z, wo, "min/max") end
  end
  for _, n in ipairs({ "farbe", "farbeWarn", "farbeAlarm", "hintergrund" }) do
    if p[n] ~= nil then
      q[n] = farbe(p[n])
      if q[n] == nil then fehler(z, wo, n) end
    end
  end
  q.zusatz = "keine"
  if p.zusatz ~= nil then
    if ZUSATZ[p.zusatz] then q.zusatz = p.zusatz else fehler(z, wo, "zusatz") end
  end
  q.kurveS = 120
  if p.kurveS ~= nil then
    if ganz(p.kurveS) and p.kurveS >= 30 and p.kurveS <= 600 then q.kurveS = p.kurveS else fehler(z, wo, "kurveS") end
  end
  if p.stufen ~= nil then
    local ok, l = type(p.stufen) == "table" and #p.stufen <= 3, {}
    if ok then
      local vor = -huge
      for i, s in ipairs(p.stufen) do
        local c = type(s) == "table" and farbe(s.farbe)
        if not (c and endlich(s.ab) and s.ab > vor) then ok = false break end
        vor = s.ab
        l[i] = { s.ab, c }
      end
    end
    if ok then q.stufen = l else fehler(z, wo, "stufen") end
  end
  return q, nKurven
end

-- Ansichten (6.2) prüfen, je Aufruf höchstens 4 Plätze (Befehlsgrenze). Rückgabe true = alle Ansichten fertig.
local PLAETZE_JE_SCHRITT = 4
local function ansichtSchritt(z)
  local a = z.d.ansichten
  if z.ai == nil then
    z.ai = 1
    if a == nil then return true end
    if type(a) ~= "table" then fehler(z, "ansichten", "keine Liste") return true end
    if #a > 2 then fehler(z, "ansichten", "mehr als 2, überzählige verworfen") end
  end
  if type(a) ~= "table" then return true end
  local i = z.ai
  local e = a[i]
  if i > 2 or e == nil then return true end
  local wo = "ansichten[" .. i .. "]"
  if z.cur == nil then
    if type(e) ~= "table" or not ganz(e.breite) or not ganz(e.hoehe) or e.breite < 100 or e.breite > 1024
      or e.hoehe < 100 or e.hoehe > 1024 or type(e.plaetze) ~= "table" then
      fehler(z, wo, "verworfen")
      z.ai = i + 1
      return false
    end
    z.cur, z.pi, z.nK = { breite = e.breite, hoehe = e.hoehe, plaetze = {} }, 0, 0
  end
  local pl, cur = e.plaetze, z.cur
  local ende = math.min(#pl, 16)
  local bis = math.min(ende, z.pi + PLAETZE_JE_SCHRITT)
  for k = z.pi + 1, bis do
    local q, n2 = platz(z, pl[k], cur.breite, cur.hoehe, wo .. ".plaetze[" .. k .. "]", z.nK)
    z.nK = n2 or z.nK
    if q then cur.plaetze[#cur.plaetze + 1] = q end
  end
  z.pi = bis
  if bis >= ende then
    if #pl > 16 then fehler(z, wo, "mehr als 16 Plätze, überzählige verworfen") end
    z.sd.ansichten[#z.sd.ansichten + 1] = cur
    z.cur, z.ai = nil, i + 1
  end
  return false
end

-- Wert-Anpassung (6.4) prüfen
local function wertAnpassung(z, key, e)
  local wo = "werte[" .. tostring(key) .. "]"
  if schluessel(key) == nil or type(e) ~= "table" then fehler(z, wo, "verworfen") return nil end
  local r = { faktor = 1, versatz = 0 }
  if e.faktor ~= nil then
    if endlich(e.faktor) and math.abs(e.faktor) >= 0.0001 and math.abs(e.faktor) <= 10000 then r.faktor = e.faktor else fehler(z, wo, "faktor") end
  end
  if e.versatz ~= nil then
    if endlich(e.versatz) and e.versatz >= -100000 and e.versatz <= 100000 then r.versatz = e.versatz else fehler(z, wo, "versatz") end
  end
  if e.einheit ~= nil then r.einheit = text(e.einheit, 8) if r.einheit == nil then fehler(z, wo, "einheit") end end
  if e.stellen ~= nil then
    if ganz(e.stellen) and e.stellen >= 0 and e.stellen <= 3 then r.stellen = e.stellen else fehler(z, wo, "stellen") end
  end
  if e.name ~= nil then r.name = text(e.name, 24) if r.name == nil then fehler(z, wo, "name") end end
  return r
end

-- Studio-Grenzen in die gespeicherte Form der eingebauten Grenzen bringen (Rohwert = (Grenze - versatz) / faktor)
local function inCfg(sd, key, e, ueber, opt)
  local b = EINGEBAUT[key:sub(5)]
  local a = sd.werte[key]
  local fk, vs = a and a.faktor or 1, a and a.versatz or 0
  local function roh(x)
    if x == nil then return 0 end
    local r = floor((x - vs) / fk * b[3] + 0.5)
    return r > 0 and r or 0
  end
  if e.aus then ueber[b[1]], ueber[b[2]] = 0, 0
  elseif e.warn or e.alarm then ueber[b[1]], ueber[b[2]] = roh(e.warn), roh(e.alarm) end
  -- ohne Zahl-Stufe und ohne «aus = true»: Werkgrenze bleibt stehen (v1 6.5, «Kein Abschalten ohne aus», 21.11.2026)
  opt[b[4]] = { ans = e.ans, vib = e.vib }
  ueber[b[5]] = e.bma ~= false
end

local function liesDateien(z)
  local sd = z.sd
  local p = S.PFAD .. z.kennung .. "." .. S.LUA
  local d, grund = studioLaden(p .. ".lua", S.FORMAT)
  if d == nil and grund == "fehlt" then
    -- Übergang 0.5.0: alte Studio-Datei <Kennung>.segler.lua (bis 0.4.0) lesen, wenn die neue fehlt
    local alt = S.PFAD .. z.kennung .. ".segler.lua"
    local d2, g2 = studioLaden(alt, S.FORMAT)
    if d2 ~= nil then
      d, grund = d2, nil
      print("Glider Studio: old studio file " .. z.kennung .. ".segler.lua found, please re-transfer")
    end
  end
  if d == nil then
    sd.status = grund
    if grund ~= "fehlt" then print("Glider Studio: " .. z.kennung .. ".glider.lua: " .. grund) end
    return
  end
  sd.status = "geladen"
  z.d = d
end

-- übrig gebliebene .funke.neu (Strom weg beim Schreiben) und .funke.lua laden
local function liesFunke(z)
  local p = S.PFAD .. z.kennung .. "." .. S.LUA
  local neu = p .. ".funke.neu"
  local f = nil
  local okF, fh = pcall(io.open, neu, "r")
  if okF and fh then
    fh:close()
    local okA, ah = pcall(io.open, p .. ".funke.lua", "r")
    if okA and ah then
      ah:close()
      pcall(os.remove, neu)
    else
      local t = studioLaden(neu, S.FORMAT)
      if t then
        local okR, r = pcall(os.rename, neu, p .. ".funke.lua")
        if not (okR and r) then
          print("Glider Studio: .funke.neu nicht umbenannt, gilt nur in dieser Sitzung")
          z.f = t
          return
        end
      else
        pcall(os.remove, neu)
      end
    end
  end
  local t, grund = studioLaden(p .. ".funke.lua", S.FORMAT)
  if t then z.f = t
  elseif grund ~= "fehlt" then
    z.sd.funkeVerworfen = true
    print("Glider Studio: " .. z.kennung .. ".glider.funke.lua: " .. grund .. ", verworfen")
  end
end

-- Befehlsgrenze am Sender (Format 12.2): grosse gültige Tabellen werden in Stücken geprüft. Je Aufruf höchstens
-- JE_AUFRUF Einträge der teuren Teile (Werte, Grenzen), bei den billigen (Einstellungen, Zusammenführen) das Vierfache.
-- Gemessen 21.11.2026 (test/studio-faelle.lua): ohne Stücke bis 62'000 Befehle in einem Aufruf.
local JE_AUFRUF = 10

-- Bis zu n Einträge der Tabelle t ab dem gemerkten Schlüssel z.ck an fn geben. true = Tabelle fertig.
-- fn darf t nicht ändern (next über eine veränderte Tabelle ist nicht erlaubt).
local function stueck(z, t, n, fn)
  if type(t) ~= "table" then z.ck = nil return true end
  local k = z.ck
  for _ = 1, n do
    local v
    k, v = next(t, k)
    if k == nil then z.ck = nil return true end
    fn(k, v)
  end
  z.ck = k
  return false
end

-- Einstellungen: Werk, darüber Studio, darüber .funke.lua (ein Eintrag)
local function legeEintrag(z, wo, k, v)
  local f = z.felder[k]
  if f == nil then
    if type(k) ~= "string" then fehler(z, wo, "Schlüssel") end   -- unbekannte Namen: still überlesen
  else
    local x = einstellung(f, v)
    if x == nil then fehler(z, wo .. "." .. k, "ungültig, Werkwert") else z.sd.ueber[f[1]] = x end
  end
end

-- Grenzen: je Feld zusammenführen (Studio, darüber .funke.lua), dann prüfen. Fehlt ein Eintrag, gilt die Werkgrenze.
local function sammleEintrag(z, wo, alle, k, g)
  if type(g) == "table" and type(k) == "string" then
    local e = alle[k] or {}
    for n, v in pairs(g) do e[n] = v end
    alle[k] = e
  else
    fehler(z, wo, "Eintrag verworfen")
  end
end

local function anwendenEintrag(z, ziel, opt, mon, k, g)
  local d = schluessel(k)
  if d == nil or d.art == "leer" then
    fehler(z, "grenzen[" .. k .. "]", "Schlüssel")
    return
  end
  local e = grenze(z, k, g, d)
  if not e then return end
  if d.art == "lua" and EINGEBAUT[d.s] then
    local b, a = EINGEBAUT[d.s], z.sd.werte[k]
    -- Positiver Faktor: in die eingebaute Grenze umrechnen (Rohwert = (Grenze - versatz) / faktor). Negativer
    -- Faktor oder eine gesetzte Stufe, die als Rohwert unter 1 (= aus) läge: im angezeigten Wert überwachen.
    local fk, vs = a and a.faktor or 1, a and a.versatz or 0
    local function r(x) return x and (x - vs) / fk * b[3] < 1 end
    local roh = fk < 0 or (not e.aus and (r(e.warn) or r(e.alarm)))
    local ohneStufe = not e.aus and not e.warn and not e.alarm   -- kein Abschalten ohne «aus»: Werkgrenze
    if e.richtung ~= S.richtung(z, k, d.s) then
      fehler(z, "grenzen[" .. k .. "]", "Richtung nicht möglich, Werkgrenze")
    elseif ohneStufe then
      inCfg(z.sd, k, e, ziel, opt)                    -- setzt nur Ansage, Vibration und «auch bei Motor aus»
    elseif roh then
      -- angepasster Wert oder Grenze, die gespeichert 0 (= aus) wäre: im angezeigten Wert überwachen
      inCfg(z.sd, k, { aus = true, ans = e.ans, vib = e.vib, bma = e.bma }, ziel, opt)
      if z.sd.monKeys then z.sd.monKeys[k] = true end
      if not e.aus and (e.warn or e.alarm) then
        mon[#mon + 1] = { key = k, d = d, richtung = e.richtung, warn = e.warn, alarm = e.alarm, ans = e.ans,
          vib = e.vib, bma = e.bma, mot = b[5], name = anzeige(z, k, d).name }
      end
    else
      inCfg(z.sd, k, e, ziel, opt)
    end
  elseif not e.aus and (e.warn or e.alarm) then
    mon[#mon + 1] = { key = k, d = d, richtung = e.richtung, warn = e.warn, alarm = e.alarm, ans = e.ans, vib = e.vib,
      bma = e.bma, name = anzeige(z, k, d).name }
  end
end

-- Teil «nicht Tabelle» melden (wie früher sammle/lege), dann true, wenn es nichts zu tun gibt
local function keineTabelle(z, t, wo)
  if t == nil then return true end
  if type(t) ~= "table" then fehler(z, wo, "keine Tabelle") return true end
  return false
end

-- Einstellungen, Werte und Grenzen prüfen, in Teilschritten (z.ph). Rückgabe true = alles fertig.
-- holeF lädt felder.lua; nur im ersten Teilschritt gebraucht (danach z.felder).
local function pruefeSchritt(z, holeF)
  local sd, ph = z.sd, z.ph or 0
  local viel = JE_AUFRUF * 4
  if ph == 0 then                                   -- Werk für Einstellungen und Grenzen
    local F = holeF()
    S.textWert = F.textWert
    z.felder = einstellFelder(F)
    local werk = F.standard()
    local ueber = {}
    for _, f in pairs(z.felder) do ueber[f[1]] = werk[f[1]] end
    for k in pairs(GRENZFELD) do ueber[k] = werk[k] end
    sd.ueber, z.ck = ueber, nil
    z.ph = keineTabelle(z, z.d.einstellungen, "einstellungen") and 2 or 1
  elseif ph == 1 then                               -- Einstellungen der Studio-Datei
    if stueck(z, z.d.einstellungen, viel, function(k, v) legeEintrag(z, "einstellungen", k, v) end) then z.ph = 2 end
  elseif ph == 2 then                               -- Basis ohne .funke.lua
    local basis = {}
    for k, v in pairs(sd.ueber) do basis[k] = v end
    sd.basis = basis
    z.ph = (z.f == nil or keineTabelle(z, z.f.einstellungen, "funke.einstellungen")) and 4 or 3
  elseif ph == 3 then                               -- Einstellungen aus .funke.lua
    if stueck(z, z.f.einstellungen, viel, function(k, v) legeEintrag(z, "funke.einstellungen", k, v) end) then z.ph = 4 end
  elseif ph == 4 then                               -- Werte (6.4)
    z.felder = nil
    sd.werte = {}
    z.ph = keineTabelle(z, z.d.werte, "werte") and 6 or 5
  elseif ph == 5 then
    if stueck(z, z.d.werte, JE_AUFRUF, function(k, e)
      local r = wertAnpassung(z, k, e)
      if r then sd.werte[k] = r end
    end) then z.ph = 6 end
  elseif ph == 6 then
    -- Basis ohne .funke.lua (still, ohne Fehler zu zählen): daran misst das Schreiben an der Funke die Änderungen
    z.still = { stumm = true, w = z.w, sd = { fehler = 0, werte = sd.werte } }
    z.nurStudio = {}
    z.ph = (type(z.d.grenzen) == "table") and 7 or 9
  elseif ph == 7 then
    if stueck(z, z.d.grenzen, viel, function(k, g) sammleEintrag(z.still, "", z.nurStudio, k, g) end) then z.ph = 8 end
  elseif ph == 8 then
    if stueck(z, z.nurStudio, JE_AUFRUF, function(k, g) anwendenEintrag(z.still, sd.basis, {}, {}, k, g) end) then z.ph = 9 end
  elseif ph == 9 then
    z.still, z.nurStudio, z.alle = nil, nil, {}
    z.ph = keineTabelle(z, z.d.grenzen, "grenzen") and 11 or 10
  elseif ph == 10 then
    if stueck(z, z.d.grenzen, viel, function(k, g) sammleEintrag(z, "grenzen", z.alle, k, g) end) then z.ph = 11 end
  elseif ph == 11 then
    z.ph = (z.f and type(z.f.grenzen) == "table") and 12 or 14
  elseif ph == 12 then
    -- Eintrag nur in .funke.lua: auf der Werkgrenze aufsetzen (ein fehlender Eintrag schaltet nie einen Alarm ab)
    if stueck(z, z.f.grenzen, viel, function(k)
      local s = type(k) == "string" and k:match("^lua:(.+)$")
      local b = s and EINGEBAUT[s]
      if b and z.alle[k] == nil then
        local wa, al = sd.basis[b[1]] or 0, sd.basis[b[2]] or 0
        local a = sd.werte[k]
        local fk, vs = a and a.faktor or 1, a and a.versatz or 0   -- Werkgrenze in Anzeige-Einheiten
        z.alle[k] = { warnung = wa > 0 and wa / b[3] * fk + vs or nil, alarm = al > 0 and al / b[3] * fk + vs or nil }
      end
    end) then z.ph = 13 end
  elseif ph == 13 then
    if stueck(z, z.f.grenzen, viel, function(k, g) sammleEintrag(z, "funke.grenzen", z.alle, k, g) end) then z.ph = 14 end
  elseif ph == 14 then
    sd.opt, sd.mon, sd.monKeys = {}, {}, {}
    sd.funkeAlt = z.f and type(z.f.grenzen) == "table" and z.f.grenzen or nil   -- für das Schreiben an der Funke
    z.ph = 15
  elseif ph == 15 then
    if stueck(z, z.alle, JE_AUFRUF, function(k, g) anwendenEintrag(z, sd.ueber, sd.opt, sd.mon, k, g) end) then
      z.alle, z.ph = nil, nil
      return true
    end
  end
  return false
end

-- Quellen für Sensoren und Kanäle (Plätze und Grenzen). Ohne Physical ID einmal getSource; mit Physical ID über die
-- Sensorliste (in Schritten).
local function quellenSammeln(z)
  local sd, liste = z.sd, {}
  local function nimm(k, d)                          -- gleicher Schlüssel = dieselbe Quelle (eine Tabelle)
    if d.art ~= "sensor" and d.art ~= "kanal" then return d end
    if sd.d[k] == nil then
      sd.d[k] = d
      liste[#liste + 1] = k
    end
    return sd.d[k]
  end
  sd.d = {}
  for _, a in ipairs(sd.ansichten) do for _, p in ipairs(a.plaetze) do p.d = nimm(p.key, p.d) end end
  for _, m in ipairs(sd.mon) do m.d = nimm(m.key, m.d) end
  z.qListe, z.qi = liste, 0
end

local function istQuelle(q)
  if q == nil then return false end
  if CATEGORY_NONE then
    local ok, k = pcall(q.category, q)
    if ok and k == CATEGORY_NONE then return false end
  end
  return true
end

local function quellenSchritt(z)
  local sd = z.sd
  local n = 0
  while z.qi < #z.qListe and n < 8 do
    z.qi = z.qi + 1
    n = n + 1
    local k = z.qListe[z.qi]
    local d = sd.d[k]
    if d.art == "kanal" then
      local ok, q = pcall(system.getSource, { category = CATEGORY_CHANNEL, member = d.n - 1 })
      if ok and istQuelle(q) then d.q = q end
    else
      -- Sensoren immer über die Sensorliste (AppID, Teilwert, Physical ID falls angegeben). Nicht über getSource mit
      -- appId: am Sender lieferte das ein Objekt ohne Wert (value nil, X18RS 20.11.2026, wie Elektro 0.3.2).
      z.mitPhys = true
      local ix = d.app * 1000 + (d.sub or 0)          -- Verzeichnis AppID/Teilwert -> Sensoren der Datei (Zahl: 4 = 4.0)
      z.idx = z.idx or {}
      local l = z.idx[ix] or {}
      l[#l + 1] = d
      z.idx[ix] = l
    end
    if d.q == nil and d.art == "kanal" then print("Glider Studio: " .. k .. " nicht gefunden") end
  end
  return z.qi >= #z.qListe
end

-- Liste aller Telemetriesensoren. Am Sender (X18RS, Ethos 26.2.0, 20.11.2026) liefert getSources mit einer Tabelle
-- { category = … } eine LEERE Liste; mit der Kategorie als Zahl geht es (wie die Sensorsuche). Tabelle nur als Rückfall.
local function sensorListe()
  if not (system.getSources and CATEGORY_TELEMETRY_SENSOR) then return {} end
  local ok, l = pcall(system.getSources, CATEGORY_TELEMETRY_SENSOR)
  if ok and type(l) == "table" and #l > 0 then return l end
  ok, l = pcall(system.getSources, { category = CATEGORY_TELEMETRY_SENSOR })
  if ok and type(l) == "table" then return l end
  return {}
end

-- Sensorliste (Quellen der Studio-Sensoren und Info-Datei), höchstens 100 Sensoren, je Schritt 10
local function sensorSchritt(z)
  if z.sl == nil then
    z.sl, z.si, z.sj = sensorListe(), 0, {}
  end
  local sd = z.sd
  local bis = math.min(#z.sl, z.si + 10, 100)
  for i = z.si + 1, bis do
    local q = z.sl[i]
    local function r(f) local ok, v = pcall(q[f], q) if ok then return v end return nil end
    local e = { app = r("appId"), sub = r("subId"), phys = r("physId"), name = r("name") }
    z.sj[#z.sj + 1] = e
    -- nur die Sensoren der Datei mit derselben AppID und demselben Teilwert ansehen (nie alle: Befehlsgrenze)
    local l = z.idx and type(e.app) == "number" and type(e.sub or 0) == "number" and z.idx[e.app * 1000 + (e.sub or 0)]
    if l then
      for _, d in ipairs(l) do
        if d.q == nil and (d.phys == nil or d.phys == e.phys) and istQuelle(q) then d.q = q end
      end
    end
  end
  z.si = bis
  local fertig = bis >= math.min(#z.sl, 100)
  if fertig and z.idx then
    z.idx = nil
    for k, d in pairs(sd.d) do
      if d.art == "sensor" and d.q == nil then print("Glider Studio: " .. k .. " nicht gefunden") end
    end
  end
  return fertig
end

-- Info-Datei (Abschnitt 14), JSON, nur das Studio liest sie
local function js(t)
  t = tostring(t or "")
  return '"' .. t:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" end
    return string.format("\\u%04X", c:byte())
  end) .. '"'
end
local function infoSchreiben(z, sitzung)
  local sd, w = z.sd, z.w
  local ver = {}
  local ok, v = pcall(system.getVersion)
  if ok and type(v) == "table" then ver = v end
  local okP, pfad = false, nil
  if model and model.path then okP, pfad = pcall(model.path) end
  local fe = {}
  for k in pairs(w.fenster or {}) do
    local b, h = k:match("^(%d+)x(%d+)$")
    if b then fe[#fe + 1] = string.format('{ "breite": %s, "hoehe": %s }', b, h) end
  end
  table.sort(fe)
  local se = {}
  for _, e in ipairs(z.sj or {}) do
    if math.type(e.app) == "integer" then
      se[#se + 1] = string.format('{ "appId": %d, "sub": %d, "phys": %d, "name": %s }', e.app,
        math.type(e.sub) == "integer" and e.sub or 0, math.type(e.phys) == "integer" and e.phys or 0, js(e.name))
    end
  end
  local st = js(sd.status) .. (sd.status == "geladen" and sd.fehler > 0 and (', "fehler": ' .. sd.fehler) or "")
  local t = "{\n" ..
    '  "format": 1,\n  "lua": ' .. js(S.LUA) .. ',\n  "luaVersion": ' .. js(w.version) .. ',\n  "formate": [1],\n  "beiMotorAus": true,\n' ..
    '  "modell": ' .. js(z.modell) .. ',\n  "kennung": ' .. js(z.kennung) .. ',\n' ..
    ((okP and type(pfad) == "string") and ('  "modellPfad": ' .. js(pfad) .. ',\n') or "") ..
    '  "funke": ' .. js(ver.board) .. ',\n  "ethos": ' .. js(ver.version) .. ',\n' ..
    '  "fenster": [ ' .. table.concat(fe, ", ") .. ' ],\n  "studioDatei": ' .. st .. ',\n' ..
    '  "sensoren": [\n    ' .. table.concat(se, ",\n    ") .. '\n  ]\n}\n'
  local p = S.PFAD .. z.kennung .. "." .. S.LUA .. ".info.json"
  if sitzung[p] == t then return end
  pcall(os.mkdir, "SCRIPTS:/studio")
  local okO, f = pcall(io.open, p, "w")
  if okO and f then
    local okW = pcall(f.write, f, t)
    f:close()
    if okW then sitzung[p] = t return end
  end
  print("Glider Studio: Info-Datei nicht geschrieben")
end

-- Ein Schritt. w.sz2 = Zwischenstand. Rückgabe true = fertig (w.sd steht, w.sz2 = nil).
function S.schritt(w, F, sitzung)
  local z = w.sz2
  if z == nil then
    studioLaden = studioLaden or loadfile("studiolad.lua")()
    WERTE = WERTE or loadfile("werte.lua")()
    local okN, name = false, nil
    if model and model.name then okN, name = pcall(model.name) end
    z = { w = w, schritt = 1, modell = okN and name or "", sd = { status = "fehlt", fehler = 0, ansichten = {}, mon = {}, opt = {}, werte = {}, d = {} } }
    z.kennung = S.kennung(z.modell)
    w.sz2 = z
  end
  local s = z.schritt
  z.schritt = s + 1
  if s == 1 then liesDateien(z) if z.sd.status ~= "geladen" then z.schritt = 8 end
  elseif s == 2 then liesFunke(z)
  elseif s == 3 then if not pruefeSchritt(z, F) then z.schritt = 3 end
  elseif s == 4 then -- frei (früher Werte und Grenzen, seit 0.3.1 in Schritt 3)
  elseif s == 5 then if not ansichtSchritt(z) then z.schritt = 5 end
  elseif s == 6 then quellenSammeln(z)
  elseif s == 7 then if not quellenSchritt(z) then z.schritt = 7 end
  elseif s == 8 then if not sensorSchritt(z) then z.schritt = 8 end
  elseif s == 9 then
    w.sd, z.d, z.f = z.sd, nil, nil
    pcall(infoSchreiben, z, sitzung)
    w.sz2 = nil
    return true
  end
  return false
end

return S
