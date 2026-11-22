-- Feste Fälle für die Studio-Datei (Lua-Studio-Format v1, Abschnitt 12) auf dem Mac, ohne Simulator.
-- Aufruf im Skriptordner: cd src/glider && /opt/homebrew/opt/lua@5.4/bin/lua ../../test/studio-faelle.lua
-- Prüft: alle Angriffsdateien der Koordination, gültige volle Datei, Feldfehler, leere Datei, keine Datei, .funke.lua
-- (Schreiben, Zusammenführen, übrig gebliebene .funke.neu), Befehle je Schritt (debug.sethook) und Speicher.
local KOORD = os.getenv("GLIDER_FORMAT_TESTS")
if not KOORD or KOORD == "" then
  print("Bitte GLIDER_FORMAT_TESTS auf den Ordner mit den Lua-Studio-Format-Testdateien setzen (mit / am Ende).")
  os.exit(2)
end
local HIER = "../../test/studio/"
local TMP = os.tmpname()
os.remove(TMP)
os.execute('mkdir -p "' .. TMP .. '"')

lcd = { RGB = function(r, g, b) return r * 65536 + g * 256 + b end }
CATEGORY_CHANNEL, CATEGORY_TELEMETRY_SENSOR = 1, 2
local NAME = "Testmodell Ö"
model = { name = function() return NAME end, path = function() return "/models/test.bin" end }
local function sensor(app, sub, phys, name, wert)
  return { appId = function() return app end, subId = function() return sub end, physId = function() return phys end,
    name = function() return name end, value = function() return wert end }
end
local SENS = { sensor(0x0100, 0, 4, "Höhe", 120), sensor(0x0100, 0, 7, "Höhe \"2\"", 130), sensor(0x0200, 0, 2, "Strom", 12) }
system = {
  getSource = function(t)
    if type(t) ~= "table" then return nil end
    if t.category == CATEGORY_CHANNEL then return sensor(0, 0, 0, "CH" .. (t.member + 1), 512) end
    for _, s in ipairs(SENS) do if s.appId() == t.appId and s.subId() == t.subId then return s end end
    return nil
  end,
  -- wie am Sender (X18RS, 20.11.2026): Tabellenform liefert eine leere Liste, nur die Zahlform geht
  getSources = function(c) if type(c) == "table" then return {} end return SENS end,
  getVersion = function() return { board = "X18RS", version = "26.2.0" } end,
}
os.mkdir = os.mkdir or function() return true end

local S = assert(loadfile("studio.lua"))()
S.PFAD = TMP .. "/"
local F = assert(loadfile("felder.lua"))()
local KENNUNG = S.kennung(NAME)
local fehler, MAXB, MAXM = 0, 0, 0

local function kopiere(von, nach)
  local a = io.open(von, "rb")
  if not a then return false end
  local t = a:read("a")
  a:close()
  local b = io.open(nach, "wb")
  b:write(t)
  b:close()
  return true
end
local function loesche()
  for _, e in ipairs({ ".lua", ".funke.lua", ".funke.neu", ".info.json" }) do os.remove(S.PFAD .. KENNUNG .. ".glider" .. e) end
end

-- Studio-Schritte wie im Kern laufen lassen; Befehle je Schritt und Speicher messen
local function lauf(w)
  w = w or { cfg = F.standard(), sp = 1, version = "0.3.0", fenster = { ["784x316"] = true } }
  local sitzung = {}
  local n = 0
  collectgarbage()
  local m0 = collectgarbage("count")
  repeat
    local z = 0
    debug.sethook(function() z = z + 1 end, "", 1)
    local ok, fertig = pcall(S.schritt, w, function() return F end, sitzung)
    debug.sethook()
    if z > MAXB then MAXB = z end
    if z > 4500 then print(string.format("  Schritt %d: %d Befehle", n + 1, z)) end
    local m = collectgarbage("count") - m0
    if m > MAXM then MAXM = m end
    if not ok then return nil, fertig end
    n = n + 1
  until fertig or n > 200
  return w
end

local function fall(titel, gut, info)
  print((gut and "OK    " or "FEHLER") .. "  " .. titel .. (info and ("  (" .. info .. ")") or ""))
  if not gut then fehler = fehler + 1 end
end

-- 1. Angriffs- und Grenzfalldateien der Koordination
local ERWARTET = { format99 = "zuNeu", typisch = "geladen" }
local p = io.popen('ls "' .. KOORD .. '"')
for datei in p:lines() do
  local name = datei:match("^(.-)%.lua$")
  if name and not datei:find("messen", 1, true) then
    loesche()
    kopiere(KOORD .. datei, S.PFAD .. KENNUNG .. ".glider.lua")
    local w, e = lauf()
    local st = w and w.sd and w.sd.status
    local soll = ERWARTET[name] or ((name:find("^mem") or name:find("^g%d")) and "egal") or "kaputt"
    fall("Angriff/Grenzfall " .. name, w ~= nil and (soll == "egal" or st == soll),
      tostring(st or e) .. (w and w.sd and w.sd.fehler > 0 and (", " .. w.sd.fehler .. " Feldfehler") or ""))
  end
end
p:close()

-- 2. keine Datei
loesche()
local w = lauf()
fall("keine Studio-Datei", w and w.sd.status == "fehlt" and w.sd.ueber == nil)

-- 2b. Übergang 0.5.0: nur die alte Datei <Kennung>.segler.lua liegt da -> wird gelesen
loesche()
kopiere(HIER .. "voll.lua", S.PFAD .. KENNUNG .. ".segler.lua")
w = lauf()
fall("alte Datei .segler.lua gelesen (Übergang)", w and w.sd.status == "geladen" and w.sd.fehler == 0)
os.remove(S.PFAD .. KENNUNG .. ".segler.lua")

-- 3. gültige volle Datei
loesche()
kopiere(HIER .. "voll.lua", S.PFAD .. KENNUNG .. ".glider.lua")
w = lauf()
local sd = w and w.sd
local u = sd and sd.ueber or {}
fall("volle Datei geladen, keine Feldfehler", sd and sd.status == "geladen" and sd.fehler == 0, sd and (sd.status .. ", " .. sd.fehler))
fall("2 Ansichten zu 16 Plätzen", sd and #sd.ansichten == 2 and #sd.ansichten[1].plaetze == 16 and #sd.ansichten[2].plaetze == 16)
fall("Einstellungen in gespeicherter Form", u.modell == 2 and u.a2S == 3 and u.kap == 2200 and u.thAb == 15 and u.startH == 15
  and u.sw1Name == "Schlepp" and u.sw1Inv == true and u.skala == 4 and u.zeitAlle == 5,
  string.format("thAb=%s kap=%s", tostring(u.thAb), tostring(u.kap)))
fall("eingebaute Grenzen", u.hWarn == 180 and u.hAlarm == 200 and u.pWarn == 35 and u.pAlarm == 0 and u.z1Warn == 0
  and u.z1Alarm == 0 and u.rssiWarn == 40 and u.rssiAlarm == 30 and u.z2Warn == 350,
  string.format("p %s/%s z1 %s/%s", tostring(u.pWarn), tostring(u.pAlarm), tostring(u.z1Warn), tostring(u.z1Alarm)))
fall("Vibration je Wert", sd and sd.opt.r and sd.opt.r.vib == false and sd.opt.h.vib == true)
fall("Grenzen ohne eingebaute (Sensor, Kanal, lua:speed)", sd and #sd.mon == 3)
local ph = nil
for _, a in ipairs(sd and sd.ansichten or {}) do for _, q in ipairs(a.plaetze) do if q.key == "sensor:0100:0:7" then ph = q end end end
fall("Sensor mit Physical ID gefunden", ph and ph.d.q and ph.d.q.physId() == 7)
local ms = nil
for _, m in ipairs(sd and sd.mon or {}) do if m.key == "sensor:0200:0" then ms = m end end
fall("Sensor ohne Physical ID über die Sensorliste (Zahlform) gefunden", ms and ms.d.q and ms.d.q.name() == "Strom")
fall("Anpassung 6.4 (Name, Einheit, Stellen)", sd and sd.werte["sensor:0830:0"] and sd.werte["sensor:0830:0"].faktor == 0.5)
-- 0.6.0: den Kopf der Info-Datei baut studio.lua, der Kern hängt studioQuelle … hinweis an und schreibt (R4)
local info = sd and sd.infoKopf or ""
fall("Info-Kopf und Pfad gebaut", sd and sd.infoPfad == S.PFAD .. KENNUNG .. ".glider.info.json")
fall("Info-Datei: studioQuelle und Wahl", sd and sd.quelle == S.PFAD .. KENNUNG .. ".glider.lua" and sd.wahl == "auto")
fall("Info-Kopf", info:find('"studioDatei": "geladen"', 1, true) and info:find('"kennung": "Testmodell___"', 1, true)
  and info:find('"name": "H\\u00F6he', 1, true) == nil and info:find('\\"2\\"', 1, true) ~= nil and info:find('"breite": 784', 1, true) ~= nil)

-- 4. .funke.lua: Änderung schreiben, neu laden, zusammenführen
w.cfg = {}
for k, v in pairs(sd.ueber) do w.cfg[k] = v end
w.cfg.kap, w.cfg.hWarn, w.cfg.pWarn, w.cfg.pAlarm = 3000, 150, 0, 0
local schreib = assert(loadfile("funkeschreib.lua"))()
local okS, gutS = pcall(schreib, w, S, F, assert(loadfile("studiolad.lua"))(), KENNUNG)
fall(".funke.lua geschrieben", okS and gutS, tostring(gutS))
local w2 = lauf()
local u2 = w2 and w2.sd.ueber or {}
fall(".funke.lua liegt über der Studio-Datei", u2.kap == 3000 and u2.hWarn == 150 and u2.hAlarm == 200 and u2.pWarn == 0
  and w2.sd.basis.kap == 2200 and w2.sd.basis.hWarn == 180, string.format("kap %s hW %s/%s p %s", tostring(u2.kap),
  tostring(u2.hWarn), tostring(u2.hAlarm), tostring(u2.pWarn)))
-- übrig gebliebene .funke.neu ohne .funke.lua: wird übernommen
os.rename(S.PFAD .. KENNUNG .. ".glider.funke.lua", S.PFAD .. KENNUNG .. ".glider.funke.neu")
local w3 = lauf()
fall("übrig gebliebene gültige .funke.neu übernommen", w3 and w3.sd.ueber.kap == 3000
  and io.open(S.PFAD .. KENNUNG .. ".glider.funke.neu") == nil)
-- kaputte .funke.lua: verworfen, Studio-Datei gilt
local g = io.open(S.PFAD .. KENNUNG .. ".glider.funke.lua", "w")
g:write("return { format = 1, x = (\"x\"):rep(1e9) }")
g:close()
local w4 = lauf()
fall("kaputte .funke.lua verworfen, Studio gilt", w4 and w4.sd.funkeVerworfen and w4.sd.ueber.kap == 2200)
-- Strom weg mitten im Schreiben: halbe .funke.neu neben gültiger .funke.lua -> .neu gelöscht
g = io.open(S.PFAD .. KENNUNG .. ".glider.funke.lua", "w") g:write("return { format = 1, einstellungen = { kap = 1000 } }\n") g:close()
g = io.open(S.PFAD .. KENNUNG .. ".glider.funke.neu", "w") g:write("return { format = 1, einstell") g:close()
local w5 = lauf()
fall("halbe .funke.neu gelöscht, .funke.lua gilt", w5 and w5.sd.ueber.kap == 1000
  and io.open(S.PFAD .. KENNUNG .. ".glider.funke.neu") == nil)

-- 5. Feldfehler einzeln verworfen
loesche()
kopiere(HIER .. "falsch.lua", S.PFAD .. KENNUNG .. ".glider.lua")
w = lauf()
sd = w and w.sd
fall("Feldfehler: geladen, Fehler gezählt, kein Absturz", sd and sd.status == "geladen" and sd.fehler >= 15, sd and tostring(sd.fehler))
fall("Feldfehler: Werkwerte bleiben", sd and sd.ueber.modell == 1 and sd.ueber.hWarn == 0 and sd.ueber.rssiWarn == 0 and sd.ueber.rssiAlarm == 40,
  sd and string.format("modell %s hW %s rA %s", tostring(sd.ueber.modell), tostring(sd.ueber.hWarn), tostring(sd.ueber.rssiAlarm)))
local nPl = sd and sd.ansichten[1] and #sd.ansichten[1].plaetze
fall("Feldfehler: ungültige Plätze verworfen, Rest bleibt", nPl == 6, tostring(nPl))
fall("Feldfehler: Ansicht 50 x 50 und dritte Ansicht verworfen", sd and #sd.ansichten == 1)

-- 6. leere Datei: alles Werk
loesche()
kopiere(HIER .. "leer.lua", S.PFAD .. KENNUNG .. ".glider.lua")
w = lauf()
local werk = F.standard()
fall("leere Datei = Werkwerte", w and w.sd.status == "geladen" and w.sd.ueber.kap == werk.kap and w.sd.ueber.pWarn == werk.pWarn)

-- 6b. Modellwechsel zehnmal: Speicher wächst nicht (Studio-Ergebnis des alten Modells wird frei)
loesche()
kopiere(HIER .. "voll.lua", S.PFAD .. KENNUNG .. ".glider.lua")
local mem = {}
for i = 1, 10 do
  local wx = lauf()
  wx = nil
  collectgarbage() collectgarbage()
  mem[i] = collectgarbage("count")
end
fall("Modellwechsel 10x: Speicher wächst nicht", mem[10] - mem[2] < 5, string.format("%.0f KB -> %.0f KB", mem[2], mem[10]))

-- 6c. Alarm-Sicherheit (Befunde der Prüfung 0.3.0)
local function schreibeStudio(text, funke)
  loesche()
  local g = io.open(S.PFAD .. KENNUNG .. ".glider.lua", "w") g:write(text) g:close()
  if funke then g = io.open(S.PFAD .. KENNUNG .. ".glider.funke.lua", "w") g:write(funke) g:close() end
end
local AP = '["\\108\\117\\97\\58\\97\\110\\116\\114\\105\\101\\98\\95\\112\\114\\111\\122"]'  -- lua:antrieb_proz
local HO = '["\\108\\117\\97\\58\\104\\111\\101\\104\\101"]'                                  -- lua:hoehe
-- T1: Studio schaltet aus, an der Funke wieder eingeschaltet -> bleibt nach Neuladen an
schreibeStudio("return { format = 1, grenzen = { " .. AP .. " = { aus = true } } }")
local wa = lauf()
wa.cfg = {}
for k, v in pairs(wa.sd.ueber) do wa.cfg[k] = v end
wa.cfg.pWarn, wa.cfg.pAlarm = 30, 20
schreib(wa, S, F, assert(loadfile("studiolad.lua"))(), KENNUNG)
local wb = lauf()
fall("T1 an der Funke wieder eingeschalteter Alarm bleibt an", wb.sd.ueber.pWarn == 30 and wb.sd.ueber.pAlarm == 20,
  string.format("%s/%s", tostring(wb.sd.ueber.pWarn), tostring(wb.sd.ueber.pAlarm)))
-- T3: versatz 500 auf Höhe: Grenzen 400/450 im angezeigten Wert überwacht, nicht still aus
schreibeStudio("return { format = 1, werte = { " .. HO .. " = { versatz = 500 } }, grenzen = { " .. HO .. " = { warnung = 400, alarm = 450 } } }")
local wc = lauf()
local mh = nil
for _, m in ipairs(wc.sd.mon) do if m.key == "lua:hoehe" then mh = m end end
fall("T3 Versatz: Höhengrenze als Überwachung im angezeigten Wert", mh and mh.warn == 400 and mh.alarm == 450
  and wc.sd.ueber.hWarn == 0 and wc.sd.ueber.hAlarm == 0)
-- T4: negativer Faktor: im angezeigten Wert überwacht (keine umgedrehte Rohgrenze)
schreibeStudio("return { format = 1, werte = { " .. AP .. " = { faktor = -1 } }, grenzen = { " .. AP .. " = { warnung = -30, alarm = -20 } } }")
local wd = lauf()
local mp = nil
for _, m in ipairs(wd.sd.mon) do if m.key == "lua:antrieb_proz" then mp = m end end
fall("T4 negativer Faktor: Überwachung im angezeigten Wert, Richtung gedreht", mp and mp.richtung == "ueber"
  and mp.alarm == -20 and mp.warn == -30 and wd.sd.ueber.pAlarm == 0, mp and string.format("%s %s/%s", mp.richtung, tostring(mp.warn), tostring(mp.alarm)))
-- T8: Eintrag nur in .funke.lua mit warnung: Werkalarm bleibt
schreibeStudio("return { format = 1 }", "return { format = 1, grenzen = { " .. AP .. " = { warnung = 35 } } }")
local we = lauf()
fall("T8 Teil-Eintrag in .funke.lua: Werkalarm bleibt", we.sd.ueber.pWarn == 35 and we.sd.ueber.pAlarm == 20,
  string.format("%s/%s", tostring(we.sd.ueber.pWarn), tostring(we.sd.ueber.pAlarm)))
-- T2: eine Stufe an der Funke abschalten bleibt nach dem Neuladen aus (warnung = false)
schreibeStudio("return { format = 1, grenzen = { " .. AP .. " = { warnung = 40, alarm = 25 } } }")
local wg = lauf()
wg.cfg = {}
for k, v in pairs(wg.sd.ueber) do wg.cfg[k] = v end
wg.cfg.pWarn = 0
schreib(wg, S, F, assert(loadfile("studiolad.lua"))(), KENNUNG)
local wh = lauf()
fall("T2 Stufe an der Funke abgeschaltet bleibt aus", wh.sd.ueber.pWarn == 0 and wh.sd.ueber.pAlarm == 25,
  string.format("%s/%s", tostring(wh.sd.ueber.pWarn), tostring(wh.sd.ueber.pAlarm)))
-- Studio-Datei mit alarm = false: nur die Warnung gilt, kein Fehler
schreibeStudio("return { format = 1, grenzen = { " .. AP .. " = { warnung = 40, alarm = false } } }")
local wi = lauf()
fall("alarm = false in der Studio-Datei", wi.sd.fehler == 0 and wi.sd.ueber.pWarn == 40 and wi.sd.ueber.pAlarm == 0)
-- Nachprüfung A: Versatz 500 auf Höhe, Studio 600/650 -> eingebaut 100/150; nur Warnung an der Funke ändern
schreibeStudio("return { format = 1, werte = { " .. HO .. " = { versatz = 500 } }, grenzen = { " .. HO .. " = { warnung = 600, alarm = 650 } } }")
local wA = lauf()
fall("A Versatz: eingebaute Höhengrenze umgerechnet", wA.sd.ueber.hWarn == 100 and wA.sd.ueber.hAlarm == 150 and #wA.sd.mon == 0)
wA.cfg = {} for k, v in pairs(wA.sd.ueber) do wA.cfg[k] = v end
wA.cfg.hWarn = 120
schreib(wA, S, F, assert(loadfile("studiolad.lua"))(), KENNUNG)
local wA2 = lauf()
fall("A nur Warnung geändert: Alarm bleibt", wA2.sd.ueber.hWarn == 120 and wA2.sd.ueber.hAlarm == 150,
  string.format("%s/%s", tostring(wA2.sd.ueber.hWarn), tostring(wA2.sd.ueber.hAlarm)))
-- Nachprüfung E: Versatz, Studio aus; an der Funke eingeschaltet; danach nur kap ändern -> Alarm bleibt
schreibeStudio("return { format = 1, werte = { " .. HO .. " = { versatz = 500 } }, grenzen = { " .. HO .. " = { aus = true } } }")
local wE = lauf()
wE.cfg = {} for k, v in pairs(wE.sd.ueber) do wE.cfg[k] = v end
wE.cfg.hWarn, wE.cfg.hAlarm = 100, 150
schreib(wE, S, F, assert(loadfile("studiolad.lua"))(), KENNUNG)
local wE2 = lauf()
wE2.cfg = {} for k, v in pairs(wE2.sd.ueber) do wE2.cfg[k] = v end
wE2.cfg.kap = 1234
schreib(wE2, S, F, assert(loadfile("studiolad.lua"))(), KENNUNG)
local wE3 = lauf()
fall("E eingeschalteter Alarm bleibt nach weiterer Änderung", wE3.sd.ueber.hWarn == 100 and wE3.sd.ueber.hAlarm == 150
  and wE3.sd.ueber.kap == 1234, string.format("%s/%s", tostring(wE3.sd.ueber.hWarn), tostring(wE3.sd.ueber.hAlarm)))
-- Nachprüfung B: Faktor 2, nur .funke.lua { warnung = 50 } (= 25 %) -> Alarm bleibt Werk (20 % = angezeigt 40)
schreibeStudio("return { format = 1, werte = { " .. AP .. " = { faktor = 2 } } }", "return { format = 1, grenzen = { " .. AP .. " = { warnung = 50 } } }")
local wB = lauf()
fall("B Faktor 2: Werkalarm bleibt", wB.sd.ueber.pAlarm == 20 and wB.sd.ueber.pWarn == 25,
  string.format("%s/%s", tostring(wB.sd.ueber.pWarn), tostring(wB.sd.ueber.pAlarm)))
-- Nachprüfung B2: Faktor -1, nur .funke.lua { warnung = -35 } -> Überwachung «ueber», Alarm bei angezeigt > -20
schreibeStudio("return { format = 1, werte = { " .. AP .. " = { faktor = -1 } } }", "return { format = 1, grenzen = { " .. AP .. " = { warnung = -35 } } }")
local wB2 = lauf()
local mB = nil
for _, m in ipairs(wB2.sd.mon) do if m.key == "lua:antrieb_proz" then mB = m end end
fall("B2 Faktor -1: Richtung gedreht, Werkalarm bleibt", mB and mB.richtung == "ueber" and mB.alarm == -20 and mB.warn == -35
  and wB2.sd.fehler == 0, mB and string.format("%s %s/%s", mB.richtung, tostring(mB.warn), tostring(mB.alarm)))

-- Nachprüfung C1b: an der Funke geändert, danach wieder auf den Studio-Wert -> nach Neuladen Studio-Wert
schreibeStudio("return { format = 1, grenzen = { " .. AP .. " = { warnung = 40, alarm = 25 } } }")
local wC = lauf()
wC.cfg = {} for k, v in pairs(wC.sd.ueber) do wC.cfg[k] = v end
wC.cfg.pWarn = 35
schreib(wC, S, F, assert(loadfile("studiolad.lua"))(), KENNUNG)
local wC2 = lauf()
wC2.cfg = {} for k, v in pairs(wC2.sd.ueber) do wC2.cfg[k] = v end
wC2.cfg.pWarn = 40
schreib(wC2, S, F, assert(loadfile("studiolad.lua"))(), KENNUNG)
local wC3 = lauf()
fall("C1b zurück auf den Studio-Wert bleibt", wC3.sd.ueber.pWarn == 40 and wC3.sd.ueber.pAlarm == 25,
  string.format("%s/%s", tostring(wC3.sd.ueber.pWarn), tostring(wC3.sd.ueber.pAlarm)))
-- T6: aus mit falschem Typ zählt als Fehler
schreibeStudio("return { format = 1, grenzen = { " .. AP .. " = { aus = 1 } } }")
local wf = lauf()
fall("T6 aus mit falschem Typ: Fehler gezählt", wf.sd.fehler == 1)

-- 6d. Kein Abschalten ohne «aus» (v1 6.5, Ergänzung 21.11.2026) und «auch bei Motor aus» (Format 2, 3.5), 0.4.0
local SE = '["\\115\\101\\110\\115\\111\\114\\58\\48\\49\\48\\48\\58\\48"]'  -- sensor:0100:0
local function pw(x) return string.format("%s/%s", tostring(x.sd.ueber.pWarn), tostring(x.sd.ueber.pAlarm)) end
schreibeStudio("return { format = 1, grenzen = { " .. AP .. " = { ansage = false } } }")
local k1 = lauf()
fall("K1 Eintrag nur mit ansage = false: Werkgrenze 30/20 bleibt", k1.sd.ueber.pWarn == 30 and k1.sd.ueber.pAlarm == 20
  and k1.sd.opt.p and k1.sd.opt.p.ans == false, pw(k1))
schreibeStudio("return { format = 1, grenzen = { " .. AP .. " = { warnung = false, alarm = false } } }")
local k2 = lauf()
fall("K2 warnung = false und alarm = false ohne aus: Werkgrenze", k2.sd.ueber.pWarn == 30 and k2.sd.ueber.pAlarm == 20, pw(k2))
schreibeStudio("return { format = 1, grenzen = { " .. AP .. " = { beiMotorAus = false } } }")
local k3 = lauf()
fall("K3 nur beiMotorAus = false: Werkgrenze, Haken aus", k3.sd.ueber.pWarn == 30 and k3.sd.ueber.pAlarm == 20
  and k3.sd.ueber.pMot == false and k3.sd.ueber.hMot == true and k3.sd.fehler == 0, pw(k3))
schreibeStudio("return { format = 1, grenzen = { " .. AP .. " = { aus = true, beiMotorAus = false } } }")
local k4 = lauf()
fall("K4 aus = true schaltet ab", k4.sd.ueber.pWarn == 0 and k4.sd.ueber.pAlarm == 0, pw(k4))
schreibeStudio("return { format = 1, grenzen = { " .. HO .. " = { warnung = false } } }")
local k5 = lauf()
fall("K5 Höhe nur warnung = false (Werk ohne Stufe): bleibt Werk, kein Abschalten", k5.sd.ueber.hWarn == 0 and k5.sd.ueber.hAlarm == 0
  and #k5.sd.mon == 0)
schreibeStudio("return { format = 1, grenzen = { " .. AP .. " = { beiMotorAus = 1 } } }")
local k6 = lauf()
fall("K6 beiMotorAus falscher Typ: zählt als true, Fehler", k6.sd.ueber.pMot == true and k6.sd.fehler == 1)
schreibeStudio("return { format = 1, grenzen = { " .. AP .. " = { warnung = 40, alarm = 25, beiMotorAus = false } } }",
  "return { format = 1, grenzen = { " .. AP .. " = { beiMotorAus = true } } }")
local k7 = lauf()
fall("K7 .funke.lua beiMotorAus = true hebt false der Studio-Datei auf", k7.sd.ueber.pMot == true
  and k7.sd.basis.pMot == false and k7.sd.ueber.pWarn == 40 and k7.sd.ueber.pAlarm == 25, pw(k7))
schreibeStudio("return { format = 1, grenzen = { " .. AP .. " = { warnung = 40, alarm = 25 } } }")
local k8 = lauf()
k8.cfg = {}
for k, v in pairs(k8.sd.ueber) do k8.cfg[k] = v end
k8.cfg.pMot, k8.cfg.hMot = false, false
schreib(k8, S, F, assert(loadfile("studiolad.lua"))(), KENNUNG)
local k8b = lauf()
fall("K8 Menü Haken aus -> .funke.lua -> nach Neuladen aus, Grenzen bleiben", k8b.sd.ueber.pMot == false and k8b.sd.ueber.hMot == false
  and k8b.sd.ueber.pWarn == 40 and k8b.sd.ueber.pAlarm == 25 and k8b.sd.ueber.hWarn == 0, pw(k8b))
k8b.cfg = {}
for k, v in pairs(k8b.sd.ueber) do k8b.cfg[k] = v end
k8b.cfg.pMot, k8b.cfg.hMot = true, true
schreib(k8b, S, F, assert(loadfile("studiolad.lua"))(), KENNUNG)
local k8c = lauf()
fall("K8b Haken wieder ein -> .funke.lua entfernt", k8c.sd.ueber.pMot == true and k8c.sd.ueber.hMot == true
  and io.open(S.PFAD .. KENNUNG .. ".glider.funke.lua") == nil)
schreibeStudio("return { format = 1, grenzen = { " .. SE .. " = { richtung = \"ueber\", warnung = 100, beiMotorAus = false }, " ..
  '["\\115\\101\\110\\115\\111\\114\\58\\48\\50\\48\\48\\58\\48"] = { richtung = "ueber", beiMotorAus = false } } }')
local k9 = lauf()
fall("K9 Sensor-Grenze mit beiMotorAus = false; Sensor ohne Stufe: kein Alarm", #k9.sd.mon == 1 and k9.sd.mon[1].bma == false
  and k9.sd.mon[1].mot == nil, tostring(#k9.sd.mon))

-- 8. Befehlsgrenze (0.3.1): grosse gültige Dateien, je Aufruf von S.schritt < 5000 Befehle (debug.sethook)
local function esc(t) return '"' .. t:gsub(".", function(c) return "\\" .. c:byte() end) .. '"' end
local function gross(teil, n, eintrag)
  local t = { "return { format = 1, " .. teil .. " = {" }
  for i = 1, n do t[#t + 1] = eintrag(i) end
  t[#t + 1] = " } }"
  return table.concat(t)
end
local GROSS = {
  { "grenzen x165", gross("grenzen", 165, function(i) return string.format("[%s]={richtung=%s,alarm=%d},", esc(string.format("sensor:%04X:0", i)), esc("ueber"), i) end) },
  { "grenzen x110 voll", gross("grenzen", 110, function(i) return string.format("[%s]={richtung=%s,warnung=%d,alarm=%d,ansage=true},", esc(string.format("sensor:%04X:0", i)), esc("ueber"), i, i + 1) end) },
  { "werte x140", gross("werte", 140, function(i) return string.format("[%s]={faktor=2,einheit=%s,stellen=1},", esc(string.format("sensor:%04X:0", i)), esc("V")) end) },
  { "einstellungen x350", gross("einstellungen", 350, function(i) return string.format("x%d=1,", i) end) },
}
for _, g in ipairs(GROSS) do
  local alt = MAXB
  MAXB = 0
  schreibeStudio(g[2])
  local wg = lauf()
  local st = wg and wg.sd and wg.sd.status
  fall("gross: " .. g[1] .. " (" .. #g[2] .. " Byte)", st == "geladen" and MAXB < 5000,
    tostring(st) .. ", höchstens " .. MAXB .. " Befehle je Schritt, " .. (wg and wg.sd and #wg.sd.mon or 0) .. " Grenzen")
  MAXB = math.max(alt, MAXB)
end
-- dieselben Grenzen zusätzlich in .funke.lua (Zusammenführen)
do
  local alt = MAXB
  MAXB = 0
  local t = gross("grenzen", 110, function(i) return string.format("[%s]={richtung=%s,warnung=%d,alarm=%d},", esc(string.format("sensor:%04X:0", i)), esc("ueber"), i, i + 1) end)
  schreibeStudio(t, t)
  local wg = lauf()
  fall("gross: grenzen x110 in Studio und .funke.lua", wg and wg.sd.status == "geladen" and MAXB < 5000, "höchstens " .. MAXB .. " Befehle")
  MAXB = math.max(alt, MAXB)
end

-- 6d. Format 2 §7.2: höchstens 48 Einträge je Liste; 60 Einstellungen -> 12 verworfen und als Fehler gezählt
do
  local e = {}
  for i = 1, 60 do e[#e + 1] = "x" .. i .. " = 1" end
  schreibeStudio("return { format = 1, einstellungen = { " .. table.concat(e, ", ") .. " } }")
  local wz = lauf()
  fall("60 Einstellungen: 12 verworfen, Fehler gezählt", wz.sd.status == "geladen" and wz.sd.fehler == 12,
    tostring(wz.sd.fehler))
end

-- 6e. Standard-Layout für alle Modelle (0.7.0): S1 nur Standard, S2 Modelldatei gewinnt, S3 Wahl gewinnt, S4 .funke.lua je Modell
do
  loesche()
  local ST = S.PFAD .. "Standard.glider.lua"
  local g = io.open(ST, "w") g:write("return { format = 1, einstellungen = { start_h = 22 } }") g:close()
  local w1 = lauf()
  fall("S1 nur Standard: geladen, studioWahl standard", w1.sd.status == "geladen" and w1.sd.wahl == "standard"
    and w1.sd.quelle == ST and w1.sd.ueber.startH == 22)
  kopiere(HIER .. "leer.lua", S.PFAD .. KENNUNG .. ".glider.lua")
  local w2 = lauf()
  fall("S2 Modelldatei gewinnt vor Standard", w2.sd.wahl == "auto" and w2.sd.quelle ~= ST and w2.sd.ueber.startH == F.standard().startH)
  local w3 = { cfg = F.standard(), sp = 1, version = "0.7.0", fenster = {}, studioWahl = ST }
  w3 = lauf(w3)
  fall("S3 Wahl im Menü gewinnt", w3.sd.wahl == "menue" and w3.sd.quelle == ST)
  os.remove(S.PFAD .. KENNUNG .. ".glider.lua")
  local w4 = lauf()
  w4.cfg = {} for k, v in pairs(w4.sd.ueber) do w4.cfg[k] = v end
  w4.cfg.kap = 1500
  schreib(w4, S, F, assert(loadfile("studiolad.lua"))(), KENNUNG)
  local f4 = io.open(S.PFAD .. KENNUNG .. ".glider.funke.lua", "r")
  fall("S4 Änderung am Sender nur im Modell (.funke.lua des Modells)", f4 ~= nil and io.open(S.PFAD .. "Standard.glider.funke.lua") == nil)
  if f4 then f4:close() end
  os.remove(ST)
end

-- 7. Kennung (2.1)
fall("Kennung nach 2.1", S.kennung("Extra 330 6S") == "Extra_330_6S" and S.kennung("Möwe") == "M__we"
  and S.kennung("Goblin 700 (neu)") == "Goblin_700__neu_" and S.kennung("") == "modell"
  and #S.kennung(string.rep("x", 40)) == 32)

loesche()
os.execute('rmdir "' .. TMP .. '"')
print(string.format("Höchste Befehlszahl je Schritt: %d (Ziel unter 5'000), Speicher in der Spitze: %.0f KB", MAXB, MAXM))
if MAXB >= 5000 then fehler = fehler + 1 end
print(fehler == 0 and "ERGEBNIS: kein Fehler" or ("ERGEBNIS: " .. fehler .. " Fehler"))
os.exit(fehler == 0 and 0 or 1)
