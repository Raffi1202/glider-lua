# Glider – flight display for gliders and electric gliders (FrSky Ethos)

**English** · [Deutsch](README.de.md) · Documentation: [Wiki (English)](wiki/en/Installation.md) · [Wiki (Deutsch)](wiki/de/Installation.md)

> **Configure on your PC with [Lua-Studio](https://github.com/Raffi1202/lua-studio)** – arrange the screen, choose values, alarms and symbols, then transfer to the radio. Download: [latest release](https://github.com/Raffi1202/lua-studio/releases/latest) · [Wiki](https://github.com/Raffi1202/lua-studio/tree/main/wiki)

**Glider** is an Ethos widget (full screen or compact view with the Ethos bars) for gliders and electric gliders on FrSky
radios with a colour display. It shows vario, altitude, flight time, batteries and link. It detects launch, release
height and thermals and announces them, and it keeps a list of all flights. Display, menu and voice are in German and English.

| Full screen (page 1 of 3) | Compact view (layout with top and bottom bar) |
|---|---|
| ![Full screen](docs/bilder-simulator/Glider%20-%20Sim%20800x480%2012%20Englisch.png) | ![Compact](docs/bilder-simulator/Glider%20-%20Sim%20472x210%2022%20Kompakt%20Englisch.png) |

- **Vario** with bar, 2-minute graph, 20 s average and thermal announcement from a threshold.
- **Release height** detected per launch type (tow release, motor off, highest point), announced and stored per flight.
- **Batteries** with cell sensor or pack voltage only; limits in two stages (warning orange, alarm red with tone and voice).
- **Flight list** with summary; each flight can be deleted.
- **Lua-Studio:** a settings file per model designs the display freely; without it everything works as before.
- **New in 0.6.0:** Studio layout is always found (search SD + radio, choice in the menu «Studio layout», scaling to other window sizes, note line). **New in 0.5.0:** renamed from **Segler** to **Glider** (breaking: re-add the widget on each model; Studio files `<id>.glider.lua`, old `<id>.segler.lua` are still read as a transition). See [Upgrading](wiki/en/Installation.md#upgrading-from-segler-040-and-older).
- **0.4.0:** "Alarm also with motor off" per value (menu and Lua-Studio, on by default); a Lua-Studio limit
  without a numeric level never switches an alarm off; storage format 2 (0.3.x settings are kept).

**Status:** public pre-release (public beta). 0.6.0 is tested in the Ethos simulator; the transmitter test on the X18RS
follows. Use at your own risk. License: GPL-3.0, see below.

## Quick start

1. Download `Glider-0.6.0.zip` from the latest **release** (`Glider-0.6.0-share.zip` also contains the manuals).
2. Connect the radio by USB, choose **Ethos Suite** on the radio and open the **FrSky Suite** on the computer.
3. Suite › **Lua library** › **Install from local ZIP** › choose the ZIP. Then restart the radio.
4. Model › Screens › **+** › layout **Full screen** (or one frame with bars) › tap the frame › widget **Glider**.
5. Discover the sensors in Ethos, then widget menu › **Find sensors (empty only)** › **Search**, and check the result.

## Documentation and testing

| What | File |
|---|---|
| Wiki | [English](wiki/en/Installation.md) · [Deutsch](wiki/de/Installation.md) |
| Manual (PDF) | [`docs/Glider - Manual.pdf`](docs/Glider%20-%20Manual.pdf) · German: [`docs/Glider - Anleitung.pdf`](docs/Glider%20-%20Anleitung.pdf) |
| Test guide (German, checklist) | [`TESTLEITFADEN.md`](TESTLEITFADEN.md) |
| Bugs and wishes | GitHub › Issues › New issue |
| Versions | [`CHANGELOG.md`](CHANGELOG.md) |

## Studio layout not showing?

1. Copy the file to `scripts/studio/` (SD card or radio memory, both work).
2. If the file name does not match the model name: widget menu › **Studio layout** › choose the file.
3. Look at the note line at the bottom of the widget: it says why the default display is shown (file faulty, no matching view, chosen file missing).
4. The info file `scripts/studio/<model id>.glider.info.json` shows `studioQuelle`, `studioWahl` and `hinweis`.

## One layout for all models (from 0.7.0)

One layout for all models: put `Standard.glider.lua` into `scripts/studio/` and every model without its own `<id>.glider.lua` and without a menu choice uses it. Order: menu choice, model file, `Standard.glider.lua`, built-in display. Changes on the radio stay per model (`<id>.glider.funke.lua`). A model named "Standard" uses its own file. The menu entry is "Default (all models)".

## Radios and test status

| Display | Radios | Status |
|---|---|---|
| 800 × 480, touch | X20, X20S, X20HD, X20 Pro, X20R, X20RS, X18R, **X18RS** | **X18RS tested on the real radio** (Ethos 26.2.0), the others only in the simulator |
| 640 × 360, no touch | Twin X14, X14S | simulator only |
| 480 × 320, touch | X18, X18S, X18SE, Twin X Lite, Twin X Lite S | simulator only |
| 480 × 272, no touch | X10, X10S, X10 Express, X12S (with Ethos) | simulator only (compact size not measured) |

Tested on a real X18RS up to 0.3.0: start, pages and announcements, sensor search with 48 sensors, compact view with
live telemetry, update from 0.1.4, the Lua-Studio file (example, broken file, 10 model changes). Not yet tested on a
radio: everything new in 0.3.1, 0.4.0, 0.5.0 and 0.6.0, a real flight, all radios except the X18RS. The pages Power and Flights exist
in full screen only.

## Development

Not needed for testers. The Mac tests run with Lua 5.4, e.g.:

```sh
luac -p src/glider/*.lua
(cd src/glider && lua ../../test/suche-faelle.lua)
(cd src/glider && lua ../../test/thermik-faelle.lua)
(cd src/glider && lua ../../test/platz-befehle.lua)
(cd src/glider && GLIDER_FORMAT_TESTS="<folder with the Lua-Studio format test files>/" lua ../../test/studio-faelle.lua)
```

The flows `test/*.json` are meant for a simulator driver based on the Ethos WASM simulator ("ethos-tools" plugin); that
driver, the random test and the PDF/package scripts belong to the author's build kit and are not part of this repo.

## License

GPL-3.0, see [LICENSE](LICENSE).

## Related projects

| Project | What it does |
|---|---|
| [Electric](https://github.com/Raffi1202/electric-lua) | Ethos widget for electric models |
| [Heli](https://github.com/Raffi1202/heli-lua) | Ethos widget for helicopters with telemetry (any flybarless system) |
| [Jet](https://github.com/Raffi1202/jet-lua) | Ethos widget for turbines (several ECU brands) |
| [Gas Engine ECU / Carb](https://github.com/Raffi1202/gas-engine-lua) | Ethos widgets for gas engines |
| [Lua-Studio](https://github.com/Raffi1202/lua-studio) | PC app to set up the widgets (Mac/Windows) |
