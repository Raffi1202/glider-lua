-- Glider: Einstellungen im Ethos-Menü (Modell › Bildschirme › Widget antippen, oder Widget lange drücken ›
-- Widget konfigurieren). Baut sich aus felder.lua: oben die Knöpfe, darunter zugeklappte Gruppen.
-- Alles, was auf der Seite nur per Berührung geht, gibt es hier auch (X14, X10 und X12 haben keine Berührung),
-- immer mit Rückfrage über form.openDialog (ABBRECHEN zuletzt = links und vorgewählt).
-- A: Aktionen des Kerns { fertig, suche, reset, loesche(nr), beende, zurueckStd }.
return function(w, F, A)
  local c = w.cfg
  local name = tostring(w.name)
  local sp, T = w.sp or 1, w.T or {}       -- Sprache beim Öffnen; ein Wechsel gilt im Menü ab dem nächsten Öffnen
  local function tx(t) return F.text(t, sp) end

  local function frage(titel, zeile, ja, tun)
    if not form.openDialog then return end
    pcall(form.openDialog, {
      title = titel, message = zeile,
      buttons = {
        { label = ja, action = function() pcall(tun) return true end },
        { label = T.abbrechen, action = function() return true end },
      },
    })
  end

  local kopf = form.addLine(T.mSuchen or "Sensoren suchen")
  if form.addButton then
    form.addButton(kopf, nil, { text = T.mKnopf or "Suchen", press = function()
      local ok, n = pcall(A.suche)
      if ok then
        print(name .. ": Suche " .. tostring(n))
      else
        print(name .. ": Fehler bei der Suche: " .. tostring(n))
        w.fehler = "Suche: " .. tostring(n)
      end
    end })
  end
  form.addStaticText(form.addLine(name), nil, "Version " .. tostring(w.version or ""))

  -- Liegen «Stumm» und «Motor aus» auf derselben Quelle, ist bei Motor aus alles stumm ausser den roten Alarmen.
  -- Gleich heisst: gleiche Kategorie und Nummer, gleicher Name, oder ein Schalter und eine Stellung davon (SF / SF↓).
  local function nameVon(q)
    local ok, n = pcall(q.name, q)
    return ok and type(n) == "string" and n or nil
  end
  local function gleich(a, b)
    if a == nil or b == nil then return false end
    local ok1, k1 = pcall(a.category, a)
    local ok2, k2 = pcall(b.category, b)
    local ok3, m1 = pcall(a.member, a)
    local ok4, m2 = pcall(b.member, b)
    if ok1 and ok2 and ok3 and ok4 and k1 ~= nil and k1 == k2 and m1 == m2 then return true end
    local n1, n2 = nameVon(a), nameVon(b)
    if not n1 or not n2 or n1 == "" or n2 == "" then return false end
    if n1 == n2 then return true end
    if #n1 > #n2 then n1, n2 = n2, n1 end
    -- Rest nach dem kürzeren Namen nur Stellungszeichen (↑ - ↓, keine Buchstaben/Ziffern): Stellung desselben Schalters
    return n2:sub(1, #n1) == n1 and not n2:sub(#n1 + 1):find("[%w]")
  end
  if gleich(c.stumm, c.swMotor) then
    form.addStaticText(form.addLine(T.mStummMotor or "Stumm = Motor aus"), nil, T.mStummMotorT or "")
  end

  -- Studio-Datei (Lua-Studio-Format v1): Stand anzeigen, zurück auf Studio-Stand bzw. Standard
  local mitStudio = w.sd and w.sd.status == "geladen"
  form.addStaticText(form.addLine(T.mStudio), nil, mitStudio and T.mStudioGeladen or T.mStudioFehlt)
  -- Studio-Layout wählen (R2): alle *.glider.lua der drei Orte ohne .funke.lua, nur beim Öffnen des Menüs gesucht.
  -- Zeigt SCRIPTS: auf denselben Ordner wie SD: oder RADIO: (gleiche Dateiliste), erscheint der Ort nur einmal.
  if form.addChoiceField and A.studioWahl then
    -- «automatisch» zeigt in Klammern, was gerade gilt: Modellname oder Standard (alle Modelle)
    local gilt = (w.sd and w.sd.wahl == "standard") and (T.mStandardKurz or "Standard") or (T.mModellname or "model name")
    local wahl, pfade, gesehen = { { (T.mAutoKurz or "auto") .. " (" .. gilt .. ")", 0 } }, {}, {}
    for _, o in ipairs({ { "SCRIPTS:/studio/", "SCRIPTS" }, { "SD:/scripts/studio/", "SD" }, { "RADIO:/scripts/studio/", "RADIO" } }) do
      local ok, l = pcall(system.listFiles, o[1])
      if ok and type(l) == "table" then
        local n = {}
        for _, d in ipairs(l) do
          if type(d) == "string" and d:sub(-11) == ".glider.lua" and d:sub(-17) ~= ".glider.funke.lua" then n[#n + 1] = d end
        end
        table.sort(n)
        local sig = table.concat(n, "/")
        if #n > 0 and not gesehen[sig] then
          gesehen[sig] = true
          for _, d in ipairs(n) do
            if #pfade < 60 then
              pfade[#pfade + 1] = o[1] .. d
              local nm = d:sub(1, -12)
              if nm == "Standard" then nm = T.mStandardAlle or nm end
              wahl[#wahl + 1] = { nm .. " (" .. o[2] .. ")", #pfade }
            end
          end
        end
      end
    end
    local akt = w.studioWahl or ""
    if akt ~= "" then
      local da = false
      for _, p in ipairs(pfade) do if p == akt then da = true end end
      if not da then pfade[#pfade + 1] = akt wahl[#wahl + 1] = { akt:match("[^/]*$") .. " (?)", #pfade } end
    end
    form.addChoiceField(form.addLine(T.mLayout or "Studio layout"), nil, wahl, function()
      for i, p in ipairs(pfade) do if p == (w.studioWahl or "") then return i end end
      return 0
    end, function(v) A.studioWahl(pfade[v] or "") end)
  end
  if form.addButton and A.zurueckStd then
    local tz = mitStudio and T.mStudioZurueck or T.mStandardZurueck
    form.addButton(form.addLine(tz), nil, { text = T.mZurueckKnopf, press = function()
      frage(tz .. "?", tz, T.mZurueckJa, function() A.zurueckStd() end)
    end })
  end

  -- erkannte Akkuart je Sensor (Zellensensor oder nur Gesamtspannung)
  for i = 1, 3 do
    local a = w.ak and w.ak[i]
    if a and a.da then
      local t = a.zellen and T.mZellen or T.mGesamt
      if not a.zellen and not a.S then t = t .. " / " .. T.zellenEinstellen end
      form.addStaticText(form.addLine(string.format(T.mErkannt, i)), nil, t)
    end
  end

  if form.addButton then
    -- Flug löschen: Nummer wählen, dann Rückfrage
    local nr = 1
    local zeile = form.addLine(T.mLoeschen)
    local n = #(w.liste or {})
    if n > 0 and form.addNumberField then
      form.addNumberField(zeile, nil, 1, n, function() return math.min(nr, #(w.liste or {})) end,
        function(v) nr = v end)
    end
    form.addButton(zeile, nil, { text = T.mLoeschenKnopf, press = function()
      local m = #(w.liste or {})
      if m == 0 then return end
      local k = math.max(1, math.min(nr, m))
      frage(string.format(T.loeschTitel, k), string.format(T.loeschZeile, k), T.loeschJa,
        function() A.loesche(k) end)
    end })
    form.addButton(form.addLine(T.mBeenden), nil, { text = T.mBeendenKnopf, press = function()
      frage(T.beendTitel, T.beendZeile, T.beendJa, A.beende)
    end })
    form.addButton(form.addLine(T.mReset), nil, { text = T.mResetKnopf, press = function()
      frage(T.resetTitel, T.resetZeile, T.resetJa, A.reset)
    end })
  end

  for _, g in ipairs(F.gruppen) do
    local panel = form.addExpansionPanel(tx(g[1]))
    pcall(panel.open, panel, false)
    for _, f in ipairs(g[2]) do
      local feld, art = f[1], f[2]
      local line = form.addLine(tx(f[3]), panel)
      local function get() return c[feld] end
      local function set(v)
        if art == "q" and not F.istQuelle(v) then v = nil end
        if art == "t" then v = F.textWert(v) end
        c[feld] = v
        -- Akkuart gewechselt: Grenzen dieses Akkus auf die Werte der Art setzen
        if f.art and F.ART_GRENZE[v] then
          c["z" .. f.art .. "Warn"], c["z" .. f.art .. "Alarm"] = F.ART_GRENZE[v][1], F.ART_GRENZE[v][2]
        end
        A.fertig()
      end
      if art == "q" then
        form.addSourceField(line, nil, get, set)
        -- Sensor: Physical ID und AppID zeigen (gleichnamige Sensoren unterscheidbar), Hinweis bei mehreren Kandidaten
        local q = c[feld]
        if q ~= nil then
          local okA, id = pcall(q.appId, q)
          if okA and type(id) == "number" and id == id and id >= 0 and id <= 65535 then
            local okP, ph = pcall(q.physId, q)
            local txt = string.format(T.mId or "ID %s / AppID 0x%04X", (okP and type(ph) == "number" and ph == ph and ph >= 0 and ph < 1000) and string.format("%.0f", ph) or "?", math.floor(id))
            local h = w.suchHinweis and w.suchHinweis[feld]
            if h then txt = txt .. "  " .. string.format(T.mMehrere or "%s / %s", tostring(h[1]), tostring(h[2])) end
            form.addStaticText(form.addLine("", panel), nil, txt)
          end
        end
      elseif art == "b" then
        form.addBooleanField(line, nil, get, set)
      elseif art == "t" then
        if form.addTextField then form.addTextField(line, nil, get, set) end
      elseif art == "w" then
        local wahl = {}
        for i, a in ipairs(f[5]) do wahl[i] = { tx(a[1]), a[2] } end
        form.addChoiceField(line, nil, wahl, get, set)
      elseif art == "z" then
        local fe = form.addNumberField(line, nil, f[5], f[6], get, set)
        if fe then
          if f[7] and f[7] > 0 then pcall(fe.decimals, fe, f[7]) end
          if f[8] then pcall(fe.suffix, fe, f[8]) end
          if f[9] then pcall(fe.step, fe, f[9]) end
          pcall(fe.default, fe, f[4])
        end
      end
    end
  end
end
