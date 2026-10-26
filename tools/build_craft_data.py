"""Build craft and condition catalogs from the local Remains data."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
src = root / "original" / "reference" / "Remains-Source2" / "Modules" / "core" / "AllData"
out_dir = root / "godot" / "assets" / "data"

schematics = json.loads((src / "schematics.json").read_text(encoding="utf-8"))
items_doc = json.loads((src / "items.json").read_text(encoding="utf-8"))
weapons_doc = json.loads((src / "weapons.json").read_text(encoding="utf-8"))
armors_doc = json.loads((src / "armors.json").read_text(encoding="utf-8"))
ammo_doc = json.loads((src / "ammo.json").read_text(encoding="utf-8"))

if isinstance(items_doc, list):
    items = {row["id"]: row for row in items_doc if isinstance(row, dict) and "id" in row}
else:
    items = items_doc

if isinstance(weapons_doc, dict) and "weapons" in weapons_doc:
    weapon_rows = weapons_doc["weapons"]
elif isinstance(weapons_doc, dict):
    weapon_rows = list(weapons_doc.values())
else:
    weapon_rows = weapons_doc

weapons = {}
for row in weapon_rows:
    if isinstance(row, dict) and row.get("id"):
        weapons[row["id"]] = row

if isinstance(armors_doc, dict) and "id" not in armors_doc:
    armors = armors_doc
else:
    armors = {row["id"]: row for row in armors_doc if isinstance(row, dict) and "id" in row}

RESIST = {
    "bul": "DAM_PIERCE",
    "blade": "DAM_CUT",
    "phis": "DAM_BLUNT",
    "fire": "DAM_BURN",
    "expl": "DAM_EXPLOSION",
    "laser": "DAM_LASER",
    "plasma": "DAM_PLASMA",
    "venom": "DAM_VENOM",
    "spark": "DAM_ELECTRIC",
    "acid": "DAM_ACID",
    "cryo": "DAM_COLD",
    "fang": "DAM_BITE",
    "necro": "DAM_DEATH",
}

recipes = []
for row in schematics:
    result = row["id"][2:] if str(row["id"]).startswith("s_") else row["id"]
    kind = "item"
    one = False
    if result in weapons:
        tip = weapons[result].get("tip", "")
        kind = "explosives" if tip == "explosives" else "weapon"
    elif result in armors:
        kind = "armor"
    elif result in items:
        tip = items[result].get("tip", "item")
        if tip == "impl":
            kind = "impl"
        one = bool(items[result].get("one"))
    bench = row.get("workbench") or row.get("work") or "work"
    recipes.append({
        "id": row["id"],
        "result": result,
        "kind": kind,
        "one": one,
        "bench": bench,
        "cat": row.get("cat", ""),
        "skill": row.get("skill", ""),
        "skill_level": int(row.get("skillRequirement", 0)),
        "perk": row.get("perk", ""),
        "kol": int(row.get("kol", 1)),
        "ingredients": row.get("ingredients", {}),
    })

condition_weapons = {}
for wid, row in weapons.items():
    tip = row.get("tip", "")
    if tip not in ("melee", "lightGun", "heavyGun"):
        continue
    maxhp = int(row.get("char_maxhp", 100))
    rep = row.get("com_rep", 1)
    condition_weapons[wid] = {
        "maxhp": maxhp,
        "rep": float(rep if rep is not None else 1),
        "kind": tip,
        "mag": int(row.get("char_mag", row.get("mag", 0)) or 0),
        "skill": int(row.get("skill", 0) or 0),
        "variant": bool(row.get("variant")),
        "ammo": str(row.get("ammo") or row.get("char_ammo") or ""),
    }

# Source weapons.json uses nested names. Pull mag/ammo from godot weapons if needed.
godot_weapons = json.loads((out_dir / "weapons.json").read_text(encoding="utf-8"))
for row in godot_weapons.get("weapons", []):
    wid = row.get("id", "")
    if wid not in condition_weapons:
        continue
    entry = condition_weapons[wid]
    if entry["mag"] <= 0:
        entry["mag"] = int(row.get("mag", 0) or 0)
    if entry["ammo"] == "":
        entry["ammo"] = str(row.get("ammo", "") or "")

condition_armors = {}
for aid, row in armors.items():
    if not isinstance(row, dict):
        continue
    upd = row.get("upd") or []
    resists = {}
    armor = 0
    marmor = 0
    qual = 0.0
    if upd and isinstance(upd[0], dict):
        base = upd[0]
        armor = int(base.get("armor", 0) or 0)
        marmor = int(base.get("marmor", 0) or 0)
        qual = float(base.get("armorQual", 0) or 0)
        for key, damage in RESIST.items():
            if key in base:
                resists[damage] = float(base[key])
    condition_armors[aid] = {
        "maxhp": int(row.get("hp", 100) or 100),
        "unbreakable": bool(row.get("unbreakable")),
        "no_repair": bool(row.get("noRepair")),
        "component": str(row.get("idComp") or (aid + "_comp")),
        "kol_comp": int(row.get("kolComp", 1) or 1),
        "max_level": int(row.get("upgrades", 0) or 0),
        "armor": armor,
        "marmor": marmor,
        "qual": qual,
        "resists": resists,
        "upgrade_kol": [
            int(step.get("kol", 0) or 0) for step in upd if isinstance(step, dict)
        ],
    }
    # armors.xml guns/melee/magic (armors.json gunsMult/meleeMult/magicMult).
    for src_key, dst_key in (("gunsMult", "guns"), ("meleeMult", "melee"), ("magicMult", "magic")):
        if src_key in row:
            condition_armors[aid][dst_key] = float(row[src_key])

wear = {}
if isinstance(ammo_doc, dict):
    ammo_rows = ammo_doc.values()
else:
    ammo_rows = ammo_doc
for row in ammo_rows:
    if not isinstance(row, dict):
        continue
    extra = float(row.get("increasedWear", 0) or 0)
    if extra:
        wear[row.get("id", "")] = extra

catalog = {
    "source": "Remains-Source2 schematics.json, weapons.json, armors.json, ammo.json",
    "stations": {
        "work": {"object": "work", "name": "Верстак", "pages": ["craft", "upgrade", "repair"], "benches": ["work", "expl"]},
        "lab": {"object": "himlab", "name": "Лаборатория", "pages": ["craft"], "benches": ["lab"]},
        "stove": {"object": "stove", "name": "Stove", "pages": ["craft"], "benches": ["stove"]},
        "expl": {"object": "mworkexpl", "name": "Explosives kit", "pages": ["craft"], "benches": ["expl"]},
        "mworkbench": {"object": "mworkbench", "name": "Portable workbench", "pages": ["repair"], "benches": []},
    },
    "recipes": recipes,
    "weapons": condition_weapons,
    "armors": condition_armors,
    "ammo_wear": wear,
}

(out_dir / "craft_condition.json").write_text(
    json.dumps(catalog, ensure_ascii=False, indent=2),
    encoding="utf-8",
)

from collections import Counter
benches = Counter(r["bench"] for r in recipes)
kinds = Counter(r["kind"] for r in recipes)
print("recipes", len(recipes), dict(benches), dict(kinds))
print("weapons", len(condition_weapons), "armors", len(condition_armors), "ammo wear", wear)
print("work+expl", benches["work"] + benches["expl"])
