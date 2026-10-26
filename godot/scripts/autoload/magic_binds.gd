extends Node

## Quick-spell cells. GameContainer.kolQS is 4: favorites cells 25-28 are
## cast by keySpell1-4 (actions spell_1..spell_4, Z and X by default, 3 and 4
## unbound). Cells start empty. In the PipBuck, pressing a spell key on a
## spell puts it in that cell (Favorites.setFavorite: the same cell again
## clears it, another cell moves it). Saved at user://magic_binds.cfg.
## Cell 30 (keyMagic, action magic_attack) takes one magic weapon or explosive,
## never a spell; the same key on it again clears it (ItemInteraction.favItem).
## Cell 29 (keyGrenad, action grenade) is throwWeapon, filled the same way.

const _UserDir := preload("res://scripts/user_dir.gd")
static var PATH := _UserDir.settings("magic_binds.cfg")
const SPELLS_PATH := "res://assets/data/spells.json"
const SLOTS := 4

signal changed

var _slots: Array[String] = []
var _magic := ""
var _throw := ""
var _catalog: Dictionary = {}
var _order: Array[String] = []
var _queued: Array[String] = []


func _ready() -> void:
	_slots.resize(SLOTS)
	_slots.fill("")
	_load_catalog()
	_load()


func spells() -> Array[String]:
	return _order.duplicate()


func spell_def(id: String) -> Dictionary:
	var found: Variant = _catalog.get(id, {})
	if typeof(found) == TYPE_DICTIONARY:
		return found
	return {}


static func action_of(slot: int) -> String:
	return "spell_%d" % (slot + 1)


func slot_spell(slot: int) -> String:
	if slot < 0 or slot >= SLOTS:
		return ""
	return _slots[slot]


func slot_of(id: String) -> int:
	if id == "":
		return -1
	return _slots.find(id)


func set_slot(slot: int, id: String) -> void:
	if slot < 0 or slot >= SLOTS or not _catalog.has(id):
		return
	var prev := slot_of(id)
	if prev >= 0:
		_slots[prev] = ""
	if prev != slot:
		_slots[slot] = id
	_save()
	changed.emit()


func magic_weapon() -> String:
	return _magic


func magic_capable(id: String) -> bool:
	var bags := get_node_or_null("/root/Inventory")
	if bags == null or not bags.has_method("weapon_def"):
		return false
	var w: Dictionary = bags.weapon_def(id)
	var kind := str(w.get("kind", ""))
	return (kind == "magic" or kind == "explosives") and not bool(w.get("spell", false))


## Cell 30 set outright ("" clears it).
func set_magic(id: String) -> void:
	if id != "" and not magic_capable(id):
		return
	_magic = id
	_save()
	changed.emit()


func throw_weapon() -> String:
	return _throw


## Cell 29 set outright ("" clears it).
func set_throw(id: String) -> void:
	if id != "" and not magic_capable(id):
		return
	_throw = id
	_save()
	changed.emit()


## PipPageInv assignKey: the spell key pressed over a spell picks the cell.
func set_bind(id: String, event: InputEvent) -> bool:
	if InputMap.has_action("grenade") and InputMap.event_is_action(event, "grenade", true):
		if not magic_capable(id):
			return false
		set_throw("" if _throw == id else id)
		return true
	if InputMap.has_action("magic_attack") and InputMap.event_is_action(event, "magic_attack", true):
		if not magic_capable(id):
			return false
		_magic = "" if _magic == id else id
		_save()
		changed.emit()
		return true
	for slot in SLOTS:
		var action := action_of(slot)
		if InputMap.has_action(action) and InputMap.event_is_action(event, action, true):
			set_slot(slot, id)
			return true
	return false


func clear_bind(id: String) -> void:
	var slot := slot_of(id)
	if slot < 0:
		return
	_slots[slot] = ""
	_save()
	changed.emit()


## GUI fav column: retKey("keySpell" + n) for the cell the spell is in.
func bind_text(id: String) -> String:
	var slot := slot_of(id)
	var action := ""
	if id != "" and id == _magic:
		action = "magic_attack"
	elif id != "" and id == _throw:
		action = "grenade"
	elif slot >= 0:
		action = action_of(slot)
	if action == "" or not InputMap.has_action(action):
		return ""
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "[???]"
	var bindings := get_node_or_null("/root/InputBindings")
	if bindings != null and bindings.has_method("event_text"):
		return "[%s]" % str(bindings.event_text(events[0]))
	return "[%s]" % events[0].as_text()


func poll() -> String:
	if _queued.is_empty():
		return ""
	return _queued.pop_front()


func is_held(id: String) -> bool:
	var slot := slot_of(id)
	if slot < 0:
		return false
	return Input.is_action_pressed(action_of(slot))


## A key a quick-spell action uses while its cell holds a spell.
func key_taken(code: int) -> bool:
	for slot in SLOTS:
		if _slots[slot] == "":
			continue
		for event in InputMap.action_get_events(action_of(slot)):
			if event is InputEventKey and (event as InputEventKey).physical_keycode == code:
				return true
	return false


func _input(event: InputEvent) -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null and bool(state.get("paused")):
		return
	if event.is_echo():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is Control and (focus as Control).is_visible_in_tree():
		return
	for slot in SLOTS:
		if _slots[slot] != "" and event.is_action_pressed(action_of(slot)):
			_queued.append(_slots[slot])
			return


func _load_catalog() -> void:
	_catalog.clear()
	_order.clear()
	if not FileAccess.file_exists(SPELLS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPELLS_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for entry_v in (parsed as Dictionary).get("spells", []):
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var id := str(entry.get("id", ""))
		if id == "":
			continue
		_catalog[id] = entry
		_order.append(id)


func _save() -> void:
	var cfg := ConfigFile.new()
	for slot in SLOTS:
		cfg.set_value("slots", str(slot + 1), _slots[slot])
	cfg.set_value("cells", "magic", _magic)
	cfg.set_value("cells", "throw", _throw)
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	_magic = str(cfg.get_value("cells", "magic", ""))
	_throw = str(cfg.get_value("cells", "throw", ""))
	if not cfg.has_section("slots"):
		return
	for slot in SLOTS:
		var id := str(cfg.get_value("slots", str(slot + 1), ""))
		if _catalog.has(id) and slot_of(id) < 0:
			_slots[slot] = id
