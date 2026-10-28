extends RefCounted

## AllData <param> rows for PipPageStat PAGE_MAIN: [id, v, tip, show].
## v "" is a heading. tip 0 raw (shown above 0), 1 +/-(p-1)%, 2 p%,
## 3 and 4 +(1-p)% (shown when not 1); 4 is a resistance index.
## show 2 needs armor or marmor, show 3 the story_canter trigger.
const ROWS := [
	["param_atk", "", "", 1],
	["alldamage", "allDamMult", "1", 1],
	["meleedamage", "meleeDamMult", "1", 1],
	["meleerapid", "meleeSpdMult", "1", 1],
	["gunsdamage", "gunsDamMult", "1", 1],
	["allprec", "allPrecMult", "1", 1],
	["reload", "reloadMult", "1", 1],
	["spelldamage", "spellsDamMult", "1", 1],
	["punchdamage", "punchDamMult", "1", 1],
	["param_def", "", "", 1],
	["skin", "skin", "0", 1],
	["armor", "armor", "0", 1],
	["marmor", "marmor", "0", 1],
	["aqual", "armor_qual", "2", 2],
	["dexter", "dexter", "1", 1],
	["allresist", "allVulnerMult", "3", 1],
	["bullet", "0", "4", 1],
	["blade", "1", "4", 1],
	["phis", "2", "4", 1],
	["fang", "14", "4", 1],
	["expl", "4", "4", 1],
	["fire", "3", "4", 1],
	["crio", "11", "4", 1],
	["laser", "5", "4", 1],
	["plasma", "6", "4", 1],
	["spark", "9", "4", 1],
	["venom", "7", "4", 1],
	["acid", "10", "4", 1],
	["pink", "19", "4", 3],
	["necro", "16", "4", 1],
	["param_oth", "", "", 1],
	["sneak", "visiMult", "3", 1],
	["allspeed", "allSpeedMult", "1", 1],
	["runspeed", "runSpeedMult", "1", 1],
	["stamrun", "stamRun", "2", 1],
	["alldmana", "allDManaMult", "2", 1],
	["wmana", "warlockDManaMult", "2", 1],
	["healeff", "healMult", "2", 1],
	["lockpick", "lockPick", "0", 1],
	["hacker", "hacker", "0", 1],
	["od", "maxOd", "0", 1],
]

## Unit.as D_* index -> the port's damage tip.
const RES_TIPS := {
	0: "DAM_PIERCE", 1: "DAM_CUT", 2: "DAM_BLUNT", 3: "DAM_BURN", 4: "DAM_EXPLOSION",
	5: "DAM_LASER", 6: "DAM_PLASMA", 7: "DAM_VENOM", 9: "DAM_ELECTRIC", 10: "DAM_ACID",
	11: "DAM_COLD", 14: "DAM_BITE", 16: "DAM_DEATH", 19: "DAM_PINKCLOUD",
}

const _LockUse := preload("res://scripts/lock_use.gd")


## [id, label value] pairs in PipPageStat order; a heading has value "".
static func rows() -> Array:
	var out: Array = []
	var arm := _worn_row()
	for r in ROWS:
		var id: String = r[0]
		var v: String = r[1]
		var tip: String = r[2]
		var show: int = r[3]
		if show == 2 and float(arm.get("armor", 0.0)) <= 0.0 and float(arm.get("marmor", 0.0)) <= 0.0:
			continue
		if show == 3 and int(Travel.triggers.get("story_canter", 0)) <= 0:
			continue
		if v == "":
			out.append([id, ""])
			continue
		var p := _value(v, tip, arm)
		match tip:
			"0":
				if p > 0.0:
					out.append([id, _numb(p)])
			"1":
				if not is_equal_approx(p, 1.0):
					out.append([id, ("+" if p >= 1.0 else "") + _numb((p - 1.0) * 100.0) + "%"])
			"2":
				out.append([id, _numb(p * 100.0) + "%"])
			"3", "4":
				if not is_equal_approx(p, 1.0):
					out.append([id, ("+" if p < 1.0 else "") + _numb((1.0 - p) * 100.0) + "%"])
	return out


static func _value(v: String, tip: String, arm: Dictionary) -> float:
	if tip == "4":
		return _vulner(str(RES_TIPS.get(int(v), "")))
	match v:
		"allDamMult":
			return GameState.damage_dealt_mult("")
		"meleeDamMult":
			return Effects.stat("meleeDamMult", 1.0) * Progression.pers("meleeDamMult", 1.0)
		"meleeSpdMult":
			return maxf(GameState.melee_speed_mult() + Progression.pers("meleeSpdMult", 0.0), 0.05)
		"gunsDamMult":
			return Effects.stat("gunsDamMult", 1.0) * Progression.pers("gunsDamMult", 1.0)
		"allPrecMult":
			return GameState.aim_prec_mult()
		"reloadMult":
			return Effects.stat("reloadMult", Progression.pers("reloadMult", 1.0))
		"spellsDamMult":
			return GameState.spell_damage_mult() * Progression.pers("spellsDamMult", 1.0)
		"punchDamMult":
			return Effects.stat("punchDamMult", Progression.pers("punchDamMult", 1.0))
		"skin":
			return GameState.skin()
		"armor", "marmor":
			return float(arm.get(v, 0.0))
		"armor_qual":
			return float(arm.get("qual", 1.0))
		"dexter":
			return Progression.player_dexter()
		"allVulnerMult":
			return GameState.damage_taken_mult()
		"visiMult":
			var visi := Effects.stat("visiMult", 1.0)
			for worn in Inventory.worn_ids():
				visi *= 1.0 - Progression.armor_sneak(worn)
			return visi
		"allSpeedMult":
			return GameState.move_speed_mult()
		"runSpeedMult":
			return GameState.sprint_speed_mult() * 2.0
		"stamRun":
			return Effects.stat("stamRun", Progression.pers("stamRun", 1.0))
		"allDManaMult":
			return GameState.mana_cost_mult()
		"warlockDManaMult":
			return Progression.warlock_mult()
		"healMult":
			return GameState.heal_mult()
		"lockPick":
			return float(_LockUse._pick_points())
		"hacker":
			return float(_LockUse._hack_points())
		"maxOd":
			return Effects.stat("maxOd", Progression.pers("maxOd", 75.0))
	return 1.0


## gg.vulner[i]: effect and perk vulnerability less the suit and amulet resists.
static func _vulner(tip: String) -> float:
	if tip == "":
		return 1.0
	var v := maxf(0.0, Effects.player_vulner(tip) + Progression.perk_vulner(tip) - 1.0)
	var res := 0.0
	for worn in Inventory.worn_ids():
		res += float((Condition.armor_row(str(worn)).get("resists", {}) as Dictionary).get(tip, 0.0))
	return v * (1.0 - res)


static func _worn_row() -> Dictionary:
	var id := str(Inventory.worn)
	return Condition.armor_row(id) if id != "" else {}


## Res.numb: whole numbers stay whole, otherwise one decimal.
static func _numb(n: float) -> String:
	var r := snappedf(n, 0.1)
	return str(int(r)) if is_equal_approx(r, roundf(r)) else str(r)
