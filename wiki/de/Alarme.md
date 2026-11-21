[🇬🇧 English](../en/Alarms.md) · 🇩🇪 Deutsch

# Alarme

> **Vorabversion:** im Ethos-Simulator getestet; der Sendertest an der X18RS folgt. Nutzung auf eigenes Risiko.

- Zwei Stufen je Wert: **Warnung** (orange) und **Alarm** (rot, mit Ton, Ansage und Vibration). Grenze 0 = aus.
- Zwischen zwei Ansagen mindestens 3 Sekunden; Alarme gehen vor. Dieselbe Ansage kommt nach der eingestellten Zeit wieder (ab Werk 30 s).
- **Stumm (Schalter):** Ereignisse und Warnungen bleiben still, **rote Alarme kommen trotzdem**, die Anzeige bleibt. Liegen «Stumm» und «Motor aus» auf demselben Schalter, zeigt das Menü «Stumm = Motor aus: nur Alarme hörbar».
- **Alarm auch bei Motor aus** (neu in 0.4.0, je ein Haken für Höhe, Antrieb %, Empfang, Akku 1/2/3 Zelle und Zellenunterschied, ab Werk **ein**): ohne Haken bleibt dieser Alarm still, solange der Schalter «Motor aus» auf «Motor aus bei» steht. Die Farbe bleibt. Lua-Studio stellt dasselbe mit `beiMotorAus` ein.
- **Ganz still nur mit «aus»:** Ein Alarm schweigt ganz nur, wenn seine Grenze aus ist (Grenze 0 oder `aus = true` in der Lua-Studio-Datei). Eine Lua-Studio-Grenze ohne Zahl-Stufe schaltet nie ab; dann gilt die Werkgrenze.

![Alarm](../../docs/bilder-simulator/Glider%20-%20Sim%20800x480%2006%20Alarm.png)

---
[← Start](../Home.md) | [← Zurück](Anzeige.md) | [Weiter →](Lua-Studio.md)
