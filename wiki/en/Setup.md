🇬🇧 English · [🇩🇪 Deutsch](../de/Einrichten.md)

# Setup

1. Discover the sensors in Ethos first: **Model › Telemetry › Discover new sensors**.
2. Open the widget menu (full screen: press **DISP**, then tap the widget) › **Find sensors (empty only)** › **Search**. Check the sensors it found; what you choose by hand stays.
3. Choose the model type: **Glider** or **E-glider** (shows the motor state and the motor battery).
4. Set the batteries (cell sensor or only pack voltage, cell count), the limits and the switches.

Default switches: **SF** = motor off, **SG** = announce altitude, **SC** = flight phase. The throttle is searched as "S1"; on some radios select it in the menu by hand.

All menu items with their defaults are listed in the manual, chapter 8: [Manual (PDF)](../../docs/Glider%20-%20Manual.pdf).

![Widget menu](../../docs/bilder-simulator/Glider%20-%20Sim%20800x480%2002%20Menue.png)

---
[← Home](../Home.md) | [← Previous](Installation.md) | [Next →](Display.md)

## Reverse throttle (from 0.7.1)

If you fly "throttle reverse" (full throttle = stick back), switch on **Reverse throttle** in the widget menu, directly below the throttle source. Glider then uses throttle % = 100 − throttle % for "motor runs", flight start and motor run time. Off by default.
