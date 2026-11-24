[🇬🇧 English](../en/Setup.md) · 🇩🇪 Deutsch

# Einrichten

1. Zuerst in Ethos die Sensoren suchen: **Modell › Telemetrie › Sensoren suchen**.
2. Widget-Menü öffnen (Vollbild: Taste **DISP**, dann Widget antippen) › **Sensoren suchen (nur leere)** › **Suchen**. Gefundene Sensoren kontrollieren; was du von Hand wählst, bleibt.
3. Modellart wählen: **Segler** oder **E-Segler** (zeigt Motorzustand und Antriebsakku).
4. Akkus (Zellensensor oder nur Gesamtspannung, Zellenzahl), Grenzen und Schalter einstellen.

Schalter ab Werk: **SF** = Motor aus, **SG** = Höhe ansagen, **SC** = Flugphase. Der Gasgeber wird als «S1» gesucht; bei manchen Sendern im Menü von Hand wählen.

Alle Einstellungen mit Werkwerten: Anleitung Kapitel 8, [Anleitung (PDF)](../../docs/Glider%20-%20Anleitung.pdf).

![Widget-Menü](../../docs/bilder-simulator/Glider%20-%20Sim%20800x480%2002%20Menue.png)

---
[← Start](../Home.md) | [← Zurück](Installation.md) | [Weiter →](Anzeige.md)

## Gas umkehren (ab 0.7.1)

Wer «Gas Reverse» fliegt (Vollgas = Knüppel hinten), schaltet im Widget-Menü direkt unter dem Gasgeber **Gas umkehren** ein. Glider rechnet dann Gas % = 100 − Gas % für «Motor läuft», Flugstart und Motorlaufzeit. Ab Werk aus.

## Zwei Bänder (TD-Empfänger, ab 0.7.2)

Die Sensorsuche findet RSSI 900, VFR 2.4, VFR 900 und RX VFR über AppID und Band. Glider zeigt dann das bessere Band gross und beide darunter, warnt je Band (VFR unter 70 %) und alarmiert auf RX VFR unter 50 %.
