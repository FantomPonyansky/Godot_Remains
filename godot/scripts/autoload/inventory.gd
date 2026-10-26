extends Node

## Carried items for the slice. Counts live in user://inventory.cfg,
## the same ConfigFile style as progression.cfg and magic_binds.cfg.
## Ammo and other stackable tips add together. Guns, spells, and the
## PipBuck stay at one.
##
## Scripts.xml beginBeg (and addBegin) grants armor id "pip" and wears it.
## That act is not in the exported begin-land triggers, so a new game
## grants it here when GameState.reset_run() runs.

signal changed

const _UserDir := preload("res://scripts/user_dir.gd")
static var SAVE_PATH := _UserDir.run("inventory.cfg")
const PIP_ID := "pip"
const ITEMS_PATH := "res://assets/data/content/items.json"
const WEAPONS_PATH := "res://assets/data/weapons.json"
const CATALOG_PATH := "res://assets/data/content/weapons_catalog.json"
const HARD_INV_PATH := "res://assets/data/hard_inv.json"
const _AlicornForm := preload("res://scripts/story/alicorn_form.gd")
## items.xml uses='pot_use': ItemInteraction.minusItem plays it when one is spent.
const POT_USE: PackedStringArray = [
	"pot1", "pot2", "pot3", "potm1", "potm2", "potm3", "antidote", "potion_stim", "potion_fly", "potion_shadow",
	"potion_mage", "potion_infra", "potion_swim", "potion_pink", "potion_chance", "potion_purif", "potion_rat",
	"potion_dskel", "potion_might", "potion_immun", "potion_speed", "potion_prec", "potion_elements",
	"potion_dexter", "potion_crit", "potion_consc", "potHP", "potMP",
]
const DURABLE_KINDS: PackedStringArray = ["melee", "lightGun", "heavyGun"]

const GUN_TYPES: PackedStringArray = ["lightGun", "heavyGun"]
const UNIQUE_TYPES: PackedStringArray = ["melee", "explosives", "internal"]

var worn: String = ""
var amulet: String = ""
var weapon_id: String = ""
## UnitPlayer.currentSpell, cast by keyDef. Spells are never weapon_id.
var spell_id: String = ""
## Leg device from otherVisual. beginBeg's takeArmor is the stable grant.
## The item seeded at reset is not enough to draw it.
var leg_pip: bool = false
## Set by the debug console command. Cleared with the run. Not a new-game grant.
var kit_granted: bool = false

var _counts: Dictionary = {}
var _order: Array[String] = []
var _names: Dictionary = {}
var _roles: Dictionary = {}
var _slice: Dictionary = {}
var _applied_player: int = 0
var _hard: Dictionary = {}
var _overload_t := 0
## Pers.invMassParam results: maxSpeed (px a tick), jumpMult, shtrManaRes.
var _max_speed := 100.0
var _jump_mult := 1.0
var _mana_res := 1.0


func _ready() -> void:
	_load_catalogs()
	_load()


func _physics_process(_delta: float) -> void:
	_overload_t -= 1
	if _overload_t <= 0:
		_overload_t = 15
		_inv_mass_param()
	if weapon_id == "":
		return
	_apply_weapon()


func count(id: String) -> int:
	return int(_counts.get(id, 0))


func carried() -> Array[String]:
	return _order.duplicate()


## The text pack name in the current language; the JSON name is the fallback.
func name_of(id: String) -> String:
	var line := OriginalLines.name_of(id)
	if line != id:
		return line
	return str(_names.get(id, id))


func is_gun(id: String) -> bool:
	return _role(id) == "gun"


func is_spell(id: String) -> bool:
	return _role(id) == "spell"


## Item.L_SPELL (Weapon.spell). Magic weapons (WMagic) are is_spell but not this.
func casts_spell(id: String) -> bool:
	return is_spell(id) and bool((_slice.get(id, {}) as Dictionary).get("spell", false))


func is_consumable(id: String) -> bool:
	return GameState != null and GameState.has_method("is_consumable") and GameState.is_consumable(id)


func use(id: String) -> bool:
	# One Accept spends one stack charge. Guns and spells are not consumed.
	if not is_consumable(id) or count(id) <= 0:
		return false
	var block := str(GameState.consume_block(id))
	if block != "":
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notice"):
			hud.show_notice(block)
		return false
	if not GameState.consume_keeps(id):
		_counts[id] = count(id) - 1
		if count(id) <= 0:
			_counts.erase(id)
			_order.erase(id)
		_save()
		changed.emit()
		if id in POT_USE:
			SfxBank.play("pot_use")
	if GameState.has_method("apply_consumable"):
		GameState.apply_consumable(id)
	return true


func weapon_def(id: String) -> Dictionary:
	if not _slice.has(id):
		return {}
	return (_slice[id] as Dictionary).duplicate(true)


func owned_weapon_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _order:
		if (is_gun(id) or is_spell(id)) and not casts_spell(id) and not Stash.is_hidden(id) and not alicorn_locked(id):
			out.append(id)
	return out


## PipPageInv skips spells while the alicorn is on.
func owned_spell_ids() -> Array[String]:
	var out: Array[String] = []
	if ScriptsEngine.alicorn:
		return out
	for id in _order:
		if casts_spell(id) and not Stash.is_hidden(id):
			out.append(id)
	return out


## Weapon.alicorn: the a_* set stays in the bag after alicornOff, usable only as the alicorn.
func alicorn_locked(id: String) -> bool:
	return not ScriptsEngine.alicorn and id in _AlicornForm.WEAPONS


func can_wear(id: String) -> bool:
	if id == PIP_ID:
		return true
	var cond := get_node_or_null("/root/Condition")
	return cond != null and cond.has_method("is_armor") and bool(cond.call("is_armor", id))


func add(id: String, n: int = 1) -> void:
	if not _put(id, n):
		return
	# UnitPlayer.take equips the first weapon when nothing is in hand.
	if weapon_id == "" and (is_gun(id) or is_spell(id)) and not casts_spell(id):
		weapon_id = id
		_applied_player = 0
	_save()
	changed.emit()
	if weapon_id == id:
		_apply_weapon()


func body_armor_id(id: String) -> String:
	# changeArmor writes Appear.ggArmorId = currentArmor.id for a suit.
	# That id is the limb label Obj.setArmor stops on. Amulets (amul_*) do not.
	# The stable jumpsuit id is "pip", so wearing it does use the label (the new
	# game wears it: ItemInteraction.addBegin, UnitPlayer.as:339).
	if id == "" or id.begins_with("amul_"):
		return ""
	var cond := get_node_or_null("/root/Condition")
	if cond != null and cond.has_method("is_armor") and bool(cond.call("is_armor", id)):
		return id
	return ""


func wear(id: String) -> bool:
	if not can_wear(id) or count(id) <= 0:
		return false
	if ScriptsEngine.alicorn:
		var hud_a := get_tree().get_first_node_in_group("hud")
		if hud_a and hud_a.has_method("show_notice"):
			hud_a.show_notice(OriginalLines.info("alicornNot"))
		return false
	if not Stash.can_change_armor(id):
		return false
	var cond := get_node_or_null("/root/Condition")
	if cond and cond.has_method("armor_usable") and bool(cond.call("is_armor", id)) and not bool(cond.call("armor_usable", id)):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notice"):
			hud.show_notice(OriginalLines.gui("abr"))
		return false
	# changeArmor: an amulet (tip 3) is currentAmul, apart from the suit.
	if is_amulet(id):
		amulet = "" if amulet == id else id
		_save()
		changed.emit()
		return true
	var visual := body_armor_id(id)
	# Choosing the suit that is already on takes it off.
	if visual != "" and _puppet_armor() == visual:
		worn = ""
		_save()
		changed.emit()
		_push_armor("")
		return true
	worn = id
	Stash.armor_worn(id)
	_save()
	changed.emit()
	_push_armor(visual)
	return true


func unworn(id: String = "") -> void:
	if id != "" and id == amulet:
		amulet = ""
		_save()
		changed.emit()
		return
	worn = ""
	_save()
	changed.emit()
	_push_armor("")


func is_amulet(id: String) -> bool:
	return id != "" and (id.begins_with("amul_") or int(Vendors.armor_data(id).get("tip", 1)) == 3)


func is_worn(id: String) -> bool:
	return id != "" and (worn == id or amulet == id)


## currentArmor, then currentAmul.
func worn_ids() -> Array[String]:
	var out: Array[String] = []
	if worn != "":
		out.append(worn)
	if amulet != "":
		out.append(amulet)
	return out


func equip(id: String) -> bool:
	if count(id) <= 0 or not (is_gun(id) or is_spell(id)):
		return false
	if Stash.is_hidden(id) or alicorn_locked(id):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notice"):
			hud.show_notice(OriginalLines.info("disSpell" if is_spell(id) else "disWeapon"))
		if casts_spell(id):
			SfxBank.play("nomagic")
		return false
	if casts_spell(id) and ScriptsEngine.alicorn:
		var hud_a := get_tree().get_first_node_in_group("hud")
		if hud_a and hud_a.has_method("show_notice"):
			hud_a.show_notice(OriginalLines.info("alicornNot"))
		return false
	if casts_spell(id):
		change_spell(id)
		return true
	# UnitPlayer.changeWeapon returns early while attackForever or atkPoss 0.
	if Effects.attack_forever() or not GameState.attack_allowed():
		return false
	weapon_id = id
	_applied_player = 0
	_save()
	changed.emit()
	_apply_weapon()
	return true


## changeWeapon("not"): nothing drawn until the next equip.
func holster() -> void:
	if weapon_id == "":
		return
	weapon_id = ""
	_save()
	changed.emit()


## UnitPlayer.changeSpell: the same spell again clears currentSpell.
func change_spell(id: String, inform: bool = true) -> void:
	if id != "" and (count(id) <= 0 or not casts_spell(id)):
		return
	spell_id = "" if id == spell_id else id
	_save()
	changed.emit()
	if inform and spell_id != "":
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notice"):
			hud.show_notice(OriginalLines.info("usedSpell", OriginalLines.name_of(spell_id)))


func reset_run() -> void:
	_counts.clear()
	_order.clear()
	worn = ""
	amulet = ""
	weapon_id = ""
	spell_id = ""
	_applied_player = 0
	_put(PIP_ID, 1)
	worn = PIP_ID
	leg_pip = false
	kit_granted = false
	# PipBuck only. Scripts.xml beginBeg grants armor "pip".
	# Spells stay unlearned until the story, or until the debug command.
	# A new game does not equip a gun. Stable loot such as p10mm is picked up.
	_save()
	changed.emit()
	# ItemInteraction.addBegin sets cArmorId = "pip" and UnitPlayer.as:339
	# runs changeArmor("pip", true) on spawn, so Appear.ggArmorId is "pip" and
	# the jumpsuit is worn from the first frame. (beginBeg's "armor" act is only
	# the PipBuck preview id.) A puppet made later reads worn in its _ready.
	_push_armor(body_armor_id(worn))


func note_kit() -> void:
	kit_granted = true
	_save()


func grant_leg_pip() -> void:
	# Scripts.xml beginBeg takeArmor "pip" while the screen is black, before
	# the wake-up. Armor swaps do not clear it.
	if leg_pip:
		return
	leg_pip = true
	_save()
	changed.emit()


func _puppet_armor() -> String:
	var pony := _pony()
	if pony != null and pony.has_method("armor_id"):
		return str(pony.call("armor_id"))
	return ""


func _push_armor(id: String) -> void:
	var pony := _pony()
	if pony != null and pony.has_method("set_armor"):
		pony.call("set_armor", id)


func _pony() -> Node:
	if not is_inside_tree():
		return null
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	return player.get_node_or_null("Puppet")


func _put(id: String, n: int) -> bool:
	if id == "" or n <= 0:
		return false
	if _role(id) != "stack":
		if count(id) >= 1:
			return false
		_counts[id] = 1
	else:
		_counts[id] = count(id) + n
	if id not in _order:
		_order.append(id)
	return true


func _role(id: String) -> String:
	return str(_roles.get(id, "stack"))


func _apply_weapon() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("_publish_weapon"):
		return
	var iid := player.get_instance_id()
	if iid == _applied_player:
		return
	if _select_weapon(player, weapon_id):
		_applied_player = iid


func _select_weapon(player: Node, id: String) -> bool:
	var weapons: Array = []
	var current: Variant = player.get("_weapons")
	if current is Array:
		weapons = current
	var index := -1
	for i in weapons.size():
		var entry: Variant = weapons[i]
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("id", "")) == id:
			index = i
			break
	if index < 0:
		var made := _fire_def(id)
		if made.is_empty():
			return false
		weapons.append(made)
		player.set("_weapons", weapons)
		index = weapons.size() - 1
	player.set("_weapon_i", index)
	player.call("_publish_weapon")
	return true


func _fire_def(id: String) -> Dictionary:
	return weapon_def(id)


func _load_catalogs() -> void:
	_names.clear()
	_roles.clear()
	_slice.clear()
	_names[PIP_ID] = "PipBuck"
	_roles[PIP_ID] = "wear"
	for entry_v in _rows(ITEMS_PATH, "items"):
		var item: Dictionary = entry_v
		var item_id := str(item.get("id", ""))
		if item_id == "":
			continue
		_names[item_id] = str(item.get("name", item_id))
		if not _roles.has(item_id):
			_roles[item_id] = "stack"
	for entry_v in _rows(CATALOG_PATH, "weapons"):
		var listed: Dictionary = entry_v
		var listed_id := str(listed.get("id", ""))
		if listed_id == "":
			continue
		_names[listed_id] = str(listed.get("name", listed_id))
		var tip := str(listed.get("type", ""))
		if tip in GUN_TYPES:
			_roles[listed_id] = "gun"
		elif tip == "magic":
			_roles[listed_id] = "spell"
		elif tip in UNIQUE_TYPES:
			_roles[listed_id] = "unique"
	var weapon_doc := _doc(WEAPONS_PATH)
	for entry_v in weapon_doc.get("weapons", []):
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var gun: Dictionary = entry_v
		var gun_id := str(gun.get("id", ""))
		if gun_id == "":
			continue
		_names[gun_id] = str(gun.get("name", gun_id))
		var kind := str(gun.get("kind", ""))
		if kind == "magic" or bool(gun.get("spell", false)):
			_roles[gun_id] = "spell"
		else:
			_roles[gun_id] = "gun"
		_slice[gun_id] = gun
	_hard = _doc(HARD_INV_PATH)


func _doc(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Inventory missing %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Inventory could not parse %s" % path)
		return {}
	return parsed


func _rows(path: String, key: String) -> Array:
	var rows: Variant = _doc(path).get(key, [])
	if rows is Array:
		var out: Array = []
		for entry_v in rows:
			if typeof(entry_v) == TYPE_DICTIONARY:
				out.append(entry_v)
		return out
	return []


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("gear", "worn", worn)
	cfg.set_value("gear", "amulet", amulet)
	cfg.set_value("gear", "weapon", weapon_id)
	cfg.set_value("gear", "spell", spell_id)
	cfg.set_value("gear", "leg_pip", leg_pip)
	cfg.set_value("gear", "kit_granted", kit_granted)
	for i in _order.size():
		var id := _order[i]
		cfg.set_value("order", str(i), id)
		cfg.set_value("items", id, count(id))
	cfg.save(SAVE_PATH)


func _load() -> void:
	_counts.clear()
	_order.clear()
	worn = ""
	amulet = ""
	weapon_id = ""
	spell_id = ""
	leg_pip = false
	kit_granted = false
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	worn = str(cfg.get_value("gear", "worn", ""))
	amulet = str(cfg.get_value("gear", "amulet", ""))
	weapon_id = str(cfg.get_value("gear", "weapon", ""))
	spell_id = str(cfg.get_value("gear", "spell", ""))
	leg_pip = bool(cfg.get_value("gear", "leg_pip", false))
	kit_granted = bool(cfg.get_value("gear", "kit_granted", false))
	if cfg.has_section("order"):
		var indexes: Array[int] = []
		for key in cfg.get_section_keys("order"):
			indexes.append(int(key))
		indexes.sort()
		for i in indexes:
			var id := str(cfg.get_value("order", str(i), ""))
			var n := int(cfg.get_value("items", id, 0))
			if id != "" and n > 0 and id not in _order:
				if _role(id) == "stack":
					_counts[id] = n
				else:
					_counts[id] = n if n > 1 else 1
				_order.append(id)
	if worn != "" and is_amulet(worn):
		if amulet == "":
			amulet = worn
		worn = ""
	if worn != "" and count(worn) <= 0:
		worn = ""
	if amulet != "" and count(amulet) <= 0:
		amulet = ""
	if weapon_id != "" and count(weapon_id) <= 0:
		weapon_id = ""
	if casts_spell(weapon_id):
		if spell_id == "":
			spell_id = weapon_id
		weapon_id = ""
	if spell_id != "" and (count(spell_id) <= 0 or not casts_spell(spell_id)):
		spell_id = ""


# --- Limited inventory (GameContainer.hardInv) ---

## The hardinv new-game option, kept with the run.
func hard_inv() -> bool:
	return bool(UiSettings.value("game", "hardinv", false))


func set_hard_inv(on: bool) -> void:
	UiSettings.set_value("game", "hardinv", on)
	_inv_mass_param()


## ItemManager.getWeight.
func item_mass(id: String) -> float:
	return float(((_hard.get("items", {}) as Dictionary).get(id, {}) as Dictionary).get("m", 0.0))


## ItemManager.getInvCat: 1 equipment, 2 ammo and explosives, 3 everything else.
func inv_cat(id: String) -> int:
	return int(((_hard.get("items", {}) as Dictionary).get(id, {}) as Dictionary).get("cat", 3))


## Inventory.calcMass: mass[cat].
func mass(cat: int) -> float:
	var total := 0.0
	for id in _order:
		if inv_cat(id) == cat:
			total += item_mass(id) * float(count(id))
	return total


## Inventory.calcWeaponMass massW: weapons with durability.
func mass_w() -> int:
	var total := 0
	for id in _order:
		if str(weapon_def_kind(id)) in DURABLE_KINDS and not Stash.is_hidden(id):
			total += int((_slice[id] as Dictionary).get("mass", 1))
	return total


## Inventory.calcWeaponMass massM: magic weapons and learned spells.
func mass_m() -> int:
	var total := 0
	for id in _order:
		if weapon_def_kind(id) == "magic" and not Stash.is_hidden(id):
			total += int((_slice[id] as Dictionary).get("mass", 1))
	return total


func weapon_def_kind(id: String) -> String:
	if not _slice.has(id):
		return ""
	return str((_slice[id] as Dictionary).get("kind", ""))


## Pers maxmW / maxmM / maxm1..3: the base, plus perks.xml sk tip='m' (Pers.setSkillParam).
func max_mass(key: String) -> float:
	var total := float((_hard.get("base", {}) as Dictionary).get(key, 0.0))
	var perks: Dictionary = _hard.get("perks", {})
	for pid in perks:
		var lvl := int(Progression.perk_rank(str(pid)))
		for row_v in perks[pid]:
			var row: Dictionary = row_v
			if str(row.get("id", "")) != key:
				continue
			var val := float(row.get("v0", 0.0))
			if lvl > 0:
				if row.has("vd"):
					val += float(lvl) * float(row["vd"])
				elif row.has("v%d" % lvl):
					val = float(row["v%d" % lvl])
				else:
					val = float(row.get("v1", 0.0))
			total += val
	return total


## Item.checkAuto, the weight checks: false keeps a loot item on the ground
## for autopickup in limited inventory mode (pressing take still picks it up).
func auto_take_ok(id: String, n: int = 1) -> bool:
	if not hard_inv():
		return true
	if _slice.has(id) and not casts_spell(id):
		if count(id) > 0:
			return true
		var wm := int((_slice[id] as Dictionary).get("mass", 1))
		if wm == 0:
			return true
		var kind := weapon_def_kind(id)
		if kind == "magic":
			return float(mass_m()) <= max_mass("maxmM") - float(wm)
		if kind == "explosives":
			return false
		return float(mass_w()) <= max_mass("maxmW") - float(wm)
	if casts_spell(id) or can_wear(id):
		return true
	var m := item_mass(id)
	if m <= 0.0:
		return true
	var cat := inv_cat(id)
	return mass(cat) + m * float(n) <= max_mass("maxm%d" % cat)


## Pers.invMassParam: overload slows you outside base and training rooms.
func _inv_mass_param() -> void:
	var was := _max_speed
	_max_speed = 100.0
	_jump_mult = 1.0
	_mana_res = 1.0
	if not hard_inv():
		return
	var shtr := 0
	var w := float(mass_w())
	var max_w := max_mass("maxmW")
	if w > max_w:
		shtr += 1
	if w > max_w + 2.0:
		shtr += 1
	if w > max_w + 4.0:
		shtr += 1
	var max2 := max_mass("maxm2")
	if mass(2) > max2:
		shtr += 1
	if mass(2) > max2 * 1.2:
		shtr += 1
	var max3 := max_mass("maxm3")
	if mass(3) > max3:
		shtr += 1
	if mass(3) > max3 * 1.2:
		shtr += 1
	if not _in_safe_room():
		if shtr >= 3:
			_max_speed = 0.0
			_jump_mult = 0.0
			if was > 0.0:
				var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
				if hud and hud.has_method("show_notice"):
					hud.show_notice(OriginalLines.info("overMass"))
		elif shtr == 2:
			_max_speed = 3.5
			_jump_mult = 0.5
		elif shtr == 1:
			_max_speed = 7.0
	var over_m := float(mass_m()) - max_mass("maxmM")
	if over_m > 0.0:
		_mana_res = maxf(0.0, 1.0 - 0.25 * over_m)


## Pers.maxSpeed in px a tick: 100 is no cap, 7 is the walk speed.
func overload_max_speed() -> float:
	return _max_speed


func overload_jump_mult() -> float:
	return _jump_mult


## Pers.shtrManaRes.
func overload_mana_mult() -> float:
	return _mana_res


## Location.base / Location.train for the room the player is in.
func _in_safe_room() -> bool:
	if not is_inside_tree():
		return true
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var land := get_tree().get_first_node_in_group("active_land")
	if player == null or land == null:
		return true
	var props := land.get_node_or_null("Actors")
	if props == null or not props.has_method("room_options_at"):
		return false
	var options: Dictionary = props.call("room_options_at", player.global_position)
	return options.has("base") or options.has("train")


func spend(id: String, n: int = 1) -> bool:
	if n <= 0 or count(id) < n:
		return false
	var dropped_suit := false
	if _role(id) != "stack" and count(id) <= n:
		_counts.erase(id)
		_order.erase(id)
		if weapon_id == id:
			weapon_id = ""
			_applied_player = 0
		if spell_id == id:
			spell_id = ""
		if worn == id:
			worn = ""
			dropped_suit = true
		if amulet == id:
			amulet = ""
	else:
		_counts[id] = count(id) - n
		if count(id) <= 0:
			_counts.erase(id)
			_order.erase(id)
	_save()
	changed.emit()
	if dropped_suit:
		_push_armor("")
	return true


func add_crafted(id: String, n: int = 1) -> void:
	if n <= 0:
		return
	var before := count(id)
	add(id, n)
	if count(id) >= before + n:
		return
	_counts[id] = before + n
	if id not in _order:
		_order.append(id)
	_save()
	changed.emit()
