-- Referenz: Studio-Datei sicher laden (Lua-Studio-Format v1, Abschnitt 3). Alle Luas übernehmen das wörtlich.
-- Rückgabe: Tabelle oder nil, Grund ("fehlt" | "kaputt" | "zuNeu").
local MAX_BYTE = 16384
local MAX_ELEMENTE = 1200   -- Kommas + «=» + «{» ausserhalb von Texten (Befehle und Speicher, gemessen)
local MAX_TABELLEN = 240    -- «{» ausserhalb von Texten (Speicher)
local SCHLUESSELWOERTER = { "and", "break", "do", "else", "elseif", "end", "for", "function", "goto", "if", "in",
  "local", "nil", "not", "or", "repeat", "then", "until", "while" }

local function studioLaden(pfad, hoechstesFormat)
  local ok, f = pcall(io.open, pfad, "r")
  if not ok or not f then return nil, "fehlt" end
  local teile, n = {}, 0
  while true do
    local ok2, s = pcall(f.read, f, 512)
    if not ok2 then f:close() return nil, "kaputt" end
    if not s or #s == 0 then break end
    n = n + #s
    if n > MAX_BYTE then f:close() return nil, "kaputt" end
    teile[#teile + 1] = s
  end
  f:close()
  local s = table.concat(teile)
  teile = nil
  -- 1. Anfang: nur «return {»
  if not s:find("^%s*return%s*{") then return nil, "kaputt" end
  -- 2. erlaubte Bytes: Buchstaben, Ziffern, Leerraum, _ { } [ ] = , " \ - .
  if s:find('[^%w%s_{}%[%]=,"\\%-%.]') then return nil, "kaputt" end
  -- 2b. nach «\» nur Ziffern (Dezimal-Escapes); sperrt \" \z \x \u{…}, die die Textgrenzen verschieben könnten
  if s:find("\\%D") then return nil, "kaputt" end
  -- 3. verbotene Folgen: Verkettung, Kommentar, lange Texte
  if s:find("..", 1, true) or s:find("--", 1, true) or s:find("[[", 1, true) then return nil, "kaputt" end
  -- 4. Schlüsselwörter ausserhalb von Texten (Texte enthalten nie ein rohes ", das Studio schreibt \34)
  local ohneTexte = s:gsub('"[^"]*"', '""')
  for _, w in ipairs(SCHLUESSELWOERTER) do
    if ohneTexte:find("%f[%w_]" .. w .. "%f[^%w_]") then return nil, "kaputt" end
  end
  -- 4b. «-» nur als Vorzeichen direkt vor einer Ziffer, nach = , { [ (keine Rechenketten)
  if ohneTexte:find("%-%s*%D") or ohneTexte:find("[^=,{%[%s]%s*%-") then return nil, "kaputt" end
  local _, anzahlReturn = ohneTexte:gsub("%f[%w_]return%f[^%w_]", "")
  if anzahlReturn ~= 1 then return nil, "kaputt" end
  -- 4b2. kein Name und keine Zahl länger als 24 Zeichen (Speicher: lange Schlüssel)
  if ohneTexte:find(string.rep("[%w_]", 25)) then return nil, "kaputt" end
  -- 4c. reine Daten: Namen nur als Schlüssel direkt vor «=», sonst nur true/false (kein _ENV, keine Variablen, keine Aufrufe)
  if ohneTexte:find("==", 1, true) then return nil, "kaputt" end
  local rest = ohneTexte:gsub("^%s*return", "")
  rest = rest:gsub("[%a_][%w_]*%s*=", "=")
  rest = rest:gsub("%f[%w_]true%f[^%w_]", "")
  rest = rest:gsub("%f[%w_]false%f[^%w_]", "")
  local nameGefunden = rest:find("[%a_]")
  rest = nil
  if nameGefunden then return nil, "kaputt" end
  -- 4d. nach «[» nur ein Text, eine Zahl oder ein Vorzeichen (keine Ausdrücke als Schlüssel)
  if ohneTexte:find('%[%s*[^%d"%-]') then return nil, "kaputt" end
  -- 5. Grösse der Tabelle begrenzen (Befehlsgrenze beim Aufbau)
  local _, kommas = ohneTexte:gsub(",", "")
  local _, gleich = ohneTexte:gsub("=", "")
  local _, klammern = ohneTexte:gsub("{", "")
  if klammern > MAX_TABELLEN or kommas + gleich + klammern > MAX_ELEMENTE then return nil, "kaputt" end
  -- 6. laden ohne Umgebung, nur Text
  -- Zwischentexte der Prüfung freigeben, bevor übersetzt wird (Speicher-Spitze)
  ohneTexte = nil
  collectgarbage("collect")
  local ok3, chunk = pcall(load, s, "=studio", "t", {})
  s = nil
  collectgarbage("collect")
  if not ok3 or type(chunk) ~= "function" then return nil, "kaputt" end
  local ok4, d = pcall(chunk)
  if not ok4 or type(d) ~= "table" or math.type(d.format) ~= "integer" or d.format < 1 then return nil, "kaputt" end
  if d.format > hoechstesFormat then return nil, "zuNeu" end
  return d
end
return studioLaden
