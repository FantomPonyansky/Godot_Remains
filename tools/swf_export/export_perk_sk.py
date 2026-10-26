"""Copy each perk's <sk> rows from perks.xml into godot/assets/data/perks.json.

Pers.setSkillParam reads them: v0 is the rank-0 value (0 for ref add or tip res,
1 for ref mult), vd adds per rank, else v<rank> or v1. Existing perk keys stay.
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
XML = ROOT / "original" / "reference" / "Remains-Source2" / "Modules" / "core" / "AllData" / "perks.xml"
OUT = ROOT / "godot" / "assets" / "data" / "perks.json"


def main():
    xml = XML.read_text(encoding="utf-8")
    rows = {}
    for m in re.finditer(r"<perk id='([^']+)'[^>]*>(.*?)</perk>", xml, re.S):
        sks = []
        for s in re.finditer(r"<sk\b([^>]*)/>", m.group(2)):
            attrs = dict(re.findall(r"(\w+)='([^']*)'", s.group(1)))
            row = {"id": attrs["id"]}
            for key in ("tip", "ref"):
                if key in attrs:
                    row[key] = attrs[key]
            for key in ("v0", "vd"):
                if key in attrs:
                    row[key] = float(attrs[key])
            ranks = []
            n = 1
            while "v%d" % n in attrs:
                ranks.append(float(attrs["v%d" % n]))
                n += 1
            if ranks:
                row["v"] = ranks
            sks.append(row)
        rows[m.group(1)] = sks
    data = json.loads(OUT.read_text(encoding="utf-8"))
    for perk in data["perks"]:
        if perk["id"] in rows:
            perk["sk"] = rows[perk["id"]]
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(sum(1 for p in data["perks"] if "sk" in p), "perks with sk")


if __name__ == "__main__":
    main()
