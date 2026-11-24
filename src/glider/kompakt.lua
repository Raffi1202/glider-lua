-- Glider: Kompaktansicht für das Ethos-Layout «ein Widget mit Kopf- und Fussleiste» (gemessen 784 x 316 bei
-- X20/X18RS, 630 x 258 bei X14, 472 x 210 bei X18 und Twin X Lite). Der Kern lädt diese Datei statt der Seiten,
-- sobald das Fenster flacher als 1:2 ist. Modellname und Senderakku zeigt Ethos in seiner Kopfzeile.
-- Aufbau: oben eine schmale Leiste (Flugzeit, Zustand, Phase, Motor, Empfang; Warnungen und Hinweise ersetzen die
-- Pillen), darunter 4 Ringe (Vario, Höhe, Antriebsakku, Empfängerakku) und 8 Felder in zwei Reihen.
-- Zeichnet nur: Werte aus w.v, w.flug, w.ak, w.th, Texte aus w.T. Masse vom Entwurf 784 x 316, verkleinert mit L.s.
local K = {}
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local function farbe(C, st, normal)
  if st == 2 then return C.rot elseif st == 1 then return C.orange end
  return normal
end

local function einh(t, sonst)
  if t == nil or t == "" then return sonst end
  return t
end

local function steig(Z, x)
  if x == nil then return nil end
  return (x >= 0 and "+" or "-") .. Z.zahl(abs(x), 1)
end

-- Zeit in der aktuellen Flugphase
local function phasenZeit(w)
  local f, pn = w.flug, w.phaseName
  if not (f and pn) then return nil end
  for _, p in ipairs(f.ph or {}) do
    if p[1] == pn then return p[2] end
  end
  return nil
end

-- Schmale Leiste oben
local function leiste(w, L, Z, sb)
  local C, s, W, T, v, f = Z.C, L.s, L.W, w.T, w.v, w.flug
  Z.rechteck(0, 0, W, sb, C.panel)
  local x = 8 * s
  -- Flugzeit links
  local zt = Z.zeit(f and f.t or 0)
  Z.text(L, x, sb / 2, zt, 22, C.text, LEFT)
  x = x + Z.breite(L, zt, 22) + 12 * s
  -- Empfang rechts
  local rt = v.rssi and ((L.klein and "" or (T.empfang .. " ")) .. string.format("%.0f %%", v.rssi)) or nil
  local st = (v.st or {}).rssi
  local rb = 0
  if rt then
    rb = Z.breite(L, rt, 16)
    Z.text(L, W - 8 * s, sb / 2, rt, 16, farbe(C, st, C.text), RIGHT)
  end
  local rest = W - 8 * s - rb - 12 * s                  -- rechte Kante für Pillen und Meldung
  local ph = max(18, floor(sb - 10 * s))
  local py = floor((sb - ph) / 2)
  local gr = ph * 0.92 / (1.25 * s)
  -- Warnung oder Hinweis statt der Pillen
  local mt, mf, tf
  if (w.nAktiv or 0) > 0 then
    mt, mf, tf = w.meldText, w.stufe == 2 and C.rot or C.orange, C.dunkel
  elseif w.hinweis then
    mt, mf, tf = w.hinweis, C.blau, C.weiss
  end
  if mt and rest - x > 40 then
    Z.rund(x, py, rest - x, ph, ph / 2, mf)
    Z.text(L, x + (rest - x) / 2, sb / 2, mt, 16, tf, CENTERED, rest - x - 12 * s)
    return
  end
  local ab = max(4, floor(6 * s))
  local function pille(t, fb, voll, mind)
    local b = max(mind or 0, Z.breite(L, t, gr) + ph * 0.8)
    if x + b > rest then b = rest - x end
    if b < ph * 1.5 then return end
    Z.pille(L, x, py, b, ph, t, fb, voll, gr)
    x = x + b + ab
  end
  local zf = ({ ok = C.gruen, warnung = C.orange, alarm = C.rot })[w.zustand] or C.grau
  pille(T[w.zustand] or "", zf, not (w.stufe == 2 and w.blink), 90 * s)
  if v.motor then
    local k = L.klasse ~= "L" and "K" or ""
    if v.motor == "laeuft" then pille(T["motorLaeuft" .. k], C.blau, true)
    elseif v.motor == "aus" then pille(T["motorAus" .. k], C.gruen, false)
    else pille(T["motorEin" .. k], C.orange, false) end
  end
  local pn = w.phaseAnz or w.phaseName
  if pn then pille(Z.kurz(pn, L.klasse == "L" and 18 or 10), C.hblau, false) end
end

-- Ring: Titel oben, Bogen von 225° bis 135° (unten offen), Wert in der Mitte, zweite Zeile darunter.
-- anteil 0..1 (Bogen ab links unten) oder mitte = -1..1 (Vario: ab oben nach links oder rechts).
local function ring(L, Z, x, y, b, h, titel, wert, zweit, fw, anteil, mitte, fb, rand)
  local C, s = Z.C, L.s
  Z.platte(x, y, b, h, rand or C.rand, C.panel, rand and max(2, floor(3 * s)) or 1)
  local th = max(16 * s, 15)                        -- kleinste Ethos-Schrift schrumpft nicht weiter
  Z.text(L, x + b / 2, y + 4 * s + th / 2, titel, 13, C.dim, CENTERED, b - 10 * s)
  local oben = y + 6 * s + th
  local r2 = min(b * 0.36, (y + h - oben - 4 * s) * 0.56)
  local d = max(5, floor(r2 * 0.16))
  local r1 = r2 - d
  local cx, cy = x + b / 2, oben + r2 + 2 * s
  Z.bogen(cx, cy, r1, r2, 225, 495, C.rand)
  if anteil then
    local a = max(0, min(1, anteil))
    if a > 0 then Z.bogen(cx, cy, r1, r2, 225, 225 + 270 * a, fb) end
  elseif mitte then
    local a = max(-1, min(1, mitte)) * 135
    if a > 0 then Z.bogen(cx, cy, r1, r2, 360, 360 + a, fb)
    elseif a < 0 then Z.bogen(cx, cy, r1, r2, 360 + a, 360, fb) end
    Z.rechteck(cx - 1, cy - r2 - 2 * s, 2, d + 4 * s, C.text)  -- Nullmarke oben
  end
  Z.wert(L, cx, cy - 2 * s, wert, 24, fw, CENTERED, r1 * 1.8)
  if zweit then Z.text(L, cx, cy + r1 * 0.55, zweit, 12, C.dim, CENTERED, r1 * 1.6) end
end

-- Feld: Beschriftung oben, Wert darunter
local function feld(L, Z, x, y, b, h, titel, wert, fw)
  local C, s = Z.C, L.s
  Z.platte(x, y, b, h, C.rand, C.panel, 1)
  Z.text(L, x + b / 2, y + h * 0.3, titel, 13, C.dim, CENTERED, b - 10 * s)
  Z.wert(L, x + b / 2, y + h * 0.68, wert, 22, fw or C.text, CENTERED, b - 10 * s)
end

function K.zeichne(w, L, Z)
  local C, W, H, s, T, v, f, c = Z.C, L.W, L.H, L.s, w.T, w.v, w.flug, w.cfg
  local st = v.st or {}
  local gp = max(3, floor(5 * s))
  local sb = floor(36 * s)
  leiste(w, L, Z, sb)

  -- Ringe
  local y1 = sb + gp
  local hr = floor((H - y1 - 3 * gp) * 0.52)
  local br = (W - 5 * gp) / 4
  local eh = einh(w.eh.h, "m")
  -- 1 Vario um die Mitte
  local sk = c.skala or 5
  ring(L, Z, gp, y1, br, hr, T.kVario, steig(Z, v.vs), "m/s",
    (v.vs and v.vs > 0.2) and C.gruen or C.text, nil, v.vs and v.vs / sk or 0,
    (v.vs and v.vs >= 0) and C.gruen or C.hblau)
  -- 2 Höhe: Bogen bis zum Höhenalarm, sonst bis zum nächsten Hunderter über der höchsten Höhe
  local ref = w.g and w.g.hAlarm
  if not ref then ref = math.ceil(max(f and f.hmax or 0, v.h or 0, 1) / 100) * 100 end   -- nächster Hunderter
  if ref < 10 then ref = 10 end
  ring(L, Z, 2 * gp + br, y1, br, hr, T.kHoehe, v.h and Z.tausend(v.h), eh, farbe(C, st.h, C.text),
    v.h and v.h / ref or 0, nil, farbe(C, st.h, C.hblau), st.h == 2 and C.rot or nil)
  -- 3 Antriebsakku; reiner Segler ohne Antriebsakku: Empfang
  local ia = v.antrieb
  if ia or c.modell == 2 then
    local a = ia and w.ak[ia] or {}
    local sa = ia and st["a" .. ia]
    ring(L, Z, 3 * gp + 2 * br, y1, br, hr, T.kAntrieb, a.p and string.format("%.0f %%", a.p),
      a.summe and (Z.zahl(a.summe, 1) .. " V"), farbe(C, sa, C.text), a.p and a.p / 100 or 0, nil,
      farbe(C, sa, C.gruen), sa == 2 and C.rot or nil)
  else
    ring(L, Z, 3 * gp + 2 * br, y1, br, hr, T.kLink, v.rssi and string.format("%.0f %%", v.rssi),
      v.zweiBand and ((v.rssi24 and string.format("%.0f", v.rssi24) or "-") .. " / " .. (v.rssi900 and string.format("%.0f", v.rssi900) or "-")) or nil,
      farbe(C, st.rssi, C.text), v.rssi and v.rssi / 100 or 0, nil, farbe(C, st.rssi, C.gruen),
      st.rssi == 2 and C.rot or nil)
  end
  -- 4 Empfängerakku
  local ie = v.empf
  local ae = ie and w.ak[ie] or {}
  local se = ie and st["a" .. ie]
  ring(L, Z, 4 * gp + 3 * br, y1, br, hr, T.kEmpf, ae.summe and (Z.zahl(ae.summe, 2) .. " V"),
    ae.p and string.format("%.0f %%", ae.p), farbe(C, se, C.text), ae.p and ae.p / 100 or 0, nil,
    farbe(C, se, C.gruen), se == 2 and C.rot or nil)

  -- Felder: zwei Reihen zu vier
  local y2 = y1 + hr + gp
  local hf = floor((H - y2 - 2 * gp) / 2)
  local pn = w.phaseName or w.phaseText
  local pz = phasenZeit(w)
  local th = w.th
  local felder = {
    { pn and Z.kurz(pn, max(8, floor(br / (8 * s)))) or T.phase, pz and Z.zeit(pz) },
    { T.kAusklink, f and f.ak and (Z.tausend(f.ak) .. " " .. eh) },
    { T.kHoechst, f and f.hmax and (Z.tausend(f.hmax) .. " " .. eh) },
    { T.kMittel, w.vMittel and (steig(Z, w.vMittel) .. " m/s"), w.vMittel and w.vMittel > 0.2 and C.gruen },
    { T.kSpeed, v.speed and (Z.tausend(v.speed) .. " " .. einh(w.eh.speed, "km/h")) },
    { T.kStrom, v.strom and (Z.zahl(v.strom, 1) .. " A") },
    { T.kMah, v.mah and (Z.tausend(v.mah) .. " mAh") },
    { T.kThermik, th and th.gew and ((th.gew >= 0 and "+" or "-") .. Z.tausend(abs(th.gew)) .. " " .. eh ..
      (th.dauer and ("  " .. Z.zeit(th.dauer)) or "")), th and th.an and C.gruen },
  }
  for i, e in ipairs(felder) do
    local sp, zl = (i - 1) % 4, (i - 1) // 4
    feld(L, Z, gp + sp * (br + gp), y2 + zl * (hf + gp), br, hf, e[1], e[2], e[3])
  end
end

-- nur die Leiste oben (über einer Studio-Ansicht, deren Fläche oben reserviert ist)
function K.leiste(w, L, Z) leiste(w, L, Z, floor(36 * L.s)) end

return K
