# Glider: Sprachansagen

Diese Liste ist die einzige Quelle der Ansagen. Texte immer hier ändern und dann neu erzeugen lassen
(Text-to-Speech, Stimme de-DE bzw. en-US).
Ablage: `src/glider/audio/de/<Dateiname>.wav` und `src/glider/audio/en/<Dateiname>.wav`.
Format WAV A-law, mono, 16 kHz, 8 Bit. Lautstärke nicht anpassen. Folgt im Skript direkt eine Zahl, vorne und
hinten keine Stille. Vor dem Einsetzen anhören lassen.

| Datei | Deutsch | Englisch | Wann |
|---|---|---|---|
| ausklinkhoehe | Ausklinkhöhe | Release height | + Zahl: beim Ausklinken, bei Motor aus, am höchsten Punkt |
| thermik | Thermik | Thermal | Steigen über der Schwelle |
| hoehe_warnung | Höhe | Altitude | + Zahl: Höhe über Warnschwelle (nur wenn «Warnung auch ansagen») |
| hoehe_alarm | Achtung! Höhe | Warning! Altitude | + Zahl: Höhe über Alarmschwelle |
| antriebsakku_tief | Antriebsakku tief | Motor battery low | + Zahl (Prozent), Warnung |
| antriebsakku_alarm | Achtung! Antriebsakku leer | Warning! Motor battery empty | + Zahl (Prozent), Alarm |
| empfaengerakku_tief | Empfängerakku tief | Receiver battery low | Warnung |
| empfaengerakku_alarm | Achtung! Empfängerakku leer | Warning! Receiver battery empty | Alarm |
| akku_tief | Akku tief | Battery low | Warnung (Akku mit Rolle «Akku») |
| akku_alarm | Achtung! Akku leer | Warning! Battery empty | Alarm (Akku mit Rolle «Akku») |
| zellenunterschied | Zellen ungleich | Cells unbalanced | Zellenunterschied über der Schwelle |
| empfang_schwach | Empfang schwach | Weak signal | + Zahl (Prozent), Warnung |
| empfang_alarm | Achtung! Empfang schwach | Warning! Weak signal | + Zahl (Prozent), Alarm |
| telemetrie_weg | Telemetrie weg | Telemetry lost | Telemetrie bricht ab |
| flug_gespeichert | Flug gespeichert | Flight saved | Flug beendet und in der Liste |
| hoehe | Höhe | Altitude | + Zahl: Höhe auf Schalter und im Intervall |
| flugzeit | Flugzeit | Flight time | + Zahl (Minuten): Flugzeit im Intervall |
