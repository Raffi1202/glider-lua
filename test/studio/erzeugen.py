#!/usr/bin/env python3
# Erzeugt gültige Studio-Dateien für die Segler-Tests, so wie das Studio sie schreibt (Format v1, Abschnitt 4):
# Texte und Schlüssel als Dezimal-Escapes, ganze Zahlen ohne Punkt, andere mit 4 Stellen.
import pathlib
hier = pathlib.Path(__file__).resolve().parent
def esc(t): return '"' + "".join("\\%d" % b for b in t.encode("utf-8")) + '"'
def wert(v):
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, int): return str(v)
    if isinstance(v, float): return "%.4f" % v
    if isinstance(v, str): return esc(v)
    if isinstance(v, list): return "{ " + ", ".join(wert(x) for x in v) + " }"
    if isinstance(v, dict):
        t = []
        for k, x in v.items():
            if k.isidentifier() and k.isascii(): t.append("%s = %s" % (k, wert(x)))
            else: t.append("[%s] = %s" % (esc(k), wert(x)))
        return "{ " + ", ".join(t) + " }"
    raise ValueError(v)
def schreibe(name, d):
    (hier / name).write_text("return " + wert(d) + "\n", encoding="utf-8")

def platz(x, y, b, h, w, dar, **k):
    p = {"x": x, "y": y, "b": b, "h": h, "w": w, "darstellung": dar}
    p.update(k); return p
# volle Belegung: 2 Ansichten zu 16 Plätzen, 2 Kurven je Ansicht, alle Darstellungen, 8 eigene Sensoren, einer mit Physical ID
sens = ["sensor:0100:0", "sensor:0110:0", "sensor:0210:0", "sensor:0200:0", "sensor:F101:0", "sensor:0830:0", "sensor:0600:0", "sensor:0100:0:7"]
def ansicht(br, ho, y0):
    l = []
    arten = [("lua:vario", "ring"), ("lua:hoehe", "kurve"), (sens[0], "zahl"), (sens[1], "balken_s"),
             ("lua:zustand", "status"), ("lua:motor", "status"), (sens[2], "balken_w"), (sens[3], "zahl"),
             ("lua:antrieb_proz", "ring"), (sens[4], "zahl"), ("lua:thermik_gewinn", "balken_w"), (sens[5], "zahl"),
             ("lua:vario_mittel", "kurve"), (sens[6], "zahl"), (sens[7], "zahl"), ("kanal:3", "zahl")]
    for i, (w, d) in enumerate(arten):
        b, h = 190, 130                         # Mindestgrössen aller Darstellungen; Überlappung prüft nur das Studio
        x, y = 5 + (i % 4) * 195, y0 + (i // 4) * ((ho - y0 - h - 2) // 3)
        p = platz(x, y, b, h, w, d, titel="Wert %d" % (i + 1), zusatz=["keine", "min", "max", "mittel"][i % 4])
        if i < 6:                               # alle Zusatzfarben auf 6 Plätzen (Studio schreibt höchstens 1100 Elemente)
            p.update(farbe=[10, 200, 30], farbeWarn=[255, 160, 0], farbeAlarm=[230, 40, 40], hintergrund=[20, 22, 28])
        if d == "kurve": p["kurveS"] = 60
        if d in ("ring", "balken_w", "balken_s"): p["stufen"] = [{"ab": 10, "farbe": [255, 255, 0]}, {"ab": 50, "farbe": [0, 200, 0]}]
        l.append(p)
    return {"breite": br, "hoehe": ho, "plaetze": l}
voll = {
    "format": 1, "studio": "0.2.0", "funke": "X18RS", "modell": "Testmodell Ö", "luaVersion": "0.3.0",
    "einstellungen": {"modell": 2, "a2_s": 3, "kap": 2200, "th_ab": 1.5, "start_h": 15, "sprache": 1, "sw1_name": "Schlepp",
                      "sw1_inv": True, "skala": 4, "zeit_alle": 5},
    "werte": {"lua:hoehe": {"faktor": 1.0, "versatz": 0, "einheit": "m", "stellen": 0},
              "sensor:0830:0": {"faktor": 0.5, "einheit": "km/h", "stellen": 1, "name": "Speed GPS"},
              "lua:vario": {"stellen": 2}},
    "grenzen": {"lua:hoehe": {"warnung": 180, "alarm": 200}, "lua:antrieb_proz": {"warnung": 35},
                "lua:akku1_zelle": {"aus": True}, "lua:empfang": {"richtung": "unter", "warnung": 40, "alarm": 30, "vibration": False},
                "sensor:0200:0": {"richtung": "ueber", "warnung": 40, "alarm": 60}, "lua:speed": {"richtung": "ueber", "alarm": 150},
                "kanal:3": {"richtung": "ueber", "warnung": 90}},
    "ansichten": [ansicht(784, 316, 36), ansicht(800, 480, 82)],
}
schreibe("voll.lua", voll)
import re
o = re.sub(r'"[^"]*"', '""', (hier / "voll.lua").read_text())
n = o.count(",") + o.count("=") + o.count("{")
print("voll.lua: %d Byte, %d Elemente, %d Tabellen" % (len(o.encode()), n, o.count("{")))
assert n <= 1100 and o.count("{") <= 240 and (hier / "voll.lua").stat().st_size <= 15 * 1024
# Fehlerhafte Felder: jede Art einmal (das Lua muss sie einzeln verwerfen, nie abstürzen)
falsch = {
    "format": 1,
    "einstellungen": {"modell": 7, "kap": -5, "th_ab": "x", "sw1_name": True, "unbekannt": 3, "a1_rolle": 1.5},
    "werte": {"lua:gibtsnicht": {"faktor": 2}, "sensor:0a10:0": {"faktor": 2}, "lua:hoehe": {"faktor": 0.00001, "stellen": 7}},
    "grenzen": {"lua:hoehe": {"richtung": "unter", "warnung": 100}, "lua:empfang": {"warnung": 30, "alarm": 40},
                "sensor:0100:0": {"warnung": 5}, "kanal:99": {"richtung": "ueber", "alarm": 1}},
    "ansichten": [{"breite": 784, "hoehe": 316, "plaetze": [
        platz(0, 0, 50, 20, "lua:vario", "zahl"), platz(700, 0, 100, 100, "lua:vario", "zahl"),
        platz(0, 40, 200, 120, "lua:vario", "tacho"), platz(0, 40, 200, 120, "lua:hoehe_max", "ring"),
        platz(200, 40, 200, 120, "lua:vario", "kurve"), platz(400, 40, 200, 120, "lua:hoehe", "kurve"),
        platz(600, 40, 180, 120, "lua:vario_mittel", "kurve"), platz(0, 170, 200, 100, "lua:vario", "zahl", titel="X" * 40,
        farbe=[300, 0, 0], zusatz="oft", kurveS=5, stufen=[{"ab": 5, "farbe": [1, 2, 3]}, {"ab": 1, "farbe": [1, 2, 3]}], min=5, max=1)]},
        {"breite": 50, "hoehe": 50, "plaetze": []}, {"breite": 800, "hoehe": 480, "plaetze": []}],
}
schreibe("falsch.lua", falsch)
schreibe("leer.lua", {"format": 1})
print("geschrieben: voll.lua, falsch.lua, leer.lua")

# Beispiel für Anleitung und Bilder: eigene Belegung ohne Überlappung, Kompakt 784 x 316 und Vollbild 800 x 480
def p(x, y, b, h, w, d, **k): return platz(x, y, b, h, w, d, **k)
kompakt = {"breite": 784, "hoehe": 316, "plaetze": [
    p(5, 41, 290, 135, "lua:vario", "kurve", kurveS=120),
    p(300, 41, 189, 135, "lua:hoehe", "ring", zusatz="max"),
    p(494, 41, 140, 135, "lua:antrieb_proz", "balken_s", stufen=[{"ab": 0, "farbe": [239, 68, 68]}, {"ab": 30, "farbe": [245, 158, 11]}, {"ab": 50, "farbe": [34, 197, 94]}]),
    p(639, 41, 140, 135, "lua:thermik_gewinn", "balken_s", max=200),
    p(5, 181, 194, 62, "lua:flugzeit", "zahl"),
    p(204, 181, 189, 62, "lua:vario_mittel", "zahl"),
    p(398, 181, 189, 62, "lua:ausklinkhoehe", "zahl"),
    p(592, 181, 187, 62, "lua:zustand", "status"),
    p(5, 248, 388, 62, "lua:empf_u", "balken_w", min=4, max=8.4),
    p(398, 248, 189, 62, "lua:speed", "zahl"),
    p(592, 248, 187, 62, "lua:phase_zeit", "zahl"),
]}
voll_b = {"breite": 800, "hoehe": 480, "plaetze": [
    p(6, 82, 390, 200, "lua:vario", "kurve", kurveS=180),
    p(402, 82, 194, 200, "lua:hoehe", "ring", zusatz="max"),
    p(602, 82, 192, 200, "lua:antrieb_proz", "ring"),
    p(6, 288, 260, 90, "lua:thermik_gewinn", "zahl", titel="Thermik"),
    p(272, 288, 260, 90, "lua:vario_mittel", "zahl", zusatz="max"),
    p(538, 288, 256, 90, "lua:motor", "status"),
    p(6, 384, 390, 90, "lua:empf_u", "balken_w", min=4, max=8.4),
    p(402, 384, 392, 90, "lua:flugzeit", "zahl"),
]}
schreibe("beispiel.lua", {"format": 1, "studio": "0.2.0", "einstellungen": {"modell": 2},
    "grenzen": {"lua:hoehe": {"warnung": 400, "alarm": 450}}, "ansichten": [kompakt, voll_b]})
print("geschrieben: beispiel.lua")
