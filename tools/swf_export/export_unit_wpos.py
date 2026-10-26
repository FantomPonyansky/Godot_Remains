"""BlitAnim.wPosRaider1/2 and the units.xml fields UnitRaider reads for its weapon.

Out: godot/assets/data/raider_wpos.json
  wpos: {"m": [[[x, y, r], ...] per frame] per anim row, "w": ...}
  units: {id: {"sex": "m"|"w", "telecolor": "RRGGBB" or "", "enclweap": bool}}
"""
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BLIT = ROOT / "original/decompiled_2021/new/scripts/fe/serv/BlitAnim.as"
UNITS = ROOT / "original/reference/Remains-Source2/Modules/core/AllData/units.xml"
OUT = ROOT / "godot/assets/data/unit_wpos.json"
TABLES = {
    "raider_m": "wPosRaider1", "raider_w": "wPosRaider2", "zebra": "wPosZebra1",
    "ranger": "wPosRanger1", "encl": "wPosEncl1", "griffon": "wPosGriffon1",
    "gutsy": "wPosGutsy", "alicorn": "wPosAlicorn", "alicorn_boss": "wPosAlicornBoss",
}


def table(src: str, name: str) -> list:
    start = src.index("public static var %s:Array = " % name) + len("public static var %s:Array = " % name)
    depth = 0
    for i in range(start, len(src)):
        if src[i] == "[":
            depth += 1
        elif src[i] == "]":
            depth -= 1
            if depth == 0:
                body = src[start:i + 1]
                break
    body = re.sub(r'"(\w+)":', r'"\1":', body)
    rows = json.loads(body)
    return [[[p.get("x", 0), p.get("y", 0), p.get("r", 0)] for p in row] for row in rows]


def units() -> dict:
    tree = ET.parse(UNITS)
    nodes = {u.get("id"): u for u in tree.getroot().iter("unit") if u.get("id")}
    out = {}

    def field(uid, tag, attr, seen=()):
        node = nodes.get(uid)
        if node is None or uid in seen:
            return None
        for child in node.findall(tag):
            if child.get(attr) is not None:
                return child.get(attr)
        parent = node.get("parent")
        return field(parent, tag, attr, seen + (uid,)) if parent else None

    for uid in nodes:
        tele = field(uid, "vis", "telecolor") or ""
        if tele.startswith("0x"):
            tele = tele[2:]
        out[uid] = {
            "sex": "w" if field(uid, "vis", "sex") == "w" else "m",
            "telecolor": tele.upper().rjust(6, "0") if tele else "",
            "enclweap": bool(field(uid, "un", "enclweap")),
            "walker": bool(field(uid, "un", "walker")),
            "flyer": bool(field(uid, "un", "flyer")),
        }
    return out


def main() -> None:
    src = BLIT.read_text(encoding="utf-8")
    data = {
        "source": "BlitAnim.wPos*: [x, y, r] per anim row and frame, blit-cell px (raider_m = wPosRaider1, raider_w = wPosRaider2). units.xml vis sex/telecolor, un enclweap (with parents).",
        "wpos": {key: table(src, name) for key, name in TABLES.items()},
        "units": units(),
    }
    OUT.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    print({k: [len(r) for r in v] for k, v in data["wpos"].items()}, "units", len(data["units"]))


if __name__ == "__main__":
    main()
