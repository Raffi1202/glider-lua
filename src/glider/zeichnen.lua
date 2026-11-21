-- Glider: Zeichen-Baukasten (Farben, Schriften, Grundformen, Statusleiste, Knopf, Rückfrage).
-- Zeichnet nur, rechnet nichts aus. Alle Masse gehen vom Entwurf 800 x 480 aus und werden mit L.s verkleinert.
local Z = {}
local floor, max, min = math.floor, math.max, math.min

Z.C = nil       -- Farben
local SCHRIFT   -- vorhandene Schriften mit gemessener Höhe, klein nach gross

-- Feste Farben: grün = gut, orange = Warnung, rot = Alarm, blau = Hinweis, grau = kein Wert.
local function farben()
  local R = lcd.RGB
  Z.C = {
    bg = R(14, 17, 22), panel = R(22, 27, 34), rand = R(48, 54, 61), text = R(230, 237, 243), dim = R(139, 148, 158),
    grau = R(75, 85, 99), blau = R(59, 130, 246), gruen = R(34, 197, 94), orange = R(245, 158, 11), rot = R(239, 68, 68),
    dunkel = R(11, 13, 16), hblau = R(96, 165, 250), weiss = R(255, 255, 255),
  }
end

local function schriften()
  SCHRIFT = {}
  local kand = { FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL }
  for i = 1, 7 do
    local f = kand[i]
    if f ~= nil then
      lcd.font(f)
      local _, h = lcd.getTextSize("0")
      local n = #SCHRIFT
      if n == 0 or h > SCHRIFT[n][2] then SCHRIFT[n + 1] = { f, h } end
    end
  end
end

-- Aufteilung für eine Fenstergrösse (wird im Kern je Grösse einmal gerechnet und gemerkt).
function Z.layout(W, H)
  if not Z.C then farben() end
  if not SCHRIFT then schriften() end
  -- Kompaktansicht: Ethos-Layout mit Kopf- und Fussleiste (X18RS gemessen 784 x 316). Erkannt am Seitenverhältnis:
  -- Vollbild hat bei allen Sendern mindestens 0,56 (480 x 272), mit Leisten ist das Fenster flacher als 0,5.
  local kompakt = H < W * 0.5
  local s = kompakt and min(W / 784, H / 316) or min(W / 800, H / 480)
  -- Displayklasse nach der gemessenen Breite, nie nach dem Namen des Senders (bauplan.md, Abschnitt Sender):
  -- L = 800 x 480 (X20-Reihe, X18R, X18RS), M = 640 x 360 (X14), S = 480 x 320 und 480 x 272 (X18, X18S, X Lite, X10, X12)
  local klasse = W >= 700 and "L" or (W >= 560 and "M" or "S")
  local L = { W = W, H = H, s = s, klasse = klasse, klein = klasse == "S", kompakt = kompakt }
  L.tipp = 32                      -- Pixel: antippbare Flächen sind nie niedriger (bei 480 x 320 sonst zu klein)
  L.sb = floor(44 * s)             -- Statusleiste
  L.top = L.sb + floor(6 * s)      -- Oberkante der Meldezeile
  L.mh = floor(26 * s)             -- Höhe der Meldezeile
  L.gp = floor(6 * s)              -- Abstand zwischen Feldern
  L.y0 = L.top + L.mh + L.gp       -- Oberkante der Felder einer Seite
  L.fi = {}                        -- Schriftwahl je Entwurfsgrösse
  return L
end

-- Schrift für eine Entwurfsgrösse (Schriftgrad im Entwurf 800 x 480) wählen; gibt die Stufe zurück.
local function stufe(L, gr)
  local i = L.fi[gr]
  if i then return i end
  local ziel = gr * 1.25 * L.s + 0.5
  i = 1
  for k = 2, #SCHRIFT do
    if SCHRIFT[k][2] <= ziel then i = k end
  end
  L.fi[gr] = i
  return i
end

-- Text mit senkrechter Mitte ym. ausr: LEFT / RIGHT / CENTERED. maxB: passt der Text nicht, wird die Schrift kleiner.
-- Rückgabe: Textbreite.
function Z.text(L, x, ym, t, gr, farbe, ausr, maxB)
  local f, h, b = Z.waehle(L, t, gr, maxB)
  lcd.color(farbe)
  lcd.drawText(floor(x), floor(ym - h / 2), t, ausr or LEFT)
  return b
end

-- Schrift für einen Text wählen, ohne zu zeichnen (lässt die Schrift gesetzt): Schrift, Höhe, Breite.
function Z.waehle(L, t, gr, maxB)
  local i = stufe(L, gr)
  lcd.font(SCHRIFT[i][1])
  local b = lcd.getTextSize(t)
  if maxB then
    while b > maxB and i > 1 do
      i = i - 1
      lcd.font(SCHRIFT[i][1])
      b = lcd.getTextSize(t)
    end
  end
  return SCHRIFT[i][1], SCHRIFT[i][2], b
end

-- Textbreite in der Schrift einer Entwurfsgrösse.
function Z.breite(L, t, gr)
  lcd.font(SCHRIFT[stufe(L, gr)][1])
  return (lcd.getTextSize(t))
end

function Z.rechteck(x, y, b, h, farbe)
  if b < 1 or h < 1 then return end
  lcd.color(farbe)
  lcd.drawFilledRectangle(floor(x), floor(y), floor(b + 0.5), floor(h + 0.5))
end

-- Rechteck mit runden Ecken (Ethos kennt keines: zwei Rechtecke und vier Kreise).
function Z.rund(x, y, b, h, r, farbe)
  x, y, b, h, r = floor(x), floor(y), floor(b), floor(h), floor(r)
  if b < 1 or h < 1 then return end
  lcd.color(farbe)
  if r * 2 + 1 > h then r = floor((h - 1) / 2) end
  if r * 2 + 1 > b then r = floor((b - 1) / 2) end
  if r < 2 then
    lcd.drawFilledRectangle(x, y, b, h)
    return
  end
  lcd.drawFilledRectangle(x + r, y, b - 2 * r, h)
  lcd.drawFilledRectangle(x, y + r, b, h - 2 * r)
  lcd.drawFilledCircle(x + r, y + r, r)
  lcd.drawFilledCircle(x + b - r - 1, y + r, r)
  lcd.drawFilledCircle(x + r, y + h - r - 1, r)
  lcd.drawFilledCircle(x + b - r - 1, y + h - r - 1, r)
end

-- Gefülltes Feld mit Rand. d = Randstärke.
function Z.feld(x, y, b, h, r, rand, fuell, d)
  d = d or 1
  Z.rund(x, y, b, h, r, rand)
  Z.rund(x + d, y + d, b - 2 * d, h - 2 * d, r - d, fuell)
end

-- Eckiges Feld mit Rand (d Pixel), braucht viel weniger Lua-Befehle als Z.feld (Kompaktansicht, Grenze je Aufruf).
function Z.platte(x, y, b, h, rand, fuell, d)
  x, y, b, h = floor(x), floor(y), floor(b), floor(h)
  if b < 1 or h < 1 then return end
  lcd.color(rand)
  lcd.drawFilledRectangle(x, y, b, h)
  lcd.color(fuell)
  lcd.drawFilledRectangle(x + d, y + d, b - 2 * d, h - 2 * d)
end

-- Feld mit Titel oben in der Mitte.
function Z.kasten(L, x, y, b, h, titel, farbe, rand)
  local C = Z.C
  Z.feld(x, y, b, h, 10 * L.s, rand or C.rand, C.panel, rand and max(2, floor(3 * L.s)) or 1)
  if titel then Z.text(L, x + b / 2, y + 18 * L.s, titel, 14, farbe or C.dim, CENTERED, b - 12 * L.s) end
end

-- Pille mit Text; voll = gefüllt, sonst nur Rand.
function Z.pille(L, x, y, b, h, t, farbe, voll, gr)
  local C = Z.C
  if voll then
    Z.rund(x, y, b, h, h / 2, farbe)
  else
    Z.feld(x, y, b, h, h / 2, farbe, C.panel, max(1, floor(2 * L.s)))
  end
  Z.text(L, x + b / 2, y + h / 2, t, gr, voll and C.dunkel or farbe, CENTERED, b - h * 0.3)
end

-- Kreisbogen; Winkel in Grad, 0 = oben, im Uhrzeigersinn. Geht auch über 360 hinaus.
function Z.bogen(cx, cy, r1, r2, a0, a1, farbe)
  if a1 <= a0 then return end
  lcd.color(farbe)
  cx, cy, r1, r2 = floor(cx), floor(cy), floor(r1), floor(r2)
  if a0 >= 360 then a0, a1 = a0 - 360, a1 - 360 end
  if a1 > 360 then
    lcd.drawAnnulusSector(cx, cy, r1, r2, a0, 360)
    lcd.drawAnnulusSector(cx, cy, r1, r2, 0, a1 - 360)
  else
    lcd.drawAnnulusSector(cx, cy, r1, r2, a0, a1)
  end
end

-- Zahl mit dez Stellen: deutsch mit Komma, englisch mit Punkt (Z.punkt setzt der Kern je Bild).
-- nil bleibt nil (Z.wert zeichnet dann einen Strich).
function Z.zahl(x, dez)
  if x == nil then return nil end
  local t = string.format("%." .. (dez or 0) .. "f", x)
  if dez and dez > 0 then
    local a, b = t:match("^(-?%d+)%.(%d+)$")
    if a and not Z.punkt then t = a .. "," .. b end
  end
  return t
end

-- Ganze Zahl mit Tausender-Trennung: 6850 -> 6'850 (deutsch) oder 6,850 (englisch).
function Z.tausend(x)
  if x == nil then return nil end
  local n = floor(x + 0.5)
  local v = n < 0 and "-" or ""
  if n < 0 then n = -n end
  if n < 1000 then return v .. string.format("%.0f", n) end
  return v .. string.format("%.0f", floor(n / 1000)) .. (Z.punkt and "," or "'") .. string.format("%03.0f", n % 1000)
end

-- Sekunden als m:ss oder h:mm:ss.
function Z.zeit(sek)
  if sek == nil then return nil end
  local n = floor(sek)
  if n < 0 then n = 0 end
  if n >= 3600 then return string.format("%.0f:%02.0f:%02.0f", n // 3600, (n % 3600) // 60, n % 60) end
  return string.format("%.0f:%02.0f", n // 60, n % 60)
end

function Z.grund(L)
  lcd.color(Z.C.bg)
  lcd.drawFilledRectangle(0, 0, L.W, L.H)
end

-- Hinweis, wenn das Feld für die Anzeige zu klein ist.
function Z.zuKlein(w, L)
  local C = Z.C
  Z.text(L, L.W / 2, L.H / 2 - 12, tostring(w.name), 26, C.text, CENTERED, L.W - 8)
  Z.text(L, L.W / 2, L.H / 2 + 12, w.T.zuKlein, 20, C.dim, CENTERED, L.W - 8)
end

-- Kurzer waagrechter Strich für «kein Wert» (die Ethos-Schrift hat keinen Gedankenstrich). gr = Entwurfsgrösse.
function Z.strich(L, x, ym, gr, farbe, ausr)
  local b = floor(gr * 0.7 * L.s + 0.5)
  local d = max(2, floor(gr * 0.09 * L.s + 0.5))
  if ausr == CENTERED then x = x - b / 2 elseif ausr == RIGHT then x = x - b end
  Z.rechteck(x, ym - d / 2, b, d, farbe or Z.C.grau)
  return b
end

-- Text oder, wenn t nil ist, ein Strich. Jeder Messwert wird mit Z.wert gezeichnet, nie mit Z.text.
function Z.wert(L, x, ym, t, gr, farbe, ausr, maxB)
  if t == nil then return Z.strich(L, x, ym, gr, Z.C.grau, ausr) end
  return Z.text(L, x, ym, t, gr, farbe, ausr, maxB)
end

local ZUSTAND_FARBE = { ok = "gruen", warnung = "orange", alarm = "rot" }

-- Statusleiste und Meldezeile (auf allen Seiten gleich): links Zustand, Flugphase, Motor (E-Segler) und bis zu zwei
-- Schalter als Pillen, rechts Modellname, Empfang und Seite, darunter Warnungen oder ein kurzer Hinweis (blau).
function Z.kopf(w, L)
  local C, s, W, T, v = Z.C, L.s, L.W, w.T, w.v
  local sb = L.sb
  Z.rechteck(0, 0, W, sb, C.panel)
  local ph = max(22, floor(28 * s))
  local py = floor((sb - ph) / 2)
  local gr = ph * 0.92 / (1.25 * s)
  local ab = max(4, floor(6 * s))
  local x = 8 * s
  local function pille(t, farbe, voll, mind, hoechst)
    local b = max(mind or 0, Z.breite(L, t, gr) + ph * 0.8)
    if hoechst and b > hoechst then b = hoechst end   -- langer Phasenname: Schrift wird kleiner
    Z.pille(L, x, py, b, ph, t, farbe, voll, gr)
    x = x + b + ab
  end
  local zf = C[ZUSTAND_FARBE[w.zustand] or "grau"]
  local voll = not (w.stufe == 2 and w.blink)        -- Alarm blinkt: gefüllt / nur Rand
  pille(T[w.zustand] or "", zf, voll, 112 * s)
  if w.phaseAnz then pille(L.klasse ~= "L" and Z.kurz(w.phaseAnz, 10) or w.phaseAnz, C.hblau, false, nil, W * (L.klein and 0.3 or 0.24)) end
  if v.motor then
    local k = L.klein and "K" or ""
    if v.motor == "laeuft" then pille(T["motorLaeuft" .. k], C.blau, true)
    elseif v.motor == "aus" then pille(T["motorAus" .. k], C.gruen, false)
    else pille(T["motorEin" .. k], C.orange, false) end
  end
  local c = w.cfg
  if not L.klein then
    for i = 1, 2 do
      local n = c["sw" .. i .. "Name"]
      local a = v["sw" .. i]
      if c["sw" .. i] and type(n) == "string" and n ~= "" and a ~= nil then pille(n, a and C.blau or C.grau, a) end
    end
  end

  local teile = {}
  if not L.klein then teile[#teile + 1] = tostring(w.modell or w.name) end
  if v.rssi then teile[#teile + 1] = (L.klein and "" or (T.empfang .. " ")) .. string.format("%.0f %%", v.rssi) end
  teile[#teile + 1] = (L.klein and "" or (T["seite" .. w.seite] .. " ")) .. w.seite .. "/" .. (w.seiten or 3)
  local rest = W - x - 16 * s                       -- Platz rechts neben den Pillen
  local rt = table.concat(teile, "    ")
  if #teile > 2 and Z.breite(L, rt, 16) > rest then
    table.remove(teile, 1)                         -- zu eng: Modellname weglassen
    rt = table.concat(teile, "    ")
  end
  Z.text(L, W - 10 * s, sb / 2, rt, 16, C.text, RIGHT, max(40, rest))

  local mt, mf, tf
  if w.nAktiv > 0 then
    mt, mf, tf = w.meldText, w.stufe == 2 and C.rot or C.orange, C.dunkel
  elseif w.hinweis then
    mt, mf, tf = w.hinweis, C.blau, C.weiss
  end
  if mt then
    Z.rund(L.gp, L.top, W - 2 * L.gp, L.mh, 8 * s, mf)
    Z.text(L, W / 2, L.top + L.mh / 2, mt, 16, tf, CENTERED, W - 2 * L.gp - 16 * s)
  end
end

-- Antippbare Fläche merken (beim Zeichnen); der Kern prüft damit die Berührungen.
function Z.ziel(w, id, x, y, b, h)
  local n = (w.nZiele or 0) + 1
  w.nZiele = n
  local z = w.ziele[n] or {}
  z.id, z.x, z.y, z.b, z.h = id, x, y, b, h
  w.ziele[n] = z
end

-- Knopf mit Rand oder gefüllt; meldet seine Fläche als Ziel.
function Z.knopf(w, L, id, x, y, b, h, t, farbe, voll, gr)
  local C = Z.C
  if voll then
    Z.rund(x, y, b, h, 8 * L.s, farbe)
  else
    Z.feld(x, y, b, h, 8 * L.s, farbe, C.panel, max(1, floor(2 * L.s)))
  end
  Z.text(L, x + b / 2, y + h / 2, t, gr, voll and C.dunkel or farbe, CENTERED, b - 12 * L.s)
  Z.ziel(w, id, x, y, b, h)
end

-- Rückfrage über der Seite. w.dlg = { Titel, Zeile, Text Ja, Ziel Ja }. Nur «JA, …» ändert etwas.
function Z.dialog(w, L)
  local d = w.dlg
  if d == nil then return end
  local C, s, W, H, T = Z.C, L.s, L.W, L.H, w.T
  lcd.color(lcd.RGB(0, 0, 0, 0.6))                   -- Seite abdunkeln
  lcd.drawFilledRectangle(0, 0, W, H)
  local b, h = min(W - 16, max(460 * s, 400)), max(200 * s, 130)   -- auf kleinen Displays nicht schmaler als 400 Pixel
  local x, y = (W - b) / 2, (H - h) / 2
  Z.feld(x, y, b, h, 14 * s, C.hblau, C.bg, max(2, floor(2 * s)))
  Z.text(L, W / 2, y + max(26, 42 * s), d[1], 26, C.text, CENTERED, b - 30 * s)
  if d[2] then Z.text(L, W / 2, y + max(54, 82 * s), d[2], 15, C.dim, CENTERED, b - 30 * s) end
  local kb, kh = (b - 3 * 22 * s) / 2, max(46 * s, L.tipp or 0)
  local ky = y + h - kh - max(10, 22 * s)
  Z.knopf(w, L, "abbrechen", x + 22 * s, ky, kb, kh, T.abbrechen, C.dim, false, 15)
  Z.knopf(w, L, d[4], x + 44 * s + kb, ky, kb, kh, d[3], C.gruen, true, 15)
end

-- Text auf höchstens n Zeichen kürzen (ohne ein Umlaut-Zeichen zu zerschneiden).
function Z.kurz(t, n)
  if type(t) ~= "string" or #t <= n then return t end
  local i = n
  while i > 0 and t:byte(i + 1) and t:byte(i + 1) >= 128 and t:byte(i + 1) < 192 do i = i - 1 end
  local k = t:sub(1, i):gsub("[%s%-]+$", "")          -- nicht auf Bindestrich oder Leerzeichen enden
  return k .. "."
end

-- Beschriftung links, Wert rechts (Zeile in einem Feld).
function Z.zeile(L, x, ym, b, label, wert, farbe)
  local s = L.s
  local lb = Z.text(L, x + 12 * s, ym, label, 15, Z.C.dim, LEFT, b * 0.6)
  Z.wert(L, x + b - 12 * s, ym, wert, 17, farbe or Z.C.hblau, RIGHT, max(20, b - lb - 30 * s))
end

-- Senkrechter Balken (Anteil 0..1) mit Rand.
function Z.balken(x, y, b, h, anteil, farbe)
  local C = Z.C
  Z.feld(x, y, b, h, 4, C.rand, C.dunkel, 1)
  if anteil then
    anteil = max(0, min(1, anteil))
    local hh = (h - 4) * anteil
    if hh >= 1 then Z.rechteck(x + 2, y + h - 2 - hh, b - 4, hh, farbe) end
  end
end

-- Waagrechter Balken (Anteil 0..1) mit Rand.
function Z.balkenQ(x, y, b, h, anteil, farbe)
  local C = Z.C
  Z.feld(x, y, b, h, 3, C.rand, C.dunkel, 1)
  if anteil then
    anteil = max(0, min(1, anteil))
    local bb = (b - 4) * anteil
    if bb >= 1 then Z.rechteck(x + 2, y + 2, bb, h - 4, farbe) end
  end
end

return Z
