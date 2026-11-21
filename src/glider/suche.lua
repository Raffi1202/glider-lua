-- Glider: Sensoren und Schalter automatisch zuweisen. Füllt nur leere Felder; was von Hand gesetzt ist, bleibt.
-- Ablauf nach «Vorgaben Sensorzuordnung» (20.11.2026):
-- Stufe 1: Kennung über AppID + Teilwert (kennung.lua, nur während der Suche geladen). Je Feld eine Liste von
--          Schlüsseln in Rangfolge; der erste Schlüssel, zu dem es einen Sensor gibt, gewinnt. Der Name zählt nicht.
--          Mehrere Sensoren zum selben Schlüssel (Instanzen, Physical IDs): (a) der mit gültigem Wert,
--          (b) die niedrigste Instanz (AppID), (c) die niedrigste Physical ID. Dann Hinweis im Menü.
-- Stufe 2: nur Sensoren ohne Kennung (DIY/0x5xxx, berechnete, ELRS/CRSF): Name und Einheit als Rückfall.
-- Ethos begrenzt die Befehle je Aufruf («Max instructions count reached», am Sender 20.11.2026 mit 37 Sensoren).
-- Darum läuft die Suche in Schritten: jeder Aufruf erledigt höchstens SCHRITT Sensoren und gibt nil zurück; erst
-- der letzte Aufruf weist zu und gibt die Zahl der neu zugewiesenen Felder zurück. Die Kennung wird einmal nach
-- AppID-Bereich (16er-Block, unter 0x0100 und ab 0xF000 die AppID selbst) indiziert.
-- Zwischenstand in w.sz; w.suchHinweis[feld] = { Anzahl, gewählter Name }.
local SCHRITT = 4

local function rufe(q, f)
  if q == nil or q[f] == nil then return nil end
  local okf, v = pcall(q[f], q)
  if okf then return v end
  return nil
end

local function bereich(id)
  if id < 0x0100 or id >= 0xF000 then return id end
  return id - id % 16
end

local function hat(name, teile)
  for _, m in ipairs(teile) do
    if name:find(m, 1, true) then return true end
  end
  return false
end

-- Start: Schalter, Sensorliste, Index der Kennung
local function start(w)
  local c = w.cfg
  local z = { n = 0, i = 0, nach = {} }
  w.sz, w.suchHinweis = z, {}
  for i = 1, 3 do                                    -- Akku-Felder nach Rolle
    local r = c["a" .. i .. "Rolle"]
    if r == 1 and z.empf == nil then z.empf = "a" .. i end
    if r == 2 and z.antr == nil then z.antr = "a" .. i end
  end
  local function nachName(feld, namen)                -- üblicher Schalter-Standard
    if c[feld] ~= nil or not system.getSource then return end
    for _, nm in ipairs(namen) do
      local ok, q = pcall(system.getSource, nm)
      if ok and q ~= nil then
        local qn = rufe(q, "name")
        if type(qn) == "string" and qn:upper() == nm:upper() then
          c[feld] = q
          z.n = z.n + 1
          return
        end
      end
    end
  end
  nachName("swSchlepp", { "SH" })
  nachName("swMotor", { "SF" })
  nachName("swHoehe", { "SG" })
  nachName("gas", { "LS", "SL", "S1" })
  if not (system.getSources and CATEGORY_TELEMETRY_SENSOR) then return false end
  local ok, liste = pcall(system.getSources, CATEGORY_TELEMETRY_SENSOR)
  if not ok or type(liste) ~= "table" then return false end
  z.liste = liste
  return true
end

-- Kennung laden (ein Aufruf), dann je Aufruf INDEX_SCHRITT Einträge nach Bereich indizieren (Befehlsgrenze).
-- Gibt true zurück, wenn der Index fertig ist; dann stehen z.idx und die Rückfallregeln.
local INDEX_SCHRITT = 30
local function index(z)
  if z.K == nil then
    local okK, K = pcall(function()
      local f = loadfile("kennung.lua")
      if not f then return {} end
      return f()
    end)
    z.K = (okK and type(K) == "table") and K or {}
    z.ki, z.bau = 0, {}
    return false
  end
  local K, idx = z.K, z.bau
  local bis = math.min(#K, z.ki + INDEX_SCHRITT)
  for k = z.ki + 1, bis do
    local e = K[k]
    local b = bereich(e[1])
    while b <= e[2] do
      local l = idx[b]
      if l == nil then l = {} idx[b] = l end
      l[#l + 1] = e
      b = b + (b < 0x0100 and 1 or (b >= 0xF000 and 1 or 16))
    end
  end
  z.ki = bis
  if bis < #K then return false end
  z.idx, z.bau, z.K = idx, nil, nil
  local E = {}                                        -- Einheit -> Endung des Schlüssels (ohne Teilwert)
  if UNIT_METER then E[UNIT_METER] = "hoehe" end
  if UNIT_METER_PER_SECOND then E[UNIT_METER_PER_SECOND] = "vario" end
  if UNIT_VOLT then E[UNIT_VOLT] = "_u" end
  if UNIT_AMPERE then E[UNIT_AMPERE] = "_i" end
  if UNIT_MILLIAMPERE_HOUR then E[UNIT_MILLIAMPERE_HOUR] = "_mah" end
  z.endung = E
  -- Rückfallregeln (nur Sensoren ohne Kennung)
  z.regeln = {
    { feld = "hoehe", teile = { "alt", "höhe", "hoehe", "height" }, ohne = { "gps" } },
    { feld = "vario", teile = { "vario", "vspd", "steig", "climb" }, ohne = {}, einheit = UNIT_METER_PER_SECOND },
    { feld = "rssi", teile = { "rssi", "lq", "link" }, ohne = {} },
    { feld = "speed", teile = { "speed", "gspd", "aspd", "geschw" }, ohne = {} },
    { feld = z.empf, teile = { "rxb", "rx batt", "rx volt", "empf" }, ohne = {} },
    { feld = z.antr, teile = { "vfas", "lipo", "esc v", "batt", "volt" }, ohne = { "rx", "bec", "rxb" } },
    { feld = "aProz", teile = { "fuel", "%", "capa%" }, ohne = {}, einheit = UNIT_PERCENT },
    { feld = "aMah", teile = { "capa", "consum", "used", "verbr", "mah" }, ohne = { "%" }, einheit = UNIT_MILLIAMPERE_HOUR },
    { feld = "aStrom", teile = { "curr", "strom", "amp" }, ohne = { "bec" }, einheit = UNIT_AMPERE },
  }
  z.nameL, z.einhL = {}, {}                          -- je Regel die passenden Sensoren (beim Lesen gefüllt)
  for r = 1, #z.regeln do z.nameL[r], z.einhL[r] = {}, {} end
  return true
end

-- Schlüssel eines Sensors über den Index. Ohne Teilwert (im Simulator per Lua angelegte Sensoren liefern subId = nil)
-- entscheidet bei gepackten AppIDs die Einheit, sonst der Eintrag mit Teilwert 0.
local function schluessel(z, id, teil, einheit)
  if type(id) ~= "number" or id ~= id or id < 0 or id > 0xFFFF then return nil end
  local l = z.idx[bereich(math.floor(id))]
  if l == nil then return nil end
  local erster, passend = nil, nil
  local e2 = z.endung[einheit]
  for _, e in ipairs(l) do
    if id >= e[1] and id <= e[2] then
      if e[3] == nil or (teil ~= nil and e[3] == teil) then return e[4] end
      if teil == nil then
        if e[3] == 0 and erster == nil then erster = e[4] end
        if e2 and passend == nil and e[4]:sub(-#e2) == e2 then passend = e[4] end
      end
    end
  end
  return passend or erster
end

-- Höchstens SCHRITT Sensoren lesen und einordnen
local function lies(z)
  local liste = z.liste
  local bis = math.min(#liste, z.i + SCHRITT)
  for k = z.i + 1, bis do
    local q = liste[k]
    local name = rufe(q, "name")
    local s = { q = q, name = type(name) == "string" and name or "", id = rufe(q, "appId"), teil = rufe(q, "subId"),
      phys = rufe(q, "physId"), einheit = rufe(q, "unit") }
    local v = rufe(q, "value")
    s.wert = type(v) == "number" and v == v and v > -1e7 and v < 1e7
    s.key = schluessel(z, s.id, s.teil, s.einheit)
    -- Betaflight/INAV melden über «Kraftstoff» (0x0600) die verbrauchten mAh: nach der Einheit trennen
    if s.key == "kraftstoff" then
      if UNIT_MILLIAMPERE_HOUR and s.einheit == UNIT_MILLIAMPERE_HOUR then s.key = "kraftstoff_mah"
      elseif UNIT_PERCENT and s.einheit == UNIT_PERCENT then s.key = "kraftstoff_proz" end
    end
    if s.key then
      local l = z.nach[s.key]
      if l == nil then l = {} z.nach[s.key] = l end
      l[#l + 1] = s
    else                                               -- Rückfall vorbereiten: passende Regeln nach Name und Einheit
      local klein = s.name:lower()
      for r, R in ipairs(z.regeln) do
        if R.feld and not hat(klein, R.ohne) then
          if hat(klein, R.teile) then local l = z.nameL[r] l[#l + 1] = s end
          if R.einheit ~= nil and s.einheit == R.einheit then local l = z.einhL[r] l[#l + 1] = s end
        end
      end
    end
    z.nS = (z.nS or 0) + 1
  end
  z.i = bis
  return bis >= #liste
end

-- Zuweisen (letzter Schritt)
local function weise(w, z)
  local c = w.cfg
  local function setze(feld, s, anzahl)
    if feld == nil or c[feld] ~= nil or s.vergeben then return false end
    c[feld] = s.q
    s.vergeben = true
    z.n = z.n + 1
    if anzahl and anzahl > 1 then w.suchHinweis[feld] = { anzahl, s.name } end
    return true
  end
  local RANG = {
    { "hoehe", { "hoehe", "rb35_hoehe", "d_hoehe", "gps_hoehe" } },
    { "vario", { "vario", "rb35_vario", "d_vario" } },
    { "rssi", { "rssi", "d_rssi" } },
    { "speed", { "airspeed", "gps_speed" } },
    { z.empf, { "rx_batt", "rx_batt1", "adc2" } },
    { z.antr, { "zellen", "esc_u", "akku_u", "bat1_u", "d_akku_u" } },
    { "aProz", { "kraftstoff_proz" } },
    { "aMah", { "esc_mah", "kraftstoff_mah" } },
    { "aStrom", { "esc_i", "strom", "bat1_i", "d_strom" } },
  }
  local function besser(a, b)                       -- a vor b? (a) gültiger Wert, (b) Instanz, (c) Physical ID
    if a.wert ~= b.wert then return a.wert end
    local ia, ib = a.id or 0, b.id or 0
    if ia ~= ib then return ia < ib end
    return (a.phys or 99) < (b.phys or 99)
  end
  for _, r in ipairs(RANG) do
    local feld = r[1]
    if feld and c[feld] == nil then
      for _, k in ipairs(r[2]) do
        local best, anz = nil, 0
        for _, s in ipairs(z.nach[k] or {}) do
          if not s.vergeben then
            anz = anz + 1
            if best == nil or besser(s, best) then best = s end
          end
        end
        if best then
          setze(feld, best, anz)
          break
        end
      end
    end
  end
  for r, R in ipairs(z.regeln) do                    -- Rückfall: Namensteil
    if R.feld and c[R.feld] == nil then
      for _, s in ipairs(z.nameL[r]) do
        if setze(R.feld, s) then break end
      end
    end
  end
  for r, R in ipairs(z.regeln) do                    -- Rückfall: Einheit
    if R.feld and c[R.feld] == nil then
      for _, s in ipairs(z.einhL[r]) do
        if setze(R.feld, s) then break end
      end
    end
  end
end

-- Ein Schritt der Suche. nil = läuft noch (nochmals aufrufen), Zahl = fertig (neu zugewiesene Felder).
return function(w)
  local z = w.sz
  if z == nil then
    if not start(w) then
      local n = w.sz.n
      w.sz = nil
      return n
    end
    return nil
  end
  if z.idx == nil and z.liste then
    index(z)
    return nil
  end
  if z.liste then
    if lies(z) then z.liste, z.idx = nil, false end -- alle gelesen: Kennung freigeben
    return nil
  end
  weise(w, z)
  w.sz = nil
  return z.n
end
