"""units.xml -> godot/assets/data/bestiary.json for the PipBuck Enemies page (PipPageInfo PAGE_ENEMIES).

Rows keep the units.xml order of every unit with a cat. Stats are the getParam
lookups of infoUnit (own value, else the parent's); weapons carry their
char damage + damexpl from weapons.xml.
"""

import json
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "original" / "reference" / "Remains-Source2" / "Modules" / "core" / "AllData"
OUT = ROOT / "godot" / "assets" / "data" / "bestiary.json"

PARAMS = [("comb", "hp"), ("comb", "skin"), ("comb", "aqual"), ("comb", "armor"), ("comb", "marmor"),
          ("comb", "dexter"), ("comb", "skill"), ("comb", "observ"), ("vis", "visdam"), ("comb", "damage"),
          ("comb", "tipdam"), ("vis", "sdamage"), ("vis", "stipdam"), ("vis", "dkill")]
VULNER = ["bul", "blade", "phis", "fire", "expl", "laser", "plasma", "venom", "emp", "spark", "acid", "cryo"]


def main():
    units = ET.parse(DATA / "units.xml").getroot().findall("unit")
    by_id = {u.get("id"): u for u in units}
    weap = {}
    for w in ET.parse(DATA / "weapons.xml").getroot().iter("weapon"):
        ch = w.find("char")
        if ch is not None:
            weap[w.get("id")] = sum(max(0.0, float(ch.get(k) or 0)) for k in ("damage", "damexpl"))
    rows = []
    for u in units:
        cat = u.get("cat")
        if not cat:
            continue
        row = {"id": u.get("id"), "cat": cat}
        if cat == "3":
            parent = by_id.get(u.get("parent", ""))
            stats = {}
            for node, attr in PARAMS:
                for src in (u, parent):
                    if src is None:
                        continue
                    el = src.find(node)
                    if el is not None and el.get(attr) is not None:
                        stats[attr] = el.get(attr)
                        break
            row["stats"] = stats
            row["comb"] = u.find("comb") is not None
            guns = []
            for w in u.findall("w"):
                if float(w.get("no", 0) or 0) > 0:
                    continue
                guns.append([w.get("id"), weap.get(w.get("id"))])
            row["w"] = guns
            vul = u.find("vulner")
            if vul is not None:
                row["vulner"] = [[i, float(vul.get(k))] for i, k in enumerate(VULNER) if vul.get(k) is not None]
        rows.append(row)
    OUT.write_text(json.dumps({"units": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(rows), "rows")


if __name__ == "__main__":
    main()
