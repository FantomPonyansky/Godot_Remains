"""Build the dev-only performance arena (land perf_arena).

Takes the busiest rooms of rooms_mane (crates, explosive boxes, containers,
spikes, turrets, doors, lights), lays them out unmirrored in a fixed 4 x 3
grid, gives each room its own enemy_type so the enl/enf/enc markers spawn
several factions, adds explicit units at the spare player markers, stacks a
crate on every small crate, and cuts a walkway through each shared side wall.

Output: godot/assets/data/maps/rooms/rooms_perf_arena.json (excluded from
exports). Rerun after changing rooms_mane.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROOMS = ROOT / "godot" / "assets" / "data" / "maps" / "rooms"
SRC = ROOMS / "rooms_mane.json"
OUT = ROOMS / "rooms_perf_arena.json"

GRID_W, GRID_H = 4, 3
COLS, ROWS = 48, 25
# Room enemy_type (LandGen._enemy_type): zombie, raider, robot, slaver, merc,
# zebra, ranger, encl, hellhound.
ENEMY_TYPES = [0, 1, 2, 3, 4, 6, 7, 9, 10, 1, 2, 0]
EXTRA_UNITS = ["raider", "zombie", "bloat", "turret", "sentinel", "ebloat"]
STACK = {"box", "woodbox"}
# Walkway through a shared side wall: rows 19-22 open, row 23 floor.
GAP_ROWS = range(19, 23)
FLOOR_ROW = 23
FLOOR = "H"


def carve(rows, cols):
    out = []
    for y, row in enumerate(rows):
        parts = row.split(".")
        for x in cols:
            if y in GAP_ROWS:
                parts[x] = "_"
            elif y == FLOOR_ROW:
                parts[x] = FLOOR
        out.append(".".join(parts))
    return out


def main():
    doc = json.loads(SRC.read_text(encoding="utf-8"))
    rooms = [r for r in doc["rooms"] if len(r.get("rows", [])) == ROWS]
    rooms.sort(key=lambda r: len(r.get("objs", [])), reverse=True)
    picked = rooms[: GRID_W * GRID_H]
    serial = 0
    out_rooms = []
    for i, src in enumerate(picked):
        gx, gy = i % GRID_W, i // GRID_W
        objs = []
        players = 0
        for obj in src.get("objs", []):
            obj = json.loads(json.dumps(obj))
            if obj.get("id") == "player":
                players += 1
                # Only the start room keeps a spawn; others get a unit there.
                if gx or gy:
                    serial += 1
                    unit = EXTRA_UNITS[serial % len(EXTRA_UNITS)]
                    objs.append({"tag": "obj", "id": unit, "x": obj["x"], "y": obj["y"],
                                 "size": 2, "attrs": {"code": "perfArena%d" % serial}})
                    continue
            objs.append(obj)
            if obj.get("id") in STACK:
                serial += 1
                objs.append({"tag": "obj", "id": obj["id"], "x": obj["x"], "y": int(obj["y"]) - 1,
                             "size": obj.get("size", 2), "attrs": {"code": "perfArena%d" % serial}})
        cols = []
        if gx > 0:
            cols += [0, 1]
        if gx < GRID_W - 1:
            cols += [COLS - 2, COLS - 1]
        out_rooms.append({
            "name": "arena_%d_%d" % (gx, gy),
            "source_room": src.get("name", ""),
            "x": gx,
            "y": gy,
            "enemy_type": ENEMY_TYPES[i % len(ENEMY_TYPES)],
            "rows": carve(src["rows"], cols),
            "objs": objs,
        })
    OUT.write_text(json.dumps({"file": "rooms_perf_arena", "placed": True, "source": "tools/make_perf_arena.py",
                               "rooms": out_rooms}, ensure_ascii=False), encoding="utf-8")
    print("wrote %s: %d rooms, %d objects" % (OUT.name, len(out_rooms), sum(len(r["objs"]) for r in out_rooms)))


if __name__ == "__main__":
    main()
