extends RefCounted

## PipPage.infoStr (PipPage.as ~587-1006). RichTextLabel BBCode.
## [word] in the text pack is yellow, same as PipBuck._bb.

const YEL := "ffff33"
const RED := "ff3333"
const PINK := "fc7fed"
## PipBuck.ORANGE is #ff9900. infoStr has no orange span.
## 'mass' on the dark pip green, and 'blue' for the damage type.
const MASS := "c8b070"
const BLUE := "66ccff"

const _DAMS: PackedStringArray = [
	"DAM_PIERCE", "DAM_CUT", "DAM_BLUNT", "DAM_BURN", "DAM_EXPLOSION", "DAM_LASER", "DAM_PLASMA",
	"DAM_VENOM", "DAM_EMP", "DAM_ELECTRIC", "DAM_ACID", "DAM_COLD", "DAM_POISON", "DAM_BLEED", "DAM_BITE",
]
## PipPage armor resist order (bullet, expl, phis, blade, fang, fire, ...).
const _RES_ORDER: PackedStringArray = [
	"DAM_PIERCE", "DAM_EXPLOSION", "DAM_BLUNT", "DAM_CUT", "DAM_BITE", "DAM_BURN",
	"DAM_LASER", "DAM_PLASMA", "DAM_ELECTRIC", "DAM_COLD", "DAM_VENOM", "DAM_ACID", "DAM_DEATH",
]
const _RES_PIP := {
	"DAM_PIERCE": "bullet", "DAM_EXPLOSION": "expl", "DAM_BLUNT": "phis", "DAM_CUT": "blade",
	"DAM_BITE": "fang", "DAM_BURN": "fire", "DAM_LASER": "laser", "DAM_PLASMA": "plasma",
	"DAM_ELECTRIC": "spark", "DAM_COLD": "crio", "DAM_VENOM": "venom", "DAM_ACID": "acid",
	"DAM_DEATH": "necro", "DAM_PINKCLOUD": "pink",
}

static var _eff: Dictionary = {}
static var _dex: Dictionary = {}


static func info_str(tip: String, id: String) -> String:
	# Armor id missing from AllData becomes an item. A spell weapon does too.
	if tip == "armor" and Vendors.armor_data(id).is_empty() and Condition.armor_row(id).is_empty():
		tip = "item"
	if tip == "weapon" and _is_spell(id):
		tip = "item"
	if tip == "weapon" or tip == "e":
		return _weapon_str(id)
	if tip == "armor":
		return _armor_str(id)
	if tip == "a":
		return _ammo_str(id)
	return _item_str(id)


static func _weapon_str(id: String) -> String:
	var w := Inventory.weapon_def(id)
	if w.is_empty():
		return ""
	var kind := str(w.get("kind", ""))
	var razn := _razn(w)
	var conf := _skill_conf(razn)
	var s := OriginalLines.pip("weapontip") + ": " + _yel(OriginalLines.pip("weapontip" + str(int(w.get("skill", 0)))))
	if int(w.get("lvl", 0)) > 0:
		var have := 0 if str(w.get("skill_id", "")) == "" else Progression.skill_level_of(str(w.skill_id))
		s += "\n" + OriginalLines.pip("lvl") + ": " + _yel(str(int(w.lvl)))
		s += "\n" + OriginalLines.pip("islvl") + ": " + _yel(str(have))
		if bool(w.get("lvl_nouse", false)) and razn > 0 or razn > 2:
			s += _col(RED, " (" + OriginalLines.pip("weapnouse") + ")")
		elif razn > 0:
			var which := "precision"
			if kind == "melee":
				which = "rapid"
			elif kind == "explosives":
				which = "distance"
			var pct := "-40% " if razn >= 2 else "-20% "
			s += _col(RED, " (" + pct + OriginalLines.pip(which) + ")")
	if int(w.get("pers_lvl", 0)) > 0:
		s += "\n" + OriginalLines.pip("perslvl") + ": " + _yel(str(int(w.pers_lvl)))
		s += "\n" + OriginalLines.pip("isperslvl") + ": " + _yel(str(Progression.level))
		if Progression.level < int(w.pers_lvl):
			s += _col(RED, " (" + OriginalLines.pip("weapnouse") + ")")
	var wdam := float(w.get("damage", 0.0))
	var wdx := float(w.get("damage_expl", 0.0))
	s += "\n" + OriginalLines.pip("damage") + ": "
	if wdam > 0.0:
		s += _yel(_tenth(wdam))
		var calc := _result_damage(w, wdam)
		if not is_equal_approx(calc, wdam):
			s += " (" + _yel(_tenth(calc)) + ")"
	if wdam > 0.0 and wdx > 0.0:
		s += " + "
	if wdx > 0.0:
		s += _yel(_tenth(wdx * _dam_mult(w)))
		var calc_x := _result_damage(w, wdx)
		if not is_equal_approx(calc_x, wdx):
			s += " (" + _yel(_tenth(calc_x)) + ")"
		s += " " + OriginalLines.pip("expldam")
	var kol := int(w.get("pellets", 1))
	if kol > 1:
		s += _bb(" [x%d]" % kol)
	var expl_kol := int(w.get("expl_kol", 1))
	if expl_kol > 1:
		s += _bb(" [x%d]" % expl_kol)
	if kind != "explosives":
		var wrap := maxf(_result_rapid(w, razn), 0.05)
		var tps := float(Effects.TPS)
		var shots := float(maxi(kol, 1))
		s += "\n" + OriginalLines.pip("aps") + ": " + _yel(_fix1(tps / wrap))
		s += "\n" + OriginalLines.pip("dps") + ": " + _yel(_fix1((wdam + wdx) * shots * tps / wrap))
		var mag := int(w.get("mag", 0))
		if mag > 0:
			var reload_m := Effects.stat("reloadMult", Progression.pers("reloadMult", 1.0))
			var rash := float(w.get("ammo_per_shot", 1))
			var gap := wrap + float(w.get("reload", 0.0)) * reload_m / float(mag) * rash
			s += " (" + _yel(_fix1((wdam + wdx) * shots * tps / maxf(gap, 0.05))) + ")"
	var crit := float(w.get("crit", 0.0)) + Progression.weapon_perk(w, "Critch", 0.0) + 0.05 + Progression.get_crit_chance()
	s += "\n" + OriginalLines.pip("critch") + ": " + _yel(str(int(round(crit * 100.0))) + "%")
	s += "\n" + OriginalLines.pip("tipdam") + ": " + _col(BLUE, _tipdam(w))
	if kind != "explosives" and kind != "magic" and int(w.get("mag", 0)) > 0:
		var ammo := str(w.get("ammo", ""))
		s += "\n" + OriginalLines.pip("inv5") + ": " + _yel(Inventory.name_of(ammo) if ammo != "" else "")
		s += "\n" + OriginalLines.pip("holder") + ": " + _yel(str(int(w.mag)))
	if int(w.get("ammo_per_shot", 1)) > 1:
		s += " (" + _yel(str(int(w.ammo_per_shot))) + " " + OriginalLines.pip("rashod") + ")"
	if kind == "magic":
		s += "\n" + OriginalLines.pip("dmana") + ": " + _yel(str(int(round(float(w.get("mana", 0.0))))))
	if float(w.get("range", 0.0)) > 0.0:
		var prec_m := GameState.aim_prec_mult() * Progression.weapon_perk(w, "Prec", 1.0)
		s += "\n" + OriginalLines.pip("prec") + ": " + _yel(str(int(round(float(w.range) * prec_m / 40.0))))
	var pier := float(w.get("pier", 0.0)) + Progression.weapon_perk(w, "Pier", 0.0)
	if pier > 0.0:
		s += "\n" + OriginalLines.pip("pier") + ": " + _yel(str(int(round(pier))))
	if not bool(w.get("no_sats", false)) and w.has("sats_cons"):
		var cost := float(w.sats_cons) * Progression.weapon_perk(w, "Cons", 1.0) / conf * Progression.pers("satsMult", 1.0)
		s += "\n" + OriginalLines.pip("ap") + ": " + _col(RED if razn > 0 else YEL, str(int(round(cost))))
		if int(w.get("sats_que", 1)) > 1:
			s += " (x" + _yel(str(int(w.sats_que))) + ")"
	if float(w.get("destroy", 0.0)) >= 100.0:
		s += "\n" + OriginalLines.pip("destroy")
	var opt: Variant = w.get("opt", {})
	if opt is Dictionary and str((opt as Dictionary).get("perk", "")) != "":
		s += "\n" + OriginalLines.pip("refperk") + ": " + _col(PINK, _bb(OriginalLines.eff(str(opt.perk))))
	if Inventory.hard_inv() and kind != "explosives" and kind != "magic":
		s += "\n" + OriginalLines.pip("mass2") + ": " + _col(MASS, str(w.get("mass", 0)))
	elif Inventory.hard_inv() and kind == "explosives":
		s += "\n\n" + OriginalLines.pip("mass") + ": " + _col(MASS, _num(Inventory.item_mass(id)))
		s += " (" + OriginalLines.pip("vault" + str(Inventory.inv_cat(id))) + ")"
	var sinf := OriginalLines.desc("weapon", id)
	if sinf == "":
		sinf = OriginalLines.desc("weapon", str(w.get("id", id)))
	s += "\n\n" + _bb(OriginalLines.text_vars(sinf, id))
	return s


static func _armor_str(id: String) -> String:
	var arm := Condition.armor_row(id)
	if arm.is_empty() and Vendors.armor_data(id).is_empty():
		return ""
	var s := ""
	if float(arm.get("qual", 0.0)) > 0.0:
		s += OriginalLines.pip("aqual") + ": " + _yel(str(int(round(float(arm.qual) * 100.0))) + "%")
	if float(arm.get("armor", 0.0)) > 0.0:
		s += "\n" + OriginalLines.pip("armor") + ": " + _yel(str(int(round(float(arm.armor)))))
	if float(arm.get("marmor", 0.0)) > 0.0:
		s += "\n" + OriginalLines.pip("marmor") + ": " + _yel(str(int(round(float(arm.marmor)))))
	var dex := _dexter(id)
	if dex != 0.0:
		s += "\n" + OriginalLines.pip("dexter") + ": " + _yel(str(int(round(dex * 100.0))) + "%")
	var sneak := Progression.armor_sneak(id)
	if sneak != 0.0:
		s += "\n" + OriginalLines.pip("sneak") + ": " + _yel(str(int(round(sneak * 100.0))) + "%")
	s += _mult_line(arm, "melee", "meleedamage")
	s += _mult_line(arm, "guns", "gunsdamage")
	s += _mult_line(arm, "magic", "spelldamage")
	if arm.has("crit") and not is_equal_approx(float(arm.crit), 0.0):
		s += "\n" + OriginalLines.pip("critch") + ": +" + _yel(str(int(round(float(arm.crit) * 100.0))) + "%")
	var resists: Dictionary = arm.get("resists", {})
	var seen := {}
	for tip in _RES_ORDER:
		seen[tip] = true
		var rv := float(resists.get(tip, 0.0))
		if rv != 0.0:
			s += "\n" + OriginalLines.pip(str(_RES_PIP.get(tip, tip))) + ": " + _yel(str(int(round(rv * 100.0))) + "%")
	for tip in resists:
		if seen.has(tip):
			continue
		var rv2 := float(resists[tip])
		if rv2 != 0.0:
			s += "\n" + OriginalLines.pip(str(_RES_PIP.get(tip, tip))) + ": " + _yel(str(int(round(rv2 * 100.0))) + "%")
	var body := OriginalLines.text_vars(OriginalLines.desc("armor", id), id)
	return s + "\n\n" + _bb(body)


static func _ammo_str(id: String) -> String:
	var pot := _item(id)
	var s := ""
	if not Inventory.weapon_def(id).is_empty() or not Vendors.weapon_data(id).is_empty():
		s = _bb(OriginalLines.text_vars(OriginalLines.desc("weapon", id), id))
	elif str(pot.get("base", "")) != "":
		s = _bb(_item_body(str(pot.base)))
		if str(pot.get("mod", "")) != "":
			s += "\n\n" + _bb(OriginalLines.desc("pip", "ammomod_" + str(pot.mod)))
	else:
		s = _bb(_item_body(id))
	s += "\n"
	if pot.has("damage") and not is_equal_approx(float(pot.damage), 1.0):
		s += "\n" + OriginalLines.pip("damage") + ": x" + _yel(_num(float(pot.damage)))
	if pot.has("pier") and not is_equal_approx(float(pot.pier), 0.0):
		s += "\n" + OriginalLines.pip("pier") + ": " + _yel(_num(float(pot.pier)))
	if pot.has("armor") and not is_equal_approx(float(pot.armor), 1.0):
		s += "\n" + OriginalLines.pip("tarmor") + ": x" + _yel(_num(float(pot.armor)))
	if pot.has("prec") and not is_equal_approx(float(pot.prec), 1.0):
		s += "\n" + OriginalLines.pip("prec") + ": x" + _yel(_num(float(pot.prec)))
	if float(pot.get("det", 0.0)) > 0.0:
		s += "\n" + OriginalLines.pip("det")
	if Inventory.hard_inv() and float(pot.get("m", 0.0)) > 0.0:
		s += "\n\n" + OriginalLines.pip("mass") + ": " + _col(MASS, _num(float(pot.m)))
		s += " (" + OriginalLines.pip("vault" + str(Inventory.inv_cat(id))) + ")"
	if float(pot.get("sell", 0.0)) > 0.0:
		s += "\n" + OriginalLines.pip("sell") + ": " + _yel(_num(float(pot.sell)))
	return s


static func _item_str(id: String) -> String:
	var pot := _item(id)
	var w := Inventory.weapon_def(id)
	var itip := str(pot.get("tip", ""))
	if itip == "" and bool(w.get("spell", false)):
		itip = "spell"
	var s := _bb(_item_body(id)) + "\n"
	if OriginalLines.desc("item", id) == "" and bool(w.get("spell", false)):
		s = _bb(OriginalLines.text_vars(OriginalLines.desc("weapon", id), id)) + "\n"
	if itip == "instr" or itip == "impl" or itip == "art":
		s = _eff_str("item", id) + "\n"
	if itip == "med" or itip == "food" or itip == "pot" or itip == "him":
		var hm := GameState.heal_mult()
		if pot.has("hhp") or pot.has("hhplong"):
			s += "\n" + OriginalLines.pip("healhp") + ": " + _yel(str(int(round(float(pot.get("hhp", 0.0)) * hm))))
		if pot.has("hhplong"):
			s += "+" + _yel(str(int(round(float(pot.hhplong) * hm))))
		if pot.has("hrad"):
			s += "\n" + OriginalLines.pip("healrad") + ": " + _yel(str(int(round(float(pot.hrad) * hm))))
		if pot.has("hcut"):
			s += "\n" + OriginalLines.pip("healcut") + ": " + _yel(str(int(round(float(pot.hcut)))))
		if pot.has("hpoison"):
			s += "\n" + OriginalLines.pip("healpoison") + ": " + _yel(str(int(round(float(pot.hpoison)))))
		if pot.has("horgan"):
			s += "\n" + OriginalLines.pip("healorgan") + ": " + _yel(str(int(round(float(pot.horgan)))))
		if pot.has("horgans"):
			s += "\n" + OriginalLines.pip("healorgans") + ": " + _yel(str(int(round(float(pot.horgans)))))
		if pot.has("hblood"):
			s += "\n" + OriginalLines.pip("healblood") + ": " + _yel(str(int(round(float(pot.hblood)))))
		if pot.has("hmana"):
			# Pers.healManaMult is not a port API. GameState restores the raw amount.
			s += "\n" + OriginalLines.pip("healmana") + ": " + _yel(str(int(round(float(pot.hmana)))))
		if pot.has("alc"):
			s += "\n" + OriginalLines.pip("alcohol") + ": " + _yel(str(int(round(float(pot.alc)))))
		if pot.has("rad"):
			s += "\n" + OriginalLines.pip("rad") + ": " + _yel(str(int(round(float(pot.rad)))))
		if pot.has("effect"):
			s += "\n" + OriginalLines.pip("refeff") + ": " + _eff_str("eff", str(pot.effect))
		if pot.has("perk"):
			var pk := Progression.perk_rank(str(pot.perk))
			s += "\n" + _col(PINK, _bb(OriginalLines.eff(str(pot.perk)))) + ": " + OriginalLines.pip("level") + " "
			s += str(pk) if pk > 0 else "0"
		if pot.has("maxperk"):
			s += "/" + str(pot.maxperk)
	if itip == "book" and _is_skill(id):
		s += "\n" + OriginalLines.pip("skillup") + ": " + _col(PINK, _bb(OriginalLines.eff(id)))
	if itip == "spell":
		var mana := float(pot.get("mana", w.get("mana", 0.0)))
		var culd := float(pot.get("culd", w.get("culd", 0.0)))
		var sec := OriginalLines.gui("sec")
		s += "\n" + OriginalLines.pip("dmana2") + ": " + _yel(_num(mana))
		s += " (" + _yel(str(int(round(mana * GameState.mana_cost_mult())))) + ")"
		s += "\n" + OriginalLines.pip("culd") + ": " + _yel(_num(culd) + sec)
		s += " (" + _yel(str(int(round(culd * Progression.spell_down()))) + sec) + ")"
		var tele := float(pot.get("tele", 0.0)) > 0.0 or str(w.get("skill_id", "")) == "tele"
		s += "\n" + OriginalLines.pip("is1") + ": " + _col(PINK, _bb(OriginalLines.eff("tele" if tele else "magic")))
	if id == "rep" and pot.has("hp"):
		var heal := float(pot.hp) * Condition.repair_mult()
		if heal > 0.0:
			s += "\n" + OriginalLines.pip("effect") + ": " + _yel(str(int(round(heal))))
	var pet_id := str(pot.get("pet_info", ""))
	if pet_id == "":
		pet_id = Pets.item_pet(id)
	if pet_id != "" and Pets.pet_alive() and str(Pets.current) == pet_id:
		var st := Pets.stats(pet_id)
		s += "\n" + OriginalLines.pip("hp") + ": " + _yel(str(int(round(Pets.hp_of(pet_id)))))
		s += "/" + _yel(str(int(round(float(st.get("maxhp", 0.0))))))
		s += "\n" + OriginalLines.pip("skin") + ": " + _yel(str(int(round(float(st.get("skin", 0.0))))))
		if float(st.get("vulner", 1.0)) < 1.0:
			s += "\n" + OriginalLines.pip("allresist") + ": " + _yel(str(int(round((1.0 - float(st.vulner)) * 100.0))) + "%")
		s += "\n" + OriginalLines.pip("damage") + ": " + _yel(str(int(round(float(st.get("dam", 0.0))))))
	if itip == "paint":
		s = _bb(OriginalLines.desc("pip", "paint"))
	if Inventory.hard_inv() and float(pot.get("m", 0.0)) > 0.0:
		s += "\n\n" + OriginalLines.pip("mass") + ": " + _col(MASS, _num(float(pot.m)))
		s += " (" + OriginalLines.pip("vault" + str(Inventory.inv_cat(id))) + ")"
	if float(pot.get("sell", 0.0)) > 0.0:
		s += "\n" + OriginalLines.pip("sell") + ": " + _yel(_num(float(pot.sell)))
	return s


## PipPage.effStr for an item or an effect id. Perk requirements and the
## hard-inventory sk rows are not in pip_eff.json.
static func _eff_str(section: String, id: String) -> String:
	var look := id
	if look.ends_with("_ad"):
		look = look.substr(0, look.length() - 3)
	var text_section := "item" if section == "item" else "eff"
	var s := OriginalLines.desc(text_section, id)
	var dp: Dictionary = _effs().get(look, {})
	var lvl := 1
	if str(dp.get("him", "")) == "2":
		var ad := int(Effects.addictions.get(look, 0))
		if ad >= Effects.AD2:
			lvl = 2
		if ad >= Effects.AD3:
			lvl = 3
	elif str(dp.get("him", "")) == "1":
		lvl = Effects.him_level()
	s = OriginalLines.text_vars(s, look, lvl)
	var effs: Array = dp.get("eff", [])
	if not effs.is_empty() and lvl > 0:
		s += "\n"
		for e in effs:
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = e
			var eid := str(row.get("id", ""))
			s += "\n" + OriginalLines.pip(eid if eid != "" else "refeff") + ": [" + str(row.get("n%d" % lvl, "")) + "]"
	return _bb(s)


static func _item(id: String) -> Dictionary:
	var row: Dictionary = Vendors.item_data(id).duplicate()
	var fx: Dictionary = Effects.item_row(id)
	for k in fx:
		row[k] = fx[k]
	return row


static func _item_body(id: String) -> String:
	var body := OriginalLines.desc("item", id)
	if body == "":
		body = OriginalLines.desc("ammo", id)
	return OriginalLines.text_vars(body, id)


static func _is_spell(id: String) -> bool:
	if bool(Inventory.weapon_def(id).get("spell", false)):
		return true
	return int(Vendors.weapon_data(id).get("spell", 0)) > 0


static func _is_skill(id: String) -> bool:
	for entry in Progression.skills():
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("id", "")) == id:
			return true
	return false


static func _razn(w: Dictionary) -> int:
	var sid := str(w.get("skill_id", ""))
	if sid == "":
		return 0
	return int(w.get("lvl", 0)) - Progression.skill_level_of(sid)


## PipPage skillConf: 0.75 one level short, 0.5 two or more.
static func _skill_conf(razn: int) -> float:
	if razn == 1:
		return 0.75
	if razn >= 2:
		return 0.5
	return 1.0


static func _dam_mult(w: Dictionary) -> float:
	var m := GameState.damage_dealt_mult("")
	var skill := int(w.get("skill", 0))
	if skill == 2 or skill == 3 or skill == 4:
		m *= Effects.stat("gunsDamMult", 1.0) * Progression.pers("gunsDamMult", 1.0)
	m *= Progression.weapon_perk(w, "Dam", 1.0)
	var kind := str(w.get("kind", ""))
	if kind == "melee":
		m *= Effects.stat("meleeDamMult", 1.0) * Progression.pers("meleeDamMult", 1.0)
	elif kind == "magic":
		m *= GameState.spell_damage_mult() * Progression.pers("spellsDamMult", 1.0)
	return m


static func _result_damage(w: Dictionary, dam0: float) -> float:
	var kind := str(w.get("kind", ""))
	var add := Progression.weapon_perk(w, "Det", 0.0)
	var sk := 1.0
	var sid := str(w.get("skill_id", ""))
	if sid != "":
		sk = 1.0 + 0.05 * float(Progression.rank(sid))
	var m := _dam_mult(w)
	if kind == "magic":
		return (dam0 + add) * m * sk
	var plus := 1.0
	var razn := _razn(w)
	if razn < 0:
		plus = 1.0 - float(razn) * 0.1
	var br := 0.6 if kind == "melee" else 0.3
	return (dam0 + add) * m * sk * plus * (1.0 - _breaking(w) * br)


static func _breaking(w: Dictionary) -> float:
	var wid := str(w.get("id", ""))
	var top := float(Condition.weapon_max(wid))
	if top <= 0.0:
		return 0.0
	var hp := Condition.weapon_hp(wid)
	if hp >= top / 2.0:
		return 0.0
	return (top - hp) / top * 2.0 - 1.0


static func _result_rapid(w: Dictionary, razn: int) -> float:
	var rap := maxf(float(w.get("rapid", 1.0)), 1.0)
	if str(w.get("kind", "")) != "melee":
		return rap
	var spd := maxf(GameState.melee_speed_mult() + Progression.pers("meleeSpdMult", 0.0), 0.05)
	return rap / maxf(_skill_conf(razn), 0.05) / spd


static func _tipdam(w: Dictionary) -> String:
	var i := _DAMS.find(str(w.get("damage_type", "")))
	return OriginalLines.pip("tipdam%d" % (i if i >= 0 else 0))


static func _mult_line(arm: Dictionary, key: String, label: String) -> String:
	if not arm.has(key):
		return ""
	var m := float(arm[key])
	if is_equal_approx(m, 1.0):
		return ""
	return "\n" + OriginalLines.pip(label) + ": +" + _yel(str(int(round((m - 1.0) * 100.0))) + "%")


static func _dexter(id: String) -> float:
	if _dex.is_empty():
		var parsed: Variant = {}
		if FileAccess.file_exists("res://assets/data/armor_dexter.json"):
			parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/armor_dexter.json"))
		_dex = parsed if parsed is Dictionary else {"_": []}
	var levels: Array = _dex.get(id, [])
	if levels.is_empty():
		return 0.0
	var lvl := clampi(Condition.armor_level(id), 0, levels.size() - 1)
	return float(levels[lvl])


static func _effs() -> Dictionary:
	if _eff.is_empty():
		var parsed: Variant = {}
		if FileAccess.file_exists("res://assets/data/pip_eff.json"):
			parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/pip_eff.json"))
		_eff = parsed if parsed is Dictionary else {"_": {}}
	return _eff


static func _bb(s: String) -> String:
	s = s.replace("[", "\u0001").replace("]", "\u0002")
	return s.replace("\u0001", "[color=#%s]" % YEL).replace("\u0002", "[/color]")


static func _col(hex: String, v: String) -> String:
	return "[color=#%s]%s[/color]" % [hex, v]


static func _yel(v: String) -> String:
	return _col(YEL, v)


static func _num(n: float) -> String:
	if is_equal_approx(n, roundf(n)):
		return str(int(roundf(n)))
	return str(snappedf(n, 0.01))


static func _tenth(n: float) -> String:
	return _num(roundf(n * 10.0) / 10.0)


static func _fix1(n: float) -> String:
	return "%.1f" % n
