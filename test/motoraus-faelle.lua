-- Segler 0.4.0: «Alarm auch bei Motor aus» (Lua-Studio-Format 2, 3.5) und Befehlsgrenze der Studio-Grenzen im Betrieb.
-- Aufruf im Skriptordner: cd src/glider && /opt/homebrew/opt/lua@5.4/bin/lua ../../test/motoraus-faelle.lua
-- Prüft warnungen()/ansagen() aus kern.lua direkt (ohne Simulator):
--  a) Haken EIN, Schalter auf «Motor aus»: Alarm kommt (Meldung, Ton/Ansage, Vibration).
--  b) Haken AUS, Schalter auf «Motor aus»: still (keine Meldung, kein Ton), die Farbe zeigt den Wert weiter.
--  c) Haken AUS, Schalter auf «Motor ein»: Alarm kommt.   d) Haken AUS ohne zugewiesenen Schalter: Alarm kommt.
--  e) laufender Alarm geht, wenn der Motor ausgeschaltet wird.   f) Studio-Sensorgrenze mit beiMotorAus = false.
--  g) Akku-% (pMot) und Zelle (z2Mot) getrennt.   h) Studio «ansage = false»: Ton bleibt.
--  i) 165 Studio-Grenzen: Befehle je warnungen()-Aufruf unter 5000, Alarm kommt trotz Kreis.
local K = assert(loadfile("kern.lua"))()
local W, A = assert(K._warnungen), assert(K._ansagen)
UNIT_METER, UNIT_PERCENT = 1, 2
local toene, ansagen, vibs = 0, 0, 0
system = { playFile = function() ansagen = ansagen + 1 end, playNumber = function() end,
  playTone = function() toene = toene + 1 end, playHaptic = function() vibs = vibs + 1 end,
  getLocale = function() return "de" end }
local fehler = 0
local function fall(titel, gut, info)
  print((gut and "OK      " or "FEHLER  ") .. titel .. (info and ("  (" .. info .. ")") or ""))
  if not gut then fehler = fehler + 1 end
end

local function neu(cfg)
  local c = { ansage = true, vibration = true, zahl = false, warnAnsage = false, sperre = 0, swMotor = 1 }
  for k, v in pairs(cfg or {}) do c[k] = v end
  local w = { cfg = c, g = { hAlarm = 200, hWarn = 150, pAlarm = 20, pWarn = 30, rssiAlarm = 30, rssiWarn = 40,
      z1Alarm = 3.3, z1Warn = 3.5, z2Alarm = 3.3, z2Warn = 3.5, z3Alarm = 3.3, z3Warn = 3.5, zDiff = 0.15, pause = 30 },
    T = setmetatable({}, { __index = function(_, k) return k end }), v = { tele = true, h = 100, rssi = 90 },
    ak = { {}, {}, {} }, meld = {}, aktiv = {}, gst = {}, anQ = {}, sp = 1 }
  return w
end
-- bis 3 s laufen lassen (AN_S = 1 s), dann Ansage auslösen
local function lauf(w, sek)
  local t = w.t or 0
  for _ = 1, (sek or 3) * 10 do t = t + 0.1 W(w, t) end
  w.t = t
  toene, ansagen, vibs = 0, 0, 0
  A(w, t + 10)
  return w
end
local function laut() return toene + ansagen > 0 end

-- Höhe 250 m (über Alarm 200)
local w = neu() w.v.h, w.v.motorSw = 250, true
lauf(w)
fall("a) Haken EIN, Motor aus: Höhenalarm kommt", w.stufe == 2 and laut() and vibs == 1 and w.v.st.h == 2)
w = neu({ hMot = false }) w.v.h, w.v.motorSw = 250, true
lauf(w)
fall("b) Haken AUS, Motor aus: still, Farbe rot", w.stufe == 0 and not laut() and vibs == 0 and w.v.st.h == 2 and w.meldText == nil,
  "stufe " .. tostring(w.stufe) .. ", st.h " .. tostring(w.v.st.h))
w = neu({ hMot = false }) w.v.h, w.v.motorSw = 180, true
lauf(w)
fall("b2) Haken AUS, Motor aus, Warnung: still, Farbe orange", w.stufe == 0 and w.v.st.h == 1)
w = neu({ hMot = false }) w.v.h, w.v.motorSw = 250, false
lauf(w)
fall("c) Haken AUS, Motor ein: Alarm kommt", w.stufe == 2 and laut())
w = neu({ hMot = false, swMotor = false }) w.v.h, w.v.motorSw = 250, nil
lauf(w)
fall("d) Haken AUS, kein Motorschalter: Alarm kommt", w.stufe == 2 and laut())
w = neu({ rMot = false }) w.v.rssi, w.v.motorSw = 20, false
lauf(w)
local vor = w.stufe
w.v.motorSw = true
lauf(w, 0.2)
fall("e) laufender Empfangsalarm geht sofort, wenn der Motor aus ist", vor == 2 and w.stufe == 0 and w.v.st.rssi == 2)
-- g) Antriebsakku: Akku 2 Rolle Antrieb, 15 % (Alarm über pMot), Zelle 3,6 V (gut)
local function antrieb(cfg, p, zelle)
  local x = neu(cfg)
  x.ak[2] = { da = true, rolle = 2, p = p, tief = zelle }
  x.v.motorSw = true
  return lauf(x)
end
w = antrieb({ pMot = false }, 15, 3.6)
fall("g1) pMot AUS, Akku-% Alarm bei Motor aus: still, Farbe", w.stufe == 0 and w.v.st.a2 == 2)
w = antrieb({ z2Mot = false }, 15, 3.6)
fall("g2) nur z2Mot AUS: Akku-% Alarm kommt", w.stufe == 2 and laut())
w = antrieb({ pMot = false }, 80, 3.2)
fall("g3) pMot AUS, Zellalarm kommt", w.stufe == 2 and laut())
-- f) Studio-Sensorgrenze
local function sens(bma, mot)
  local x = neu()
  x.v.motorSw = mot
  local q = { value = function() return 120 end }
  x.sd = { mon = { { key = "sensor:0100:0", d = { art = "sensor", q = q }, richtung = "ueber", alarm = 100, bma = bma, name = "S" } } }
  return lauf(x)
end
w = sens(false, true)
fall("f1) Sensorgrenze beiMotorAus = false, Motor aus: still, Farbe", w.stufe == 0 and w.gst["sensor:0100:0"] == 2)
w = sens(false, false)
fall("f2) dieselbe, Motor ein: Alarm kommt", w.stufe == 2 and laut())
w = sens(true, true)
fall("f3) beiMotorAus = true, Motor aus: Alarm kommt", w.stufe == 2 and laut())
-- h) Studio ansage = false: Ton bleibt, keine Ansage
w = neu() w.v.h = 250 w.sd = { opt = { h = { ans = false, vib = true } } }
lauf(w)
fall("h) Studio ansage = false: Ton kommt, keine Ansage", toene == 1 and ansagen == 0)
-- i) 165 Grenzen, Befehle je Aufruf
w = neu() w.v.motorSw = false
local mon = {}
for i = 1, 165 do
  local q = { value = function() return (i == 160) and 500 or 10 end }
  mon[i] = { key = "sensor:" .. i, d = { art = "sensor", q = q }, richtung = "ueber", warn = 300, alarm = 400, name = "S" .. i }
end
w.sd = { mon = mon }
local maxB, n = 0, 0
local function zaehle() n = n + 1 end
local t = 0
for _ = 1, 40 do
  t = t + 0.1
  n = 0
  debug.sethook(zaehle, "", 1)
  W(w, t)
  debug.sethook()
  if n > maxB then maxB = n end
end
fall("i) 165 Studio-Grenzen: Befehle je warnungen() unter 5000", maxB < 5000, maxB .. " Befehle")
fall("i2) Alarm des 160. Eintrags kommt trotz Kreis", w.stufe == 2 and w.gst["sensor:160"] == 2)
-- i3) schlimmster Fall: alle 165 Grenzen gleichzeitig über dem Alarm
for i = 1, 165 do mon[i].d.q = { value = function() return 500 end } end
maxB = 0
for _ = 1, 60 do
  t = t + 0.1
  n = 0
  debug.sethook(zaehle, "", 1)
  W(w, t)
  debug.sethook()
  if n > maxB then maxB = n end
end
fall("i3) alle 165 Grenzen im Alarm: Befehle je warnungen()", maxB < 5000, maxB .. " Befehle")
-- j) Update von 0.3.x: Widget-Speicher FORMAT 1 wird ohne Verlust gelesen, neue Haken stehen auf EIN
do
  local F = assert(loadfile("felder.lua"))()
  local q = {}
  for _, name in ipairs(F.folge) do local f = F.feld(name) if f and f[2] == "q" then q[#q + 1] = name end end
  local quelle = { name = function() return "SF" end, value = function() return 0 end }
  local mem = { fmt = 1, ende = 1 }
  for i = 1, #q do mem["q" .. i] = quelle end
  storage = { read = function(k) return mem[k] end, write = function(k, v) mem[k] = v end }
  model = { path = function() return "models/gibtsnicht_update.bin" end }
  local alt = io.open
  io.open = function() return nil end
  local wu = { name = "Segler" }
  local gef = F.lies(wu)
  local alle = true
  for _, name in ipairs(q) do if wu.cfg[name] ~= quelle then alle = false end end
  fall("j1) FORMAT 1 (0.3.x): alle " .. #q .. " Quellen gelesen", gef and alle)
  fall("j2) neue Haken nach Update EIN", wu.cfg.hMot == true and wu.cfg.pMot == true and wu.cfg.rMot == true
    and wu.cfg.z1Mot == true and wu.cfg.z2Mot == true and wu.cfg.z3Mot == true and wu.cfg.dMot == true)
  F.schreibe(wu)
  fall("j3) danach als FORMAT 2 geschrieben und wieder gelesen", mem.fmt == 2 and mem.ende == 2 and F.lies(wu) and wu.cfg[q[1]] == quelle)
  io.open = alt
end
print(fehler == 0 and "ERGEBNIS: kein Fehler" or ("ERGEBNIS: " .. fehler .. " Fehler"))
os.exit(fehler == 0 and 0 or 1)
