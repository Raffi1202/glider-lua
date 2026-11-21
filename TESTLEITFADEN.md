# Testleitfaden Glider

Danke fürs Testen! Arbeite die Fälle der Reihe nach durch und hake ab, was klappt. Klappt etwas nicht, melde es als
Issue (siehe unten). Ein Fall dauert meist 2–5 Minuten. Alles zusammen dauert ohne Flug etwa 45 Minuten.

## Was du brauchst

- [ ] Einen FrSky-Sender mit Ethos 26.1 oder neuer und Farbdisplay. Notiere Sender und Ethos-Version unter
      System › Info.
- [ ] Einen Computer mit der FrSky Suite (Download auf frsky-rc.com unter Downloads › FrSky Suite) und ein USB-Kabel.
- [ ] Die Datei `Glider-<Version>-share.zip` aus den Releases dieses Repos.
- [ ] Ab Fall 4: ein Modell mit FrSky-Empfänger und Telemetrie. Ideal ist ein Vario mit Höhe und Steigen. Für den
      E-Segler zusätzlich ein Spannungs- oder Stromsensor.
- [ ] Die Telemetrie-Sensoren sind im Ethos-Modell schon gesucht (**Modell › Telemetrie › Sensoren suchen**). Das Widget
      kann nur Sensoren zuweisen, die Ethos kennt.
- [ ] Zum Testen ein **eigenes Modell** oder eine Kopie anlegen, nicht dein bestes Flugmodell.

## Testfälle

### 1. Installieren
- [ ] ZIP entpacken. Darin liegen `Glider-<Version>.zip`, die Anleitung (Deutsch), das Manual (Englisch) als PDF und
      `LIES MICH.txt`.
- [ ] Den Sender per USB anschliessen, am Sender **Ethos Suite** wählen und die FrSky Suite öffnen.
- [ ] In der Suite **Lua-Bibliothek › Von lokaler ZIP installieren** wählen und `Glider-<Version>.zip` angeben.
- [ ] Den Sender neu starten.
- **Erwartet:** Der Sender startet ohne Fehlermeldung. In Fall 2 steht **Glider** in der Widget-Liste. (Wer will, sieht den
  Ordner `scripts/glider/` auf der SD-Karte, wenn der Sender als USB-Speicher angeschlossen ist.)

### 2. Vollbild einrichten
- [ ] **Modell › Bildschirme › +** antippen, Layout **Vollbild** (ein Feld ohne Leisten) wählen.
- [ ] Ins Feld tippen und **Widget › Glider** wählen.
- **Erwartet:** Die Anzeige erscheint. Ohne Telemetrie steht oben grau «KEINE DATEN» und statt Zahlen kurze Striche.
- [ ] Mit Wischen oder dem Drehrad blättern.
- **Erwartet:** Es gibt drei Seiten: Flug, Elektrik und Flüge.

### 3. Kompaktansicht einrichten
- [ ] Einen zweiten Bildschirm anlegen, diesmal mit dem Layout **ein Feld mit Kopf- und Fussleiste**, und wieder
      **Glider** wählen.
- **Erwartet:**
  - Oben zeigt Ethos weiter Modellname und Senderakku.
  - Im Widget steht oben eine schmale Leiste mit Flugzeit, Zustand und Empfang.
  - Darunter liegen 4 Ringe: Vario, Höhe, Antriebsakku und Empfängerakku.
  - Darunter folgen 8 Felder.
  - Es erscheint kein Hinweis «Feld zu klein».

### 4. Sensoren suchen
- [ ] Das Modell mit Telemetrie einschalten und 10 Sekunden warten.
- [ ] Das Widget-Menü öffnen: **Modell › Bildschirme › Bildschirm wählen › Widget antippen**.
- [ ] Unter **Modellart** Segler oder E-Segler wählen.
- [ ] Bei **Sensoren suchen** auf **Suchen** tippen und das Menü schliessen.
- **Erwartet:**
  - Nach wenigen Sekunden erscheint oben im blauen Balken für 3 s «… Sensoren neu zugewiesen».
  - Im Menü stehen unter jedem Sensor «ID» und «AppID».
  - Höhe, Vario und Empfang sind richtig zugewiesen.
- [ ] Notiere, welche Zeilen falsch oder leer geblieben sind, und wie viele Sensoren das Modell hat.
- [ ] Oben im Menü steht «Version …». Notiere sie für deine Meldung.

### 5. Livewerte am Boden
- [ ] Das Modell langsam etwa 1 m anheben und wieder senken.
- **Erwartet:** Vario und Höhe ändern sich passend. Der Empfang zeigt einen Wert in %.
- [ ] Beim E-Segler: Akku anstecken.
- **Erwartet:** Akku in % und die Spannung stimmen ungefähr mit einem Messgerät überein.
- [ ] Nur mit Gesamtspannung ohne Zellensensor: Im Menü unter **Akkus** die Zellenzahl einstellen.
- **Erwartet:** Der Hinweis «Zellenzahl einstellen» verschwindet.

### 6. Warnung und Alarm
- [ ] Mindestens 10 s nach dem Einschalten des Modells warten (ab Werk «Startsperre» 10 s, vorher gibt es keine Warnung).
- [ ] Im Menü unter **Grenzwerte (0 = aus)** den Wert **Empfang Warnung unter** über den aktuellen Empfang setzen
      (z. B. 100).
- **Erwartet:**
  - Oben erscheint orange «WARNUNG» mit einer Meldung.
  - Ist «Warnung auch ansagen» eingeschaltet, kommt eine Ansage.
- [ ] Die Grenze wieder zurückstellen.
- **Erwartet:** Die Warnung verschwindet.

### 7. Ansagen
- [ ] Im Menü unter **Ansagen** einen Schalter bei **Höhe ansagen (Schalter)** wählen und ihn umlegen.
- **Erwartet:** Der Sender sagt «Höhe» und eine Zahl, in der Sprache des Widgets.
- [ ] Im Menü die **Sprache** auf English stellen.
- **Erwartet:** Anzeige und Ansagen sind englisch.

### 8. Flug erkennen (am Boden nachstellen)
- [ ] Das Modell über **Flug beginnt ab Höhe** (ab Werk 10 m) anheben, z. B. am Hang. Oder für den Test den Wert im
      Menü auf 1 m stellen und das Modell anheben. **Mindestens 30 s oben halten**, sonst kommt der Flug nicht in die
      Liste (oder im Menü «Kürzere Flüge weglassen» auf 0 stellen).
- **Erwartet:** Die Flugzeit läuft.
- [ ] Das Modell wieder hinlegen und 10 s ruhig lassen.
- **Erwartet:** Oben im blauen Balken steht für 3 s «Flug … gespeichert». Auf Seite **Flüge** steht der Flug.
- [ ] Den Flug antippen.
- **Erwartet:** Ein Fenster mit den Werten des Flugs erscheint.
- [ ] Im Fenster auf **Löschen** tippen und die Rückfrage bestätigen.
- **Erwartet:** Der Flug ist weg, die Nummern der anderen Flüge rücken nach.
- Sender ohne Berührung (X14, X10, X12): Seiten mit dem Drehrad wechseln, einen Flug im Widget-Menü mit
  **Flug löschen (Nr.)** löschen.

### 9. Update und Neustart
- [ ] Den Sender aus- und wieder einschalten.
- **Erwartet:** Einstellungen, zugewiesene Sensoren und die Flugliste sind noch da.
- [ ] Kommt eine neue Version: Sie genauso wie in Fall 1 installieren.
- **Erwartet:** Einstellungen und die Flugliste bleiben erhalten.

### 10. Im Flug (wenn möglich)
- [ ] Einen normalen Flug machen und auf Thermik achten. (Der Thermik-Gewinn zählt nur in einem erkannten Flug und ist
      am Sender noch nicht getestet. Bitte hier besonders genau hinschauen.)
- **Erwartet:**
  - Bei Steigen ab 1 m/s während 3 s erscheint «THERMIK» und der Sender sagt «Thermik».
  - Im Feld **Thermik-Gewinn** stehen Meter und Zeit.
  - Nach dem Ausklinken (Schlepp), dem Motor-Aus (E-Segler) oder dem höchsten Punkt (Hand- oder Windenstart) erscheint
    «AUSKLINKHÖHE» mit einer Zahl.
- [ ] Nach der Landung den Eintrag in der Flugliste prüfen.
- **Erwartet:** Flugzeit, höchste Höhe und Ausklinkhöhe sind plausibel.

### 11. Studio-Datei ohne Lua-Studio (ab 0.3.0, optional)
- [ ] Die **Kennung** des Modells bilden: Modellname, jedes Zeichen ausser A–Z, a–z und 0–9 wird zu `_`, ein Umlaut zu
      `__`. Beispiel: «Möwe 2» wird zu `M__we_2`.
- [ ] Den Sender als USB-Speicher anschliessen und die Datei `studio/beispiel.glider.lua` aus diesem Repo auf die
      SD-Karte kopieren als `scripts/studio/<Kennung>.glider.lua` (Ordner `studio` anlegen, falls er fehlt).
      Gut zu wissen: Die Beispieldatei stellt die Modellart auf **E-Segler** und setzt **Höhe Warnung 400 m, Alarm 450 m**.
      Kurve und Balken füllen sich erst mit Telemetrie.
- [ ] Am Sender ein anderes Modell und dann wieder dieses Modell laden.
- **Erwartet:**
  - Kompaktansicht: Vario als Kurve, Höhe als Ring, Antriebsakku und Thermik-Gewinn als senkrechte Balken
    (Vergleichsbild `docs/bilder-simulator/Glider - Sim 784x316 33 Studio Beispiel.png`).
  - Vollbild, Seite 1: Vario als Kurve, Höhe und Antriebsakku als Ringe, Thermik-Gewinn als Zahl, Motor als Zustand
    (Vergleichsbild `docs/bilder-simulator/Glider - Sim 800x480 34 Studio Beispiel.png`).
  - Im Widget-Menü steht «Studio-Datei: geladen».
  - Auf der SD-Karte entsteht `scripts/studio/<Kennung>.glider.info.json`.
- [ ] Im Menü eine Einstellung ändern, z. B. «Startsperre».
- **Erwartet:** Auf der SD-Karte entsteht `scripts/studio/<Kennung>.glider.funke.lua`, die Studio-Datei bleibt unverändert.
- [ ] Im Menü bei **Zurück auf Studio-Stand** auf **Zurück** tippen und mit **JA, ZURÜCK** bestätigen.
- **Erwartet:** Die Änderung ist weg.
- [ ] Die Studio-Datei `scripts/studio/<Kennung>.glider.lua` wieder löschen und das Modell neu laden.
- **Erwartet:** Glider sieht aus wie vorher.

## Fehler melden

Bitte ein **Issue** in diesem Repo anlegen: **Issues › New issue › Fehler melden**. Die Vorlage fragt alles ab:

- **Sender und Ethos-Version** (System › Info) und die **Glider-Version** (steht oben im Widget-Menü).
- **Was du gemacht hast**, Schritt für Schritt, und **was passiert ist**. Gib die Nummer des Testfalls an.
- **Ein Bildschirmfoto:** In der FrSky Suite mit verbundenem Sender die Bildschirmaufnahme nutzen, sonst ein Handyfoto.
- **Das Lua-Log**, wenn ein roter Text unten links stand oder das Widget verschwunden ist:
  - In der FrSky Suite den **Debug-Log** des Senders öffnen und die Zeilen mit «Glider» oder «lua» kopieren.
  - Ohne Suite: Den roten Text abfotografieren.

Für Wünsche und Ideen gibt es die Vorlage **Wunsch**.
