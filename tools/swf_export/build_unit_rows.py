"""Merge the vclass units (turrets, drones, bats, fish, slimes, robots, bosses,
mines) into godot/assets/data/enemies.json.

Their art comes from export_units.py + godot/tools/pack_units.gd
(assets/sprites/sheets/units/<vis>.png and manifest.json). Stats come from
units.xml (mines from weapons.xml). Each row names the brain script that runs
the original Unit*.control(). Run after build_enemies.py; it rewrites only
these ids.
"""
import json
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

import build_enemies as be

ROOT = be.ROOT
WEAPONS_XML = ROOT / "original/reference/Remains-Source2/Modules/core/AllData/weapons.xml"
MANIFEST = ROOT / "godot/assets/sprites/sheets/units/manifest.json"
SHEETS = ROOT / "godot/assets/sprites/sheets"
TPS = be.TPS

VULNER = {
    "bul": "DAM_PIERCE", "blade": "DAM_CUT", "phis": "DAM_BLUNT", "fire": "DAM_BURN",
    "expl": "DAM_EXPLOSION", "laser": "DAM_LASER", "plasma": "DAM_PLASMA", "venom": "DAM_VENOM",
    "emp": "DAM_EMP", "spark": "DAM_ELECTRIC", "acid": "DAM_ACID", "cryo": "DAM_COLD",
    "poison": "DAM_POISON", "bleed": "DAM_BLEED", "fang": "DAM_BITE", "pink": "DAM_PINKCLOUD",
}

# unit id: (units.xml id, brain, vis key in the unit manifest, class weapons)
UNITS = {
    "turret0": ("turret0", "turret", "turret0", []),
    "turret1": ("turret1", "turret", "turret1", []),
    "turret2": ("turret2", "turret", "turret2", []),
    "turret3": ("turret3", "turret", "turret3", []),
    "turret4": ("turret4", "turret", "turret4", []),
    "turret5": ("turret5", "turret", "turret5", []),
    "dron1": ("dron1", "dron", "dron1", []),
    "dron2": ("dron2", "dron", "dron2", []),
    "dron3": ("dron3", "dron", "dron3", []),
    "bloodwing": ("bloodwing", "bat", "bloodwing", []),
    "bloodwing2": ("bloodwing2", "bat", "bloodwing2", []),
    "fish1": ("fish1", "fish", "fish1", []),
    "fish2": ("fish2", "fish", "fish2", []),
    "fish3": ("fish3", "fish", "fish3", []),
    "slime": ("slime", "slime", "slime", ["slime"]),
    "pinkslime": ("pinkslime", "slime", "pinkslime", ["pinkslime"]),
    "cryoslime": ("cryoslime", "slime", "cryoslime", ["slime"]),
    "roller": ("roller", "roller", "roller", []),
    "roller2": ("roller2", "roller", "roller2", []),
    "msp": ("msp", "msp", "msp", []),
    "vortex": ("vortex", "vortex", "vortex", []),
    "spritebot": ("spritebot", "spritebot", "spritebot", ["robolaser"]),
    "sentinel": ("sentinel", "robot", "sentinel", ["robomlau"]),
    "robobrain": ("robobrain", "robot", "robobrain", []),
    "eant": ("eant", "emitter", "eant", []),
    "destr1": ("destr1", "destr", "destr1", []),
    "transmitter": ("transmitter", "transmitter", "transmitter", []),
    "thunderhead": ("thunderhead", "thunderhead", "", ["dron"]),
    "ttur": ("ttur", "thunder_turret", "ttur", ["ttweap1", "ttweap2", "ttweap3", "ttweap4", "ttweap5", "ttweap6"]),
    "bossraider": ("bossraider", "boss_raider", "bossraider", ["carbine", "flamer"]),
    "bossultra": ("bossultra", "boss_ultra", "bossultra", ["robogatp", "robogatp2", "robomlau2", "robogas", "roboplagr"]),
    "bossnecr": ("bossnecr", "boss_necr", "bossnecr", ["necrbullet"]),
    "bossdron": ("bossdron", "boss_dron", "bossdron", ["dronmlau", "drongr"]),
    "bossalicorn": ("bossalicorn", "boss_alicorn", "", ["alilight2", "aliblade", "alipsy2", "alimray"]),
    "scythe": ("scythe", "scythe", "scythe", []),
}
MINES = ["hmine", "mine", "plamine", "impmine", "zebmine", "balemine"]
ALICORN_SHEET = ROOT / "original/extracted_swf/sheets_raw/sprite/40_sprAlicorn4.png"


def fnum(value, default=0.0):
    return be.fnum(value, default)


def vulner_of(sections):
    out = {}
    for key, value in sections.get("vulner", {}).items():
        if key in VULNER:
            out[VULNER[key]] = fnum(value, 1.0)
    return out


def unit_row(uid, src, brain, vis_key, class_weapons, manifest):
    sec = src["sections"]
    phis = sec.get("phis", {})
    move = sec.get("move", {})
    comb = sec.get("comb", {})
    param = sec.get("param", {})
    vis = sec.get("vis", {})
    speed = fnum(move.get("speed"), 10.0)
    weapons = [w for w in src["weapons"]]
    row = {
        "name": src["name"],
        "family": brain,
        "brain": brain,
        "vis": vis_key,
        "hp": int(fnum(comb.get("hp"), 60)),
        "xp": int(fnum(src["xp"], 0)),
        "body": [fnum(phis.get("sX"), 48), fnum(phis.get("sY"), 56)],
        "massa": fnum(phis.get("massa"), 50),
        "speed": round(speed * TPS, 2),
        "run": round(speed * TPS, 2),
        "damage": int(fnum(comb.get("damage"), 0)),
        "damage_type": be.dam_type(comb.get("tipdam"), "DAM_PIERCE"),
        "weapon": "",
        "weapons": [{"id": w.get("id", ""), "ch": fnum(w.get("ch"), 1.0), "f": w.get("f", "") == "1",
                     "dif": fnum(w.get("dif"), 0)} for w in weapons],
        "class_weapons": class_weapons,
        "fight": "brain",
        "fixed": move.get("fixed", "") == "1",
        "lift": move.get("levit", "1") != "0",
        "fly": False,
        "senses": "robot" if param.get("robot") == "1" else "plain",
        "vision": fnum(comb.get("vision"), 1.0),
        "alert": fnum(comb.get("vision"), 1.0),
        "ear": fnum(comb.get("ear"), 1.0),
        "cone": 0,
        "aim_down": False,
        "hold": False,
        "chase_shot": False,
        "contact": False,
        "move": {k: fnum(v) for k, v in move.items() if k not in ("fixed",)},
        "vulner": vulner_of(sec),
        "param": dict(param),
        "boss": src["cat"] == "3" and uid.startswith("boss") or uid in ("thunderhead", "destr1"),
        "clips": {},
    }
    snd = sec.get("snd", {})
    if snd:
        row["snd"] = {k: v for k, v in snd.items() if k in ("die", "run", "music")}
    if "noise" in vis:
        row["noise"] = fnum(vis["noise"])
    if vis.get("replic"):
        row["replic"] = vis["replic"]
    if vis_key:
        entry = manifest.get(vis_key)
        if entry is None:
            row["missing"] = "no exported sheet %s" % vis_key
        else:
            row["texture"] = "units/%s" % entry["sheet"]
    return row


def mine_rows(manifest):
    tree = ET.parse(WEAPONS_XML)
    rows = {}
    for node in tree.getroot().iter("weapon"):
        wid = node.attrib.get("id", "")
        if wid not in MINES:
            continue
        char = node.find("char").attrib
        entry = manifest.get(wid)
        rows[wid] = {
            "name": (node.findtext("n") or "").strip(),
            "family": "mine",
            "brain": "mine",
            "vis": wid,
            "hp": int(fnum(char.get("maxhp"), 10)),
            "xp": 0,
            "body": [fnum(node.attrib.get("sX"), 30), fnum(node.attrib.get("sY"), 20)],
            "massa": fnum(char.get("massafix"), 50) / 50.0,
            "speed": 0.0,
            "run": 0.0,
            "damage": int(fnum(char.get("damexpl"), 12)),
            "damage_type": be.dam_type(char.get("tipdam"), "DAM_PIERCE"),
            "weapon": "",
            "fight": "brain",
            "fixed": False,
            "lift": True,
            "fly": False,
            "senses": "plain",
            "vision": 0.0,
            "alert": 0.0,
            "ear": 0.0,
            "cone": 0,
            "mine": {
                "knock": fnum(char.get("knock"), 5),
                "destroy": fnum(char.get("destroy"), 10),
                "expl": fnum(char.get("expl"), 0),
                "time": int(fnum(char.get("time"), 15)) if char.get("time") else 0,
                "sens": int(fnum(char.get("sens"), 100)),
                "lvl": int(fnum(node.attrib.get("lvl"), 1)),
            },
            "vulner": {"DAM_EMP": 1.0, "DAM_VENOM": 0.0},
            "param": {"trup": "0", "mech": "1"},
            "clips": {},
        }
        snd = node.find("snd")
        if snd is not None:
            rows[wid]["snd"] = {k: v for k, v in snd.attrib.items() if k in ("dem", "sens")}
        if entry is not None:
            rows[wid]["texture"] = "units/%s" % entry["sheet"]
    return rows


def alicorn_row(row):
    """UnitBossAlicorn blits sprAlicorn4 with the alicorn animation set."""
    dest = SHEETS / "bossalicorn.png"
    shutil.copyfile(ALICORN_SHEET, dest)
    width, height = be.png_size(dest)
    clips = json.loads(be.SHEETS.read_text(encoding="utf-8")).get("alicorn", {})
    row["texture"] = dest.name
    row["sheet"] = "alicorn"
    row["cell"] = [170, 170]
    row["atlas"] = [width, height]
    row["offset"] = be.offset_for((170, 170), {"sprDX": "105", "sprDY": "150"})
    row["clips"] = clips


def main():
    units = be.load_units()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    data = json.loads(be.OUT_JSON.read_text(encoding="utf-8"))
    table = data["units"]
    for uid, (src_id, brain, vis_key, class_weapons) in UNITS.items():
        src = units.get(src_id)
        if src is None and uid == "turret0":
            src = dict(units["turret2"])
            src["name"] = units.get("turret", {}).get("name", "")
        if src is None:
            print("SKIP", uid, "no units.xml row")
            continue
        row = unit_row(uid, src, brain, vis_key, class_weapons, manifest)
        if uid == "turret0" and "turret0" in table:
            old = table["turret0"]
            row["hp"] = old.get("hp", row["hp"])
            row["xp"] = old.get("xp", row["xp"])
            row["body"] = old.get("body", row["body"])
        if uid == "bossalicorn":
            alicorn_row(row)
        table[uid] = row
    for wid, row in mine_rows(manifest).items():
        table[wid] = row
    data["order"] = sorted(table)
    data["units"] = {k: table[k] for k in data["order"]}
    be.OUT_JSON.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print("rows", len(UNITS) + len(MINES))
    for uid in list(UNITS) + MINES:
        miss = table.get(uid, {}).get("missing")
        if miss:
            print(" MISSING", uid, miss)


if __name__ == "__main__":
    main()
