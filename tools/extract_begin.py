"""Extract land id begin (rooms_begin) from the uncompressed pfe.swf binary."""
import json
import struct
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SWF = ROOT / "original" / "swf" / "pfe.swf"
PIECES = ROOT / "original" / "reference" / "Remains-Source2" / "Modules" / "core" / "AllData" / "tilePieces.json"
OBJS = ROOT / "original" / "reference" / "Remains-Source2" / "Modules" / "core" / "AllData" / "objs.xml"
OUT = ROOT / "godot" / "assets" / "data" / "maps" / "begin_land.json"

TILE = 40
ROOM_X = 48
ROOM_Y = 25


def parse_swf(data: bytes):
    assert data[:3] == b"FWS", data[:3]
    pos = 8
    nbits = data[pos] >> 3
    total_bits = 5 + nbits * 4
    pos += (total_bits + 7) // 8
    pos += 4
    print("tags start", pos, "file", len(data))
    symbols = {}
    binaries = {}
    tag_counts = {}
    while pos + 2 <= len(data):
        code = struct.unpack_from("<H", data, pos)[0]
        pos += 2
        tag = code >> 6
        length = code & 0x3F
        if length == 0x3F:
            length = struct.unpack_from("<I", data, pos)[0]
            pos += 4
        end = pos + length
        tag_counts[tag] = tag_counts.get(tag, 0) + 1
        if end > len(data) or end < pos:
            print("bad tag", tag, "at", pos, "len", length)
            break
        if tag == 0:
            print("end tag at", pos, "symbols", len(symbols), "binaries", len(binaries))
            print("tag counts", dict(sorted(tag_counts.items())))
            break
        if tag == 76:
            count = struct.unpack_from("<H", data, pos)[0]
            p = pos + 2
            for _ in range(count):
                cid = struct.unpack_from("<H", data, p)[0]
                p += 2
                z = data.index(b"\x00", p)
                symbols[cid] = data[p:z].decode("utf-8", "replace")
                p = z + 1
        elif tag == 87:
            cid = struct.unpack_from("<H", data, pos)[0]
            binaries[cid] = data[pos + 6 : end]
        pos = end
    else:
        print("fell off end at", pos, "symbols", len(symbols), "binaries", len(binaries))
        print("tag counts", dict(sorted(tag_counts.items())))
    return symbols, binaries


def load_pieces():
    raw = json.loads(PIECES.read_text(encoding="utf-8"))
    blocks = {}
    overlays = {}
    for piece in raw["pieces"]:
        entry = {
            "id": piece["id"],
            "code": piece["code"],
            "behaviour": piece.get("behaviour", "none"),
            "layer": piece.get("layer", ""),
            "side": piece.get("side", ""),
            "texture": piece.get("texture", ""),
            "name": piece.get("name", ""),
        }
        if piece.get("layer") == "main":
            blocks[piece["code"]] = entry
        else:
            overlays[piece["code"]] = entry
    return blocks, overlays


def load_objs():
    # objs.xml may not be a single root-friendly file; wrap it.
    text = OBJS.read_text(encoding="utf-8")
    root = ET.fromstring(text)
    out = {}
    for node in root.iter("obj"):
        oid = node.attrib.get("id")
        if not oid:
            continue
        out[oid] = {
            "tip": node.attrib.get("tip", ""),
            "size": int(node.attrib.get("size") or 1),
            "wid": int(node.attrib.get("wid") or 1),
            "door": int(node.attrib.get("door") or 0),
            "phis": int(node.attrib.get("phis") or 1),
            "opac": float(node.attrib.get("opac") or 1),
            "inter": node.attrib.get("inter", "") == "1",
            "wall": int(node.attrib.get("wall") or 0),
        }
    return out


def add_piece(state, piece):
    beh = piece["behaviour"]
    if beh == "solid":
        state["collision"] = 1
        state["block"] = piece["code"]
        state["texture"] = piece.get("texture") or state["texture"]
        state["name"] = piece.get("name") or state["name"]
    elif beh == "platform":
        state["platform"] = True
        if not state["texture"]:
            state["texture"] = piece.get("texture") or ""
    elif beh == "ladder":
        state["ladder"] = piece.get("side") or "right"
    elif beh == "slope":
        state["slope"] = piece.get("side") or "right"
    elif beh == "hidingSpot":
        state["hiding"] = True


def decode(code: str, blocks, overlays):
    state = {
        "collision": 0,
        "platform": False,
        "ladder": "",
        "slope": "",
        "hiding": False,
        "height": 4,
        "block": "",
        "texture": "",
        "name": "",
        "code": code,
    }
    if not code:
        return state
    symbol = code[0]
    if symbol > "@" and symbol != "_":
        piece = blocks.get(symbol)
        if piece:
            add_piece(state, piece)
    for symbol in code[1:]:
        if symbol == "*":
            continue
        if symbol == ",":
            state["height"] = 3
        elif symbol == ";":
            state["height"] = 2
        elif symbol == ":":
            state["height"] = 1
        else:
            piece = overlays.get(symbol)
            if piece:
                add_piece(state, piece)
    return state


def mesh(cells, key_fn, allow_vertical: bool):
    """Greedy rectangles. Partial-height tiles must not merge vertically:
    each tile's box is the bottom of that cell, not one shortened column."""
    remaining = {pos: key_fn(payload) for pos, payload in cells.items()}
    rects = []
    for (x, y) in sorted(remaining):
        if (x, y) not in remaining:
            continue
        key = remaining.pop((x, y))
        w = 1
        while (x + w, y) in remaining and remaining[(x + w, y)] == key:
            remaining.pop((x + w, y))
            w += 1
        h = 1
        if allow_vertical:
            while True:
                row = [(x + dx, y + h) for dx in range(w)]
                if all(pos in remaining and remaining[pos] == key for pos in row):
                    for pos in row:
                        remaining.pop(pos)
                    h += 1
                else:
                    break
        rects.append((x, y, w, h, key))
    return rects


def main():
    data = SWF.read_bytes()
    # Room XML is an ABC string constant, not DefineBinaryData. The begin land is the
    # <all> document that contains both <room> tiles and the beginBeg trigger.
    hits = []
    search = 0
    while True:
        at = data.find(b"beginBeg", search)
        if at < 0:
            break
        start = data.rfind(b"<all>", 0, at)
        end = data.find(b"</all>", at)
        blob = data[start : end + 6]
        hits.append((at, start, end, b"<room " in blob, blob[:60]))
        search = at + 1
    print("beginBeg contexts", [(a, s, e, room) for a, s, e, room, _head in hits])
    room_hits = []
    for at, start, end, _room, _head in hits:
        head = data[start : start + 180]
        if b'<room name="' in head:
            room_hits.append((at, start, end))
    if len(room_hits) != 1:
        raise SystemExit("expected one authored room document containing beginBeg")
    _, start, end = room_hits[0]
    begin_blob = data[start : end + 6]
    begin_name = "rooms_begin"
    print("USING raw", start, end, "bytes", len(begin_blob))
    print("HEAD REPR", begin_blob[:80])
    xml_text = begin_blob.replace(b"\x00", b"").decode("utf-8")
    root = ET.fromstring(xml_text)
    blocks, overlays = load_pieces()
    obj_defs = load_objs()

    rooms_out = []
    solid_cells = {}
    platform_cells = {}
    slope_cells = []
    ladder_cells = {}
    door_cells = set()
    doors = []
    spawns = []
    units = []
    other_counts = {}
    unknown_codes = {}

    rooms = list(root.iter("room"))
    print("rooms", len(rooms))
    for room in rooms:
        rx = int(room.attrib.get("x", "0"))
        ry = int(room.attrib.get("y", "0"))
        rz = int(room.attrib.get("z", "0"))
        rows = [a.text or "" for a in room.findall("a")]
        if len(rows) != ROOM_Y:
            print("ROW COUNT", room.attrib.get("name"), len(rows))
        grid = []
        for j, row in enumerate(rows):
            cells = row.split(".")
            if len(cells) != ROOM_X:
                print("COL COUNT", room.attrib.get("name"), j, len(cells))
            decoded_row = []
            for i, code in enumerate(cells):
                state = decode(code, blocks, overlays)
                if code and code[0] > "@" and code[0] != "_" and code[0] not in blocks and code[0] not in ("*",):
                    unknown_codes[code] = unknown_codes.get(code, 0) + 1
                decoded_row.append(state)
                if rz != 0:
                    continue
                wx = rx * ROOM_X + i
                wy = ry * ROOM_Y + j
                if state["slope"]:
                    slope_cells.append({
                        "x": wx, "y": wy, "side": state["slope"], "height": state["height"],
                        "code": state["block"] or code,
                    })
                if state["ladder"]:
                    ladder_cells[(wx, wy)] = state["ladder"]
                if state["collision"] > 0 and not state["slope"]:
                    solid_cells[(wx, wy)] = (state["height"], state["block"] or code[:1], state["texture"], state["name"])
                elif state["platform"] and state["collision"] == 0 and not state["slope"]:
                    platform_cells[(wx, wy)] = (state["height"], state["texture"] or "platform")
            grid.append(decoded_row)

        # Ladder-top shelves: Location.buildLoc turns the first ladder tile of a run into a platform.
        if rz == 0:
            for j, row in enumerate(grid):
                for i, state in enumerate(row):
                    if not state["ladder"]:
                        continue
                    if state["collision"] != 0 or state["platform"]:
                        continue
                    above = grid[j - 1][i]["ladder"] if j > 0 else ""
                    if above != state["ladder"]:
                        wx = rx * ROOM_X + i
                        wy = ry * ROOM_Y + j
                        platform_cells[(wx, wy)] = (4, "ladder_top")

        for obj in room.findall("obj"):
            oid = obj.attrib.get("id", "")
            ox = int(obj.attrib.get("x", "0"))
            oy = int(obj.attrib.get("y", "0"))
            defin = obj_defs.get(oid, {})
            tip = defin.get("tip", "")
            other_counts[tip or oid] = other_counts.get(tip or oid, 0) + 1
            if rz != 0:
                continue
            if tip == "spawnpoint":
                spawns.append({"room": [rx, ry], "cell": [ox, oy], "id": oid})
            elif tip == "unit":
                size = defin.get("size", 1)
                units.append({
                    "id": oid,
                    "room": [rx, ry],
                    "cell": [ox, oy],
                    "feet": [
                        int((rx * ROOM_X + ox + 0.5 * size) * TILE),
                        int((ry * ROOM_Y + oy + 1) * TILE - 1),
                    ],
                })
            elif tip == "door" or defin.get("door", 0) > 0:
                size = int(obj.attrib.get("w") or defin.get("size") or 1)
                wid = int(obj.attrib.get("h") or defin.get("wid") or 1)
                if size < 1:
                    size = 1
                if wid < 1:
                    wid = 1
                for dx in range(size):
                    for dy in range(wid):
                        door_cells.add((rx * ROOM_X + ox + dx, ry * ROOM_Y + oy + dy))
                doors.append({
                    "id": oid,
                    "uid": obj.attrib.get("uid", ""),
                    "room": [rx, ry],
                    "cell": [ox, oy],
                    "w": size,
                    "h": wid,
                    "phis": defin.get("phis", 1),
                    "opac": defin.get("opac", 1.0),
                    "inter": defin.get("inter", False),
                    # Instance open="1" calls Interact.setAct("open") after initDoor, which clears collision.
                    "open": obj.attrib.get("open") == "1",
                    "px": (rx * ROOM_X + ox) * TILE,
                    "py": (ry * ROOM_Y + oy) * TILE,
                })

        rooms_out.append({"name": room.attrib.get("name", ""), "x": rx, "y": ry, "z": rz, "rows": len(rows)})

    for pos in door_cells:
        solid_cells.pop(pos, None)
        platform_cells.pop(pos, None)

    solid_rects = []
    full_solids = {pos: payload for pos, payload in solid_cells.items() if payload[0] == 4}
    partial_solids = {pos: payload for pos, payload in solid_cells.items() if payload[0] != 4}
    for group, vertical in ((full_solids, True), (partial_solids, False)):
        for x, y, w, h, key in mesh(group, lambda p: p, vertical):
            height, code, texture, name = key
            top = (4 - height) * (TILE // 4)
            solid_rects.append({
                "x": x * TILE,
                "y": y * TILE + top,
                "w": w * TILE,
                "h": h * TILE - top,
                "code": code,
                "texture": texture,
                "name": name,
            })

    plat_rects = []
    for x, y, w, h, key in mesh(platform_cells, lambda p: p, False):
        height, texture = key
        top = (4 - height) * (TILE // 4)
        plat_rects.append({
            "x": x * TILE,
            "y": y * TILE + top,
            "w": w * TILE,
            "h": max(8, height * (TILE // 4)),
            "texture": texture,
        })

    ladder_rects = []
    for x, y, w, h, side in mesh(ladder_cells, lambda s: s, True):
        ladder_rects.append({
            "x": x * TILE,
            "y": y * TILE,
            "w": w * TILE,
            "h": h * TILE,
            "side": side,
        })

    slopes = []
    for cell in slope_cells:
        if (cell["x"], cell["y"]) in door_cells:
            continue
        height = cell["height"]
        top = (4 - height) * (TILE // 4)
        slopes.append({
            "x": cell["x"] * TILE,
            "y": cell["y"] * TILE,
            "top": top,
            "side": cell["side"],
            "code": cell["code"],
        })

    # Start cell is Lands.xml locx/locy = 0,0 on z=0.
    start_spawns = [s for s in spawns if s["room"] == [0, 0]]
    if start_spawns:
        cell = start_spawns[0]["cell"]
        spawn_px = [(0 * ROOM_X + cell[0] + 1) * TILE, (0 * ROOM_Y + cell[1] + 1) * TILE - 1]
        spawn_note = "first spawnpoint in room 0,0; Land.setGGToSpawnPoint"
    else:
        spawn_px = [(3 + 1) * TILE, (3 + 1) * TILE - 1]
        spawn_note = "room 0,0 has no spawnpoint; Land.setGGToSpawnPoint default cell 3,3"

    xs = [r["x"] for r in rooms_out if r["z"] == 0]
    ys = [r["y"] for r in rooms_out if r["z"] == 0]
    minx, maxx = min(xs), max(xs)
    miny, maxy = min(ys), max(ys)
    map_w = (maxx + 1) * ROOM_X * TILE
    map_h = (maxy + 1) * ROOM_Y * TILE

    start_units = [u for u in units if u["room"] == [0, 0]]

    payload = {
        "id": "begin",
        "source": "pfe.swf DefineBinaryData exported as rooms_begin",
        "symbol": begin_name,
        "lands_xml": "original/reference/Remains-Source2/Modules/core/GameData/Lands.xml land id begin file rooms_begin locx 0 locy 0",
        "tile_px": TILE,
        "room_tiles": [ROOM_X, ROOM_Y],
        "origin": "room x,y tile i,j -> pixel ((x*48+i)*40, (y*25+j)*40). Y grows downward.",
        "bounds_rooms": {"min": [minx, miny], "max": [maxx, maxy]},
        "map_px": [map_w, map_h],
        "spawn": {"px": spawn_px, "candidates": start_spawns, "note": spawn_note},
        "rooms": rooms_out,
        "solids": solid_rects,
        "platforms": plat_rects,
        "ladders": ladder_rects,
        "slopes": slopes,
        "doors": doors,
        "start_units": start_units,
        "all_units": units,
        "counts": {
            "rooms": len(rooms_out),
            "solid_rects": len(solid_rects),
            "platform_rects": len(plat_rects),
            "ladders": len(ladder_rects),
            "slopes": len(slopes),
            "doors": len(doors),
            "spawns": len(spawns),
            "units": len(units),
            "start_units": len(start_units),
            "obj_tips": other_counts,
            "unknown_codes": unknown_codes,
            "z_rooms": sum(1 for r in rooms_out if r["z"] != 0),
        },
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print("WROTE", OUT, "bytes", OUT.stat().st_size)
    print(json.dumps(payload["counts"], ensure_ascii=False, indent=2))
    print("SPAWN", payload["spawn"])
    print("START UNITS", start_units)
    print("DOORS sample", doors[:8], "count", len(doors))
    print("ROOMS", [(r["name"], r["x"], r["y"], r["z"]) for r in rooms_out])


if __name__ == "__main__":
    main()
