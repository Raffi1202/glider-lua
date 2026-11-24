-- Glider: Seite 1 «Flug». Oben drei Kacheln (im Menü wählbar: Vario, Höhe, Flugzeit, Antriebsakku, Empfängerakku,
-- Empfang, Geschwindigkeit), in der Mitte der Verlauf (Vario oder Höhe, 60 Säulen), unten eine Leiste mit bis zu
-- drei Werten. Zeichnet nur: Werte aus w.v, w.flug, w.ak, Texte aus w.T.
local S = {}
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local function farbe(Z, st)
  if st == 2 then return Z.C.rot elseif st == 1 then return Z.C.orange end
  return Z.C.text
end

-- Steigen als Text mit Vorzeichen, z. B. «+2,4»
local function steig(Z, x)
  if x == nil then return nil end
  return (x >= 0 and "+" or "-") .. Z.zahl(abs(x), 1)
end

local function einh(t, sonst)
  if t == nil or t == "" then return sonst end
  return t
end

-- Höhengewinn der aktuellen oder letzten Thermik als Text, z. B. «+85 m»; nil = keine Thermik in diesem Flug.
local function gewinn(w, Z)
  local th = w.th
  if not (th and th.gew) then return nil end
  return (th.gew >= 0 and "+" or "-") .. Z.tausend(abs(th.gew)) .. " " .. einh(w.eh.h, "m")
end
S.gewinn = gewinn

-- Zeit in der aktuellen Flugphase
local function phasenZeit(w)
  local f, pn = w.flug, w.phaseName
  if not (f and pn) then return nil end
  for _, p in ipairs(f.ph or {}) do
    if p[1] == pn then return p[2] end
  end
  return nil
end

local function kachel(w, L, Z, typ, x, y, b, h)
  local C, s, T, v, f = Z.C, L.s, w.T, w.v, w.flug
  local st = v.st or {}
  local gross = 46
  local cx, cy = x + b / 2, y + h * 0.40
  local z1, z2 = y + h - 46 * s, y + h - 20 * s
  local kl = L.klein
  if typ == 1 then                                         -- Vario mit Balken
    Z.kasten(L, x, y, b, h, T.vario)
    local bb = max(8, 16 * s)
    local bx, by, bh = x + 14 * s, y + 32 * s, h - 46 * s
    local sk = (w.cfg.skala or 5)
    local mitte = by + bh / 2
    Z.feld(bx, by, bb, bh, 3, C.rand, C.dunkel, 1)
    if v.vs then
      local a = max(-1, min(1, v.vs / sk))
      local hh = abs(a) * (bh / 2 - 2)
      if hh >= 1 then Z.rechteck(bx + 2, a >= 0 and mitte - hh or mitte, bb - 4, hh, a >= 0 and C.gruen or C.hblau) end
    end
    Z.rechteck(bx - 3 * s, mitte - 1, bb + 6 * s, 2, C.text)
    local rx = bx + bb
    local rb = b - (rx - x)
    local vx = rx + rb / 2
    local t = v.vs and (steig(Z, v.vs)) or nil
    Z.wert(L, vx, cy, t, gross, (v.vs and v.vs > 0.2) and C.gruen or C.text, CENTERED, rb - 12 * s)
    Z.text(L, vx, cy + 34 * s, "m/s", 15, C.dim, CENTERED)
    Z.zeile(L, rx, z1, rb - 4 * s, kl and T.mittelK or T.mittel, w.vMittel and (steig(Z, w.vMittel) .. " m/s"))
    Z.zeile(L, rx, z2, rb - 4 * s, T.hoechst, f and f.vmax and (steig(Z, f.vmax) .. " m/s"))
  elseif typ == 2 then                                     -- Höhe
    Z.kasten(L, x, y, b, h, T.hoehe, nil, st.h == 2 and C.rot or nil)
    local e = " " .. einh(w.eh.h, "m")
    Z.wert(L, cx, cy, v.h and (Z.tausend(v.h) .. e), gross, farbe(Z, st.h), CENTERED, b - 24 * s)
    Z.zeile(L, x, z1, b, T.hoechst, f and f.hmax and (Z.tausend(f.hmax) .. e))
    Z.zeile(L, x, z2, b, kl and T.ausklinkK or T.ausklink, f and f.ak and (Z.tausend(f.ak) .. e))
  elseif typ == 3 then                                     -- Flugzeit
    Z.kasten(L, x, y, b, h, T.flugzeit)
    Z.text(L, cx, cy, Z.zeit(f and f.t or 0), gross, C.text, CENTERED, b - 24 * s)
    local pn = w.phaseName or w.phaseText
    Z.zeile(L, x, z1, b, pn and (kl and Z.kurz(pn, 9) or (L.klasse == "M" and Z.kurz(pn, 13) or (T.phase .. " " .. Z.kurz(pn, 18)))) or T.phase, Z.zeit(phasenZeit(w)))
    if w.cfg.modell == 2 then
      Z.zeile(L, x, z2, b, T.motor, Z.zeit(f and f.mot or 0))
    else
      Z.zeile(L, x, z2, b, T.flugNr, tostring(#w.liste + 1))
    end
  elseif typ == 4 then                                     -- Antriebsakku
    local i = v.antrieb
    local a = i and w.ak[i] or {}
    local sa = i and st["a" .. i]
    Z.kasten(L, x, y, b, h, T.antrieb, nil, sa == 2 and C.rot or nil)
    Z.wert(L, cx, cy, a.p and string.format("%.0f %%", a.p), gross, farbe(Z, sa), CENTERED, b - 24 * s)
    Z.zeile(L, x, z1, b, "", a.summe and (Z.zahl(a.summe, 1) .. " V"))
    Z.zeile(L, x, z2, b, T.zelleMittel, a.tief and (Z.zahl(a.tief, 2) .. " V"))
  elseif typ == 5 then                                     -- Empfängerakku
    local i = v.empf
    local a = i and w.ak[i] or {}
    local sa = i and st["a" .. i]
    Z.kasten(L, x, y, b, h, T.empfAkku, nil, sa == 2 and C.rot or nil)
    Z.wert(L, cx, cy, a.summe and (Z.zahl(a.summe, 2) .. " V"), gross, farbe(Z, sa), CENTERED, b - 24 * s)
    Z.zeile(L, x, z1, b, "", a.p and string.format("%.0f %%", a.p))
    Z.zeile(L, x, z2, b, T.tiefst, i and w.akMin[i] and (Z.zahl(w.akMin[i], 2) .. " V"))
  elseif typ == 6 then                                     -- Empfang
    Z.kasten(L, x, y, b, h, T.link, nil, st.rssi == 2 and C.rot or nil)
    Z.wert(L, cx, cy, v.rssi and string.format("%.0f %%", v.rssi), gross, farbe(Z, st.rssi), CENTERED, b - 24 * s)
    if v.zweiBand then                                     -- 0.7.2: beide Bänder (besseres Band gross)
      Z.zeile(L, x, z1, b, T.zweiBand, (v.rssi24 and string.format("%.0f", v.rssi24) or "-") .. " / " ..
        (v.rssi900 and string.format("%.0f", v.rssi900) or "-") .. " %")
    end
    Z.zeile(L, x, z2, b, T.tiefst, w.rssiMin and string.format("%.0f %%", w.rssiMin))
  elseif typ == 8 then                                     -- Höhengewinn Thermik
    local th = w.th
    Z.kasten(L, x, y, b, h, T.thermikT)
    Z.wert(L, cx, cy, gewinn(w, Z), gross, (th and th.an) and C.gruen or C.text, CENTERED, b - 24 * s)
    Z.zeile(L, x, z1, b, T.thDauer, th and th.dauer and Z.zeit(th.dauer))
    Z.zeile(L, x, z2, b, th and (th.an and T.thJetzt or T.thLetzte) or "", "")
  else                                                     -- Geschwindigkeit
    Z.kasten(L, x, y, b, h, T.speed)
    local e = " " .. einh(w.eh.speed, "km/h")
    Z.wert(L, cx, cy, v.speed and (Z.tausend(v.speed) .. e), gross, C.text, CENTERED, b - 24 * s)
    Z.zeile(L, x, z2, b, T.hoechst, w.speedMax and (Z.tausend(w.speedMax) .. e))
  end
end

-- Verlauf: 60 Säulen, Vario um die Nulllinie (grün steigen, blau sinken), Höhe ab 0 nach oben.
local function verlauf(w, L, Z, x, y, b, h)
  local C, s, T, c = Z.C, L.s, w.T, w.cfg
  local art = c.verlauf or 1
  local titel = string.format(art == 1 and T.verlaufV or T.verlaufH, tostring(c.verlaufMin or 2))
  Z.feld(x, y, b, h, 10 * s, C.rand, C.panel, 1)
  Z.text(L, x + 12 * s, y + 15 * s, titel, 14, C.dim, LEFT, b * 0.5)
  local th = w.g.thAb or 1
  if art == 1 and not L.klein then
    Z.text(L, x + b - 12 * s, y + 15 * s, string.format(T.thLinie, Z.zahl(th, 1)), 14, C.dim, RIGHT, b * 0.45)
  end
  local px, pw = x + 40 * s, b - 52 * s
  local py, ph = y + 28 * s, h - 34 * s
  if ph < 10 then return end
  local vl = w.vl or {}
  local n = 60
  local sw = pw / n
  local fl = 12
  if art == 1 then
    local sk = c.skala or 5
    local pm = py + ph / 2
    local f = ph / 2 / sk
    Z.text(L, px - 8 * s, py + 4, "+" .. sk, fl, C.dim, RIGHT)
    Z.text(L, px - 8 * s, pm, "0", fl, C.dim, RIGHT)
    Z.text(L, px - 8 * s, py + ph - 4, "-" .. sk, fl, C.dim, RIGHT)
    Z.rechteck(px, pm, pw, 1, C.grau)
    for i, v in ipairs(vl) do
      if v then
        local vv = max(-sk, min(sk, v))
        local hh = max(1, abs(vv) * f)
        Z.rechteck(px + (i - 1) * sw + sw * 0.15, vv >= 0 and pm - hh or pm, max(1, sw * 0.7), hh, vv >= 0 and C.gruen or C.hblau)
      end
    end
    -- Thermik-Schwelle gestrichelt
    local ty = floor(pm - th * f)
    if th < sk then
      local d = max(4, floor(6 * s))
      local xx = px
      while xx < px + pw do
        Z.rechteck(xx, ty, min(d, px + pw - xx), max(1, floor(1.5 * s)), C.blau)
        xx = xx + d + floor(4 * s) + 1
      end
    end
  else
    local hm = 10
    for _, v in ipairs(vl) do if v and v > hm then hm = v end end
    hm = math.ceil(hm / 50) * 50
    Z.text(L, px - 8 * s, py + 4, Z.tausend(hm), fl, C.dim, RIGHT)
    Z.text(L, px - 8 * s, py + ph - 4, "0", fl, C.dim, RIGHT)
    Z.rechteck(px, py + ph, pw, 1, C.grau)
    for i, v in ipairs(vl) do
      if v then
        local hh = max(1, max(0, v) / hm * ph)
        Z.rechteck(px + (i - 1) * sw + sw * 0.15, py + ph - hh, max(1, sw * 0.7), hh, C.hblau)
      end
    end
  end
  if #vl == 0 then Z.strich(L, px + pw / 2, py + ph / 2 - 14 * s, 30, C.grau, CENTERED) end
end

-- Ein Eintrag der Leiste unten: Beschriftung, Text, Stufe. nil = Eintrag weglassen.
local function leistenWert(w, L, Z, typ)
  local T, v, f = w.T, w.v, w.flug
  local st = v.st or {}
  if typ == 1 then return T.lVario, v.vs and (steig(Z, v.vs) .. " m/s"), nil
  elseif typ == 2 then return T.lHoehe, v.h and (Z.tausend(v.h) .. " " .. einh(w.eh.h, "m")), st.h
  elseif typ == 3 then return T.lZeit, Z.zeit(f and f.t or 0), nil
  elseif typ == 4 then
    local i = v.antrieb
    if w.cfg.modell ~= 2 and not i then return nil end
    local a = i and w.ak[i] or {}
    local t = a.p and string.format("%.0f %%", a.p)
    if t and a.summe and not L.klein then t = t .. " / " .. Z.zahl(a.summe, 1) .. " V" end
    return T.lAntrieb, t, i and st["a" .. i]
  elseif typ == 5 then
    local i = v.empf
    local a = i and w.ak[i] or {}
    local t = a.summe and (Z.zahl(a.summe, 1) .. " V")
    if t and a.p and w.cfg.modell ~= 2 and not L.klein then t = t .. " / " .. string.format("%.0f %%", a.p) end
    return T.lEmpf, t, i and st["a" .. i]
  elseif typ == 6 then return T.lLink, v.rssi and string.format("%.0f %%", v.rssi), st.rssi
  elseif typ == 7 then return T.lSpeed, v.speed and (Z.tausend(v.speed) .. " " .. einh(w.eh.speed, "km/h")), nil
  elseif typ == 8 then return T.lThermik, gewinn(w, Z), nil
  end
  return nil
end


function S.zeichne(w, L, Z)
  local C, W, H, gp, s = Z.C, L.W, L.H, L.gp, L.s
  local c = w.cfg
  local y0 = L.y0
  local hu = max(52 * s, 30)
  local yu = H - gp - hu
  local mitV = (c.verlauf or 1) ~= 0
  local frei = yu - y0 - (mitV and 2 or 1) * gp
  local ha = mitV and floor(frei * 0.6) or frei
  local hv = frei - ha
  local b1 = (W - 4 * gp) * 0.38
  local b2 = (W - 4 * gp) * 0.31
  kachel(w, L, Z, c.k1 or 1, gp, y0, b1, ha)
  kachel(w, L, Z, c.k2 or 2, 2 * gp + b1, y0, b2, ha)
  kachel(w, L, Z, c.k3 or 3, 3 * gp + b1 + b2, y0, b2, ha)
  if mitV then verlauf(w, L, Z, gp, y0 + ha + gp, W - 2 * gp, hv) end

  -- Leiste unten
  local e = {}
  for i = 1, 3 do
    local typ = c["l" .. i]
    if typ and typ > 0 then
      local l, t, st = leistenWert(w, L, Z, typ)
      if l then e[#e + 1] = { l, t, st } end
    end
  end
  Z.feld(gp, yu, W - 2 * gp, hu, 10 * s, C.rand, C.panel, 1)
  if #e == 0 then return end
  local cb = (W - 2 * gp) / #e
  for i, x in ipairs(e) do
    local cx = gp + cb * (i - 1) + cb / 2
    if i > 1 then Z.rechteck(gp + cb * (i - 1), yu + 8 * s, 1, hu - 16 * s, C.rand) end
    Z.text(L, cx, yu + hu * 0.27, x[1], 13, C.dim, CENTERED, cb - 8 * s)
    Z.wert(L, cx, yu + hu * 0.66, x[2], 24, farbe(Z, x[3]), CENTERED, cb - 8 * s)
  end
end

return S
