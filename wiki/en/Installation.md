🇬🇧 English · [🇩🇪 Deutsch](../de/Installation.md)

# Installation

## What you need
- A FrSky radio with Ethos 26.1 or newer (tested with 26.2) and a colour display.
- `Glider-0.6.0.zip` from the latest release (it is also inside `Glider-0.6.0-share.zip` with the manuals).
- The FrSky Suite on your computer (download at frsky-rc.com).

## Install with the FrSky Suite
1. Connect the radio by USB and choose **Ethos Suite** on the radio.
2. In the Suite open **Lua library › Install from local ZIP** and select `Glider-0.6.0.zip` (the inner ZIP, do not unpack it).
3. Restart the radio.

Without the Suite: connect the radio as USB storage and copy the folder `glider` from the package to `scripts/` on the SD card.

## Put it on a screen
Model › Screens › **+** › layout **Full screen** or **one frame with top and bottom bar** › tap the frame › Widget › **Glider**.
In an even smaller frame Glider only shows "Area too small".

## Upgrading from Segler (0.4.0 and older)

**Breaking:** the widget was renamed from **Segler** to **Glider** in 0.5.0 (key and folder `glider` instead of `segler`, Studio file `<id>.glider.lua` instead of `<id>.segler.lua`).
- Ethos sees Glider as a new widget: on every model, choose the widget **Glider** again in the screen frame. The settings stored in the old widget are not taken over; set them again (or let Lua-Studio transfer them).
- Studio files: re-transfer them from Lua-Studio, or rename `<id>.segler.lua` to `<id>.glider.lua`. As a transition, Glider still reads an old `<id>.segler.lua` when no `<id>.glider.lua` exists and writes "old studio file found, please re-transfer" to the log.
- **Copy your settings and flight list:** they are stored in `scripts/segler/daten/` (one file per model). Copy all files from `scripts/segler/daten/` to `scripts/glider/daten/` before you start Glider, otherwise Glider starts with default settings and an empty flight list. The assigned sensors and switches are kept in the model and come back when the widget key is changed or the sensors are searched again.
- The old folder `scripts/segler` can be deleted after the switch.

## Update
Install the new ZIP the same way. Settings and the flight list stay. Memory format 1 from 0.3.x is read without loss.

---
[← Home](../Home.md) | Previous | [Next →](Setup.md)
