import json
from pathlib import Path
p = json.loads((Path(__file__).resolve().parents[2] / r"godot\assets\data\enemies.json").read_text(encoding="utf-8"))
units = p["units"]
print("count", len(units))
ids = ["raider1","raider2","raider5","raider9","protect","protect1","scorp1","scorp3","tarakan","ant1","ant3","gutsy","eqd","hellhound1","alicorn1","bossencl","bossencl3","zombie0","zombie1","merc1","encl1","necros","phoenix","owl","zebra1","ranger1"]
for uid in ids:
    u = units[uid]
    print(uid, u["fight"], "hp", u["hp"], "dmg", u["damage"], u["damage_type"], "cell", u["cell"], "spd", u["speed"], u["run"], "hold", u["hold"], u["backoff"], "rng", u["hold_range"], "weap", u["weapon"], "move", u["move_clip"], "nclips", len(u["clips"]))
