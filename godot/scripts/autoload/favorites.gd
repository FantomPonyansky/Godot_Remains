extends Node

## Favorites (Favorites.as, ItemInteraction.favItem / useFav). Cells 1-12 are
## keyWeapon1..12 (actions weapon_1..weapon_12: 1-9, 0, -, =), cells 13-24 the
## same keys with keyRun held. Cells 25-28 (keySpell1-4), 29 (keyGrenad) and
## 30 (keyMagic) are MagicBinds.
## A weapon cell draws the weapon, an armour cell puts it on, an item cell uses
## it. Saved with the run (WorldState provider "favorites").
## Pad: the weapon wheel (D-pad Up hold) lists the filled weapon cells.

signal changed

const HOTKEYS := 12
const CELL_SPELL := 25
const CELL_THROW := 29
const CELL_MAGIC := 30
const KEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]

## cell -> id, cells 1-24.
var _fav: Dictionary = {}
var _prune_queued := false


static func action_of(n: int) -> String:
	return "weapon_%d" % n


static func ensure_actions() -> void:
	for i in HOTKEYS:
		var action := action_of(i + 1)
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.5)
		var key := InputEventKey.new()
		key.physical_keycode = KEYS[i]
		InputMap.action_add_event(action, key)


func _ready() -> void:
	ensure_actions()
	WorldState.register("favorites", get_state, set_state)
	WorldState.run_reset.connect(reset_run)
	Inventory.changed.connect(_queue_prune)


func reset_run() -> void:
	_fav.clear()
	changed.emit()


func get_state() -> Dictionary:
	var out := {}
	for cell in _fav:
		out[str(cell)] = _fav[cell]
	return out


func set_state(data: Variant) -> void:
	_fav.clear()
	if data is Dictionary:
		for key in data:
			var cell := int(str(key))
			if cell >= 1 and cell < CELL_SPELL:
				_fav[cell] = str(data[key])
	changed.emit()


func cell_id(cell: int) -> String:
	return str(_fav.get(cell, ""))


## Favorites.getCell, 1-24, or -1.
func cell_of(id: String) -> int:
	for cell in _fav:
		if _fav[cell] == id:
			return int(cell)
	return -1


## Favorites.setFavorite: the same cell again clears it, another cell moves it.
func set_favorite(id: String, cell: int) -> void:
	if id == "" or cell < 1 or cell >= CELL_SPELL:
		return
	var prev := cell_of(id)
	if prev >= 0:
		_fav.erase(prev)
	_fav.erase(cell)
	if prev != cell:
		_fav[cell] = id
	changed.emit()


func remove_favorite(id: String) -> void:
	var cell := cell_of(id)
	if cell >= 0:
		_fav.erase(cell)
		changed.emit()


## ItemInteraction.favItem: 25-28 take only spells, 29 and 30 only an
## explosive or a magic weapon that is not a spell.
func fav_item(id: String, cell: int) -> bool:
	if id == "" or cell < 1 or cell > CELL_MAGIC:
		return false
	if cell == CELL_THROW or cell == CELL_MAGIC:
		if not MagicBinds.magic_capable(id):
			_info("onlyExpl")
			return false
		if cell == CELL_THROW:
			MagicBinds.set_throw(id if MagicBinds.throw_weapon() != id else "")
			return true
		var on := MagicBinds.magic_weapon() == id
		MagicBinds.set_magic(id if not on else "")
		return true
	if cell >= CELL_SPELL:
		if not Inventory.casts_spell(id):
			_info("onlySpell")
			return false
		MagicBinds.set_slot(cell - CELL_SPELL, id)
		return true
	set_favorite(id, cell)
	return true


## ItemInteraction.useFav: weapon -> changeWeapon, armour -> changeArmor,
## item -> useItem.
func use_fav(cell: int) -> bool:
	var id := cell_id(cell)
	if id == "" or Inventory.count(id) <= 0:
		return false
	if not Inventory.weapon_def(id).is_empty():
		if Inventory.weapon_id == id:
			return false
		return Inventory.equip(id)
	if Inventory.can_wear(id):
		return Inventory.wear(id)
	return Inventory.use(id)


## Filled cells 1-24 in order.
func filled_cells() -> Array:
	var cells: Array = _fav.keys()
	cells.sort()
	return cells


## The cell an assign key press means: weapon_N (+12 with sprint held),
## spell_N, or magic_attack. 0 if none.
func cell_of_event(event: InputEvent) -> int:
	var run := Input.is_action_pressed("sprint")
	for i in HOTKEYS:
		var action := action_of(i + 1)
		if InputMap.has_action(action) and InputMap.event_is_action(event, action, true):
			return i + 1 + (HOTKEYS if run else 0)
	for slot in MagicBinds.SLOTS:
		var action := MagicBinds.action_of(slot)
		if InputMap.has_action(action) and InputMap.event_is_action(event, action, true):
			return CELL_SPELL + slot
	if InputMap.has_action("magic_attack") and InputMap.event_is_action(event, "magic_attack", true):
		return CELL_MAGIC
	if InputMap.has_action("grenade") and InputMap.event_is_action(event, "grenade", true):
		return CELL_THROW
	return 0


## GUI fav label: retKey("keyWeapon" + n), "^" before it for cells 13-24.
func cell_text(cell: int) -> String:
	if cell < 1:
		return ""
	if cell >= CELL_SPELL:
		return ""
	var n := cell if cell <= HOTKEYS else cell - HOTKEYS
	var events := InputMap.action_get_events(action_of(n)) if InputMap.has_action(action_of(n)) else []
	var key := "???"
	if not events.is_empty():
		key = str(InputBindings.event_text(events[0]))
	return ("^" if cell > HOTKEYS else "") + key


## The fav label of an item: its 1-24 cell, else its MagicBinds cell.
func label_of(id: String) -> String:
	var cell := cell_of(id)
	if cell >= 0:
		return "[%s]" % cell_text(cell)
	return MagicBinds.bind_text(id)


func _queue_prune() -> void:
	if _prune_queued:
		return
	_prune_queued = true
	call_deferred("_prune")


func _prune() -> void:
	_prune_queued = false
	var gone := false
	for cell in _fav.keys():
		if Inventory.count(str(_fav[cell])) <= 0:
			_fav.erase(cell)
			gone = true
	if gone:
		changed.emit()


func _info(key: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_notice"):
		hud.show_notice(OriginalLines.info(key))
