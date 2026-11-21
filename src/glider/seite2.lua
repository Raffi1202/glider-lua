-- Glider: Seite 2 «Elektrik». E-Segler mit Antriebsakku: links der Antriebsakku (Akku-%, Spannung, je Zelle ein
-- Balken, Verbrauch und Strom), rechts die übrigen Akkus und der Empfang untereinander. Ohne Antriebsakku: übrige
-- Akkus und Empfang je über die ganze Breite untereinander. Die Seite zeichnet nur; Werte kommen aus w.ak, w.v,
-- w.akMin, w.rssiMin, Texte aus w.T. Fehlender Wert = grauer Strich (Z.wert mit nil).
local S = {}
local floor, max, min = math.floor, math.max, math.min

local TYP = { "LiPo", "LiFe", "NiMH" }                       -- Bezeichnungen der Akkuarten (in allen Sprachen gleich)
local LEER = { 3.30, 2.80, 1.00 }                            -- Zellspannung leer je Art
local VOLL = { 4.20, 3.60, 1.45 }                            -- Zellspannung voll je Art

-- Farbe einer Stufe (1 orange, 2 rot), sonst die Grundfarbe
local function stufeF(C, st, sonst)
  if st == 2 then return C.rot elseif st == 1 then return C.orange end
  return sonst
end

-- Anteil 0..1 einer Zellspannung zwischen leer und voll
local function anteil(z, typ)
  if z == nil then return nil end
  local lo, hi = LEER[typ] or LEER[1], VOLL[typ] or VOLL[1]
  return max(0.04, min(1, (z - lo) / (hi - lo)))
end

-- «3S LiPo» (eingestellte Zellenzahl, sonst gemessene), ohne Zellenzahl nur die Art
local function bezeichnung(a)
  local n = a.S or (a.n > 0 and a.n or nil)
  local t = TYP[a.typ] or TYP[1]
  if n then return string.format("%.0f", n) .. "S " .. t end
  return t
end

local function quelleText(T, q)
  if q == 1 then return T.quelleRegler elseif q == 2 then return T.quelleVerbr end
  return T.quelleSpann
end

-- Feld mit Titel links und Zusatz rechts; Stufe 2 mit rotem Rahmen
local function feld(L, Z, x, y, b, h, titel, st, rechts)
  local C, s = Z.C, L.s
  Z.kasten(L, x, y, b, h, nil, nil, st == 2 and C.rot or nil)
  local tb = Z.text(L, x + 12 * s, y + 15 * s, titel, 14, C.dim, LEFT, rechts and b * 0.55 or b - 24 * s)
  if rechts then Z.text(L, x + b - 12 * s, y + 15 * s, rechts, 14, C.dim, RIGHT, max(10, b - tb - 36 * s)) end
end

-- Empfang: waagrechter Balken mit Wert, unten der Tiefstwert
local function empfang(w, L, Z, x, y, b, hh)
  local C, s, T, v = Z.C, L.s, w.T, w.v
  local st = v.st and v.st.rssi
  feld(L, Z, x, y, b, hh, T.link, st)
  local bh = max(8, floor(14 * s))
  local by = y + hh * 0.45 - bh / 2
  local bb = b - 100 * s
  Z.balkenQ(x + 12 * s, by, bb, bh, v.rssi and v.rssi / 100, stufeF(C, st, C.blau))
  Z.wert(L, x + b - 12 * s, by + bh / 2, v.rssi and (Z.zahl(v.rssi, 0) .. " %"), 26, stufeF(C, st, C.hblau), RIGHT,
    88 * s)
  Z.zeile(L, x, y + hh - 20 * s, b, T.tiefst, w.rssiMin and (Z.zahl(w.rssiMin, 0) .. " %"))
end

-- Übriger Akku schmal (rechte Spalte neben dem Antriebsakku): Spannung gross, unten Akku-% und Tiefstspannung
local function akkuSchmal(w, L, Z, i, x, y, b, hh)
  local C, s, T = Z.C, L.s, w.T
  local a = w.ak[i]
  local st = w.v.st and w.v.st["a" .. i]
  feld(L, Z, x, y, b, hh, a.rolle == 1 and T.empfAkku or T.akku, st, (not L.klein) and bezeichnung(a) or nil)
  Z.wert(L, x + b / 2, y + hh * 0.45, a.summe and (Z.zahl(a.summe, 1) .. " V"), 36, stufeF(C, st, C.text), CENTERED,
    b - 24 * s)
  local lb = a.summe and a.p and (Z.zahl(a.p, 0) .. " % / " .. T.tiefst) or T.tiefst
  Z.zeile(L, x, y + hh - 20 * s, b, lb, w.akMin[i] and (Z.zahl(w.akMin[i], 2) .. " V"))
end

-- Übriger Akku über die ganze Breite: Akku-% gross, Spannung, waagrechter Balken, unten Tiefstspannung
local function akkuBreit(w, L, Z, i, x, y, b, hh)
  local C, s, T = Z.C, L.s, w.T
  local a = w.ak[i]
  local st = w.v.st and w.v.st["a" .. i]
  local re = bezeichnung(a)
  if not L.klein then re = re .. " / " .. T.quelleSpann end
  feld(L, Z, x, y, b, hh, a.rolle == 1 and T.empfAkku or T.akku, st, re)
  local ym = y + hh * 0.45
  local f = stufeF(C, st, C.text)
  Z.wert(L, x + b * 0.16, ym, a.p and (Z.zahl(a.p, 0) .. " %"), 46, f, CENTERED, b * 0.26)
  Z.wert(L, x + b * 0.40, ym, a.summe and (Z.zahl(a.summe, 1) .. " V"), 30, f, CENTERED, b * 0.2)
  local bx, bb, bh = x + b * 0.55, b * 0.45 - 16 * s, max(14, floor(34 * s))
  Z.balkenQ(bx, ym - bh / 2, bb, bh, a.p and a.p / 100, stufeF(C, st, C.gruen))
  Z.zeile(L, x, y + hh - 20 * s, b, T.tiefst, w.akMin[i] and (Z.zahl(w.akMin[i], 2) .. " V"))
end

-- Antriebsakku (links): Akku-%, Spannung, Zellbalken bzw. ein Balken mit Gesamtspannung, Verbrauch und Strom
local function antrieb(w, L, Z, i, x, y, b, h)
  local C, s, T, v = Z.C, L.s, w.T, w.v
  local a = w.ak[i]
  local st = v.st and v.st["a" .. i]
  local fT = stufeF(C, st, C.text)                         -- Schrift der grossen Werte
  local fa = stufeF(C, st, C.gruen)                        -- Füllung der Balken
  feld(L, Z, x, y, b, h, T.antrieb, st, bezeichnung(a))
  Z.wert(L, x + b * 0.3, y + 62 * s, a.p and (Z.zahl(a.p, 0) .. " %"), 46, fT, CENTERED, b * 0.42)
  Z.wert(L, x + b * 0.72, y + 62 * s, a.summe and (Z.zahl(a.summe, 1) .. " V"), 30, fT, CENTERED, b * 0.34)
  local zt = y + 104 * s
  local zh = h - 104 * s - 92 * s
  if a.zellen and a.n > 0 then
    -- je Zelle ein senkrechter Balken mit Wert darunter (ab 7 Zellen zwei Reihen)
    local n = a.n
    local reihen = n > 6 and 2 or 1
    local je = reihen == 2 and math.ceil(n / 2) or n
    local zw = 24 * s                                      -- Platz für den Zellenwert unter dem Balken
    local rh = (zh + 24 * s) / reihen
    local sp = (b - 16 * s) / je
    local bw = min(sp * 0.62, 44 * s)
    for k = 1, n do
      local r, col = (k - 1) // je, (k - 1) % je
      local z = a[k]
      local cx = x + 8 * s + sp * (col + 0.5)
      local by = zt + rh * r
      local bh = rh - zw - (reihen == 2 and 4 * s or 0)
      Z.balken(cx - bw / 2, by, bw, bh, anteil(z, a.typ), fa)
      Z.wert(L, cx, by + bh + 12 * s, z and Z.zahl(z, 2), 15, z and fa or C.text, CENTERED, sp - 2)
    end
  else
    -- nur Gesamtspannung: EIN Balken mit der Gesamtspannung, darunter die mittlere Zelle (Gesamt ÷ Zellenzahl)
    local gb = b * 0.42
    local gx = x + (b - gb) / 2
    local an = anteil(a.mittel, a.typ)
    Z.balken(gx, zt, gb, zh, an, fa)
    if an and a.summe then
      local oben = zt + 2 + (zh - 4) * (1 - an)            -- Oberkante der Füllung
      local tz = Z.zahl(a.summe, 1) .. " V"
      if an > 0.25 then
        Z.text(L, gx + gb / 2, oben + 18 * s, tz, 20, C.dunkel, CENTERED, gb - 8 * s)
      else
        Z.text(L, gx + gb / 2, oben - 14 * s, tz, 20, C.text, CENTERED, gb - 8 * s)
      end
    end
    local ty = zt + zh + 13 * s
    if a.S == nil then
      Z.text(L, x + b / 2, ty, T.zellenEinstellen, 15, C.orange, CENTERED, b - 24 * s)
    elseif a.mittel and a.summe then
      local t = T.zelleMittel .. " " .. Z.zahl(a.mittel, 2) .. " V"
      if not L.klein then
        t = t .. "  (" .. Z.zahl(a.summe, 2) .. " V / " .. string.format("%.0f", a.S) .. ")"
      end
      Z.text(L, x + b / 2, ty, t, 15, C.hblau, CENTERED, b - 24 * s)
    else
      Z.text(L, x + b / 2 - 4 * s, ty, T.zelleMittel, 15, C.dim, RIGHT, b * 0.4)
      Z.wert(L, x + b / 2 + 4 * s, ty, nil, 15, C.hblau, LEFT)
    end
  end
  Z.zeile(L, x, y + h - 46 * s, b, T.verbrauch, v.mah and (Z.tausend(v.mah) .. " mAh"))
  local lb = L.klein and T.strom or (T.strom .. " / " .. quelleText(T, a.quelle))
  Z.zeile(L, x, y + h - 20 * s, b, lb, v.strom and (Z.zahl(v.strom, 1) .. " A"))
end

function S.zeichne(w, L, Z)
  local W, H, gp = L.W, L.H, L.gp
  local y0 = L.y0
  local h = H - y0 - gp
  local ai = w.v.antrieb
  if ai and not (w.ak[ai] and w.ak[ai].da) then ai = nil end
  -- übrige Akkus: zugewiesen, nicht der Antriebsakku, Rolle Empfänger oder Akku
  local rest = {}
  for i = 1, 3 do
    local a = w.ak[i]
    if a and a.da and i ~= ai and a.rolle ~= 2 then rest[#rest + 1] = i end
  end
  local n = #rest + 1                                      -- Akkus und Empfang
  if ai then
    local bl = (W - 3 * gp) * 0.58
    local x2, b2 = 2 * gp + bl, W - 3 * gp - bl
    antrieb(w, L, Z, ai, gp, y0, bl, h)
    local nn = max(2, n)
    local h1 = (h - (nn - 1) * gp) / nn
    local y = y0
    for _, i in ipairs(rest) do
      akkuSchmal(w, L, Z, i, x2, y, b2, h1)
      y = y + h1 + gp
    end
    empfang(w, L, Z, x2, y, b2, h1)
  else
    local bv = W - 2 * gp
    local nn = max(2, n)
    local h1 = (h - (nn - 1) * gp) / nn
    local y = y0
    for _, i in ipairs(rest) do
      akkuBreit(w, L, Z, i, gp, y, bv, h1)
      y = y + h1 + gp
    end
    empfang(w, L, Z, gp, y, bv, h1)
  end
end

return S
