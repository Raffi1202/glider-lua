-- Glider: Seite 3 «Flüge». Links GESAMT (aus den gespeicherten Flügen und dem laufenden Flug), rechts die Flugliste
-- (neueste oben, laufender Flug zuoberst), unten Hinweis und Knopf «ÜBERSICHT ZURÜCKSETZEN» (fragt immer nach).
-- Antippen eines Flugs öffnet das Detailfenster (S.detail) mit der Zeit je Flugphase.
-- Die Seite zeichnet nur; Werte aus w.liste und w.flug, Texte aus w.T. Fehlender Wert = grauer Strich.
local S = {}
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

-- Zahl mit Vorzeichen (+4,2 / -3,1)
local function vz(Z, x, d)
  local t = Z.zahl(abs(x), d)
  if x > 0 then return "+" .. t elseif x < 0 then return "-" .. t end
  return t
end

-- Feld mit Titel links und Zusatz rechts (wie im Konzept)
local function feld(L, Z, x, y, b, h, titel, rechts)
  local C, s = Z.C, L.s
  Z.kasten(L, x, y, b, h)
  local tb = Z.text(L, x + 12 * s, y + 15 * s, titel, 14, C.dim, LEFT, rechts and b * 0.5 or b - 24 * s)
  if rechts then Z.text(L, x + b - 12 * s, y + 15 * s, rechts, 14, C.dim, RIGHT, max(10, b - tb - 36 * s)) end
end

-- Pfeil-Knopf zum Blättern der Liste (Dreieck statt Text, in allen Sprachen gleich)
local function pfeil(w, L, Z, id, x, y, b, h, hoch, aktiv)
  local C = Z.C
  local f = aktiv and C.text or C.grau
  Z.knopf(w, L, id, x, y, b, h, "", f, false, 14)
  local g = max(4, floor(min(b, h) * 0.18))
  local cx, cy = floor(x + b / 2), floor(y + h / 2)
  lcd.color(f)
  if hoch then
    lcd.drawFilledTriangle(cx - g, cy + g // 2, cx + g, cy + g // 2, cx, cy - g)
  else
    lcd.drawFilledTriangle(cx - g, cy - g // 2, cx + g, cy - g // 2, cx, cy + g)
  end
end

function S.zeichne(w, L, Z)
  local C, W, H, gp, s, T, kl = Z.C, L.W, L.H, L.gp, L.s, w.T, L.klein
  local liste, lf = w.liste or {}, w.flug
  local y0 = L.y0
  local kh = max(40 * s, L.tipp)
  local h = H - y0 - kh - 2 * gp
  local bl = (W - 3 * gp) * 0.55
  local x2, b2 = 2 * gp + bl, W - 3 * gp - bl

  -- Gesamtwerte aus allen Flügen (gespeicherte und laufender)
  local anz, zeit, hmax, akmax, steig, sink, lang, mot = 0, 0, nil, nil, nil, nil, nil, 0
  local function dazu(f)
    anz = anz + 1
    zeit = zeit + (f.t or 0)
    mot = mot + (f.mot or 0)
    if f.hmax and (hmax == nil or f.hmax > hmax) then hmax = f.hmax end
    if f.ak and (akmax == nil or f.ak > akmax) then akmax = f.ak end
    if f.vmax and (steig == nil or f.vmax > steig) then steig = f.vmax end
    if f.vmin and (sink == nil or f.vmin < sink) then sink = f.vmin end
    if f.t and (lang == nil or f.t > lang) then lang = f.t end
  end
  for _, f in ipairs(liste) do dazu(f) end
  if lf then dazu(lf) end
  local da = anz > 0

  -- links: GESAMT (zwei Spalten, vier Reihen)
  feld(L, Z, gp, y0, bl, h, T.gesamt)
  local G = {
    { T.gFluege, string.format("%.0f", anz) },
    { kl and T.gZeitK or T.gZeit, da and Z.zeit(zeit) or nil },
    { T.gHoehe, hmax and (Z.zahl(hmax, 0) .. " m") },
    { kl and T.gAkK or T.gAk, akmax and (Z.zahl(akmax, 0) .. " m") },
    { T.gSteig, steig and (vz(Z, steig, 1) .. " m/s") },
    { T.gSink, sink and (vz(Z, sink, 1) .. " m/s") },
    { T.gLang, lang and Z.zeit(lang) },
    { T.gMotor, da and Z.zeit(mot) or nil },
  }
  local rh = (h - 30 * s) / 4
  local sb = bl / 2 - 16 * s
  for i, e in ipairs(G) do
    local k = i - 1
    local cx = gp + 12 * s + (k % 2) * bl / 2
    local cy = y0 + 30 * s + (k // 2) * rh
    Z.text(L, cx, cy + rh * 0.2, e[1], 13, C.dim, LEFT, sb)
    Z.wert(L, cx, cy + rh * 0.58, e[2], 26, C.text, LEFT, sb)
  end

  -- rechts: FLÜGE (neueste oben, laufender Flug zuoberst)
  feld(L, Z, x2, y0, b2, h, T.fluege, (not kl and da) and T.antippen or nil)
  local zeilen = {}
  if lf then zeilen[1] = { #liste + 1, lf, "f_0", true } end
  for i = #liste, 1, -1 do zeilen[#zeilen + 1] = { i, liste[i], "f_" .. i, false } end
  local zh = max(40 * s, L.tipp)
  local za = 6 * s                                         -- Abstand der Zeilen
  local fuss = max(36 * s, L.tipp + 4)                     -- unten: Ø pro Flug und Pfeil-Knöpfe
  local ly = y0 + 30 * s
  local platz = max(1, floor((y0 + h - fuss - ly + za) / (zh + za)))
  local blaettern = #zeilen > platz
  local ab = 0
  if blaettern then
    ab = max(0, min(w.lAb or 0, #zeilen - platz))
    w.lAb = ab                                             -- Versatz begrenzen (der Kern zählt nur hoch und runter)
  else
    w.lAb = 0
  end
  local fs = 16
  local y = ly
  for k = ab + 1, min(#zeilen, ab + platz) do
    local r = zeilen[k]
    local f = r[2]
    local rx, rb = x2 + 10 * s, b2 - 20 * s
    Z.feld(rx, y, rb, zh, 8 * s, r[4] and C.hblau or C.rand, C.dunkel, 1)
    Z.text(L, x2 + 20 * s, y + zh / 2, string.format(T.flugN, tostring(r[1])), fs, r[4] and C.hblau or C.text, LEFT,
      b2 * (kl and 0.42 or 0.36) - 24 * s)
    local tx = x2 + b2 * (kl and 0.42 or 0.36)
    Z.wert(L, tx, y + zh / 2, Z.zeit(f.t), fs, C.text, LEFT, b2 * 0.24)
    local art = T.artK and T.artK[(f.art or 0) + 1] or ""
    local akT = f.ak and (Z.zahl(f.ak, 0) .. " m") or nil
    local rechts
    if kl then
      rechts = akT
    elseif akT and art ~= "" then
      rechts = art .. " " .. akT
    elseif art ~= "" then
      rechts = art
    else
      rechts = akT
    end
    Z.wert(L, x2 + b2 - 34 * s, y + zh / 2, rechts, fs, C.hblau, RIGHT, max(20, x2 + b2 - 40 * s - tx - b2 * 0.2))
    Z.text(L, x2 + b2 - 20 * s, y + zh / 2, ">", fs, C.dim, RIGHT)
    Z.ziel(w, r[3], rx, y, rb, zh)
    y = y + zh + za
  end

  local fy = y0 + h - fuss                                 -- Oberkante des Fussbereichs
  local pb = 0
  if blaettern then
    local ph = min(fuss - 4, max(L.tipp, 30 * s))
    pb = max(L.tipp, 44 * s)
    local py = fy + (fuss - ph) / 2
    pfeil(w, L, Z, "ab", x2 + b2 - 10 * s - pb, py, pb, ph, false, ab < #zeilen - platz)
    pfeil(w, L, Z, "auf", x2 + b2 - 16 * s - 2 * pb, py, pb, ph, true, ab > 0)
    pb = 2 * pb + 12 * s
  end
  if da then
    Z.text(L, x2 + 12 * s, fy + fuss / 2, string.format(T.proFlug, Z.zeit(zeit / anz)), 16, C.hblau, LEFT,
      b2 - 24 * s - pb)
  else
    Z.text(L, x2 + b2 / 2, y0 + h * 0.45, T.keineFluege, 18, C.dim, CENTERED, b2 - 24 * s)
  end

  -- unten: Hinweis und Knopf (alles, was Daten löscht, fragt nach)
  local kb = kl and W * 0.5 or max(260 * s, 150)
  if not kl then
    Z.text(L, gp + 8 * s, H - gp - kh / 2, T.seitReset, 13, C.dim, LEFT, W - kb - 3 * gp - 8 * s)
  end
  Z.knopf(w, L, "reset", W - gp - kb, H - gp - kh, kb, kh, kl and T.zuruecksetzen or T.uebersichtReset, C.text, false, 15)
end

-- Detailfenster eines Flugs: w.detail = 0 für den laufenden Flug, sonst Platz in der Liste.
function S.detail(w, L, Z)
  local C, s, W, H, T, kl = Z.C, L.s, L.W, L.H, w.T, L.klein
  local nr = w.detail
  local f = nil
  if nr == 0 then f = w.flug elseif type(nr) == "number" then f = w.liste and w.liste[nr] end
  local n = nr == 0 and (#(w.liste or {}) + 1) or nr
  lcd.color(lcd.RGB(0, 0, 0, 0.6))                         -- Seite abdunkeln
  lcd.drawFilledRectangle(0, 0, W, H)
  local x, y = 16 * s, 46 * s
  local b, h = W - 32 * s, H - 46 * s - 8 * s
  Z.feld(x, y, b, h, 14 * s, C.hblau, C.bg, max(2, floor(2 * s)))
  local kh = max(40 * s, L.tipp)
  local kb = (b - 60 * s) / 2.4
  local ky = y + h - 12 * s - kh
  Z.knopf(w, L, "schliessen", x + b - 18 * s - kb, ky, kb, kh, T.schliessen, C.text, false, 15)
  if f == nil then return end                               -- Flug nicht mehr da: nur «SCHLIESSEN»
  Z.knopf(w, L, "loeschen", x + b - 30 * s - 2 * kb, ky, kb, kh, string.format(T.flugLoeschen, tostring(n)), C.rot,
    false, 15)

  local titel = string.format(T.flugN, tostring(n))
  local art = T.artName and T.artName[(f.art or 0) + 1] or ""
  if art ~= "" then titel = titel .. " / " .. art end
  Z.text(L, x + 18 * s, y + 24 * s, titel, 24, C.text, LEFT, b - 36 * s)

  local rh = (h - 48 * s - kh - 16 * s) / 6
  local sb = b / 2 - 30 * s
  local ss
  if f.vmax or f.vmin then
    ss = (f.vmax and vz(Z, f.vmax, 1) or "-") .. " / " .. (f.vmin and vz(Z, f.vmin, 1) or "-")
  end
  local A = {
    { w.T.dFlugzeit or "Flugzeit", Z.zeit(f.t) },
    { kl and T.ausklinkK or T.ausklink, f.ak and (Z.zahl(f.ak, 0) .. " m") },
    { T.gHoehe, f.hmax and (Z.zahl(f.hmax, 0) .. " m") },
    { kl and T.dSteigSinkK or T.dSteigSink, ss },
    { T.dMotor, (f.mot and f.mot > 0) and Z.zeit(f.mot) or nil },
    { kl and T.dRxK or T.dRx, f.rxmin and (Z.zahl(f.rxmin, 2) .. " V") },
  }
  local lx = x + 18 * s
  for i, e in ipairs(A) do
    local cy = y + 48 * s + (i - 1) * rh
    Z.text(L, lx, cy + rh * 0.25, e[1], 13, C.dim, LEFT, sb)
    Z.wert(L, lx, cy + rh * 0.68, e[2], 23, C.text, LEFT, sb)
  end

  -- rechts: Zeit je Flugphase (bis 5 Phasen wie links, mehr als 5 je eine Zeile)
  local px = x + b / 2 + 8 * s
  local pbr = b / 2 - 26 * s
  Z.text(L, px, y + 48 * s, T.dPhasen, 14, C.hblau, LEFT, pbr)
  local ph = f.ph or {}
  local np = #ph
  local function name(p)
    local t = tostring(p[1] or "")
    local vor = T.phase or ""
    if vor ~= "" and t:sub(1, #vor) ~= vor then t = vor .. " " .. t end
    return t
  end
  if np == 0 then
    Z.wert(L, px, y + 48 * s + 1.2 * rh, nil, 23, C.text, LEFT)
  elseif np <= 5 then
    for i, p in ipairs(ph) do
      local cy = y + 48 * s + (i - 0.3) * rh
      Z.text(L, px, cy + rh * 0.25, name(p), 13, C.dim, LEFT, pbr)
      Z.wert(L, px, cy + rh * 0.68, Z.zeit(p[2]), 23, C.text, LEFT, pbr)
    end
  else
    local top = y + 48 * s + 0.6 * rh
    local zh = (ky - 8 * s - top) / np
    for i, p in ipairs(ph) do
      local ym = top + (i - 0.5) * zh
      local lb = Z.text(L, px, ym, name(p), 13, C.dim, LEFT, pbr * 0.6)
      Z.wert(L, px + pbr, ym, Z.zeit(p[2]), 17, C.text, RIGHT, max(20, pbr - lb - 10 * s))
    end
  end
end

return S
