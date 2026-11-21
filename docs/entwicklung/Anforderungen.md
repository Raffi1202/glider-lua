# Glider (früher Segler): Anforderungen und Entscheide

Angelegt 19.11.2026. Hier steht, was das Widget können muss und was entschieden wurde.

## Auftrag

- 19.11.2026: Ein Flug-Widget für Segler und E-Segler im Stil der Motoren-Widgets: Vario, Höhe, Flugzeit,
  Empfänger- bzw. Antriebsakku (E-Segler), Flugphasen, Flüge, Thermik-Hinweise und Ausklinkhöhe.
- So viel wie möglich einstellbar.
- Akkus mit Zellensensor oder nur mit Gesamtspannung (Ø Zelle = Gesamtspannung durch Zellenzahl).

## Was es zeigen und können muss

| Nr. | Anforderung | Stand |
|---|---|---|
| 1 | Für alle Segler: Modellart Segler / E-Segler im Menü | erfüllt 0.1.0 |
| 2 | Vario mit Balken, Verlauf, Mittel 20 s; Höhe; Flugzeit | erfüllt 0.1.0 |
| 3 | Ausklinkhöhe automatisch je Startart (SH, Motor aus SF, höchster Punkt), angesagt, in der Flugliste | erfüllt 0.1.0 |
| 4 | Thermik: Verlauf, Ansage «Thermik» ab Schwelle, Höhe auf Schalter | erfüllt 0.1.0 |
| 5 | Flugphase (SC): Name in der Statusleiste, Zeit je Phase in den Flug-Details | erfüllt 0.1.0 |
| 6 | Akkus mit Zellensensor oder nur Gesamtspannung; Akku-% Regler vor Rechnung; Akkuart wählbar | erfüllt 0.1.0 |
| 7 | Flugliste, jeder Flug einzeln löschbar | erfüllt 0.1.0 |
| 8 | So viel wie möglich konfigurierbar (Sensoren, Schalter mit Namen, Akkus, Grenzen, Ansagen, Kacheln, Sprache) | erfüllt 0.1.0 |
| 9 | Deutsch und englisch, alle Displaygrössen, auch ohne Berührung | erfüllt 0.1.0 (Ansagen als WAV offen) |
| 10 | Anleitung als PDF, ZIP für Suite und zum Teilen | erfüllt 0.2.0 |

## Freigabe des Konzepts

- 19.11.2026: Konzept `docs/konzept/Glider - Konzept.html` freigegeben. Bei Zellenzahl «automatisch» ohne
  Zellensensor keine Schätzung, nur Hinweis «Zellenzahl einstellen». Offene Punkte A–G wie vorgeschlagen.

## Entscheide

| Datum | Entscheid | Grund |
|---|---|---|
| 19.11.2026 | Name «Segler», Repo `segler-lua`, Skriptordner `segler`, Schlüssel `segler` | Punkt A |
| 21.11.2026 | Umbenannt in «Glider» (Schlüssel und Ordner `glider`, Studio-Datei `<Kennung>.glider.lua`, Repo `glider-lua`), Version 0.5.0 | alle Namen auf GitHub englisch |
| 19.11.2026 | Höhenwarnung dabei, ab Werk aus | Punkt B |
| 19.11.2026 | Höhe ansagen ab Werk auf SG, frei wählbar | Punkt C |
| 19.11.2026 | Zeit je Flugphase im Detailfenster statt in der Listenzeile | Punkt F, Platz |
| 19.11.2026 | Schlanker Weg: Lua, Simulatortest, Update-Test, Commit; Anleitung, ZIP, Bilder später | Umfang |

## Offen

- Am Sender prüfen: echte Sensoren, linker Schieber «S1», Ton, erste Drehung des Drehgebers (wählt im Simulator
  erst das Widget an).
