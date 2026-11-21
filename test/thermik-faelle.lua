-- Feste Fälle für den Thermik-Gewinn (K._thermik aus kern.lua), auf dem Mac ohne Simulator.
-- Aufruf im Skriptordner: cd src/glider && /opt/homebrew/opt/lua@5.4/bin/lua ../../test/thermik-faelle.lua
-- Profil = Vario in m/s je Sekunde (oder je «schritt» s); Takt 0,1 s; Schwelle 1,0 m/s während 3 s (Werkwerte).
local K = assert(loadfile("kern.lua"))()
local thermik = assert(K._thermik, "K._thermik fehlt")
local fehler = 0

local function lauf(profil, motorAb, schritt)
  local w = { g = { thAb = 1.0 }, T = { thermik = "THERMIK %s" }, sp = 1 }
  w.ansagen = {}
  local c = { thS = 3, thRuhe = 30, ansTh = false }
  local h, now, dt = 100, 0, 0.1
  local je = math.floor((schritt or 1) / dt + 0.5)       -- Takte je Profilwert
  for k = 1, #profil * je do
    local vs = profil[(k - 1) // je + 1]
    now = now + dt
    h = h + vs * dt
    local v = { vs = vs, laeuft = motorAb ~= nil and now >= motorAb }
    local ok, e = pcall(thermik, w, c, v, h, now, dt)
    if not ok then return nil, e end
  end
  return w.th
end

local function reihe(...)
  local p = {}
  for _, t in ipairs({ ... }) do for _ = 1, t[2] do p[#p + 1] = t[1] end end
  return p
end

local function fall(titel, profil, an, gew, dauer, motorAb, schritt)
  local th, e = lauf(profil, motorAb, schritt)
  local gut = th ~= nil and th.an == an and math.abs((th.gew or -999) - gew) < 0.6 and math.abs((th.dauer or -999) - dauer) < 0.6
  if th == nil and gew == nil then gut = e == nil end
  print((gut and "OK    " or "FEHLER") .. "  " .. titel .. (th and string.format("  (an=%s gew=%.1f dauer=%.1f)",
    tostring(th.an), th.gew or -1, th.dauer or -1) or (e and ("  " .. tostring(e)) or "  (keine Thermik)")))
  if not gut then fehler = fehler + 1 end
end

-- 30 s Gleiten, 5 s +1,5, 1 s Delle +0,6, 40 s +1,5: Gewinn ab Beginn des Steigens (5*1,5 + 0,6 + 40*1,5 = 68,1 m, 46 s)
fall("Delle nach Gleitflug setzt nichts zurück", reihe({ -0.8, 30 }, { 1.5, 5 }, { 0.6, 1 }, { 1.5, 40 }), true, 68.1, 46)
-- 30 s Gleiten, 49 s +1,5, 1 s Delle, 30 s -0,8: höchster Gewinn bleibt stehen (73,5 m nach 49 s, Delle +0,6 = 74,1 m bei 50 s)
fall("Gewinn bleibt nach dem Ende stehen", reihe({ -0.8, 30 }, { 1.5, 49 }, { 0.6, 1 }, { -0.8, 30 }), false, 74.1, 50)
-- kurz unter 0 (5 s) mitten in der Thermik: läuft weiter
fall("5 s Sinken beendet nicht", reihe({ 1.5, 20 }, { -0.5, 5 }, { 1.5, 10 }), true, 30 - 2.5 + 15, 35)
-- 10 s Sinken beendet
fall("10 s Sinken beendet", reihe({ 1.5, 20 }, { -0.5, 12 }), false, 30, 20)
-- Motor läuft: Ende
fall("Motor beendet", reihe({ 1.5, 20 }, { 1.5, 10 }), false, 30, 20, 20.05)
-- nur 2 s Steigen: keine Thermik
fall("2 s Steigen ist keine Thermik", reihe({ -0.5, 10 }, { 1.5, 2 }, { -0.5, 10 }), nil, nil, nil)
-- Delle in den ersten 3 s (0,5 s +0,6): Anfang bleibt (2*1,5 + 0,5*0,6 + 40*1,5 = 63,3 m, 42,5 s)
fall("Delle vor der Erkennung setzt nichts zurück", (function() local p = {} for i = 1, 20 do p[#p + 1] = 1.5 end
  for i = 1, 5 do p[#p + 1] = 0.6 end for i = 1, 400 do p[#p + 1] = 1.5 end return p end)(), true, 63.3, 42.5, nil, 0.1)
-- Rauschen um schwaches Sinken (-0,3 +/- 0,5) nach 30 s Steigen: Thermik endet
fall("Rauschen um schwaches Sinken beendet", (function() local p = reihe({ 1.5, 30 }) for i = 1, 60 do
  p[#p + 1] = (i % 2 == 0) and 0.2 or -0.8 end return p end)(), false, 45, 30)
-- erster Aufruf mit schwachem Steigen unter der Schwelle (0 < vs < 1,0): kein Fehler (Fehler in 0.2.0)
fall("erster Aufruf mit schwachem Steigen", reihe({ 0.5, 5 }), nil, nil, nil)
-- zweite Thermik ersetzt die erste
fall("zweite Thermik beginnt neu", reihe({ 1.5, 10 }, { -1, 15 }, { 2.0, 10 }), true, 20, 10)

print(fehler == 0 and "ERGEBNIS: kein Fehler" or ("ERGEBNIS: " .. fehler .. " Fehler"))
os.exit(fehler == 0 and 0 or 1)
