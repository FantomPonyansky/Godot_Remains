"""Build godot/assets/data/enemies.json and copy enemy atlases into the Godot project."""
import json
import shutil
import struct
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
UNITS = ROOT / "original/reference/Remains-Source2/Modules/core/AllData/units.xml"
SHEETS = ROOT / "original/reference/Remains-Source2/Modules/core/spritesheets/spritesheets.json"
WEAPONS = ROOT / "original/reference/Remains-Source2/Modules/core/AllData/weapons.json"
RAW = ROOT / "original/extracted_swf/sheets_raw"
OUT_DIR = ROOT / "godot/assets/sprites/sheets"
OUT_JSON = ROOT / "godot/assets/data/enemies.json"
TPS = 30.0

LEGACY = {
    0: "DAM_PIERCE", 1: "DAM_CUT", 2: "DAM_BLUNT", 3: "DAM_BURN", 4: "DAM_EXPLOSION",
    5: "DAM_LASER", 6: "DAM_PLASMA", 7: "DAM_VENOM", 8: "DAM_EMP", 9: "DAM_ELECTRIC",
    10: "DAM_ACID", 11: "DAM_COLD", 12: "DAM_POISON", 13: "DAM_BLEED", 14: "DAM_BITE",
    15: "DAM_BALEFIRE", 16: "DAM_DEATH", 17: "DAM_PSYCHIC", 18: "DAM_ASTRO", 19: "DAM_PINKCLOUD",
    100: "DAM_INTERNAL", 101: "DAM_HARMONY",
}

# Spawnable families. Templates (cat 2) and the player are not enemies.
RAIDER = {"raider", "slaver", "zebra", "merc", "ranger", "encl"}
CRITTER = {"tarakan", "rat", "molerat", "scorp1", "scorp2", "scorp3", "ant1", "ant2", "ant3"}
ROBOT = {"protect", "protect1", "gutsy", "gutsy1", "eqd"}
NOT_ENEMIES = {
    "training", "littlepip", "npc", "vendor", "doctor", "captive", "ponpon", "pony",
    "monster", "other", "robot", "bigrobot", "smallrobot",
}
PROPS = {
    "mtrap", "trigcans", "trigridge", "trigplate", "triglaser",
    "damshot", "damgren", "damexpl1", "transmitter", "mwall", "scythe",
    "thunderhead", "dront", "ttur", "destr1",
}
RUN_MULT = {
    "raider": 2, "slaver": 2, "merc": 2, "ranger": 2, "encl": 2, "zebra": 3,
    "protect": 3, "protect1": 3, "gutsy": 2, "gutsy1": 2, "eqd": 2.5,
}
VISION_MULT = {
    "raider": 1.0, "slaver": 1.0, "zebra": 1.3, "merc": 1.5, "ranger": 1.0, "encl": 1.5,
}
GUNS = {"lightGun", "heavyGun", "magic"}
# Boss phases that share bossencl's clip rows and cell.
PHASES = {
    "bossencl2": "sprEnclboss2",
    "bossencl3": "sprEnclboss3",
}
# Weapons the class assigns in code, rather than on the unit's <w> list.
CLASS_WEAPONS = {
    "scorp1": "scorppunch",
    "scorp2": "scorp2punch",
    "scorp3": "scorp3punch",
    "ant3": "antfire",
    "bossencl": "lmg",
    "bossencl2": "quick",
    "bossencl3": "mlau",
}


def png_size(path: Path):
    data = path.read_bytes()
    return struct.unpack(">II", data[16:24])


def dam_type(value, fallback):
    if value is None or value == "":
        return fallback
    try:
        return LEGACY.get(int(float(value)), fallback)
    except ValueError:
        text = str(value)
        return text if text.startswith("DAM_") else fallback


def fnum(value, default=0.0):
    if value is None or value == "":
        return default
    return float(value)


def merge_attrs(base, extra):
    out = dict(base)
    out.update(extra)
    return out


def load_units():
    tree = ET.parse(UNITS)
    raw = {}
    for node in tree.getroot().findall("unit"):
        uid = node.attrib["id"]
        sections = {}
        for child in list(node):
            if child.tag in ("n", "w"):
                continue
            sections[child.tag] = dict(child.attrib)
        weapons = [dict(w.attrib) for w in node.findall("w")]
        raw[uid] = {
            "id": uid,
            "parent": node.attrib.get("parent", ""),
            "cat": node.attrib.get("cat", ""),
            "xp": node.attrib.get("xp", ""),
            "fraction": node.attrib.get("fraction", ""),
            "sections": sections,
            "weapons": weapons,
            "name": (node.findtext("n") or "").strip(),
        }
    merged = {}
    for uid, row in raw.items():
        parent = raw.get(row["parent"])
        sections = {}
        if parent:
            for key, attrs in parent["sections"].items():
                # UnitRaider reads <un> only from the variant, not the family template.
                if key == "un":
                    continue
                sections[key] = dict(attrs)
        for key, attrs in row["sections"].items():
            sections[key] = merge_attrs(sections.get(key, {}), attrs)
        weapons = row["weapons"] or (parent["weapons"] if parent else [])
        merged[uid] = {
            "id": uid,
            "parent": row["parent"],
            "cat": row["cat"],
            "xp": row["xp"] or (parent["xp"] if parent else ""),
            "fraction": row["fraction"] or (parent["fraction"] if parent else ""),
            "sections": sections,
            "weapons": weapons,
            "name": row["name"],
        }
    return merged


def load_blits():
    found = {}
    for folder in RAW.iterdir():
        for path in folder.glob("*.png"):
            # 12_sprProtect.png
            name = path.stem.split("_", 1)[1]
            found[name] = path
    return found


def pick_weapon(weapons):
    eligible = []
    for w in weapons:
        if w.get("f"):
            continue
        if w.get("dif") and fnum(w["dif"]) > 100:
            continue
        eligible.append(w)
    for w in eligible:
        ch = w.get("ch")
        if ch is None or ch == "" or fnum(ch) >= 1:
            return w.get("id", "")
    best = ""
    best_c = -1.0
    for w in eligible:
        c = fnum(w.get("ch"), 0)
        if c >= best_c:
            best = w.get("id", "")
            best_c = c
    return best


def sheet_keys(uid, parent, manifest):
    keys = []
    if parent and parent in manifest:
        keys.append(parent)
    elif uid in manifest:
        keys.append(uid)
    if uid in manifest and uid not in keys:
        keys.append(uid)
    return keys


def locomotion(clips):
    if "trot" in clips:
        return "trot"
    if "walk" in clips:
        return "walk"
    if "fly" in clips:
        return "fly"
    if "run" in clips:
        return "run"
    return "stay"


def offset_for(cell, vis):
    cw, ch = cell
    dx = vis.get("sprDX")
    dy = vis.get("sprDY")
    if dx is None or dx == "":
        ox = 0.0
    else:
        ox = -float(dx) + cw / 2.0
    if dy is None or dy == "":
        oy = -ch / 2.0 + 10.0
    else:
        oy = -float(dy) + ch / 2.0
    return [round(ox, 2), round(oy, 2)]


def build():
    units = load_units()
    manifest = json.loads(SHEETS.read_text(encoding="utf-8"))
    weapons = json.loads(WEAPONS.read_text(encoding="utf-8"))
    blits = load_blits()
    ported = {}
    skipped = []

    def consider(uid, blit_name, phase_of=""):
        src = units.get(phase_of or uid)
        if src is None:
            skipped.append((uid, "no unit data"))
            return
        parent = src["parent"]
        keys = sheet_keys(phase_of or uid, parent if not phase_of else "", manifest)
        if phase_of:
            keys = ["bossencl"]
        if not keys:
            skipped.append((uid, "no clip list in spritesheets.json"))
            return
        image = blits.get(blit_name)
        if image is None:
            skipped.append((uid, "sheet %s missing from sprite.swf and sprite1.swf" % blit_name))
            return
        vis = src["sections"].get("vis", {})
        cw = int(fnum(vis.get("sprX"), 0))
        chy = vis.get("sprY")
        ch = int(fnum(chy, cw))
        if cw <= 0 or ch <= 0:
            skipped.append((uid, "no cell size"))
            return
        width, height = png_size(image)
        if width % cw or height % ch:
            skipped.append((uid, "atlas %dx%d is not a %dx%d grid" % (width, height, cw, ch)))
            return
        family = parent or uid
        if phase_of:
            family = "bossencl"
        entry = make_entry(uid, src, family, keys, (cw, ch), (width, height), weapons, CLASS_WEAPONS.get(uid, ""))
        dest = OUT_DIR / ("%s.png" % uid)
        shutil.copyfile(image, dest)
        entry["texture"] = dest.name
        ported[uid] = entry

    parents = {row["parent"] for row in units.values() if row["parent"]}
    for uid, src in units.items():
        if uid in NOT_ENEMIES or uid in PROPS:
            continue
        if src["cat"] in ("1", "2"):
            continue
        vis = src["sections"].get("vis", {})
        blit = vis.get("blit", "")
        if not blit and uid in parents:
            continue
        if not blit:
            reason = "no sprite sheet (vclass %s)" % vis.get("vclass", "none")
            skipped.append((uid, reason))
            continue
        consider(uid, blit)

    # Boss encl phases use the same clip rows on their own atlases.
    base = units["bossencl"]
    for phase, blit in PHASES.items():
        fake = dict(base)
        fake = {
            "id": phase,
            "parent": "",
            "cat": "3",
            "xp": base["xp"],
            "fraction": base["fraction"],
            "sections": base["sections"],
            "weapons": [],
            "name": base["name"],
        }
        units[phase] = fake
        consider(phase, blit, phase_of="bossencl")

    order = sorted(ported)
    payload = {
        "aliases": {"scorp": "scorp1"},
        "order": order,
        "units": {uid: ported[uid] for uid in order},
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    report = ROOT / "original/extracted_swf/enemy_skip.txt"
    lines = ["ported %d" % len(order)]
    lines.extend(order)
    lines.append("--- skipped %d ---" % len(skipped))
    for uid, why in skipped:
        lines.append("%s: %s" % (uid, why))
    report.write_text("\n".join(lines), encoding="utf-8")
    print("ported", len(order))
    print("skipped", len(skipped))
    for uid, why in skipped:
        print(" SKIP", uid, "-", why)


def make_entry(uid, src, family, keys, cell, image, weapons, forced_weapon):
    phis = src["sections"].get("phis", {})
    move = src["sections"].get("move", {})
    comb = src["sections"].get("comb", {})
    vis = src["sections"].get("vis", {})
    un = src["sections"].get("un", {})
    speed = fnum(move.get("speed"), 0)
    run_attr = move.get("run")
    if family in RUN_MULT and speed:
        run = speed * RUN_MULT[family]
    elif run_attr:
        run = fnum(run_attr)
    else:
        run = speed
    body_w = fnum(phis.get("sX"), 48)
    body_h = fnum(phis.get("sY"), 56)
    hp = int(fnum(comb.get("hp"), 60))
    xp = int(fnum(src["xp"], 10))
    body_damage = int(fnum(comb.get("damage"), 0))
    body_type = dam_type(comb.get("tipdam"), "DAM_BLUNT")
    krep = comb.get("krep", "") == "1"
    weapon_id = forced_weapon or pick_weapon(src["weapons"])
    weapon = weapons.get(weapon_id, {}) if weapon_id else {}
    tip = weapon.get("tip", "")
    wdam = int(fnum(weapon.get("char_damage"), 0))
    wtype = dam_type(weapon.get("char_tipdam"), "DAM_PIERCE")
    rapid = fnum(weapon.get("char_rapid"), 5)
    bullet_speed = fnum(weapon.get("phis_speed"), 12) * TPS
    if family in ("encl", "ranger") and wdam:
        if wdam < 20:
            wdam = int(round(wdam * 1.2))
        wdam = int(round(wdam * 1.2))
    sdamage = int(fnum(vis.get("sdamage"), 0))
    stype = dam_type(vis.get("stipdam"), "")

    fight = "melee"
    damage = body_damage
    dtype = body_type
    hold = False
    backoff = False
    hold_range = 1000.0
    hold_chance = 0.7
    swing_x = 100.0
    swing_above = 80.0
    swing_below = 80.0
    strike_cd = 15.0 / TPS
    windup = 0.0
    strike_hold = 1.0
    contact = False
    reach = 160.0
    vision = 1.0
    alert = 1.5
    ear = fnum(comb.get("ear"), 1.0)
    senses = "plain"
    fixed = move.get("fixed", "") == "1"
    lift = move.get("levit", "1") != "0"

    if family in RAIDER or uid in RAIDER:
        senses = "raider"
        mult = VISION_MULT.get(family, VISION_MULT.get(uid, 1.0))
        vision = mult
        alert = mult * 1.5
        ear = fnum(comb.get("ear"), 1.0)
        if tip in GUNS or (tip == "internal" and wdam and weapon.get("phis_speed")):
            fight = "gunner"
            damage = wdam or body_damage
            dtype = wtype
            hold = True
            backoff = True
            hold_range = fnum(un.get("dist"), 1000)
            strike_cd = max(rapid, 1) / TPS
        elif tip == "explosives":
            fight = "gunner"
            damage = wdam or body_damage
            dtype = wtype or "DAM_EXPLOSION"
            hold = False
            backoff = False
            strike_cd = 50.0 / TPS
        elif tip == "melee" and not krep:
            fight = "melee"
            damage = wdam or body_damage
            dtype = wtype
            swing_x = 100.0
            strike_cd = max(rapid, 1) / TPS
        else:
            fight = "melee"
            contact = True
            damage = body_damage or wdam
            dtype = body_type
            reach = 140.0
    elif uid in ("scorp1", "scorp2", "scorp3"):
        senses = "critter"
        vision, alert, ear = 0.25, 0.5, 0.0
        fight = "melee"
        damage = wdam or body_damage
        dtype = wtype or "DAM_BITE"
        swing_x, swing_above, swing_below = 80.0, 80.0, 40.0
        strike_hold = 0.7
        strike_cd = 15.0 / TPS
        windup = 5.0 / TPS
    elif uid in CRITTER or family in ("tarakan", "rat", "molerat", "ant"):
        senses = "critter"
        vision, alert, ear = 0.25, 0.5, 0.0
        fight = "melee"
        damage = body_damage or wdam
        dtype = body_type if body_damage else wtype
        if uid.startswith("ant"):
            swing_above = 120.0
            swing_below = 120.0
        if uid == "ant3":
            # Fire ants breathe while holding. The bite range stays 120 tall.
            fight = "gunner"
            damage = wdam or body_damage
            dtype = wtype or "DAM_BURN"
            hold = True
            hold_chance = 0.07
            hold_range = 120.0
            backoff = False
            strike_cd = max(rapid, 1) / TPS
    elif uid in ROBOT or family in ROBOT:
        senses = "robot"
        vision = fnum(comb.get("vision"), 1.0)
        alert = vision
        ear = fnum(comb.get("ear"), 1.0)
        fight = "gunner"
        damage = wdam or body_damage
        dtype = wtype if wdam else body_type
        hold = True
        backoff = False
        hold_range = 1000.0
        hold_chance = 0.7
        strike_cd = max(rapid, 1) / TPS
    elif family == "hellhound" or uid.startswith("hellhound"):
        senses = "hound"
        vision, alert, ear = 0.7, 1.5, fnum(comb.get("ear"), 1.0)
        fight = "melee"
        damage = body_damage
        dtype = body_type
    elif family == "zombie" or uid.startswith("zombie"):
        senses = "plain"
        vision, alert = 1.0, 1.5
        ear = fnum(comb.get("ear"), 1.0)
        if tip in GUNS:
            fight = "gunner"
            damage = wdam
            dtype = wtype
            hold = True
            backoff = False
            hold_range = fnum(un.get("dist"), 200)
            strike_cd = max(rapid, 1) / TPS
        else:
            fight = "melee"
            damage = body_damage or wdam
            dtype = body_type if body_damage else wtype
            swing_x = 200.0
            strike_cd = max(rapid, 15) / TPS
    elif family == "alicorn" or uid.startswith("alicorn"):
        senses = "caster"
        vision, alert, ear = 1.5, 2.0, fnum(comb.get("ear"), 1.0)
        fight = "gunner"
        damage = sdamage or wdam or body_damage
        dtype = stype or wtype or body_type
        hold = True
        backoff = False
        hold_range = 500.0
        strike_cd = max(rapid, 10) / TPS
    elif uid == "necros":
        senses = "plain"
        fight = "melee"
        contact = True
        damage = body_damage
        dtype = body_type
        reach = 200.0
    elif uid.startswith("bossencl"):
        senses = "robot"
        vision, alert, ear = 1.0, 1.5, 1.0
        fight = "gunner"
        damage = wdam or body_damage
        dtype = wtype if wdam else body_type
        hold = True
        backoff = False
        hold_range = 1000.0
        strike_cd = max(rapid, 1) / TPS
    elif uid in ("phoenix", "owl"):
        senses = "plain"
        fight = "gunner"
        damage = wdam or body_damage or 1
        dtype = wtype if wdam else body_type
        hold = True
        backoff = False
        hold_range = 400.0
        strike_cd = max(rapid, 1) / TPS
    else:
        if tip in GUNS or sdamage:
            fight = "gunner"
            damage = wdam or sdamage or body_damage
            dtype = wtype if wdam else (stype or body_type)
            hold = False
            strike_cd = max(rapid, 1) / TPS
        else:
            fight = "melee"
            damage = body_damage or wdam
            dtype = body_type if body_damage else wtype

    # Bloats and turrets have no atlas; they are not in this function.
    clips = {}
    manifest = json.loads(SHEETS.read_text(encoding="utf-8"))
    for key in keys:
        for clip, data in manifest.get(key, {}).items():
            clips[clip] = data
    return {
        "name": src["name"],
        "family": family,
        "sheet": keys[0],
        "clip_sheets": keys,
        "clips": clips,
        "cell": [cell[0], cell[1]],
        "atlas": [image[0], image[1]],
        "offset": offset_for(cell, vis),
        "hp": hp,
        "xp": xp,
        "body": [body_w, body_h],
        "speed": round(speed * TPS, 2),
        "run": round(run * TPS, 2),
        "damage": int(damage),
        "damage_type": dtype or "DAM_BLUNT",
        "weapon": weapon_id,
        "fight": fight,
        "fixed": fixed,
        "lift": lift,
        "senses": senses,
        "vision": vision,
        "alert": alert,
        "ear": ear,
        "cone": 0,
        "aim_down": False,
        "hold": hold,
        "chase_shot": fight == "gunner" and uid != "ant3",
        "hold_range": hold_range,
        "hold_chance": hold_chance,
        "backoff": backoff,
        "swing_x": swing_x,
        "swing_above": swing_above,
        "swing_below": swing_below,
        "strike_cd": round(strike_cd, 4),
        "windup": round(windup, 4),
        "strike_hold": strike_hold,
        "contact": contact,
        "reach": reach,
        "move_clip": locomotion(clips),
        "bullet_speed": round(bullet_speed, 2),
    }


if __name__ == "__main__":
    build()
