"""Build build/TESTER_IDS.md from _shots/ids_dump.txt (written by a headless dump of the game's catalogs)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DUMP = ROOT / "_shots" / "ids_dump.txt"
OUT = ROOT / "build" / "TESTER_IDS.md"
LANDS = ROOT / "godot" / "assets" / "data" / "maps" / "lands.json"

ITEM_GROUPS = [
    ("Healing potions and medicine", ["med"]),
    ("Chems", ["him"]),
    ("Potions", ["pot"]),
    ("Ammo", ["a"]),
    ("Grenades, mines and explosives", ["e"]),
    ("Keys", ["key"]),
    ("Equipment and tools", ["equip", "instr"]),
    ("Skill books", ["book"]),
    ("Implants and armour mods", ["impl"]),
    ("Special and quest items", ["spec", "sphera", "art", "note"]),
    ("Money and valuables", ["money", "valuables"]),
    ("Crafting schemes", ["scheme"]),
    ("Crafting parts", ["compw", "compa", "compm", "compe", "compp"]),
    ("Food and drink", ["food"]),
    ("Paints", ["paint"]),
    ("Junk", ["stuff"]),
]
WEAPON_GROUPS = [
    ("Melee weapons", "melee"),
    ("Small guns", "lightGun"),
    ("Big and energy guns", "heavyGun"),
    ("Throwing weapons (as weapons)", "explosives"),
]


def probs():
    data = json.loads(LANDS.read_text(encoding="utf-8"))
    lands = data.get("lands", data)
    trials, bosses = [], []
    seen = set()
    for lid, land in lands.items():
        if not isinstance(land, dict) or str(land.get("tip", "")) == "prob":
            continue
        for row in land.get("probs") or []:
            if not isinstance(row, dict):
                continue
            pid = str(row.get("id", ""))
            if not pid or pid in seen:
                continue
            seen.add(pid)
            rec = (pid, lid)
            if str(row.get("tip", "")) == "2":
                bosses.append(rec)
            else:
                trials.append(rec)
    return trials, bosses


def table(rows):
    lines = ["| ID | Name |", "|---|---|"]
    lines += ["| `%s` | %s |" % (i, n.replace("|", "/")) for i, n in rows]
    return "\n".join(lines)


def id_land(rows):
    lines = ["| ID | Land |", "|---|---|"]
    lines += ["| `%s` | `%s` |" % (i, land) for i, land in rows]
    return "\n".join(lines)


def main():
    items, weapons, armor, extra = {}, {}, [], {}
    for line in DUMP.read_text(encoding="utf-8").splitlines():
        parts = line.split("|")
        if parts[0] == "item":
            items.setdefault(parts[1], []).append((parts[2], parts[3]))
        elif parts[0] == "weapon":
            weapons.setdefault(parts[1], []).append((parts[2], parts[3]))
        elif parts[0] == "armor":
            armor.append((parts[2], parts[3]))
        else:
            extra[parts[0]] = parts[1]
    out = [
        "# FoE Remains port: ID list for the debug console",
        "",
        "Use these with the console commands in `TESTER_GUIDE.md`. Examples: `give pot2 5`, `give p10 200`, "
        "`give power`, `spell mbul`, `land raiders`. IDs are case-sensitive. A weapon ID ending in `^1` or `^2` "
        "is an improved variant of the same weapon.",
        "",
        "## Trials (`trials`, `trial <id>`)",
        "",
        id_land(probs()[0]),
        "",
        "## Boss arenas (`bosses`, `boss <id>`)",
        "",
        id_land(probs()[1]),
        "",
        "## Lands (`land <id>`, `quiet <id>`, `openland <id>`)",
        "",
        " ".join("`%s`" % x for x in extra.get("lands", "").split() if x),
        "",
        "## Vendors (`vendor <id>`)",
        "",
        " ".join("`%s`" % x for x in extra.get("vendors", "").replace(";", " ").split() if x and x != "nope"),
        "",
        "## Armour and amulets (`give <id>`)",
        "",
        table(armor),
        "",
        "## Magic weapons (`spell <id>`)",
        "",
        table(weapons.get("magic", [])),
        "",
        "## Spells (`spell <id>`)",
        "",
        table(items.get("spell", [])),
        "",
    ]
    for title, kind in WEAPON_GROUPS:
        out += ["## %s (`give <id>`)" % title, "", table(weapons.get(kind, [])), ""]
    for title, kinds in ITEM_GROUPS:
        rows = [r for k in kinds for r in items.get(k, [])]
        out += ["## %s (`give <id> [count]`)" % title, "", table(rows), ""]
    OUT.write_text("\n".join(out), encoding="utf-8")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
