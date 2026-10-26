"""Pull begin-land actors out of the rooms_begin document inside pfe.swf."""
import json
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SWF = ROOT / "original" / "swf" / "pfe.swf"
OBJS = ROOT / "original" / "reference" / "Remains-Source2" / "Modules" / "core" / "AllData" / "objs.xml"
DIALOGUES = ROOT / "original" / "reference" / "Remains-Source2" / "Modules" / "core" / "Language" / "English" / "dialogues.json"
OUT = ROOT / "godot" / "assets" / "data" / "maps" / "begin_actors.json"

TILE = 40
ROOM_X = 48
ROOM_Y = 25

# Species this slice can place. Speeds are px/s (units.xml px/tick * 30).
# scorp on the map is the family id; the original rolls scorp1-3. This uses scorp1.
SPECIES = {
    "tarakan": {"hp": 8, "xp": 10, "damage": 4, "speed": 36, "run": 120, "body": [30, 20], "fight": "melee", "diff": 5, "tint": [0.45, 0.32, 0.18]},
    "rat": {"hp": 15, "xp": 20, "damage": 6, "speed": 75, "run": 180, "body": [40, 20], "fight": "melee", "diff": 6, "tint": [0.55, 0.52, 0.48]},
    "molerat": {"hp": 34, "xp": 60, "damage": 10, "speed": 60, "run": 240, "body": [55, 40], "fight": "melee", "diff": 45, "tint": [0.42, 0.28, 0.22]},
    "scorp": {"hp": 40, "xp": 100, "damage": 7, "speed": 45, "run": 150, "body": [70, 39], "fight": "melee", "diff": 35, "tint": [0.35, 0.55, 0.28]},
    "bloat": {"hp": 12, "xp": 20, "damage": 8, "speed": 150, "run": 150, "body": [30, 30], "fight": "melee", "diff": 10, "tint": [0.72, 0.35, 0.55]},
    "turret": {"hp": 46, "xp": 80, "damage": 10, "speed": 0, "run": 0, "body": [38, 38], "fight": "turret", "diff": 250, "tint": [0.62, 0.64, 0.66], "fixed": True},
    "ebloat": {"hp": 300, "xp": 1000, "damage": 30, "speed": 0, "run": 0, "body": [80, 100], "fight": "melee", "diff": 500, "tint": [0.55, 0.20, 0.35], "fixed": True},
}

# Door-relevant steps from Scripts.xml. Dialogue, blackouts, and armor stay out.
NAMED = {
    "beginBeg": [{"act": "mess", "val": "trWalk"}, {"act": "off", "targ": "this"}],
    "beginMtn": [{"act": "unlock", "targ": "begDoor"}, {"act": "off", "targ": "this"}],
    "beginLevit": [
        {"act": "perk", "val": "levitation"},
        {"act": "mess", "val": "perkLevit"},
        {"act": "on", "targ": "trLevit"},
        {"act": "off", "targ": "this"},
    ],
    "beginUp": [{"act": "on", "targ": "trCrossroad"}, {"act": "off", "targ": "this"}],
    "beginStory": [{"act": "off", "targ": "this"}],
}


def room_doc(data: bytes) -> ET.Element:
    search = 0
    while True:
        at = data.find(b"beginBeg", search)
        if at < 0:
            raise SystemExit("beginBeg not in pfe.swf")
        start = data.rfind(b"<all>", 0, at)
        end = data.find(b"</all>", at)
        head = data[start : start + 180]
        if b'<room name="' in head:
            blob = data[start : end + 6].replace(b"\x00", b"")
            return ET.fromstring(blob.decode("utf-8"))
        search = at + 1


def obj_defs() -> dict:
    root = ET.fromstring(OBJS.read_text(encoding="utf-8"))
    out = {}
    for node in root.iter("obj"):
        oid = node.attrib.get("id")
        if not oid:
            continue
        out[oid] = node.attrib
    return out


def messages() -> dict:
    raw = json.loads(DIALOGUES.read_text(encoding="utf-8"))
    found = {}

    def walk(node):
        if isinstance(node, dict):
            if "Key" in node and "Lines" in node:
                lines = node.get("Lines") or []
                text = ""
                if lines and isinstance(lines[0], dict):
                    text = str(lines[0].get("text") or "")
                text = text.replace("[br]", " ").replace("<br>", " ")
                for i in range(1, 6):
                    token = str(node.get("s%d" % i) or "")
                    label = token[3:] if token.startswith("key") else token
                    text = text.replace("@%d" % i, label)
                found[str(node["Key"])] = " ".join(text.split())
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(raw)
    return found


def steps_of(obj: ET.Element) -> list:
    named = obj.attrib.get("scr")
    if named:
        if named in NAMED:
            return [dict(step) for step in NAMED[named]]
        return [{"act": "notice", "val": named}]
    out = []
    for scr in obj.findall("scr"):
        if scr.attrib.get("act"):
            out.append({k: scr.attrib[k] for k in ("act", "targ", "val", "eve") if k in scr.attrib})
        for child in scr.findall("s"):
            out.append({k: child.attrib[k] for k in ("act", "targ", "val") if k in child.attrib})
    return out


def num(text, default=0.0) -> float:
    if text is None or text == "":
        return default
    return float(text)


def feet(rx, ry, ox, oy, size) -> list:
    return [
        int((rx * ROOM_X + ox + 0.5 * size) * TILE),
        int((ry * ROOM_Y + oy + 1) * TILE - 1),
    ]


def main():
    root = room_doc(SWF.read_bytes())
    defs = obj_defs()
    text = messages()
    units = []
    hazards = []
    traps = []
    loot = []
    buttons = []
    areas = []
    doors = []

    for room in root.iter("room"):
        rx = int(room.attrib.get("x", "0"))
        ry = int(room.attrib.get("y", "0"))
        for obj in room.findall("obj"):
            oid = obj.attrib.get("id", "")
            defin = defs.get(oid, {})
            tip = defin.get("tip", "")
            ox = int(obj.attrib.get("x", "0"))
            oy = int(obj.attrib.get("y", "0"))
            size = int(obj.attrib.get("w") or defin.get("size") or 1)
            wid = int(obj.attrib.get("h") or defin.get("wid") or 1)
            if size < 1:
                size = 1
            if wid < 1:
                wid = 1
            uid = obj.attrib.get("uid", "")
            actions = steps_of(obj)
            if tip == "unit":
                record = {
                    "id": oid,
                    "uid": uid,
                    "room": [rx, ry],
                    "cell": [ox, oy],
                    "feet": feet(rx, ry, ox, oy, size),
                    "actions": [step for step in actions if step.get("eve") in (None, "", "die")],
                }
                if oid in ("expl1", "trap"):
                    record["damage"] = 40 if oid == "expl1" else 20
                    record["radius"] = 90 if oid == "expl1" else 0
                    hazards.append(record)
                else:
                    spec = SPECIES.get(oid, {"hp": 20, "xp": 10, "damage": 6, "speed": 60, "run": 90, "body": [40, 30], "fight": "melee", "diff": 20, "tint": [0.7, 0.7, 0.7]})
                    record.update(spec)
                    units.append(record)
            elif tip == "trap":
                traps.append({
                    "id": oid,
                    "room": [rx, ry],
                    "cell": [ox, oy],
                    "feet": feet(rx, ry, ox, oy, 1),
                    "damage": int(num(defin.get("damage"), 15)),
                    "ceiling": oid == "fspikes",
                })
            elif tip == "door" or int(defin.get("door") or 0) > 0:
                opened = obj.attrib.get("open") == "1"
                if "lock" in obj.attrib:
                    lock = num(obj.attrib.get("lock"), 0)
                elif opened:
                    # setAct("open") clears the template lock when the map does not set one.
                    lock = 0
                else:
                    lock = num(defin.get("lock"), 0)
                if "inter" in obj.attrib:
                    usable = obj.attrib.get("inter") not in ("0", "")
                else:
                    usable = defin.get("inter", "0") not in ("0", "")
                doors.append({
                    "id": oid,
                    "uid": uid,
                    "room": [rx, ry],
                    "cell": [ox, oy],
                    "lock": lock,
                    "open": obj.attrib.get("open") == "1",
                    "usable": usable,
                })
            elif tip == "area":
                w = int(obj.attrib.get("w") or 2)
                h = int(obj.attrib.get("h") or 2)
                left = (rx * ROOM_X + ox) * TILE
                bottom = (ry * ROOM_Y + oy + 1) * TILE
                mess = obj.attrib.get("mess", "")
                areas.append({
                    "uid": uid,
                    "room": [rx, ry],
                    "rect": [left, bottom - h * TILE, w * TILE, h * TILE],
                    "enabled": obj.attrib.get("off") != "1",
                    "once": obj.attrib.get("trig") == "1" or any(step.get("act") == "off" and step.get("targ") == "this" for step in actions),
                    "mess": text.get(mess, ""),
                    "actions": actions,
                })
            elif tip == "box":
                items = []
                for item in obj.findall("item"):
                    items.append({"id": item.attrib.get("id", ""), "n": int(item.attrib.get("kol") or 1)})
                if "lock" in obj.attrib:
                    lock = num(obj.attrib.get("lock"), 0)
                else:
                    lock = num(defin.get("lock"), 0)
                spot = feet(rx, ry, ox, oy, size)
                if oid.startswith("knop") or oid == "detonator" or (not items and actions):
                    buttons.append({
                        "id": oid,
                        "uid": uid,
                        "room": [rx, ry],
                        "feet": spot,
                        "bullet": oid == "knop2",
                        "actions": actions,
                    })
                else:
                    loot.append({
                        "id": oid,
                        "uid": uid,
                        "room": [rx, ry],
                        "feet": spot,
                        "w": size * TILE,
                        "h": wid * TILE,
                        "lock": lock,
                        "items": items,
                        "actions": actions,
                    })

    # Attach the line a mess action should show.
    for bucket in (areas, buttons, loot, units, hazards):
        for record in bucket:
            for step in record.get("actions", []):
                if step.get("act") == "mess":
                    step["text"] = text.get(step.get("val", ""), "")

    payload = {
        "source": "pfe.swf rooms_begin objects. Room 0,0 has no unit tags.",
        "tile_px": TILE,
        "units": units,
        "hazards": hazards,
        "traps": traps,
        "loot": loot,
        "buttons": buttons,
        "areas": areas,
        "doors": doors,
        "messages": {key: text[key] for key in text if key.startswith("tr") or key.startswith("perk")},
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print("units", len(units), "room00", sum(1 for u in units if u["room"] == [0, 0]))
    print("hazards", len(hazards), "traps", len(traps), "loot", len(loot), "buttons", len(buttons), "areas", len(areas), "doors", len(doors))
    print("open doors", sum(1 for d in doors if d["open"]), "locked", sum(1 for d in doors if d["lock"] > 0 and not d["open"]))
    from collections import Counter
    print("species", Counter(u["id"] for u in units))


if __name__ == "__main__":
    main()
