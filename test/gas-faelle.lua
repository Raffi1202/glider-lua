-- Feste Fälle für «Gas umkehren» (0.7.1), auf dem Mac ohne Simulator.
-- Aufruf im Skriptordner: cd src/glider && /opt/homebrew/opt/lua@5.4/bin/lua ../../test/gas-faelle.lua
local K = assert(loadfile("kern.lua"))()
local g = assert(K._gasProzent, "K._gasProzent fehlt")
local fehler = 0
local function fall(titel, ist, soll)
  local gut = ist == soll
  print((gut and "OK    " or "FEHLER") .. "  " .. titel .. "  (" .. tostring(ist) .. ")")
  if not gut then fehler = fehler + 1 end
end
fall("aus: Knüppel unten = 0 %", g({ gasInv = false }, 0), 0)
fall("aus: Knüppel oben = 100 %", g({}, 100), 100)
fall("an: Knüppel unten = 100 %", g({ gasInv = true }, 0), 100)
fall("an: Knüppel oben = 0 %", g({ gasInv = true }, 100), 0)
fall("an: 30 % -> 70 %", g({ gasInv = true }, 30), 70)
fall("an: kein Geber bleibt nil", g({ gasInv = true }, nil), nil)
local F = assert(loadfile("felder.lua"))()
fall("Werkwert aus", F.standard().gasInv, false)
local da = false
for _, n in ipairs(F.folge) do if n == "gasInv" then da = true end end
fall("Feld in der Speicherreihenfolge (Datei)", da, true)
print(fehler == 0 and "ERGEBNIS: kein Fehler" or ("ERGEBNIS: " .. fehler .. " Fehler"))
os.exit(fehler == 0 and 0 or 1)
