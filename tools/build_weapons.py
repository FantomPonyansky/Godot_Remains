"""Build godot/assets/data/weapons.json from the local Remains catalog."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / r"original\reference\Remains-Source2\Modules\core\AllData\weapons.json"
CAT = ROOT / r"godot\assets\data\content\weapons_catalog.json"
SPELLS = ROOT / r"godot\assets\data\spells.json"
OUT = ROOT / r"godot\assets\data\weapons.json"

DAMAGE = {
    0: "DAM_PIERCE", 1: "DAM_CUT", 2: "DAM_BLUNT", 3: "DAM_BURN", 4: "DAM_EXPLOSION",
    5: "DAM_LASER", 6: "DAM_PLASMA", 7: "DAM_VENOM", 8: "DAM_EMP", 9: "DAM_ELECTRIC",
    10: "DAM_ACID", 11: "DAM_COLD", 12: "DAM_POISON", 13: "DAM_BLEED", 14: "DAM_BITE",
    15: "DAM_BALEFIRE", 16: "DAM_DEATH", 17: "DAM_PSYCHIC", 18: "DAM_ASTRO",
    19: "DAM_PINKCLOUD", 100: "DAM_INTERNAL", 101: "DAM_HARMONY",
}
SKILL = {
    1: "melee", 2: "smallguns", 3: "repair", 4: "energy",
    5: "explosives", 6: "magic", 7: "tele",
}
# items.xml tip=spell. These are the weapons UnitPlayer.attach -> addAllSpells grants.
ITEM_SPELL = {
    "sp_slow": {"magic": 500, "mana": 30, "culd": 10, "rad": 200, "hp": 60, "effect": "slow", "snd": "slow"},
    "sp_mwall": {"magic": 300, "mana": 30, "culd": 20, "hp": 200, "dist": 300, "effect": "barrier", "snd": "mwall"},
    "sp_blast": {"magic": 300, "mana": 30, "culd": 10, "dam": 20, "rad": 500, "effect": "blast", "snd": "blast", "tele": True},
    "sp_cryst": {"magic": 50, "mana": 5, "culd": 0, "effect": "crystal", "snd": "crystal", "prod": True},
    "sp_kdash": {"magic": 100, "mana": 10, "culd": 3, "dam": 20, "effect": "dash", "snd": "dash", "tele": True},
    "sp_mshit": {"magic": 500, "mana": 100, "culd": 30, "hp": 150, "effect": "shield", "snd": "mshit"},
    "sp_moon": {"magic": 800, "mana": 300, "culd": 60, "effect": "moonblade", "snd": "crystal"},
    "sp_gwall": {"magic": 500, "mana": 50, "culd": 6, "hp": 100, "dam": 10, "dist": 300, "effect": "ghost_wall", "snd": "mwall"},
    "sp_invulner": {"magic": 800, "mana": 200, "culd": 12, "dam": 50, "effect": "blood_shield", "snd": "mshit"},
}
NEW_GAME = list(ITEM_SPELL.keys())


def num(value, default=0):
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    return value


def main() -> None:
    raw = json.loads(SRC.read_text(encoding="utf-8"))
    names = {}
    catalog = json.loads(CAT.read_text(encoding="utf-8"))
    for row in catalog.get("weapons", []):
        names[row["id"]] = row.get("name", row["id"])
    spell_names = json.loads(SPELLS.read_text(encoding="utf-8"))
    for row in spell_names.get("spells", []):
        names.setdefault(row["id"], row.get("name", row["id"]))

    weapons = []
    for wid, data in raw.items():
        tip = data.get("tip") or "internal"
        skill = data.get("skill")
        rapid = int(data["char_rapid"]) if "char_rapid" in data else 5
        auto = rapid <= 6
        if "char_auto" in data:
            auto = bool(data["char_auto"])
        tipdam = data.get("char_tipdam")
        if tipdam is None:
            damage_type = "DAM_PIERCE"
        else:
            damage_type = DAMAGE[int(tipdam)]
        ammo = data.get("ammo_base") or ""
        throw_tip = int(data.get("throwtip") or 0)
        spell = bool(data.get("spell"))
        if tip == "melee":
            delivery = "melee"
        elif tip == "explosives":
            delivery = "mine" if throw_tip == 1 else "grenade"
        elif spell:
            delivery = "spell"
        else:
            delivery = "projectile"
        length = int(data["phis_long"]) if "phis_long" in data else 50
        min_length = int(data["phis_minlong"]) if "phis_minlong" in data else length
        row = {
            "id": wid,
            "name": names.get(wid, wid),
            "kind": tip,
            "skill": int(skill) if skill is not None else 0,
            "skill_id": SKILL.get(int(skill), "") if skill is not None else "",
            "lvl": int(data.get("lvl") or 0),
            "pers_lvl": int(data.get("perslvl") or 0),
            "perk": data.get("perk") or "",
            "damage": num(data.get("char_damage"), 0),
            "damage_expl": num(data.get("char_damexpl"), 0),
            "damage_type": damage_type,
            "pellets": int(data.get("char_kol") or 1),
            "burst": int(data.get("char_dkol") or 0),
            "spread": num(data.get("phis_deviation"), 0),
            "range": num(data.get("char_prec"), 0) * 40,
            "antiprec": num(data.get("char_antiprec"), 0) * 40,
            "rapid": rapid,
            "auto": auto,
            "prep": int(data.get("char_prep") or 0),
            "ammo": ammo,
            "ammo_per_shot": int(data.get("ammo_rashod") or 1),
            "mag": int(data.get("ammo_holder") or 0),
            "reload": int(data.get("ammo_reload") or 0),
            "recharg": int(data.get("ammo_recharg") or 0),
            "magic": num(data.get("ammo_magic"), 0),
            "mana": num(data.get("ammo_mana"), 0),
            "weight": num(data.get("phis_massa"), 0) / 50.0,
            "mass": int(data.get("phis_m") or 1),
            "sound": data.get("snd_shoot") or "",
            "speed": num(data.get("phis_speed"), 100),
            "radius": num(data.get("char_expl"), 0),
            "length": length,
            "min_length": min_length,
            "flame": int(data.get("phis_flame") or 0),
            "grav": num(data.get("phis_grav"), 0),
            "volna": bool(data.get("phis_volna")),
            "accel": num(data.get("phis_accel"), 0),
            "drot": num(data.get("phis_drot"), 0),
            "throw_tip": throw_tip,
            "fuse": int(data["char_time"]) if "char_time" in data else (75 if tip == "explosives" else 0),
            "dop_effect": data.get("dop_effect") or "",
            "dop_damage": num(data.get("dop_damage"), 0),
            "dop_chance": num(data.get("dop_ch"), 1),
            "spell": spell,
            "delivery": delivery,
            "effect": "",
        }
        extra = ITEM_SPELL.get(wid)
        if extra:
            row["spell"] = True
            row["delivery"] = "spell"
            row["kind"] = "magic"
            row["effect"] = extra.get("effect", "")
            row["magic"] = extra.get("magic", row["magic"])
            row["mana"] = extra.get("mana", row["mana"])
            row["culd"] = extra.get("culd", 0)
            row["radius"] = extra.get("rad", row["radius"])
            row["damage"] = extra.get("dam", row["damage"])
            row["sound"] = extra.get("snd") or row["sound"]
            row["dist"] = extra.get("dist", 0)
            row["spell_hp"] = extra.get("hp", 0)
        weapons.append(row)

    payload = {
        "source": "Remains-Source2 weapons.json via WeaponFactory numbers. speed is px/tick at 30 Hz. range is char_prec*40.",
        "tick_rate": 30,
        "new_game": NEW_GAME,
        "weapons": weapons,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print("wrote", len(weapons), "new_game", NEW_GAME)


if __name__ == "__main__":
    main()
