# Glider versions (formerly Segler)

The version number is in `src/glider/main.lua` (`local VERSION`). It is the same in the manual, the Suite package and here.
The top section appears in the FrSky Suite as version note. From 0.4.0 on in English; older entries in German.

## 0.6.1 (22 Nov 2026, pre-release)

- **Settings no longer stick after a layout change.** With a studio file the Lua wrote the studio values into its own
  data file; after choosing another layout (or removing the studio file) they stayed. The data file now keeps the own
  values. Changing the layout in the menu resets settings, limits, colours, min/max and studio alarms to the state
  without studio and then applies the new file. The running flight, flight list and totals stay.
- **Studio notes never cover values.** The note ("Studio: view 800x480 adapted", "Studio: file faulty (…)") is shown in
  the own top bar (compact view) or message line (full screen) instead of over the bottom row. Warnings, alarms and event
  notes keep priority.
- **Command limit in every wakeup:** writing the data file is split into five steps and never runs together with a
  studio or search step (measured max. 4,718 instead of 9,677 commands). Pending data is written completely when Ethos
  saves the model.
- Test fixture for the restart test rebuilt for the `glider` folder (the "data not read after restart" finding came
  from an outdated fixture, not from the Lua).

## 0.6.0 (22 Nov 2026, pre-release)

- **Studio layout is always found.** The studio file is searched in `SCRIPTS:/studio/`, `SD:/scripts/studio/` and
  `RADIO:/scripts/studio/` (in this order, same folder only once). `.funke.lua` and the info file stay in `SCRIPTS:/studio/`.
- **Widget menu › Studio layout:** choose any `*.glider.lua` of the three places (place in brackets) or
  "automatic (model name)". The choice wins over the model name. Stored at the end of the widget storage (storage
  format 3); updating from 0.5.0 keeps everything, the choice starts at "automatic".
- **Other window size:** if no view matches exactly, the view with the most similar aspect ratio (tie: larger area) is
  scaled once to the window, below the own top bar. Too small places become numbers or are left out (counted in the note).
  Note "Studio: view 800x480 adapted" for 5 s.
- **Note line at the bottom** when the default display is shown although a file was found or chosen:
  "Studio: file faulty (…)", "Studio: no matching view", "Studio: chosen file missing".
- **Info file:** new fields at the end: `studioQuelle`, `studioWahl`, `ansichtGenutzt`, `angepasst`, `hinweis`.
- Unchanged: studio format 1/2, alarms and announcements, motor-off rule, command limits.

## 0.5.0 (21 Nov 2026, pre-release)

- **Renamed from Segler to Glider – breaking: old models must re-add the widget; Studio files must be renamed or re-transferred.**
  Widget key and folder on the radio `glider` (was `segler`), Studio file `<id>.glider.lua`, `.glider.funke.lua`,
  `.glider.info.json`; `beschreibung.json` and the info file report `"lua": "glider"`. Ethos treats it as a new widget,
  so the settings stored with the old widget are not taken over. Package names `Glider-<version>.zip` and
  `Glider-<version>-share.zip`; repository `glider-lua`.
- Transition: if no `<id>.glider.lua` exists, an old `<id>.segler.lua` is read and the log shows
  "old studio file found, please re-transfer".
- The English model type is now "Glider" (German stays "Segler").
- Upgrading: settings and the flight list are stored in `scripts/segler/daten/`; copy these files to
  `scripts/glider/daten/` before the first start (see wiki "Upgrading from Segler").

## 0.4.0 (21 Nov 2026, as Segler)

- Fixed (critical): A limit entry in the Lua-Studio file **without a numeric level** (e.g. only `ansage = false`,
  only `beiMotorAus = false`, or `warnung = false` plus `alarm = false`) and without `aus = true` no longer switches the
  alarm off. The built-in limit applies instead (Lua-Studio format v1 §6.5, "no switch-off without `aus`").
- New: **"Alarm also with motor off"** per limit (Lua-Studio format 2 §3.5, key `beiMotorAus`). New widget menu group
  with one checkbox each for altitude, motor battery %, link, battery 1/2/3 cell and cell difference, default ON.
  Unticked: while the switch "Motor off" is at its "Motor off at" position, this alarm stays silent (no message,
  tone, voice or vibration); the display keeps its colour. Read from the studio file and `.funke.lua`; menu changes
  are written to `.funke.lua`. Info file and `beschreibung.json` report `"beiMotorAus": true`.
- New: widget storage FORMAT 2 (new settings appended at the end). FORMAT 1 from 0.3.x is still read without loss;
  the new checkboxes start ON.
- Fixed: a studio limit for a sensor or channel (no voice file) crashed the announcement step when it fired; it now
  plays a tone. A studio entry with `ansage = false` still plays a tone at the alarm level (format 2 §7.5).
- Changed: studio limits are read in a ring (12 per cycle, at most 16 reported at once) so that a run stays below
  5,000 instructions even with 165 limits (measured on the Mac: 1,917, all 165 in alarm 3,561). The message band
  shows at most 6 messages.

## 0.3.1 (21.11.2026)

- Geändert: **Rote Alarme (Stufe 2) kommen trotz «Stumm»**. Der Stumm-Schalter hält
  nur noch Ereignisse (Ausklinkhöhe, Thermik, Intervalle) und Warnungen zurück. Liegen «Stumm» und «Motor aus» auf
  derselben Quelle (auch Schalter und eine Stellung davon, z. B. SF und SF↓), zeigt das Widget-Menü oben den Hinweis
  «Stumm = Motor aus: nur Alarme hörbar».
- Geändert: Der **Antriebsakku wird bei jeder Modellart überwacht**, sobald ihm ein Sensor zugewiesen ist (bisher nur
  beim E-Segler). Er erscheint dann auch beim reinen Segler in der Kompaktansicht, auf Seite 2 und in der Leiste.
- Behoben: Die Sensorliste für Studio-Sensoren und die Info-Datei kommt über die Zahlform
  `system.getSources(CATEGORY_TELEMETRY_SENSOR)`. Die Tabellenform liefert an der X18RS eine leere Liste
  (Info-Datei hatte «sensoren: []»). Studio-Sensoren werden immer über die Liste gesucht (AppID, Teilwert, Physical ID
  falls angegeben), nicht mehr über `getSource` mit appId (am Sender ohne Wert).
- Behoben: **Befehlsgrenze** beim Laden der Studio-Datei. Einstellungen, Werte und Grenzen werden in Stücken geprüft
  und angewendet (`JE_AUFRUF`), die Sensor-Zuordnung über ein Verzeichnis statt über alle Paare. Grösste gültige
  Dateien (165 Grenzen, 140 Werte, 350 Einstellungen, Grenzen in Studio und `.funke.lua`): höchstens 3'510 Befehle je
  Aufruf (vorher bis 62'161).
- Speicher: Der Kern hängt nur noch schwach an `main.lua`, fest gehalten von den Widget-Instanzen. Gibt Ethos die
  Instanzen frei (Modellwechsel), wird der Kern samt Seiten und Studio-Daten frei. Gemessen auf dem Mac
  (Lua 5.4, 64 Bit): nach dem Loslassen der Instanz bleiben 8 KB statt 114 KB.
- Tests: `test/studio-faelle.lua` mit grossen Dateien und Sensorliste wie am Sender, Simulator-Abläufe 60–63
  (Alarm trotz Stumm, Warnung bleibt still, Menühinweis gleiche/andere Quelle).

## 0.3.0 (20.11.2026)

- Neu: **Lua-Studio-Format v1** (Teil B). Eine Studio-Datei je Modell (`scripts/studio/<Kennung>.segler.lua`) legt fest,
  welcher Wert wo steht: Zahl, Ring, Balken waagrecht und senkrecht, Kurve, Zustand. Dazu kommen eigene Farben,
  Farbstufen, Min/Max/Mittel über den Flug, Wert-Anpassung (Faktor, Versatz, Einheit, Stellen, Name), Grenzen je Wert
  (auch für Sensoren und Kanäle) und Einstellungen. Bis zu 16 Plätze je Ansicht. Die Kompaktansicht und Vollbild-Seite 1
  werden ersetzt, wenn die Grösse genau passt. Ohne Datei bleibt alles wie bisher.
- Laden mit der Referenzfunktion `studio_laden` (wörtlich): Erlaubtliste, höchstens 16 KB, 1200 Elemente und
  240 Tabellen. Danach wird jedes Feld nach Abschnitt 6 geprüft; Ungültiges ergibt den Standard plus Hinweis, nie einen
  Absturz. Das Laden ist auf mehrere Aufrufe verteilt (höchstens rund 3'200 Befehle je Aufruf).
- Änderungen im Widget-Menü gehen bei geladener Studio-Datei in `….segler.funke.lua`. Das Schreiben ist sicher gegen
  Stromausfall (.funke.neu, zurücklesen, prüfen, umbenennen). Neu im Menü: Stand der Studio-Datei und «Zurück auf
  Studio-Stand» bzw. «Zurück auf Standard».
- Info-Datei `….segler.info.json` für das Studio (Modell, Sender, Fenster, Sensorliste).
- Eine kaputte oder zu neue Studio-Datei bzw. `.funke.lua` gibt zusätzlich eine Zeile im Log aus.
- Sendertest X18RS (Ethos 26.2.0) bestanden: Beispiel-Datei, Info-Datei, Feldfehler, kaputte Datei, 10 Modellwechsel.
  Am Sender noch offen: Änderungen im Menü (`.funke.lua`) und die volle Datei mit 16 Plätzen.
- Plätze werden im wakeup vorbereitet, paint zeichnet nur noch (16 Plätze mit 2 Kurven: rund 3'500 Befehle).
- `studio/beschreibung.json` beschreibt Werte, Einstellungen, Werkgrenzen und Standard für das Studio. `werte.lua`
  wird daraus erzeugt (`studio/werte_erzeugen.py`).
- Tests: `test/studio-faelle.lua` (alle Angriffsdateien der Koordination, volle Datei, Feldfehler, .funke.lua,
  Modellwechsel 10×), `test/platz-befehle.lua`, Simulator-Abläufe 50–56.

## 0.2.1 (20.11.2026)

- Behoben: Im ersten Durchlauf der Thermik-Erkennung konnte bei schwachem Steigen unter der Thermik-Schwelle ein
  Lua-Fehler entstehen (roter Text unten links, bis zu 2 s). Gefunden mit dem Zufallstest, fester Fall in
  `test/thermik-faelle.lua`.

## 0.2.0 (20.11.2026)

- Neu: **Kompaktansicht** für das Ethos-Layout «ein Widget mit Kopf- und Fussleiste». Das Widget erkennt die
  Fenstergrösse selbst (Fenster flacher als 1:2), ein Menüpunkt ist nicht nötig. Oben eine schmale Leiste mit
  Flugzeit, Zustand, Motor, Flugphase und Empfang (Warnungen und Hinweise ersetzen dort die Pillen), darunter
  4 Ringe (Vario, Höhe, Antriebsakku, Empfängerakku; beim reinen Segler ohne Antriebsakku: Empfang) und 8 Felder
  (Flugphase mit Zeit, Ausklinkhöhe, höchste Höhe, Ø Steigen 20 s, Geschwindigkeit, Strom, Verbrauch,
  Thermik-Gewinn). Gemessene Fenster: 784 × 316 (X20-Reihe, X18R/RS), 630 × 258 (X14), 472 × 210 (X18, Twin X Lite).
  Der Hinweis «nur im Vollbild» fällt weg; ganz kleine Felder zeigen «Feld zu klein».
- Neu: **Thermik-Gewinn**: höchste in der aktuellen Thermik gewonnene Höhe und die Zeit bis dahin. Zählt ab Beginn
  des Steigens über der Thermik-Schwelle, endet nach 10 s Sinken ohne Unterbruch oder wenn der Motor läuft, und
  bleibt bis zur nächsten Thermik stehen; auch das Flugende beendet sie. Kurze Dellen (auch vor der Erkennung, bis 2 s)
  setzen nichts zurück, Rauschen um 0 hält das Ende nicht auf (9 feste Fälle in `test/thermik-faelle.lua`). Im Vollbild als Kachel und als Wert der unteren Leiste wählbar.
- Sensorsuche: Das Indizieren der Kennung ist auf mehrere Aufrufe verteilt, je Aufruf werden 4 Sensoren gelesen.
  Gemessen höchstens 2'864 Lua-Befehle je Aufruf (vorher 5'135). Kompaktansicht zeichnet mit höchstens rund 4'000.

## 0.1.4 (20.11.2026)

- Absturzschutz: Nach einem Neuladen der Skripte ruft Ethos die Widget-Rückrufe kurz ohne Widget (`w = nil`) auf.
  Alle Rückrufe und `paint` prüfen das jetzt und tun dann nichts.

## 0.1.3 (20.11.2026)

- Sensorsuche in Schritten: am Sender brach die Suche mit vielen Sensoren mit «Max instructions count reached» ab.
  Die Kennung wird jetzt einmal nach AppID-Bereich indiziert, je Aufruf werden höchstens 5 Sensoren gelesen,
  zugewiesen wird im letzten Schritt. Gemessen höchstens 5'135 Lua-Befehle je Aufruf mit 100 Sensoren.
  Der Knopf «Suchen» im Menü startet die Suche; das Ergebnis erscheint als Hinweis auf der Anzeige.
- 640 × 360: Name der Flugphase in der Kachel «Flugzeit» gekürzt (überlappte bei langen Namen).

## 0.1.2 (20.11.2026)

- Automatische Sensorzuordnung nach der gemeinsamen Kennung (AppID + Teilwert, `kennung.lua`, nur während der Suche
  geladen): Rangfolge je Feld, der Name zählt nicht mehr. Mehrere passende Sensoren: gültiger Wert vor niedrigster
  Instanz vor niedrigster Physical ID, Hinweis im Menü. Ohne Teilwert entscheidet bei gepackten AppIDs die Einheit.
  «Kraftstoff» (0x0600) in mAh gilt als Verbrauch. Name und Einheit nur noch als Rückfall für Sensoren ohne Kennung.
- Menü: unter jedem zugewiesenen Sensor Physical ID und AppID.
- Tests: feste Fälle a–g auf dem Mac (`test/suche-faelle.lua`) und im Simulator (`test/30-suche-simulator.json`).

## 0.1.1 (19.11.2026)

- Ansagen: Warnung und Alarm je Akku und beim Empfang mit eigener Sprachdatei («…_tief», «…_alarm»); Höhe,
  Flugzeit und «Flug gespeichert» mit Ansage vor der Zahl. Liste der 17 Ansagen in `docs/Sprachansagen.md`.
- Sprachansagen als WAV, deutsch und englisch (17 je Sprache, `src/segler/audio/`).
- Anleitung deutsch (PDF) und englisch (Manual), Paket für die FrSky Suite und ZIP zum Teilen.

## 0.1.0 (19.11.2026)

- Erste Fassung nach dem freigegebenen Konzept (19.11.2026): drei Seiten Flug, Elektrik, Flüge; für Segler und
  E-Segler (Modellart im Menü).
- Seite Flug: drei wählbare Kacheln (Vario mit Balken, Mittel 20 s und Höchstwert; Höhe mit Höchst- und
  Ausklinkhöhe; Flugzeit mit Zeit der Flugphase und Motorlaufzeit), Verlauf 1/2/5 min (Vario oder Höhe) mit
  Thermik-Schwelle, Leiste unten wählbar.
- Ausklinkhöhe automatisch je Startart: Schleppkupplung (SH), Motor aus (SF) beim E-Segler, sonst höchster Punkt.
  Ansage der Ausklinkhöhe, Ansage «Thermik» ab einstellbarem Steigen, Höhe auf Schalter (SG) und in Intervallen.
- Akkus bis 3 (Empfänger, Antrieb, Akku): Zellensensor mit Balken je Zelle oder nur Gesamtspannung mit einem
  Balken und Ø Zelle; ohne eingestellte Zellenzahl kein Schätzen, sondern Hinweis «Zellenzahl einstellen».
  Akku-% vom Regler, aus Verbrauch und Kapazität oder aus der Spannung je Akkuart (LiPo, LiFe, NiMH).
- Je überwachtem Wert zwei Schwellen (Höhe, Zelle, Antriebsakku-%, Empfang), Zellenunterschied, Startsperre,
  Stumm-Schalter.
- Flugliste (bis 40 Flüge) mit Gesamtwerten, Detailfenster mit Zeit je Flugphase, jeder Flug einzeln löschbar.
- Deutsch und englisch, alle Displaygrössen. Ansagen als WAV folgen (bis dahin Ton plus Zahl).
