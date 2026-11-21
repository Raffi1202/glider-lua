#!/usr/bin/env python3
# Erzeugt src/glider/werte.lua aus studio/beschreibung.json, damit Lua und Studio dieselben Werte kennen.
# Aufruf im Repo-Ordner: python3 studio/werte_erzeugen.py
import json, pathlib
r = pathlib.Path(__file__).resolve().parent.parent
d = json.loads((r / "studio" / "beschreibung.json").read_text(encoding="utf-8"))
def s(t): return '"' + str(t).replace('\\', '\\\\').replace('"', '\\"') + '"'
def zahl(x): return repr(x) if isinstance(x, float) else str(x)
z = ["-- Glider: Werte für die Studio-Plätze (Lua-Studio-Format v1). ERZEUGT aus studio/beschreibung.json mit",
     "-- studio/werte_erzeugen.py, nicht von Hand ändern. Felder: [1] Name de, [2] Name en, [3] Einheit, [4] Stellen,",
     "-- [5] min, [6] max, [7] erlaubte Darstellungen, [8] Richtung der Grenze, [9] Zeit (m:ss), zst = Zustände,",
     "-- lauf = laufender Titel. Nur beim Prüfen der Studio-Datei und beim Zeichnen der Plätze geladen.",
     "return {"]
for w in d["werte"]:
    dar = "{ " + ", ".join(f"{x} = true" for x in w["darstellungen"]) + " }"
    teile = [s(w["name"]["de"]), s(w["name"]["en"]), s(w.get("einheit", "")), str(w.get("stellen", 0)),
             zahl(w.get("min", 0)), zahl(w.get("max", 100)), dar, s(w["grenzeRichtung"]) if "grenzeRichtung" in w else "nil",
             "true" if w.get("zeit") else "false"]
    extra = ""
    if "zustaende" in w:
        extra += ", zst = { " + ", ".join("[%d] = { %s, %s, { %d, %d, %d } }" % (x["wert"], s(x["de"]), s(x["en"]), *x["farbe"]) for x in w["zustaende"]) + " }"
    if "titelLaufend" in w: extra += ", lauf = true"
    z.append(f"  {w['s']} = {{ {', '.join(teile)}{extra} }},")
z.append("}")
(r / "src" / "glider" / "werte.lua").write_text("\n".join(z) + "\n", encoding="utf-8")
print("werte.lua:", len(d["werte"]), "Werte")
