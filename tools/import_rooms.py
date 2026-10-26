"""Import the 2021 (1.0.2) room files into one JSON file per land.

Reads `original/release_2021/FoE - Remains/Rooms/rooms_<land>.xml` directly;
the file name is the land. The 2021 LandLoader loads these external files
(World.roomsLoad = 1). Plant and sewer are the exception: the shipped
rooms_plant.xml / rooms_sewer.xml are stale 2018 files, so those two come from
the fixed documents embedded in the 2021 pfe.swf (original/decompiled_2021/docs_new).

Writes godot/assets/data/maps/rooms/<file>.json and index.json.
Run with --check to report differences against the current JSON without writing.
"""
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROOMS = ROOT / "original" / "release_2021" / "FoE - Remains" / "Rooms"
EMBEDDED = {
    "rooms_plant": ROOT / "original" / "decompiled_2021" / "docs_new" / "22.xml",
    "rooms_sewer": ROOT / "original" / "decompiled_2021" / "docs_new" / "21.xml",
}
LANDS = ROOT / "original" / "reference" / "Remains-Source2" / "Modules" / "core" / "GameData" / "Lands.xml"
OBJS = ROOT / "original" / "reference" / "Remains-Source2" / "Modules" / "core" / "AllData" / "objs.xml"
OUT = ROOT / "godot" / "assets" / "data" / "maps" / "rooms"


def load_obj_kinds():
    root = ET.fromstring(OBJS.read_text(encoding="utf-8"))
    up = set()
    loot = set()
    size = {}
    for node in root.iter("obj"):
        oid = node.attrib.get("id")
        if not oid:
            continue
        size[oid] = int(node.attrib.get("size") or 1)
        if node.attrib.get("tip") == "up":
            up.add(oid)
        if node.attrib.get("cont"):
            loot.add(oid)
    return up, loot, size


def land_files() -> list:
    root = ET.fromstring(LANDS.read_text(encoding="utf-8"))
    return sorted({land.attrib["file"] for land in root.findall("land") if land.attrib.get("file")})


def kind_of(oid: str, up: set, loot: set) -> str:
    if oid in up:
        return "up"
    if oid in loot:
        return "loot"
    return ""


def _node(el: ET.Element) -> dict:
    out = {"tag": el.tag}
    if el.attrib:
        out["attrs"] = dict(el.attrib)
    kids = [_node(k) for k in el]
    if kids:
        out["kids"] = kids
    return out


def room_to_dict(room: ET.Element, up: set, loot: set, size: dict) -> dict:
    rows = [a.text or "" for a in room.findall("a")]
    options = {}
    opt = room.find("options")
    if opt is not None:
        options = dict(opt.attrib)
    doors = None
    door = room.find("doors")
    if door is not None and door.text:
        doors = [int(p) if p.strip().lstrip("-").isdigit() else 0 for p in door.text.split(".")]
    objs = []
    for tag in ("obj", "back"):
        for node in room.findall(tag):
            oid = node.attrib.get("id", "")
            entry = {
                "tag": tag,
                "id": oid,
                "x": int(node.attrib.get("x") or 0),
                "y": int(node.attrib.get("y") or 0),
                "size": size.get(oid, 1),
            }
            kind = kind_of(oid, up, loot) if tag == "obj" else ""
            if kind:
                entry["kind"] = kind
            extra = {k: v for k, v in node.attrib.items() if k not in ("id", "x", "y")}
            if extra:
                entry["attrs"] = extra
            kids = [_node(k) for k in node]
            if kids:
                entry["kids"] = kids
            objs.append(entry)
    out = {
        "name": room.attrib.get("name", ""),
        "rows": rows,
        "objs": objs,
    }
    for axis in ("x", "y", "z"):
        if axis in room.attrib:
            out[axis] = int(room.attrib.get(axis) or 0)
    if options:
        out["options"] = options
    if doors is not None:
        out["doors"] = doors
    return out


def source_of(name: str) -> tuple:
    if name in EMBEDDED:
        return EMBEDDED[name], "2021 pfe.swf embedded fe.rooms document (fixed; shipped Rooms/%s.xml is stale)" % name
    return ROOMS / ("%s.xml" % name), "2021 Rooms/%s.xml" % name


def build(name: str, up, loot, size) -> dict:
    path, note = source_of(name)
    root = ET.fromstring(path.read_text(encoding="utf-8"))
    land = root.find("land")
    return {
        "file": name,
        "source": note,
        "placed": land is not None and land.attrib.get("serial") == "1",
        "rooms": [room_to_dict(r, up, loot, size) for r in root.findall("room")],
    }


def _canon(value) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def keep_order(old: dict, new: dict) -> None:
    """The swf documents and the external files list the same rooms and objects
    in different orders. Where only the order differs, keep the current order:
    land_gen draws random-land plans from the room list with a saved seed, so a
    reorder alone would change every saved random land."""
    old_rooms = {r["name"]: r for r in old.get("rooms", [])}
    for room in new["rooms"]:
        prev = old_rooms.get(room["name"])
        if prev is None or prev == room:
            continue
        if sorted(map(_canon, prev.get("objs", []))) == sorted(map(_canon, room.get("objs", []))):
            room["objs"] = prev["objs"]
    rank = {r["name"]: i for i, r in enumerate(old.get("rooms", []))}
    if len(rank) == len(old.get("rooms", [])):
        fresh = len(rank)
        new["rooms"].sort(key=lambda r: rank.get(r["name"], fresh))


def summarize(old: dict, new: dict) -> str:
    old_rooms = {r["name"]: r for r in old.get("rooms", [])}
    new_rooms = {r["name"]: r for r in new.get("rooms", [])}
    added = [n for n in new_rooms if n not in old_rooms]
    gone = [n for n in old_rooms if n not in new_rooms]
    edited = [n for n in new_rooms if n in old_rooms and new_rooms[n] != old_rooms[n]]
    order = [r["name"] for r in old.get("rooms", [])] != [r["name"] for r in new.get("rooms", [])]
    return "rooms %d->%d added=%s removed=%s edited=%d%s" % (
        len(old_rooms), len(new_rooms), added, gone, len(edited), " reordered" if order else "")


def main() -> None:
    check = "--check" in sys.argv
    up, loot, size = load_obj_kinds()
    names = land_files()
    OUT.mkdir(parents=True, exist_ok=True)
    for name in names:
        new = build(name, up, loot, size)
        path = OUT / ("%s.json" % name)
        old = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
        keep_order(old, new)
        same = {k: v for k, v in old.items() if k != "source"} == {k: v for k, v in new.items() if k != "source"}
        tests = [r["name"] for r in new["rooms"] if (r.get("options") or {}).get("test") == "1"]
        print("%-16s %s%s" % (name, "same" if same else summarize(old, new), " test=%s" % tests if tests else ""))
        if not check:
            path.write_text(json.dumps(new, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    if not check:
        (OUT / "index.json").write_text(json.dumps({"files": names}, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
