[🇬🇧 English](../en/Lua-Studio.md) · 🇩🇪 Deutsch

# Lua-Studio

> **Am PC einrichten mit [Lua-Studio](https://github.com/Raffi1202/lua-studio)**: Bildschirm einteilen, Werte, Alarme und Symbole wählen, auf die Funke übertragen.

Mit dem PC-Programm Lua-Studio gestaltest du die Anzeige je Modell: Wert, Darstellung (Zahl, Ring, Balken, Kurve, Zustand), Farben, Grenzen und Einstellungen. Lua-Studio legt `scripts/studio/<Kennung>.glider.lua` auf den Sender; ohne diese Datei arbeitet Glider wie bisher.
Änderungen im Widget-Menü kommen in die `.funke.lua` daneben. Was Glider kann, steht in `studio/beschreibung.json`; eine Beispiel-Datei ist `studio/beispiel.glider.lua`.

![Studio-Beispiel](../../docs/bilder-simulator/Glider%20-%20Sim%20800x480%2034%20Studio%20Beispiel.png)

Einzelheiten: Anleitung Kapitel 12.

---
[← Start](../Home.md) | [← Zurück](Alarme.md) | [Weiter →](FAQ.md)

## Studio layout not showing? (Studio-Layout wird nicht angezeigt?)

- Die Datei nach `scripts/studio/` auf der SD-Karte oder im Funkenspeicher kopieren; Glider sucht an beiden Orten (0.6.0).
- Dateiname passt nicht zum Modell: Widget-Menü › **Studio-Layout** › Datei wählen.
- Die Hinweiszeile unten nennt den Grund der Standardanzeige; die Info-Datei hat `studioQuelle`, `studioWahl`, `hinweis`.
- Andere Fenstergrösse: Glider rechnet die ähnlichste Ansicht um (Hinweis «Studio: Ansicht 800x480 angepasst»).
