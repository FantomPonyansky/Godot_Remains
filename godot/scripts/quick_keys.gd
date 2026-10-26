extends Node

## The original keys the player node has no other home for (UnitPlayer.control,
## ItemInteraction, Camera.calc, Ctr keyFull). Child of the player.
## keyItemNext / keyItemPrev pick the "use item" item among items.xml us >= 2,
## keyItem uses it (the first press after the panel faded only shows it),
## keyPot / keyMana drink the best-fitting heal / mana potion (usePotion),
## keyArmor toggles the worn armour's ability (armorAbil), keyCrack spends a
## rune or electronic lockpick on the lock in reach (crackAction / useRuna),
## keyLook leans the camera toward the cursor, keyZoom steps Camera.isZoom,
## keyFull toggles fullscreen.

const _LockUse := preload("res://scripts/lock_use.gd")
const CONSUMABLES := "res://assets/data/content/consumables.json"
const ITEM_ICONS := "res://assets/sprites/loot/items/%s.png"
const FONT := "res://theme/hud_sans.tres"
const TPS := 30.0
## items.xml us >= 2, in file order.
const USE_ITEMS: PackedStringArray = [
	"pot1", "pot2", "pot3", "antiradin", "pot0", "potm1", "potm2", "potm3", "antidote",
	"mint", "pmint", "dash", "rage", "medx", "stampede", "buck", "ultradash", "hydra",
	"potion_stim", "potion_fly", "potion_shadow", "potion_mage", "potion_infra", "potion_swim",
	"potion_pink", "potion_chance", "potion_purif", "potion_rat", "radcookie", "stealth", "rep",
]
## items.xml heal='hp' and heal='mana'.
const HEAL_HP: PackedStringArray = ["pot1", "pot2", "pot3"]
const HEAL_MANA: PackedStringArray = ["potm1", "potm2", "potm3"]
## armors.xml abil rows (every upd level has the same mana / act / used / res).
const ABILS := {"astealth": {"abil": "stealth_armor", "mana": 1000.0, "act": 100.0, "use": 1.0, "res": 1.0}}
## GUI t_item.
const ITEM_SHOW := 200
const REACH := 72.0

static var _pots: Dictionary = {}

var _player: Node2D
var _acc := 0.0
var _c_item := -1
var _t_item := 0
var _armor_mana: Dictionary = {}
var _abil_on := ""
var _otryv := 0.0
var _zoom_tick := 0
var _layer: CanvasLayer
var _item_icon: TextureRect
var _item_label: Label


func _ready() -> void:
	add_to_group("quick_keys")
	_player = get_parent() as Node2D
	_load_pots()
	_build()


func _exit_tree() -> void:
	CamShake.look = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not InputMap.has_action("fullscreen") or not event.is_action_pressed("fullscreen"):
		return
	if get_tree().paused or not _player.is_physics_processing() or Travel.control_off():
		return
	var full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if GameState.paused or not _player.is_physics_processing() or Travel.control_off():
		return
	var control := not Travel.blocks_control() and not Travel.control_off() and not bool(_player.get("rat"))
	if control:
		_keys()
	_acc += delta * TPS
	while _acc >= 1.0:
		_acc -= 1.0
		_tick(control)


func _just(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)


func _keys() -> void:
	if _just("item_next"):
		next_item(1)
	elif _just("item_prev"):
		next_item(-1)
	if _just("use_item"):
		use_item()
	if _just("quick_heal"):
		use_potion("")
	if _just("quick_mana"):
		use_potion("mana")
	if _just("armor_ability"):
		armor_ability()
	if _just("crack") and not Input.is_action_pressed("interact"):
		crack()
	if _just("zoom"):
		_zoom()


func _tick(control: bool) -> void:
	if _t_item > 0:
		_t_item -= 1
		if _t_item <= 0:
			_layer.visible = false
	_tick_armor()
	var look := control and InputMap.has_action("look") and Input.is_action_pressed("look")
	if look and _otryv < 1.0:
		_otryv = minf(1.0, _otryv + 0.05)
	elif not look and _otryv > 0.0:
		_otryv = maxf(0.0, _otryv - 0.2)
	CamShake.look = _look_offset()
	if CameraDistance.zoom_mode > 0:
		_zoom_tick += 1
		if _zoom_tick >= 15:
			_zoom_tick = 0
			CameraDistance.apply()


# --- keyItem (ItemInteraction.nextItem / useItem) ---

func current_item() -> String:
	return USE_ITEMS[_c_item] if _c_item >= 0 and _c_item < USE_ITEMS.size() else ""


func next_item(n: int) -> void:
	var size := USE_ITEMS.size()
	var ci := posmod(_c_item + n, size)
	for _i in size:
		if Inventory.count(USE_ITEMS[ci]) > 0:
			_c_item = ci
			break
		ci = posmod(ci + n, size)
	_show_item()


func use_item() -> bool:
	if _c_item < 0:
		return false
	if _t_item <= 0:
		_show_item()
		return false
	var id := current_item()
	if Inventory.count(id) <= 0:
		return false
	var used := bool(Inventory.use(id))
	_show_item()
	return used


func _show_item() -> void:
	var id := current_item()
	if id == "":
		_layer.visible = false
		return
	_t_item = ITEM_SHOW
	var path := ITEM_ICONS % id
	_item_icon.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_item_label.text = "%s (%d)" % [Inventory.name_of(id), Inventory.count(id)]
	_layer.visible = true


# --- keyPot / keyMana (ItemInteraction.usePotion) ---

## "" picks a heal potion, "mana" a mana potion.
func use_potion(kind: String) -> bool:
	var best := ""
	var best_gap := 10000.0
	if kind == "mana":
		var need_m := GameState.mana_max() - GameState.mana_hp
		if need_m < 1.0:
			return false
		for id in HEAL_MANA:
			if Inventory.count(id) > 0:
				var gap := absf(float(_pot(id).get("hmana", 0.0)) - need_m)
				if gap < best_gap:
					best_gap = gap
					best = id
	else:
		var need := float(GameState._max_health()) - float(GameState.health) - GameState.rad - GameState.healing_pending()
		if need < 1.0:
			_notice(OriginalLines.info("noHeal"))
			if GameState.rad > 1.0:
				_notice(OriginalLines.info("useAntirad"))
			return false
		var mult := GameState.heal_mult()
		for id in HEAL_HP:
			if Inventory.count(id) > 0:
				var row := _pot(id)
				var hhp := (float(row.get("hhp", 0.0)) + float(row.get("hhplong", 0.0))) * mult
				var gap := absf(hhp - need)
				if gap < best_gap:
					best_gap = gap
					best = id
	if best == "":
		_notice(OriginalLines.info("noSuitablePot"))
		return false
	return bool(Inventory.use(best))


func _pot(id: String) -> Dictionary:
	return _pots.get(id, {})


static func _load_pots() -> void:
	if not _pots.is_empty() or not FileAccess.file_exists(CONSUMABLES):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONSUMABLES))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for row_v in (parsed as Dictionary).get("items", []):
		if typeof(row_v) == TYPE_DICTIONARY:
			_pots[str((row_v as Dictionary).get("id", ""))] = row_v


# --- keyArmor (UnitPlayer.armorAbil and its mana in actions) ---

func armor_ability() -> void:
	var worn := str(Inventory.worn)
	var spec: Dictionary = ABILS.get(worn, {})
	if spec.is_empty():
		return
	if _abil_on != "":
		_abil_off()
		return
	var mana := float(_armor_mana.get(worn, spec["mana"]))
	if float(spec["act"]) < mana:
		_armor_mana[worn] = mana - float(spec["act"])
		Effects.add(_player, str(spec["abil"]))
		_abil_on = worn


func _tick_armor() -> void:
	var worn := str(Inventory.worn)
	if _abil_on != "" and _abil_on != worn:
		_abil_off()
	var spec: Dictionary = ABILS.get(worn, {})
	if spec.is_empty():
		return
	var mana := float(_armor_mana.get(worn, spec["mana"]))
	if _abil_on != "":
		if mana > 0.0:
			mana -= float(spec["use"])
		else:
			_abil_off()
	elif mana < float(spec["mana"]):
		mana += float(spec["res"])
	_armor_mana[worn] = mana


func _abil_off() -> void:
	var spec: Dictionary = ABILS.get(_abil_on, {})
	if not spec.is_empty():
		Effects.remove(_player, str(spec["abil"]))
	_abil_on = ""


# --- keyCrack (Interact.needRuna / useRuna) ---

func crack() -> bool:
	var best := _crack_target()
	if best == null:
		return false
	var item := _need_runa(best)
	if item == "alarm":
		for props in get_tree().get_nodes_in_group("land_props"):
			if props.has_method("trip_alarm"):
				props.trip_alarm(best)
				return true
		return false
	best.set_meta("lock", 0.0)
	Inventory.spend(item, 1)
	_notice(OriginalLines.info("useRuna" if item == "runa" else "useReboot"))
	return true


## Pad Y taps crack instead of reload while this is true.
func crack_ready() -> bool:
	return not GameState.paused and not bool(_player.get("rat")) and not Travel.blocks_control() and not Travel.control_off() and _crack_target() != null


## UnitPlayer.crackAction: loc.celObj, on the cursor and within actionDist.
func _crack_target() -> Node2D:
	if not _player.has_method("_cursor_world") or not _player.has_method("_cursor_gap"):
		return null
	var cursor: Vector2 = _player.call("_cursor_world")
	var best: Node2D = null
	var best_d := REACH
	for node in get_tree().get_nodes_in_group("tk_use"):
		if not node is Node2D or not is_instance_valid(node) or _need_runa(node) == "":
			continue
		if float(_player.call("_cursor_gap", node, cursor)) > 0.0:
			continue
		var gap := _player.global_position.distance_to(_player.call("_body_center", node))
		if gap < best_d:
			best_d = gap
			best = node
	return best


## The item that would open this lock, or "".
func _need_runa(node: Node) -> String:
	if int(node.get_meta("mine_tip", 3)) == 6 and int(node.get_meta("mine", 0)) > 0:
		return "alarm"
	var lock := int(round(float(node.get_meta("lock", 0.0))))
	if lock <= 0 or int(node.get_meta("mine", 0)) > 0 or bool(node.get_meta("no_runa", false)):
		return ""
	var tip := int(node.get_meta("locktip", 1))
	var level := int(node.get_meta("lock_level", 0))
	if tip == 1 and Inventory.count("runa") > 0:
		var pick := _LockUse._pick_points() if _LockUse._can_pick() else -100
		if lock - pick > 1 or level > _LockUse._master("lockpick"):
			return "runa"
	if tip == 2 and Inventory.count("reboot") > 0:
		if lock - _LockUse._hack_points() > 1 or level > _LockUse._master("science"):
			return "reboot"
	return ""


# --- keyLook / keyZoom (Camera.calc) ---

func _look_offset() -> Vector2:
	if _otryv <= 0.0:
		return Vector2.ZERO
	var cursor := get_tree().get_first_node_in_group("aim_cursor")
	if cursor == null or not "screen_pos" in cursor:
		return Vector2.ZERO
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	var zoom := cam.zoom.x if cam != null else 1.0
	var view := get_viewport().get_visible_rect().size
	return _otryv * ((cursor.get("screen_pos") as Vector2) - view * 0.5) / maxf(zoom, 0.01)


func _zoom() -> void:
	if CameraDistance.room_zoom > 0.0:
		return
	CameraDistance.cycle_zoom()
	_notice(OriginalLines.info("zoom%d" % CameraDistance.zoom_mode))


func _notice(text: String) -> void:
	if _player.has_method("_notice"):
		_player.call("_notice", text)


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 3
	_layer.visible = false
	add_child(_layer)
	var box := HBoxContainer.new()
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 16.0
	box.offset_top = -176.0
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(box)
	_item_icon = TextureRect.new()
	_item_icon.custom_minimum_size = Vector2(32, 32)
	_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(_item_icon)
	_item_label = Label.new()
	if ResourceLoader.exists(FONT):
		_item_label.add_theme_font_override("font", load(FONT))
	_item_label.add_theme_font_size_override("font_size", 15)
	_item_label.add_theme_color_override("font_color", Color("00ff99"))
	_item_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_item_label.add_theme_constant_override("outline_size", 4)
	box.add_child(_item_label)
