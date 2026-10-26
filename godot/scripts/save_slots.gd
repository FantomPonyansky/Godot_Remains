class_name SaveSlots
extends RefCounted

## PipPageOpt Сохранить / Загрузить and MainMenu Продолжить / Загрузить.
## Slot 0 is the autosave (written when you leave to the main menu and on
## every land change); slots 1..10 are written from the PipBuck. A slot is a
## copy of the run files the autoloads already keep (UserDir.run), plus
## WorldState's world.json (every visited land, the current land and spot).
## slot.cfg format 1 has no world.json: such a slot loads the player only and
## the run starts in the stable, as before.
## A hardcore run autosaves into the slot picked when it began (World.autoSaveN),
## so save(0) means "the autosave" and goes there.

const _UserDir := preload("res://scripts/user_dir.gd")
const SLOTS := 10
const FORMAT := 2
const RUN_FILES: PackedStringArray = [
	"inventory.cfg", "progression.cfg", "condition.cfg", "body_pools.cfg",
]
const META := "slot.cfg"

static var _pending := -1


static func dir_of(slot: int) -> String:
	return _UserDir.saves() + "slot%d/" % slot


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(dir_of(slot) + META)


static func info(slot: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(dir_of(slot) + META) != OK:
		return {}
	var out := {}
	for k in cfg.get_section_keys("slot"):
		out[k] = cfg.get_value("slot", k)
	return out


static func latest() -> int:
	var best := -1
	var best_time := -1
	for slot in range(0, SLOTS + 1):
		var row := info(slot)
		if row.is_empty():
			continue
		var t := int(row.get("time", 0))
		if t > best_time:
			best_time = t
			best = slot
	return best


static func auto_slot() -> int:
	return clampi(int(UiSettings.value("game", "autosave_n", 0)), 0, SLOTS)


## SaveManager.clearSave.
static func clear(slot: int) -> void:
	var dir := dir_of(slot)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + file)


static func save(slot: int) -> bool:
	if slot == 0:
		slot = auto_slot()
	var dir := dir_of(slot)
	DirAccess.make_dir_recursive_absolute(dir)
	_flush_autoloads()
	for file in RUN_FILES:
		var src := _UserDir.run(file)
		if FileAccess.file_exists(src):
			DirAccess.copy_absolute(src, dir + file)
		elif FileAccess.file_exists(dir + file):
			DirAccess.remove_absolute(dir + file)
	var cfg := ConfigFile.new()
	cfg.set_value("slot", "time", int(Time.get_unix_time_from_system()))
	cfg.set_value("slot", "date", Time.get_datetime_string_from_system(false, true))
	cfg.set_value("slot", "name", str(UiSettings.value("game", "name", OriginalLines.unit("littlepip"))))
	cfg.set_value("slot", "difficulty", UiSettings.difficulty())
	var prog := _node("Progression")
	cfg.set_value("slot", "level", int(prog.get("level")) if prog else 1)
	var gs := _node("GameState")
	if gs:
		cfg.set_value("slot", "health", int(gs.get("health")))
		cfg.set_value("slot", "magic", int(gs.get("magic")))
	cfg.set_value("slot", "format", FORMAT)
	var travel := _node("Travel")
	cfg.set_value("slot", "hardcore", bool(UiSettings.value("game", "hardcore", false)))
	cfg.set_value("slot", "dead", travel != null and bool(travel.call("is_hard_dead")))
	cfg.set_value("slot", "hardinv", bool(UiSettings.value("game", "hardinv", false)))
	cfg.set_value("slot", "autosave_n", auto_slot())
	cfg.set_value("slot", "rndpump", prog != null and bool(prog.get("rndpump")))
	var world := _node("WorldState")
	if world:
		cfg.set_value("slot", "land", str(world.call("current_land_id")))
		world.call("write", dir)
	return cfg.save(dir + META) == OK


## The land a slot was saved in, by its original map name. Empty for old slots.
static func land_name(row: Dictionary) -> String:
	var id := str(row.get("land", ""))
	if id == "":
		return ""
	return OriginalLines.text("map", id)


## Queue a slot; the HUD applies it once game.tscn has finished its reset.
static func request_load(slot: int) -> void:
	_pending = slot


static func has_pending() -> bool:
	return _pending >= 0


static func apply_pending() -> void:
	if _pending < 0:
		return
	var slot := _pending
	_pending = -1
	if not exists(slot):
		return
	var dir := dir_of(slot)
	for file in RUN_FILES:
		if FileAccess.file_exists(dir + file):
			DirAccess.copy_absolute(dir + file, _UserDir.run(file))
	var row := info(slot)
	if row.has("name"):
		UiSettings.set_value("game", "name", str(row["name"]))
	if row.has("difficulty"):
		UiSettings.set_difficulty(int(row["difficulty"]))
	UiSettings.set_value("game", "hardcore", bool(row.get("hardcore", false)))
	UiSettings.set_value("game", "hardinv", bool(row.get("hardinv", false)))
	UiSettings.set_value("game", "autosave_n", int(row.get("autosave_n", 0)))
	for pair in [["Progression", "_load"], ["Condition", "_load"], ["Inventory", "_load"], ["GameState", "_load_pools"]]:
		var n := _node(pair[0])
		if n and n.has_method(pair[1]):
			n.call(pair[1])
	var bags := _node("Inventory")
	if bags:
		if "_applied_player" in bags:
			bags.set("_applied_player", 0)
		if bags.has_signal("changed"):
			bags.emit_signal("changed")
	var prog := _node("Progression")
	if prog and prog.has_signal("changed"):
		prog.emit_signal("changed")
	var gs := _node("GameState")
	if gs:
		var cap := int(gs.call("_hp_cap")) if gs.has_method("_hp_cap") else int(gs.get("health"))
		gs.set("health", clampi(int(row.get("health", cap)), 1, maxi(1, cap)))
		gs.set("magic", int(row.get("magic", gs.get("magic"))))
		var maxh := int(gs.call("_max_health")) if gs.has_method("_max_health") else cap
		gs.emit_signal("health_changed", int(gs.get("health")), maxh)
		if gs.has_signal("pools_changed"):
			gs.emit_signal("pools_changed")
	var world := _node("WorldState")
	if world and int(row.get("format", 1)) >= 2:
		world.call("read", dir)


static func _flush_autoloads() -> void:
	for pair in [["Progression", "_save"], ["Condition", "_save"], ["Inventory", "_save"], ["GameState", "_save_pools"]]:
		var n := _node(pair[0])
		if n and n.has_method(pair[1]):
			n.call(pair[1])


static func _node(n: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(n)
