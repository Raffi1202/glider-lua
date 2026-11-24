# Glider – Flug-Anzeige für Segler und E-Segler (FrSky Ethos)

[English](README.md) · **Deutsch** · Dokumentation: [Wiki (Deutsch)](wiki/de/Installation.md) · [Wiki (English)](wiki/en/Installation.md)

> **Am PC einrichten mit [Lua-Studio](https://github.com/Raffi1202/lua-studio)**: Bildschirm einteilen, Werte, Alarme und Symbole wählen, auf die Funke übertragen.

**Glider** ist ein Ethos-Widget (Vollbild oder Kompaktansicht mit den Ethos-Leisten) für Segler und E-Segler auf
FrSky-Sendern mit Farbdisplay. Es zeigt Vario, Höhe, Flugzeit, Akkus und Empfang. Start, Ausklinkhöhe und Thermik
erkennt es selbst und sagt sie an. Jeder Flug kommt in eine Liste mit Übersicht. Anzeige, Menü und Ansagen gibt es auf
Deutsch und Englisch.

| Vollbild (Seite 1 von 3) | Kompaktansicht (Layout mit Kopf- und Fussleiste) |
|---|---|
| ![Vollbild](docs/bilder-simulator/Glider%20-%20Sim%20800x480%2004%20Normal.png) | ![Kompakt](docs/bilder-simulator/Glider%20-%20Sim%20784x316%2020%20Kompakt%20E-Segler.png) |

- **Vario** mit Balken, Verlauf 2 Minuten, Mittel 20 s und Thermik-Ansage ab Schwelle.
- **Ausklinkhöhe** je Startart (Schleppkupplung, Motor aus, höchster Punkt), angesagt und je Flug gespeichert.
- **Akkus** mit Zellensensor oder nur Gesamtspannung; Grenzen in zwei Stufen (Warnung orange, Alarm rot mit Ton und Ansage).
- **Flugliste** mit Übersicht; jeder Flug einzeln löschbar.
- **Lua-Studio:** Eine Datei je Modell gestaltet die Anzeige frei; ohne sie arbeitet alles wie bisher.
- **Neu in 0.6.0:** Studio-Layout wird immer gefunden (Suche SD + Funke, Wahl im Menü «Studio-Layout», Umrechnen anderer Fenstergrössen, Hinweiszeile). **Neu in 0.5.0:** umbenannt von **Segler** in **Glider** (nicht rückwärts verträglich: Widget in jedem Modell neu wählen; Studio-Dateien `<Kennung>.glider.lua`, alte `<Kennung>.segler.lua` werden übergangsweise gelesen). Siehe [Update von Segler](wiki/de/Installation.md#update-von-segler-040-und-älter).
- **0.4.0:** «Alarm auch bei Motor aus» je Wert (Menü und Lua-Studio, ab Werk ein); eine Lua-Studio-Grenze
  ohne Zahl-Stufe schaltet nie ab; Speicherformat 2 (Einstellungen aus 0.3.x bleiben).

**Stand:** öffentliche Vorabversion (Public Beta). 0.6.0 ist im Ethos-Simulator getestet; der Sendertest an der X18RS
folgt. Nutzung auf eigenes Risiko. Lizenz: GPL-3.0, siehe unten.

## Schnellstart

1. Aus dem neusten **Release** `Glider-0.6.0.zip` laden (`Glider-0.6.0-share.zip` enthält zusätzlich die Anleitungen).
2. Sender per USB anschliessen, am Sender **Ethos Suite** wählen und auf dem Computer die **FrSky Suite** öffnen.
3. Suite › **Lua-Bibliothek** › **Von lokaler ZIP installieren** › ZIP wählen. Danach den Sender neu starten.
4. Modell › Bildschirme › **+** › Layout **Vollbild** (oder ein Feld mit Leisten) › ins Feld tippen › Widget **Glider**.
5. In Ethos die Sensoren suchen, dann Widget-Menü › **Sensoren suchen (nur leere)** › **Suchen** und das Ergebnis kontrollieren.

Ohne Suite: Sender als USB-Speicher anschliessen und den Ordner `glider` nach `scripts/` auf die SD-Karte kopieren.

## Dokumentation und Test

| Was | Datei |
|---|---|
| Wiki | [Deutsch](wiki/de/Installation.md) · [English](wiki/en/Installation.md) |
| Anleitung (PDF) | [`docs/Glider - Anleitung.pdf`](docs/Glider%20-%20Anleitung.pdf) · Englisch: [`docs/Glider - Manual.pdf`](docs/Glider%20-%20Manual.pdf) |
| Testleitfaden | [`TESTLEITFADEN.md`](TESTLEITFADEN.md) |
| Fehler und Wünsche | GitHub › Issues › New issue |
| Versionen | [`CHANGELOG.md`](CHANGELOG.md) |

## Studio-Layout wird nicht angezeigt?

1. Die Datei nach `scripts/studio/` kopieren (SD-Karte oder Funkenspeicher, beides geht).
2. Passt der Dateiname nicht zum Modellnamen: Widget-Menü › **Studio-Layout** › Datei wählen.
3. Die Hinweiszeile unten im Widget nennt den Grund für die Standardanzeige (Datei fehlerhaft, keine passende Ansicht, gewählte Datei fehlt).
4. Die Info-Datei `scripts/studio/<Kennung>.glider.info.json` zeigt `studioQuelle`, `studioWahl` und `hinweis`.

## Ein Layout für alle Modelle (ab 0.7.0)

Ein Layout für alle Modelle: Legt man `Standard.glider.lua` in `scripts/studio/`, nutzt jedes Modell ohne eigene `<Kennung>.glider.lua` und ohne Wahl im Menü dieses Layout. Reihenfolge: Wahl im Menü, Datei des Modells, `Standard.glider.lua`, eingebaute Anzeige. Änderungen am Sender bleiben je Modell (`<Kennung>.glider.funke.lua`). Ein Modell namens «Standard» nimmt seine eigene Datei. Im Menü «Studio-Layout» heisst der Eintrag «Standard (alle Modelle)».

## Sender und Stand der Erprobung

| Display | Sender | Stand |
|---|---|---|
| 800 × 480, Berührung | X20, X20S, X20HD, X20 Pro, X20R, X20RS, X18R, **X18RS** | **X18RS am echten Sender getestet** (Ethos 26.2.0), die anderen nur im Simulator |
| 640 × 360, ohne Berührung | Twin X14, X14S | nur Simulator |
| 480 × 320, Berührung | X18, X18S, X18SE, Twin X Lite, Twin X Lite S | nur Simulator |
| 480 × 272, ohne Berührung | X10, X10S, X10 Express, X12S (mit Ethos) | nur Simulator (Kompaktgrösse nicht gemessen) |

Am echten X18RS getestet bis 0.3.0: Start, Seiten und Ansagen, Sensorsuche mit 48 Sensoren, Kompaktansicht mit
Live-Telemetrie, Update von 0.1.4, die Lua-Studio-Datei (Beispiel, kaputte Datei, 10 Modellwechsel). Am Sender noch
nicht getestet: alles Neue aus 0.3.1, 0.4.0, 0.5.0 und 0.6.0, ein echter Flug, alle Sender ausser der X18RS. Elektrik und Flüge gibt
es nur im Vollbild. Der Gasgeber wird als «S1» gesucht; bei manchen Sendern im Menü von Hand wählen.

## Wo liegt was

| Inhalt | Ort |
|---|---|
| Skript, so wie es auf den Sender kommt | `src/glider/` |
| Anleitung (PDF) und ihre Quelle (HTML) | `docs/`, `docs/anleitung/` |
| Bilder aus dem Ethos-Simulator | `docs/bilder-simulator/` |
| Texte aller Sprachansagen | `docs/Sprachansagen.md` |
| Abläufe für den Simulator, feste Testfälle | `test/` |
| Beschreibung für Lua-Studio, Beispiel-Datei | `studio/` |

## Unterstützen

Dieses Projekt ist kostenlos. Wer die Arbeit unterstützen möchte, kann das über PayPal tun: https://paypal.me/RaphaelHunziker. Vielen Dank!

## Lizenz

GPL-3.0, siehe [LICENSE](LICENSE).

## Weitere Projekte

| Projekt | Wozu |
|---|---|
| [Electric](https://github.com/Raffi1202/electric-lua) | Ethos-Widget für Elektromodelle |
| [Heli](https://github.com/Raffi1202/heli-lua) | Ethos-Widget für Helis mit Telemetrie (jedes Flybarless-System) |
| [Jet](https://github.com/Raffi1202/jet-lua) | Ethos-Widget für Turbinen (mehrere ECU-Hersteller) |
| [Gas Engine ECU / Carb](https://github.com/Raffi1202/gas-engine-lua) | Ethos-Widgets für Verbrennungsmotoren |
| [Lua-Studio](https://github.com/Raffi1202/lua-studio) | PC-Programm zum Einrichten der Widgets (Mac/Windows) |
