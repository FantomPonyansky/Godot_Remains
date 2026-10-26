class_name LootRoll
extends RefCounted

## Container rolls from Remains LootGen.lootCont / newLoot / getRandom.
## Weighted pools: res://assets/data/loot/pools.json
## (weapons.json, items.json, ammo.json, schematics.json).
## Which container uses which table: res://assets/data/loot/containers.json
## (objs.xml cont). Begin land is story difficulty 0, plot stage 1.

const POOLS_PATH := "res://assets/data/loot/pools.json"
const BOXES_PATH := "res://assets/data/loot/containers.json"

static var _loaded := false
static var _tips: Dictionary = {}
static var _info: Dictionary = {}
static var _boxes: Dictionary = {}
static var _limits: Dictionary = {}

var _drops: Array = []
var _got := 0
var _stage := 1
var _locdif := 0.0
var _dif_full := 0.0
var _wlevel := 1.0
var _lockdif := 50.0
var _biom := 0
var _land_rnd := false
var _broken := false
var _cap := 3.0


## broken: Interact.lootBroken, the container was smashed open.
static func roll(cont: String, broken := false) -> Array:
	_ensure()
	if cont == "" or cont == "empty" or cont == "*":
		return []
	var gen: RefCounted = (load("res://scripts/loot_roll.gd") as GDScript).new()
	return gen.call("_run", cont, broken) as Array


static func container(id: String) -> Dictionary:
	_ensure()
	var found: Variant = _boxes.get(id, {})
	if typeof(found) != TYPE_DICTIONARY:
		return {}
	return (found as Dictionary).duplicate()


static func is_single(id: String) -> bool:
	_ensure()
	if _marked(id):
		return true
	var base := id.split("^")[0]
	return base != id and _marked(base)


## LootGen.newLoot for a fixed Interact item (lootId) of a smashed container:
## money and bits halve, ammo and explosives drop half the time. Returns the count, 0 for none.
## LootGen.lootId: money and bits times capsMult / bitsMult (fortune) and difCapsMult.
static func caps_count(id: String, n: int) -> int:
	if id != "money" and id != "bit":
		return n
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return n
	var prog: Node = tree.root.get_node_or_null("Progression")
	var state: Node = tree.root.get_node_or_null("GameState")
	var luck: float = float(prog.call("pers", "capsMult" if id == "money" else "bitsMult", 1.0)) if prog else 1.0
	var dif: float = float(state.call("dif_value", "caps_mult")) if state else 1.0
	return int(float(n) * luck * dif)


static func broken_count(id: String, n: int) -> int:
	_ensure()
	if id == "money" or id == "bit":
		return int(floor(float(n) * 0.5))
	for tip in ["a", "e"]:
		for entry_v in _tips.get(tip, []):
			if typeof(entry_v) == TYPE_DICTIONARY and str((entry_v as Dictionary).get("id", "")) == id:
				return 0 if randf() < 0.5 else n
	return n


static func _marked(id: String) -> bool:
	var found: Variant = _info.get(id, {})
	return typeof(found) == TYPE_DICTIONARY and bool((found as Dictionary).get("single", false))


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var pools := _read(POOLS_PATH)
	_tips = pools.get("tips", {})
	_info = pools.get("info", {})
	for tip in _tips.keys():
		var list: Array = _tips[tip]
		var total := 0.0
		for entry_v in list:
			if typeof(entry_v) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_v
			total += float(entry.get("chance", 1.0))
			entry["r"] = total
	var boxes := _read(BOXES_PATH)
	_boxes = boxes.get("boxes", {})


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Loot missing %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Loot could not parse %s" % path)
		return {}
	return parsed


func _run(cont: String, broken := false) -> Array:
	_drops = []
	_got = 0
	_stage = 1
	_locdif = 0.0
	_dif_full = 0.0
	_wlevel = 1.0
	# Interact.loot calls lootCont with 50 unless the container is a prize.
	_lockdif = 50.0
	_biom = 0
	_land_rnd = false
	_broken = broken
	var level := 1
	var prog := _autoload("Progression")
	if prog != null:
		level = maxi(1, int(prog.get("level")))
	# Land.lootLimit = (level - 1) + 3. Begin starts at level 1.
	_cap = float(level - 1 + 3)
	_from_room()
	_table(cont)
	return _drops.duplicate(true)


## The Location the player is in (play_land meta loot_ctx): locDifLevel
## (capped at 20 for amounts), weaponLevel 1 + locDifLevel / 4, biom, and the
## Land's gameStage, lootLimit and rnd. The stable has none and keeps the defaults.
func _from_room() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var land := tree.get_first_node_in_group("active_land")
	var player := tree.get_first_node_in_group("player") as Node2D
	if land == null or player == null or not land.has_meta("loot_ctx"):
		return
	var ctx: Dictionary = land.get_meta("loot_ctx")
	var at := (land as Node2D).to_local(player.global_position) if land is Node2D else player.global_position
	var room := Vector2i(floori(at.x / 1920.0), floori(at.y / 1000.0))
	var dif := float((ctx.get("rooms", {}) as Dictionary).get(room, ctx.get("land_dif", 0.0)))
	_dif_full = dif
	_locdif = minf(dif, 20.0)
	_wlevel = 1.0 + dif / 4.0
	_biom = int(ctx.get("biom", 0))
	_land_rnd = bool(ctx.get("rnd", false)) and not (ctx.get("prob_rooms", {}) as Dictionary).has(room)
	_stage = int(ctx.get("stage", _stage))
	_cap = float(ctx.get("limit", _cap))


func _table(cont: String) -> void:
	var n := 0
	if cont == "ammo":
		_new(0.70, "a")
		_new(0.25, "a")
		_new(0.15, "a")
		if _freel():
			_new(0.70, "a")
	elif cont == "metal":
		if not _new(0.5, "item", "money", int(randf() * 30.0 * (_locdif * 0.15 + 1.0) + 5.0)):
			_new(1, "a")
	elif cont == "bomb":
		for _i in 3:
			_new(1, "e", "dinamit")
	elif cont == "expl":
		n = int(floor(randf() * 4.0 - 1.0))
		for _j in range(n + 1):
			_new(1, "e")
		_new(0.5, "compe")
		if _freel():
			_new(0.5, "e")
	elif cont == "bigexpl":
		n = int(floor(randf() * 4.0 + 2.0))
		for _k in range(n + 1):
			_new(1, "e")
		if _freel():
			_new(0.5, "e")
		_new(0.5, "compe")
	elif cont == "wbattle":
		if not _new(0.04, "uniq"):
			if randf() < minf(_locdif / 5.0, 0.7):
				_new(1, "weapon", "4", 1)
			else:
				_new(1, "weapon", "3", 1)
		_new(0.8, "a")
		if _freel():
			_new(0.5, "a")
		_new(0.1, "item", "stealth")
		if _barahlo():
			_new(0.1, "compa", "intel_comp")
	elif cont == "case":
		_new(0.9, "item", "money", int(randf() * 20.0 * (_locdif * 0.11 + 1.0) + 5.0))
	elif cont == "wbig":
		if not _new(0.08, "uniq"):
			if randf() < 0.5:
				_new(1, "weapon", "5", 1)
			else:
				_new(1, "weapon", "4", 1)
		_new(0.5, "e", "", int(floor(randf() * 4.0)))
		_new(0.5, "a", "", int(floor(randf() * 4.0)))
		if _freel():
			_new(0.5, "a")
		if _barahlo():
			_new(0.5, "compa", "intel_comp")
	elif cont == "robocell":
		_new(1, "compm")
	elif cont == "instr":
		_new(0.1, "item", "pin", int(floor(randf() * 5.0 + 1.0)))
		if not _new(0.35, "weapon", "2", 1):
			_new(0.5, "item", "rep")
		_new(0.85, "compa")
		_new(0.7, "compw")
		_new(0.1, "compe")
		_new(0.5, "compm")
		_new(0.5, "paint")
		if _barahlo():
			_new(0.85, "compa")
			_new(0.70, "compw")
			_new(0.10, "compe")
			_new(0.10, "compe")
			_new(0.50, "compa")
	elif cont == "instr2":
		_new(0.1, "item", "pin", int(floor(randf() * 5.0 + 1.0)))
		if not _new(0.35, "weapon", "2", 1):
			_new(0.5, "item", "rep")
		_new(0.75, "compa")
		_new(0.4, "compw")
		_new(0.5, "compm")
		_new(0.2, "paint")
		if _barahlo():
			_new(0.75, "compa")
			_new(0.40, "compw")
			_new(0.10, "compe")
			_new(0.50, "compa")
	elif cont == "trash":
		if _biom == 0:
			_new(0.25, "food", "radcookie")
		# Source may spawn a radroach or a rat here and skip the pile.
		if randf() >= 0.25:
			n = int(floor(randf() * 2.0))
			if _barahlo():
				n += 2
			for _i in range(n + 1):
				_new(1, "stuff")
			_new(0.4, "item", "money", int(randf() * 10.0 * (_locdif * 0.1 + 1.0) + 5.0))
	elif cont == "fridge":
		_new(0.5, "food", "sparklecola")
		_new(0.5, "food", "sars")
		_new(0.1, "food", "radcola")
		if randf() >= 0.2:
			n = int(floor(randf() * 2.0))
			for _i in range(n + 1):
				_new(1, "food")
			_new(0.3, "compp", "herbs", int(floor(randf() * 6.0 + 1.0)))
	elif cont == "food":
		if _biom == 0:
			_new(0.25, "food", "radcookie")
		if randf() >= 0.25:
			_new(0.8, "food")
			_new(0.5, "stuff")
			_new(0.2, "compp", "herbs", int(floor(randf() * 6.0 + 1.0)))
			_new(0.05, "co")
	elif cont == "med":
		_new(0.05, "item", "pin", int(floor(randf() * 2.0 + 1.0)))
		n = int(floor(randf() * 3.0 - 1.0))
		for _i in range(n + 1):
			_new(1, "med")
		_new(0.25, "him")
		_new(0.03, "med", "firstaid")
		_new(0.05, "pot", "potHP")
		_new(0.25, "item", "gel")
	elif cont == "med2":
		_new(0.75, "pot", "potHP")
		n = int(floor(randf() * 3.0))
		for _i in range(n + 1):
			_new(1, "med")
		_new(1, "him")
		_new(0.5, "med", "firstaid")
		_new(0.5, "med", "doctor")
		_new(0.5, "med", "surgeon")
		_new(0.8, "item", "gel")
	elif cont == "table":
		_new(0.1, "item", "pin", int(floor(randf() * 3.0 + 1.0)))
		if not _new(0.08, "book"):
			_new(0.5, "item", "money", int(randf() * 50.0 + 5.0 + 3.0 * _locdif))
		_new(0.1, "food")
		_new(0.13, "weapon", "3")
		_new(0.3, "a")
		_new(0.1, "item", "dart")
		_new(0.1, "item", "app")
		_new(0.04, "scheme")
		_new(0.25, "food")
		_new(0.08, "co")
		_new(0.1, "med", "potm1")
	elif cont == "filecab":
		_new(0.1, "item", "pin", int(floor(randf() * 3.0 + 1.0)))
		_new(0.5, "item", "money", int(randf() * 20.0))
		_new(0.1, "item", "app")
		_new(0.02, "scheme")
		_new(0.08, "co")
	elif cont == "cup":
		_new(0.06, "item", "pin", int(floor(randf() * 3.0 + 1.0)))
		_new(0.3, "item", "money", int(randf() * 20.0))
		_new(0.25, "compa")
		_new(0.75, "stuff")
		_new(0.2, "compa", "kombu_comp")
		_new(0.2, "compa", "antirad_comp")
		_new(0.2, "compa", "antihim_comp")
	elif cont == "bloat":
		pass
	elif cont == "book":
		if not _new(0.3, "book"):
			_new(1, "item", "lbook")
		_new(0.1, "item", "gem" + str(int(floor(randf() * 3.0 + 1.0))))
		_new(0.25, "scheme")
		_new(0.3, "co")
	elif cont == "term" or cont == "info":
		if not _new(0.25, "item", "disc"):
			_new(1, "item", "data")
		_new(0.5, "compm")
	elif cont == "cryo":
		n = int(floor(randf() * 3.0))
		for _i in range(n + 1):
			_new(1, "item", "pcryo")
		_new(0.5, "item", "gel")
	elif cont == "chest":
		_new(0.1, "item", "pin", int(floor(randf() * 5.0 + 1.0)))
		_new(0.2, "weapon", "3", 2)
		_new(0.2, "item", "bit", int(randf() * 50.0 + 7.0 * _locdif + 2.0))
		_new(0.3, "item", "gem" + str(int(floor(randf() * 3.0 + 1.0))))
		_new(0.25, "compa")
		_new(0.03, "book")
		_new(0.5, "a")
		_new(0.03, "scheme")
	elif cont == "safe":
		# A random land can hide bloats in a safe. Begin is not a random land.
		if not (_land_rnd and randf() < 0.05):
			_new(_lockdif / 100.0, "uniq")
			_new(0.1 + _lockdif / 100.0, "item", "sphera")
			_new(0.2 + _lockdif / 200.0, "item", "stealth")
			_new(0.25 + _lockdif / 100.0, "item", "gem" + str(int(floor(randf() * 3.0 + 1.0))))
			_new(0.2, "med")
			_new(0.25, "item", "retr")
			_new(0.1, "item", "runa")
			_new(0.1, "item", "reboot")
			_new(0.2 + _lockdif / 100.0, "book")
			_new(0.1 + _lockdif / 100.0, "compp")
			_new(1, "item", "bit", int(randf() * (_lockdif + 10.0) * 8.0 + 2.0 + 4.0 * _locdif))
			_new(0.1 + _lockdif / 300.0, "scheme")
			_new(0.25, "pot", "potMP")
			_new(0.1, "pot", "potHP")
			if not _new(0.4, "med", "potm2"):
				_new(0.3, "med", "potm3")
			if _got == 0:
				_new(1, "item", "gem" + str(int(floor(randf() * 3.0 + 1.0))))
	elif cont == "specweap":
		var have: Array[String] = []
		for spec in ["lsword^1", "antidrak^1", "quick^1", "mlau^1"]:
			if not _owned(spec):
				have.append(spec)
		if have.is_empty():
			_new(1, "uniq")
		else:
			_new(1, "weapon", have[randi() % have.size()])
	elif cont == "specalc":
		_new(1, "spec", "alc7")
		_new(1, "item", "gem" + str(int(floor(randf() * 3.0 + 1.0))))
	elif cont == "speclp":
		_new(1, "spec", "lp_item")
		_new(1, "item", "gem" + str(int(floor(randf() * 3.0 + 1.0))))


func _new(chance: float, loot_type: String, id: String = "", count: int = -1) -> bool:
	if chance < 1.0 and randf() > chance:
		return false
	if loot_type == "weapon":
		if id.is_valid_int() and int(id) > 0:
			id = _pick("weapon", maxf(1.0, _wlevel + (randf() * 2.0 - 1.0)), int(id))
		if id == "":
			id = _pick("weapon", maxf(1.0, _wlevel + (randf() * 2.0 - 1.0)))
		if id == "":
			id = _pick("weapon")
	if id == "":
		if loot_type == "e" or loot_type == "uniq":
			id = _pick(loot_type, maxf(1.0, _wlevel + (randf() * 2.0 - 1.0)))
		else:
			id = _pick(loot_type, maxf(1.0, _dif_full / 2.0 + (randf() * 2.0 - 1.0)))
		if id == "":
			id = _pick(loot_type)
	if id == "":
		return false
	var give := caps_count(id, _amount(id, loot_type, count))
	if _broken and (id == "money" or id == "bit"):
		give = int(floor(float(give) * 0.5))
	if _broken and _kind(id) in ["a", "e"] and randf() < 0.5:
		return false
	if not _under_limit(id):
		return false
	if give > 0:
		_drops.append({"id": id, "n": give})
	_got += 1
	return true


func _amount(id: String, loot_type: String, count: int) -> int:
	if loot_type == "weapon" or loot_type == "uniq" or is_single(id):
		return 1
	if count >= 0:
		return count
	var found: Variant = _info.get(id, {})
	if typeof(found) == TYPE_DICTIONARY and (found as Dictionary).has("kol"):
		return int((found as Dictionary)["kol"])
	return 1


func _kind(id: String) -> String:
	for tip in _tips.keys():
		for entry_v in _tips[tip]:
			if typeof(entry_v) == TYPE_DICTIONARY and str((entry_v as Dictionary).get("id", "")) == id:
				return str(tip)
	return ""


func _under_limit(id: String) -> bool:
	var found: Variant = _info.get(id, {})
	if typeof(found) != TYPE_DICTIONARY or not (found as Dictionary).has("limit"):
		return true
	var data: Dictionary = found
	var key := str(data["limit"])
	var have := int(_limits.get(key, 0))
	var cap := _cap
	if data.has("mlim"):
		cap *= float(data["mlim"])
	if data.has("maxlim") and float(have) >= float(data["maxlim"]):
		return false
	if float(have) >= cap:
		return false
	_limits[key] = have + 1
	return true


func _pick(loot_type: String, maxlvl: float = -100.0, worth: int = -100) -> String:
	var pool: Variant = _tips.get(loot_type, [])
	if typeof(pool) != TYPE_ARRAY or (pool as Array).is_empty():
		return ""
	var source: Array = pool
	var res: Array = []
	var narrow := loot_type != "book" and (maxlvl > 0.0 or worth > 0 or _stage > 0)
	if narrow:
		var total := 0.0
		for entry_v in source:
			if typeof(entry_v) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_v
			if not _fits(entry, maxlvl, worth):
				continue
			total += float(entry.get("chance", 1.0))
			res.append({"id": entry.get("id", ""), "r": total})
	else:
		res = source
	if res.is_empty():
		return ""
	if res.size() == 1:
		return str((res[0] as Dictionary).get("id", ""))
	var roll := randf() * float((res[res.size() - 1] as Dictionary).get("r", 0.0))
	for entry_v in res:
		var entry: Dictionary = entry_v
		if float(entry.get("r", 0.0)) > roll:
			return str(entry.get("id", ""))
	return ""


func _fits(entry: Dictionary, maxlvl: float, worth: int) -> bool:
	if _stage > 0 and entry.has("stage") and int(entry["stage"]) > _stage:
		return false
	if maxlvl != -100.0 and entry.has("lvl") and float(entry["lvl"]) > maxlvl:
		return false
	if worth != -100 and entry.has("worth") and int(entry["worth"]) != worth:
		return false
	return true


func _freel() -> bool:
	return _perk("freel") > 0


func _barahlo() -> bool:
	return _perk("sparepart") > 0 or _perk("barahlo") > 0


func _perk(id: String) -> int:
	var prog := _autoload("Progression")
	if prog == null or not prog.has_method("perk_rank"):
		return 0
	return int(prog.call("perk_rank", id))


func _owned(id: String) -> bool:
	var inv := _autoload("Inventory")
	if inv == null or not inv.has_method("count"):
		return false
	return int(inv.call("count", id)) > 0


func _autoload(node_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(node_name)
