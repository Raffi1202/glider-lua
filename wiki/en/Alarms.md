🇬🇧 English · [🇩🇪 Deutsch](../de/Alarme.md)

# Alarms

> **Pre-release:** tested in the Ethos simulator; transmitter test on the X18RS follows. Use at your own risk.

- Two stages per value: **warning** (orange) and **alarm** (red, with tone, voice and vibration). Limit 0 = off.
- Between two announcements there are at least 3 seconds; alarms come first. The same announcement repeats after the set time (default 30 s).
- **Mute (switch):** events and warnings stay silent, **red alarms still sound**, the display remains. If "Mute" and "Motor off" use the same switch, the menu shows "Mute = motor off: alarms only".
- **Alarm also with motor off** (new in 0.4.0, menu group with one checkbox each for altitude, motor %, link, battery 1/2/3 cell and cell difference, default **on**): unticked, this alarm stays silent while the switch "Motor off" is at its "Motor off at" position. The colour stays. Lua-Studio sets the same with `beiMotorAus`.
- **Completely silent only with "off":** an alarm is fully silent only when its limit is switched off (limit 0, or `aus = true` in the Lua-Studio file). A Lua-Studio limit without a numeric level never switches the alarm off; the built-in limit applies.

![Alarm](../../docs/bilder-simulator/Glider%20-%20Sim%20800x480%2006%20Alarm.png)

---
[← Home](../Home.md) | [← Previous](Display.md) | [Next →](Lua-Studio.md)
