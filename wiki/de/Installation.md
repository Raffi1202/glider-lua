[🇬🇧 English](../en/Installation.md) · 🇩🇪 Deutsch

# Installation

## Was du brauchst
- Einen FrSky-Sender mit Ethos ab 26.1 (getestet mit 26.2) und Farbdisplay.
- `Glider-0.6.0.zip` aus dem neusten Release (auch in `Glider-0.6.0-share.zip` mit den Anleitungen).
- Die FrSky Suite auf dem Computer (Download auf frsky-rc.com).

## Mit der FrSky Suite installieren
1. Sender per USB anschliessen und am Sender **Ethos Suite** wählen.
2. In der Suite **Lua-Bibliothek › Von lokaler ZIP installieren** und `Glider-0.6.0.zip` wählen (die innere ZIP, nicht entpacken).
3. Sender neu starten.

Ohne Suite: Sender als USB-Speicher anschliessen und den Ordner `glider` aus dem Paket nach `scripts/` auf die SD-Karte kopieren.

## Auf einen Bildschirm legen
Modell › Bildschirme › **+** › Layout **Vollbild** oder **ein Feld mit Kopf- und Fussleiste** › ins Feld tippen › Widget › **Glider**.

## Update von Segler (0.4.0 und älter)

**Achtung, nicht rückwärts verträglich:** Das Widget heisst ab 0.5.0 **Glider** statt **Segler** (Schlüssel und Ordner `glider` statt `segler`, Studio-Datei `<Kennung>.glider.lua` statt `<Kennung>.segler.lua`).
- Ethos sieht Glider als neues Widget: In jedem Modell im Bildschirmfeld das Widget **Glider** neu wählen. Die Einstellungen des alten Widgets werden nicht übernommen; neu einstellen (oder mit Lua-Studio übertragen).
- Studio-Dateien: aus Lua-Studio neu übertragen oder `<Kennung>.segler.lua` in `<Kennung>.glider.lua` umbenennen. Als Übergang liest Glider eine alte `<Kennung>.segler.lua`, solange keine `<Kennung>.glider.lua` da ist, und schreibt «old studio file found, please re-transfer» ins Log.
- **Einstellungen und Flugliste mitnehmen:** Sie liegen in `scripts/segler/daten/` (eine Datei je Modell). Vor dem ersten Start von Glider alle Dateien aus `scripts/segler/daten/` nach `scripts/glider/daten/` kopieren, sonst startet Glider mit Werkeinstellungen und leerer Flugliste. Zugewiesene Sensoren und Schalter stehen im Modell und kommen zurück, wenn der Widget-Schlüssel getauscht oder die Sensoren neu gesucht werden.
- Der alte Ordner `scripts/segler` kann nach dem Wechsel gelöscht werden.

## Update
Neue ZIP genauso installieren. Einstellungen und Flugliste bleiben.

---
[← Start](../Home.md) | Zurück | [Weiter →](Einrichten.md)
