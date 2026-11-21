-- Glider: Plätze einer Studio-Ansicht (Lua-Studio-Format v1, Abschnitte 6.3 und 7). Darstellungen: zahl, ring,
-- balken_w, balken_s, kurve, status. Nach dem Grundsatz «der PC denkt, die Funke zeigt» in zwei Teilen:
--   P.vorbereiten (im wakeup, je Aufruf einige Plätze): Wert, Text, Schrift, Farbe und Lage in eine Liste fertiger
--     Zeichenbefehle p.ops legen. Das kostet die meisten Befehle und wird auf mehrere Aufrufe verteilt.
--   P.zeichne (in paint): nur die Befehle ausführen. So bleibt paint auch mit 16 Plätzen unter der Befehlsgrenze.
-- Befehle: { "r", x, y, b, h, Farbe } Rechteck, { "t", Schrift, Farbe, x, y, Text, Ausrichtung },
--          { "b", cx, cy, r1, r2, a0, a1, Farbe } Bogen, { "k", gx, gy, gb, gh, Farbe } Kurve aus p.buf.
-- Spätere Plätze liegen oben. Werte, Zustände, Verläufe und Min/Max/Mittel liefert der Kern (w.wert, w.zustandVon,
-- p.buf, w.zs).
local P = {}
local floor, max, min = math.floor, math.max, math.min

-- Entwurfsgrösse für die Schriftwahl aus einer Höhe in Pixeln (Z rechnet gr * 1,25 * L.s)
local function gr(L, px) return px / (1.25 * L.s) end

local function anteil(p, x)
  if x == nil then return 0 end
  return max(0, min(1, (x - p.min) / (p.max - p.min)))
end
P.anteil = anteil          -- für den Kern beim Sammeln der Kurvenpunkte

local function text(Z, p, x)
  local a = p.a
  if x == nil then return nil end
  if a.zst then
    local z = a.zst[floor(x + 0.5)]
    return z and z[1] or tostring(x)
  end
  if a.zeit then return Z.zeit(x) end
  local t = Z.zahl(x, a.stellen)
  if a.einheit ~= "" then t = t .. " " .. a.einheit end
  return t
end

-- Farbe nach 6.3: Grenze erreicht (Alarm/Warnung) vor Stufen vor Normalfarbe
local function farbe(p, x, st, normal, C)
  if st == 2 then return p.farbeAlarm or C.rot end
  if st == 1 then return p.farbeWarn or C.orange end
  if p.stufen and x then
    local c = nil
    for _, s in ipairs(p.stufen) do if x >= s[1] then c = s[2] end end
    if c then return c end
  end
  return p.farbe or normal
end

local function titel(w, p)
  if p.titel then return p.titel end
  if p.a.lauf and w.phaseName then return w.phaseName end
  return p.a.name
end

local function zusatz(w, Z, p)
  if p.zusatz == "keine" then return nil end
  local s = w.zs and w.zs[p.key]
  if not s or s.n == 0 then return nil end
  local T = w.T
  if p.zusatz == "min" then return T.zMin .. " " .. (text(Z, p, s.min) or "")
  elseif p.zusatz == "max" then return T.zMax .. " " .. (text(Z, p, s.max) or "") end
  return T.zMittel .. " " .. (text(Z, p, s.sum / s.n) or "")
end

-- Text (oder Strich für «kein Wert») als Zeichenbefehl; ym = senkrechte Mitte, px = Schrifthöhe in Pixeln
local function tx(o, L, Z, x, ym, t, px, fb, ausr, maxB)
  if t == nil then
    local b = floor(px * 0.7)
    local d = max(2, floor(px * 0.09))
    if ausr == CENTERED then x = x - b / 2 elseif ausr == RIGHT then x = x - b end
    o[#o + 1] = { "r", floor(x), floor(ym - d / 2), b, d, Z.C.grau }
    return
  end
  local f, h = Z.waehle(L, t, gr(L, px), maxB)
  o[#o + 1] = { "t", f, fb, floor(x), floor(ym - h / 2), t, ausr or LEFT }
end

local function rechteck(o, x, y, b, h, fb)
  if b >= 1 and h >= 1 then o[#o + 1] = { "r", floor(x), floor(y), floor(b + 0.5), floor(h + 0.5), fb } end
end

local VORB = {}

function VORB.zahl(o, w, L, Z, p, x, st, C)
  local tg = min(16, max(11, p.h * 0.2))
  tx(o, L, Z, p.x + p.b / 2, p.y + tg * 0.75 + 2, titel(w, p), tg, C.dim, CENTERED, p.b - 8)
  local zt = zusatz(w, Z, p)
  local unten = zt and p.h >= 70 and tg or 0
  local vh = min(64, (p.h - tg - unten) * 0.62)
  tx(o, L, Z, p.x + p.b / 2, p.y + tg + 4 + (p.h - tg - unten - 4) / 2, text(Z, p, x), vh, farbe(p, x, st, C.text, C),
    CENTERED, p.b - 10)
  if unten > 0 then tx(o, L, Z, p.x + p.b / 2, p.y + p.h - tg * 0.7, zt, tg * 0.85, C.dim, CENTERED, p.b - 8) end
end

function VORB.ring(o, w, L, Z, p, x, st, C)
  local tg = min(16, max(11, p.h * 0.12))
  tx(o, L, Z, p.x + p.b / 2, p.y + tg * 0.75 + 2, titel(w, p), tg, C.dim, CENTERED, p.b - 8)
  local oben = p.y + tg + 6
  local r2 = min(p.b * 0.4, (p.y + p.h - oben - 4) * 0.56)
  local d = max(5, floor(r2 * 0.16))
  local r1 = r2 - d
  local cx, cy = p.x + p.b / 2, oben + r2 + 2
  local fb = farbe(p, x, st, C.hblau, C)
  o[#o + 1] = { "b", cx, cy, r1, r2, 225, 495, C.rand }
  local a = anteil(p, x)
  if a > 0 then o[#o + 1] = { "b", cx, cy, r1, r2, 225, 225 + 270 * a, fb } end
  tx(o, L, Z, cx, cy - 2, text(Z, p, x), min(34, r1 * 0.55), st and fb or C.text, CENTERED, r1 * 1.8)
  local zt = zusatz(w, Z, p)
  if zt then tx(o, L, Z, cx, cy + r1 * 0.55, zt, 12, C.dim, CENTERED, r1 * 1.6) end
end

function VORB.balken_w(o, w, L, Z, p, x, st, C)
  local tg = min(16, max(11, p.h * 0.28))
  local fb = farbe(p, x, st, C.hblau, C)
  tx(o, L, Z, p.x + 6, p.y + tg * 0.75 + 2, titel(w, p), tg, C.dim, LEFT, p.b * 0.5)
  tx(o, L, Z, p.x + p.b - 6, p.y + tg * 0.75 + 2, text(Z, p, x), tg * 1.15, st and fb or C.text, RIGHT, p.b * 0.48)
  local by = p.y + tg + 6
  local bh = max(6, p.y + p.h - by - 6)
  rechteck(o, p.x + 6, by, p.b - 12, bh, C.rand)
  rechteck(o, p.x + 7, by + 1, p.b - 14, bh - 2, C.dunkel)
  local a = anteil(p, x)
  if a > 0 then rechteck(o, p.x + 8, by + 2, (p.b - 16) * a, bh - 4, fb) end
end

function VORB.balken_s(o, w, L, Z, p, x, st, C)
  local tg = min(16, max(11, p.b * 0.14))
  local fb = farbe(p, x, st, C.hblau, C)
  tx(o, L, Z, p.x + p.b / 2, p.y + tg * 0.75 + 2, titel(w, p), tg, C.dim, CENTERED, p.b - 6)
  local vt = tg * 1.2
  local by = p.y + tg + 6
  local bh = max(10, p.y + p.h - by - vt - 6)
  local bb = min(p.b - 12, max(14, p.b * 0.4))
  local bx = p.x + (p.b - bb) / 2
  rechteck(o, bx, by, bb, bh, C.rand)
  rechteck(o, bx + 1, by + 1, bb - 2, bh - 2, C.dunkel)
  local a = anteil(p, x)
  if a > 0 then rechteck(o, bx + 2, by + 2 + (bh - 4) * (1 - a), bb - 4, (bh - 4) * a, fb) end
  tx(o, L, Z, p.x + p.b / 2, p.y + p.h - vt * 0.6 - 2, text(Z, p, x), vt, st and fb or C.text, CENTERED, p.b - 6)
end

function VORB.kurve(o, w, L, Z, p, x, st, C)
  local tg = min(16, max(11, p.h * 0.16))
  local fb = farbe(p, x, st, C.hblau, C)
  tx(o, L, Z, p.x + 6, p.y + tg * 0.75 + 2, titel(w, p), tg, C.dim, LEFT, p.b * 0.5)
  tx(o, L, Z, p.x + p.b - 6, p.y + tg * 0.75 + 2, text(Z, p, x), tg * 1.15, st and fb or C.text, RIGHT, p.b * 0.48)
  local gx, gy = p.x + 6, p.y + tg + 8
  local gb, gh = p.b - 12, p.y + p.h - gy - 6
  if gh < 8 then return end
  rechteck(o, gx, gy + gh, gb, 1, C.rand)
  o[#o + 1] = { "k", gx, gy, gb, gh, fb }
end

function VORB.status(o, w, L, Z, p, x, st, C)
  local tg = min(16, max(11, p.h * 0.22))
  tx(o, L, Z, p.x + p.b / 2, p.y + tg * 0.75 + 2, titel(w, p), tg, C.dim, CENTERED, p.b - 8)
  local zst = p.a.zst
  local z = zst and x and zst[floor(x + 0.5)]
  tx(o, L, Z, p.x + p.b / 2, p.y + tg + 4 + (p.h - tg - 4) / 2, z and z[1] or text(Z, p, x), min(40, (p.h - tg) * 0.55),
    z and z[2] or (p.farbe or C.text), CENTERED, p.b - 10)
end

-- Im wakeup: n Plätze ab w.pVorb vorbereiten (reihum). L und Z wie beim Zeichnen.
function P.vorbereiten(w, L, Z, A, n)
  local C = Z.C
  local pl = A.plaetze
  if #pl == 0 then return end
  Z.punkt = w.sp == 2
  for _ = 1, min(n, #pl) do
    local i = (w.pVorb or 0) % #pl + 1
    w.pVorb = i
    local p = pl[i]
    local o = {}
    rechteck(o, p.x, p.y, p.b, p.h, C.rand)
    rechteck(o, p.x + 1, p.y + 1, p.b - 2, p.h - 2, p.hintergrund or C.panel)
    if p.d.art ~= "leer" then
      local x = w.wert(w, p.d, p.key)
      VORB[p.dar](o, w, L, Z, p, x, w.zustandVon(w, p.key, p.d), C)
    end
    p.ops = o
  end
end

-- In paint: nur die vorbereiteten Befehle ausführen. Noch nicht vorbereitete Plätze bleiben leer.
local function kurve(p, o)
  local buf = p.buf
  if not buf or #buf < 2 then return end
  local gx, gy, gb, gh = o[2], o[3], o[4], o[5]
  lcd.color(o[6])
  local n, sp = #buf, gb / 119
  local x00, yu = gx + (119 - n) * sp, gy + gh
  local x0, y0 = nil, nil
  for i = 1, n, 3 do                                     -- jeder dritte Punkt: 40 Linien (Befehlsgrenze)
    local a = buf[i]
    if a then
      local xi, yi = floor(x00 + i * sp), floor(yu - a * gh)
      if x0 then lcd.drawLine(x0, y0, xi, yi) end
      x0, y0 = xi, yi
    else
      x0 = nil
    end
  end
end

function P.zeichne(w, L, Z, A)
  local font, color, rect, txt = lcd.font, lcd.color, lcd.drawFilledRectangle, lcd.drawText
  for _, p in ipairs(A.plaetze) do
    local ops = p.ops
    if ops then
      for _, o in ipairs(ops) do
        local k = o[1]
        if k == "t" then font(o[2]) color(o[3]) txt(o[4], o[5], o[6], o[7])
        elseif k == "r" then color(o[6]) rect(o[2], o[3], o[4], o[5])
        elseif k == "b" then Z.bogen(o[2], o[3], o[4], o[5], o[6], o[7], o[8])
        else kurve(p, o) end
      end
    end
  end
end

-- R3: Ansicht a (andere Grösse) einmal auf W x H umrechnen. Die Fläche unter der eigenen Kopfzeile bzw. Leiste
-- (Kompakt 36 px, Vollbild Statusleiste, je skaliert) wird proportional auf die Fläche unter der Kopfzeile des echten
-- Fensters abgebildet. Zu kleine Plätze werden Zahl, sind sie auch dafür zu klein, fallen sie weg (gezählt).
local MIN = { zahl = { 90, 50 }, ring = { 110, 110 }, balken_w = { 140, 40 }, balken_s = { 50, 110 }, kurve = { 180, 90 },
  status = { 120, 40 } }
-- wie Z.layout: kompakt = flacher als 0,5; s = Massstab; Vollbild L.sb = floor(44 * s), Kompakt-Leiste floor(36 * s)
local function oben(W, H)
  if H < W * 0.5 then return floor(36 * min(W / 784, H / 316)) end
  return floor(44 * min(W / 800, H / 480))
end
function P.umrechnen(a, W, H)
  local ts, tz = oben(a.breite, a.hoehe), oben(W, H)
  local fx, fy = W / a.breite, (H - tz) / max(1, a.hoehe - ts)
  local neu, weg = { breite = a.breite, hoehe = a.hoehe, plaetze = {}, angepasst = true }, 0
  local function passt(d, b, h)
    local m = MIN[d]
    return m and b >= floor(m[1] * W / 800 + 0.5) and h >= floor(m[2] * W / 800 + 0.5)
  end
  for _, p in ipairs(a.plaetze) do
    local x0, x1 = floor(p.x * fx + 0.5), floor((p.x + p.b) * fx + 0.5)
    local y0 = tz + floor((max(p.y, ts) - ts) * fy + 0.5)
    local y1 = tz + floor((max(p.y + p.h, ts) - ts) * fy + 0.5)
    x0, x1, y0, y1 = max(0, x0), min(W, x1), max(tz, y0), min(H, y1)
    local b, h, d = x1 - x0, y1 - y0, p.dar
    if not passt(d, b, h) then d = "zahl" end
    if passt(d, b, h) then
      local q = setmetatable({ x = x0, y = y0, b = b, h = h, dar = d }, { __index = p })
      neu.plaetze[#neu.plaetze + 1] = q
    else
      weg = weg + 1
    end
  end
  return neu, weg
end

return P
