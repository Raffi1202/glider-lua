🇬🇧 English · [🇩🇪 Deutsch](../de/Lua-Studio.md)

# Lua-Studio

> **Configure on your PC with [Lua-Studio](https://github.com/Raffi1202/lua-studio)** – arrange the screen, choose values, alarms and symbols, then transfer to the radio. Download: [latest release](https://github.com/Raffi1202/lua-studio/releases/latest) · [Wiki](https://github.com/Raffi1202/lua-studio/tree/main/wiki)

With the PC program Lua-Studio you design the display per model: value, look (number, ring, bar, graph, status), colours, limits and settings. Lua-Studio writes `scripts/studio/<id>.glider.lua` to the radio; without this file Glider works as before.
Changes made in the widget menu go into `.funke.lua` next to it. What Glider can do is described in `studio/beschreibung.json`; an example file is `studio/beispiel.glider.lua`.

![Studio example](../../docs/bilder-simulator/Glider%20-%20Sim%20800x480%2034%20Studio%20Beispiel.png)

Details: manual chapter 12.

---
[← Home](../Home.md) | [← Previous](Alarms.md) | [Next →](FAQ.md)

## Studio layout not showing?

- Copy the file to `scripts/studio/` on the SD card or in the radio memory; Glider searches both (0.6.0).
- File name does not match the model: widget menu › **Studio layout** › choose the file.
- The note line at the bottom says why the default display is shown; the info file has `studioQuelle`, `studioWahl`, `hinweis`.
- Window size differs from the view: Glider scales the most similar view (note "Studio: view 800x480 adapted").
