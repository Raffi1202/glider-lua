-- Glider (bis 0.4.0 «Segler»): Ethos-Widget nach festem Bauplan.
-- Diese Datei meldet nur das Widget an. Die Arbeit steckt in kern.lua und wird erst beim ersten Gebrauch geladen.
-- Für ein neues Lua ändern sich hier nur die vier Zeilen NAME, KEY, VERSION und INFO.
local NAME = "Glider"     -- Anzeigename in Ethos und Vorsatz aller Meldungen
local KEY = "glider"       -- Schlüssel des Widgets: kurz, klein, eindeutig; nach der ersten Abgabe nie mehr ändern
local VERSION = "0.6.1"    -- die Versionsnummer steht nur hier (x.y.z); das Suite-Paket liest sie von hier
local INFO = "Glider: vario, altitude, flight time, release height, thermal hint, batteries and flight list for gliders and electric gliders."   -- ein Satz für die FrSky Suite
local gemeldet = {}

-- Speicher freigeben (Auftrag 21.11.2026): Der Kern hängt nur schwach an diesem Skript. Fest gehalten wird er von
-- den Widget-Instanzen (w._K). Gibt Ethos beim Modellwechsel die Instanzen frei, kann der Kern samt allen Seiten,
-- Texten und Studio-Daten weg. Ein close-Ereignis gibt es für Widgets nicht; so braucht es auch keines.
local schwach = setmetatable({}, { __mode = "v" })

local function kern()
  local K = schwach.k
  if K == nil then
    local f, e = loadfile("kern.lua")
    if not f then error(e, 0) end
    K = f()
    K.VERSION, K.NAME, K.INFO = VERSION, NAME, INFO
    schwach.k = K
  end
  return K
end

-- Ein Fehler im Skript darf die Funke nicht stören: einmal pro Stelle melden und weiterlaufen.
local function ruf(name, w, ...)
  local ok, a = pcall(function(...)
    local K = kern()
    if type(w) == "table" then w._K = K end       -- die Instanz hält den Kern (siehe oben)
    return K[name](w, ...)
  end, ...)
  if ok then return a end
  if not gemeldet[name] then
    gemeldet[name] = true
    print(NAME .. ": Fehler in " .. name .. ": " .. tostring(a))
  end
  if type(w) == "table" then w.fehler = name .. ": " .. tostring(a) end
  return nil
end

local function create()
  local ok, w = pcall(function()
    local K = kern()
    local w = K.neu()
    if type(w) == "table" then w._K = K end
    return w
  end)
  if ok and type(w) == "table" then return w end
  print(NAME .. ": Fehler in create: " .. tostring(w))
  return { fehler = "create: " .. tostring(w) }
end

-- Nach einem Neuladen der Skripte ruft Ethos die Rückrufe kurz mit w = nil auf (am Sender gesehen, 20.11.2026):
-- darum jeder Rückruf nur mit einer Tabelle, die schon Einstellungen hat.
local function bereit(w) return type(w) == "table" and w.cfg ~= nil end

local function paint(w)
  if type(w) ~= "table" then return end
  if w.cfg then ruf("zeichne", w) end
  if w.fehler then                             -- Fehler klein und sichtbar über dem Bild, unten links
    pcall(function()
      local t = NAME .. ": " .. tostring(w.fehler)
      local _, H = lcd.getWindowSize()
      lcd.font(FONT_S)
      lcd.color(lcd.RGB(0, 0, 0))
      lcd.drawFilledRectangle(0, H - 26, lcd.getTextSize(t) + 16, 26)
      lcd.color(lcd.RGB(239, 68, 68))
      lcd.drawText(8, H - 24, t)
    end)
  end
end

local function init()
  system.registerWidget({
    key = KEY,
    name = NAME,
    create = create,
    wakeup = function(w) if bereit(w) then ruf("wecke", w) end end,
    paint = paint,
    event = function(w, kat, wert, x, y) if bereit(w) then return ruf("ereignis", w, kat, wert, x, y) end end,
    configure = function(w) if bereit(w) then ruf("menue", w) end end,
    read = function(w) if bereit(w) then ruf("lies", w) end end,
    write = function(w) if bereit(w) then ruf("schreibe", w) end end,
    title = false,
  })
end

return { init = init }
