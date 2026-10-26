"""Unit combat/boss music from AllData/units.xml into godot/assets/data/music.json.

Unit.getXmlParam reads <snd music musicp> from the family first, then the unit
itself, so a unit inherits its parent's track. musicp defaults to 1 when a
music attribute is present (Unit.sndMusicPrior).
"""
import json
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UNITS = ROOT / "original" / "reference" / "Remains-Source2" / "Modules" / "core" / "AllData" / "units.xml"
OUT = ROOT / "godot" / "assets" / "data" / "music.json"


def main() -> None:
    root = ET.fromstring(UNITS.read_text(encoding="utf-8"))
    rows = {u.attrib["id"]: u for u in root.iter("unit") if "id" in u.attrib}

    def own(uid: str) -> tuple:
        snd = rows[uid].find("snd")
        if snd is None:
            return None, None
        music = snd.attrib.get("music")
        prior = snd.attrib.get("musicp")
        return music, (int(prior) if prior else (1 if music else None))

    out = {}
    for uid in rows:
        chain = []
        at = uid
        while at in rows and at not in chain:
            chain.append(at)
            at = rows[at].attrib.get("parent", "")
        music, prior = None, 0
        for step in reversed(chain):
            m, p = own(step)
            if m:
                music = m
            if p is not None:
                prior = p
        if music:
            out[uid] = [music, prior]
    OUT.write_text(json.dumps({"units": dict(sorted(out.items()))}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("units with music", len(out))


if __name__ == "__main__":
    main()
