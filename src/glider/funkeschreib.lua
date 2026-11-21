-- Glider: Änderungen aus dem Widget-Menü in <Kennung>.glider.funke.lua schreiben (Lua-Studio-Format v1, Abschnitt 9).
-- Nur mit geladener Studio-Datei; die Studio-Datei selbst schreibt das Lua nie. Geschrieben wird, was vom Stand
-- Werk + Studio (w.sd.basis) abweicht. Ohne Halbfertiges: .funke.neu schreiben, mit studioLaden zurücklesen und
-- prüfen, alte .funke.lua löschen, .funke.neu umbenennen. Texte und Schlüssel als Dezimal-Escapes (Abschnitt 4).
-- Rückgabe: true = geschrieben (oder nichts zu schreiben), false = «Änderung nicht gespeichert».
local floor = math.floor

local function esc(t)
  return '"' .. t:gsub(".", function(c) return "\\" .. c:byte() end) .. '"'
end

local function zahl(v)
  if math.type(v) == "integer" then return string.format("%d", v) end
  if v == floor(v) and v > -1e9 and v < 1e9 then return string.format("%d", floor(v)) end
  return string.format("%.4f", v)
end

local function wert(v)
  if type(v) == "boolean" then return v and "true" or "false" end
  if type(v) == "number" then return zahl(v) end
  return esc(tostring(v))
end

return function(w, S, F, studioLaden, kennung)
  local sd, c = w.sd, w.cfg
  local felder = S.einstellFelder(F)
  local teile = {}
  local namen = {}
  for n in pairs(felder) do namen[#namen + 1] = n end
  table.sort(namen)
  for _, n in ipairs(namen) do
    local f = felder[n]
    local k = f[1]
    local v = c[k]
    if v ~= nil and v ~= sd.basis[k] then
      if f[2] == "z" then v = v / 10 ^ (f[7] or 0) end
      teile[#teile + 1] = n .. " = " .. wert(v)
    end
  end
  local gr = {}
  -- Eintrag der geladenen .funke.lua übernehmen; «auch bei Motor aus» (mot) kommt aus dem Menü, wenn es abweicht
  local function alt(key, mot)
    local e = sd.funkeAlt and sd.funkeAlt[key]
    local f = {}
    for _, n in ipairs({ "aus", "richtung", "warnung", "alarm", "ansage", "vibration", "beiMotorAus" }) do
      local v = type(e) == "table" and e[n] or nil
      if n == "beiMotorAus" then v = mot end            -- gleich wie die Studio-Datei: weglassen
      if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then f[#f + 1] = n .. " = " .. wert(v) end
    end
    if #f > 0 then gr[#gr + 1] = "[" .. esc(key) .. "] = { " .. table.concat(f, ", ") .. " }" end
  end
  for s, b in pairs(S.EINGEBAUT) do
    local key = "lua:" .. s
    if sd.monKeys and sd.monKeys[key] then
      -- im angezeigten Wert überwacht (negativer Faktor): das Menü kann sie nicht ändern, Bestehendes bleibt
      local m = c[b[5]] ~= false
      if m == (sd.basis[b[5]] ~= false) then m = nil end
      alt(key, m)
      goto weiter
    end
    local wa, al = c[b[1]] or 0, c[b[2]] or 0
    local mot = c[b[5]] ~= false                       -- «auch bei Motor aus» je Feld wie «ansage» (Format 2, 3.5)
    local motAnders = mot ~= (sd.basis[b[5]] ~= false)
    local e = {}
    if motAnders then e[1] = "beiMotorAus = " .. tostring(mot) end
    if wa ~= (sd.basis[b[1]] or 0) or al ~= (sd.basis[b[2]] or 0) then
      local a = sd.werte[key]
      local fk, vs = a and a.faktor or 1, a and a.versatz or 0
      local function anz(x) return x / b[3] * fk + vs end
      if wa <= 0 and al <= 0 then e[#e + 1] = "aus = true"
      else
        e[#e + 1] = "aus = false"                      -- hebt ein «aus = true» der Studio-Datei auf
        -- beide Stufen immer angeben; eine abgeschaltete Stufe als false (Entscheid Lua Studio 20.11.)
        e[#e + 1] = "warnung = " .. (wa > 0 and zahl(anz(wa)) or "false")
        e[#e + 1] = "alarm = " .. (al > 0 and zahl(anz(al)) or "false")
      end
    end
    if #e > 0 then gr[#gr + 1] = "[" .. esc(key) .. "] = { " .. table.concat(e, ", ") .. " }" end
    ::weiter::
  end
  local p = S.PFAD .. kennung .. "." .. S.LUA
  if #teile == 0 and #gr == 0 then                   -- nichts abweichend: .funke.lua entfernen
    pcall(os.remove, p .. ".funke.lua")
    return true
  end
  local t = "return { format = " .. S.FORMAT .. ", einstellungen = { " .. table.concat(teile, ", ") ..
    " }, grenzen = { " .. table.concat(gr, ", ") .. " } }\n"
  pcall(os.mkdir, "SCRIPTS:/studio")
  local ok, f = pcall(io.open, p .. ".funke.neu", "w")
  if not (ok and f) then return false end
  local okW = pcall(f.write, f, t)
  f:close()
  local d = okW and studioLaden(p .. ".funke.neu", S.FORMAT)
  if not d then
    pcall(os.remove, p .. ".funke.neu")
    return false
  end
  pcall(os.remove, p .. ".funke.lua")
  local okR, r = pcall(os.rename, p .. ".funke.neu", p .. ".funke.lua")
  return okR and r ~= nil and r ~= false
end
