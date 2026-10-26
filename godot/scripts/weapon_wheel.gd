extends CanvasLayer

## Port extra for pads: two radial pickers that freeze the world like Sats.
## weapon_wheel (D-pad Up hold): filled favourite cells 1-24 holding a weapon,
## then the known magic weapons (keyMagic, favourites cell 30).
## spell_wheel (D-pad Down hold): the known spells keyDef casts (currentSpell).
## The right stick (or the mouse) points at a slice; letting go of the button
## applies it, a centred stick cancels. More than PAGE entries page with
## LB / RB or the mouse wheel. The aim cursor does not move while it is open.

const _Flags := preload("res://scripts/map/room_flags.gd")
const FONT := "res://theme/hud_sans.tres"
const WEAPON_ICONS := "res://assets/sprites/loot/weapons/%s.png"
const ITEM_ICONS := "res://assets/sprites/loot/items/%s.png"
const PAGE := 12
const R_OUT := 190.0
const R_IN := 70.0
const STICK_PICK := 0.5
const MOUSE_PICK := 40.0
const GREEN := Color("00ff99")
const DIM := Color(0.0, 1.0, 0.6, 0.35)
const FON := Color(0.0, 0.16, 0.1, 0.82)
const HOT := Color(0.0, 0.55, 0.33, 0.9)

var active := ""
## {id, kind: "weapon" | "magic" | "spell"}
var entries: Array = []
var hover := -1
var page := 0

var _player: Node
var _paused_by_us := false
var _mouse := Vector2.ZERO
var _font: Font
var _dim: ColorRect
var _canvas: Control
var _icons: Dictionary = {}
## Right stick per device from motion events; get_joy_axis misses remapped input.
var _axes: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 7
	_player = get_parent()
	_font = load(FONT) if ResourceLoader.exists(FONT) else ThemeDB.fallback_font
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_paint)
	add_child(_canvas)
	visible = false


func _exit_tree() -> void:
	if active != "":
		_close(false)


func _process(_delta: float) -> void:
	if active == "":
		for action in ["weapon_wheel", "spell_wheel"]:
			if InputMap.has_action(action) and Input.is_action_just_pressed(action):
				_open(action)
				return
		return
	if not Input.is_action_pressed(active):
		_close(true)
		return
	if not get_tree().paused:
		_close(false)
		return
	_pick()
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var right: Vector2 = _axes.get(maxi(motion.device, 0), Vector2.ZERO)
		if motion.axis == JOY_AXIS_RIGHT_X:
			right.x = motion.axis_value
		elif motion.axis == JOY_AXIS_RIGHT_Y:
			right.y = motion.axis_value
		_axes[maxi(motion.device, 0)] = right
		return
	if active == "":
		return
	if event is InputEventMouseMotion:
		_mouse += (event as InputEventMouseMotion).relative
		if _mouse.length() > R_OUT:
			_mouse = _mouse.normalized() * R_OUT
	elif event is InputEventJoypadButton and event.is_pressed():
		var button := (event as InputEventJoypadButton).button_index
		if button == JOY_BUTTON_LEFT_SHOULDER:
			_turn_page(-1)
		elif button == JOY_BUTTON_RIGHT_SHOULDER:
			_turn_page(1)
	elif event is InputEventMouseButton and event.is_pressed():
		var wheel := (event as InputEventMouseButton).button_index
		if wheel == MOUSE_BUTTON_WHEEL_UP:
			_turn_page(-1)
		elif wheel == MOUSE_BUTTON_WHEEL_DOWN:
			_turn_page(1)
	else:
		return
	get_viewport().set_input_as_handled()


func _open(action: String) -> void:
	if get_tree().paused or GameState.paused or GameState.health <= 0:
		return
	if _player == null or not is_instance_valid(_player) or not _player.is_physics_processing():
		return
	if Travel.blocks_control() or Travel.control_off() or bool(_player.get("rat")):
		return
	if action == "weapon_wheel" and not _Flags.allows("weapons"):
		return
	entries = _weapon_entries() if action == "weapon_wheel" else _spell_entries()
	active = action
	hover = -1
	page = _page_of_current()
	_mouse = Vector2.ZERO
	_paused_by_us = true
	GameState.set_paused(true)
	var cursor := _cursor()
	if cursor != null:
		cursor.set_meta("wheel", true)
	visible = true
	_pick()
	_canvas.queue_redraw()


func _close(apply: bool) -> void:
	var picked: Dictionary = entries[hover] if apply and hover >= 0 and hover < entries.size() else {}
	active = ""
	visible = false
	var cursor := _cursor()
	if cursor != null:
		cursor.remove_meta("wheel")
		cursor.set_meta("stick_lock", true)
	if _paused_by_us and get_tree().paused:
		GameState.set_paused(false)
	_paused_by_us = false
	if not picked.is_empty():
		_apply(picked)
	entries.clear()
	hover = -1


func _apply(row: Dictionary) -> void:
	var id := str(row["id"])
	match str(row["kind"]):
		"weapon":
			if Inventory.weapon_id != id:
				Inventory.equip(id)
		"magic":
			if MagicBinds.magic_weapon() != id:
				MagicBinds.set_magic(id)
		"spell":
			if str(Inventory.spell_id) != id:
				Inventory.change_spell(id)


func _weapon_entries() -> Array:
	var out: Array = []
	var seen := {}
	for cell in Favorites.filled_cells():
		var id := Favorites.cell_id(int(cell))
		var w := Inventory.weapon_def(id)
		if w.is_empty() or seen.has(id) or Inventory.count(id) <= 0 or Stash.is_hidden(id):
			continue
		if Inventory.casts_spell(id) or Inventory.alicorn_locked(id) or _is_magic(w):
			continue
		seen[id] = true
		out.append({"id": id, "kind": "weapon"})
	for id in Inventory.owned_weapon_ids():
		var w := Inventory.weapon_def(id)
		if seen.has(id) or not _is_magic(w):
			continue
		seen[id] = true
		out.append({"id": id, "kind": "magic"})
	return out


func _spell_entries() -> Array:
	var out: Array = []
	for id in Inventory.owned_spell_ids():
		out.append({"id": id, "kind": "spell"})
	return out


func _is_magic(w: Dictionary) -> bool:
	return str(w.get("kind", "")) == "magic" and not bool(w.get("spell", false))


func _is_current(row: Dictionary) -> bool:
	var id := str(row["id"])
	match str(row["kind"]):
		"weapon":
			return Inventory.weapon_id == id
		"magic":
			return MagicBinds.magic_weapon() == id
		"spell":
			return str(Inventory.spell_id) == id
	return false


func _page_of_current() -> int:
	for i in entries.size():
		if _is_current(entries[i]):
			return floori(float(i) / PAGE)
	return 0


func _pages() -> int:
	return maxi(1, int(ceil(float(entries.size()) / float(PAGE))))


func _turn_page(step: int) -> void:
	if _pages() <= 1:
		return
	page = posmod(page + step, _pages())
	hover = -1
	_canvas.queue_redraw()


func _slice_count() -> int:
	return mini(PAGE, entries.size() - page * PAGE)


## Right stick first, then the mouse offset gathered while open.
func _pick() -> void:
	var count := _slice_count()
	if count <= 0:
		hover = -1
		return
	var dir := _stick()
	if dir.length() < STICK_PICK:
		dir = _mouse / MOUSE_PICK if _mouse.length() >= MOUSE_PICK else Vector2.ZERO
	if dir.length() < STICK_PICK:
		hover = -1
		return
	var step := TAU / float(count)
	var ang := fposmod(atan2(dir.x, -dir.y) + step * 0.5, TAU)
	hover = page * PAGE + mini(int(ang / step), count - 1)


func _stick() -> Vector2:
	var best := Vector2.ZERO
	var ids := {0: true}
	for pad in Input.get_connected_joypads():
		ids[int(pad)] = true
	for id in ids:
		var v := Vector2(Input.get_joy_axis(int(id), JOY_AXIS_RIGHT_X), Input.get_joy_axis(int(id), JOY_AXIS_RIGHT_Y))
		if v.length() > best.length():
			best = v
	for v in _axes.values():
		if (v as Vector2).length() > best.length():
			best = v
	return best


func _cursor() -> Node:
	return get_tree().get_first_node_in_group("aim_cursor")


func _icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var tex: Texture2D = null
	for pattern in [WEAPON_ICONS, ITEM_ICONS]:
		var path := str(pattern) % id
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
			break
	_icons[id] = tex
	return tex


func _title() -> String:
	return InputBindings.label_for("weapon_wheel" if active == "weapon_wheel" else "cast_spell")


func _paint() -> void:
	if active == "":
		return
	var view := _canvas.size
	var c := view * 0.5
	_text(_title(), c + Vector2(0.0, -R_OUT - 34.0), 20, GREEN)
	_canvas.draw_circle(c, R_OUT, FON)
	var count := _slice_count()
	if count <= 0:
		_canvas.draw_arc(c, R_OUT, 0.0, TAU, 96, GREEN, 2.0)
		_text(Locale.t("wheel_empty" if active == "weapon_wheel" else "wheel_empty_spells"), c, 16, GREEN)
		_text(Prompts.hint([[active, Locale.t("wheel_close")]]), c + Vector2(0.0, R_OUT + 30.0), 14, GREEN)
		return
	var step := TAU / float(count)
	for i in count:
		var index := page * PAGE + i
		var a0 := -PI * 0.5 + step * (float(i) - 0.5)
		var a1 := a0 + step
		if index == hover:
			_wedge(c, a0, a1, HOT)
		elif _is_current(entries[index]):
			_wedge(c, a0, a1, Color(0.0, 0.3, 0.18, 0.85))
		if count > 1:
			_canvas.draw_line(c + Vector2.from_angle(a0) * R_IN, c + Vector2.from_angle(a0) * R_OUT, DIM, 1.5)
		var mid := c + Vector2.from_angle((a0 + a1) * 0.5) * (R_IN + R_OUT) * 0.5
		var tex := _icon(str(entries[index]["id"]))
		if tex != null:
			var size := tex.get_size()
			var fit := minf(1.0, minf(56.0 / maxf(size.x, 1.0), 40.0 / maxf(size.y, 1.0)))
			var box := size * fit
			_canvas.draw_texture_rect(tex, Rect2(mid - box * 0.5, box), false, Color.WHITE if index == hover else Color(1, 1, 1, 0.75))
		else:
			_text(_short(Inventory.name_of(str(entries[index]["id"]))), mid, 11, GREEN)
	_canvas.draw_arc(c, R_OUT, 0.0, TAU, 96, GREEN, 2.0)
	_canvas.draw_circle(c, R_IN, Color(0.0, 0.1, 0.06, 0.95))
	_canvas.draw_arc(c, R_IN, 0.0, TAU, 48, GREEN, 1.5)
	if hover >= 0:
		var row: Dictionary = entries[hover]
		var tex := _icon(str(row["id"]))
		if tex != null:
			var size := tex.get_size()
			var fit := minf(1.0, minf(90.0 / maxf(size.x, 1.0), 44.0 / maxf(size.y, 1.0)))
			_canvas.draw_texture_rect(tex, Rect2(c - size * fit * 0.5 - Vector2(0.0, 12.0), size * fit), false)
		_text(_short(Inventory.name_of(str(row["id"]))), c + Vector2(0.0, 30.0), 13, GREEN)
		_text(Inventory.name_of(str(row["id"])), c + Vector2(0.0, R_OUT + 26.0), 18, GREEN)
	if _pages() > 1:
		_text("%d / %d" % [page + 1, _pages()], c + Vector2(0.0, -R_OUT - 12.0), 14, GREEN)
	var hint := Locale.tf("wheel_hint", [Prompts.action(active)])
	if _pages() > 1:
		hint += "   " + Locale.tf("wheel_pages", ["[LB]/[RB]" if Prompts.pad else "[%s]" % OriginalLines.key("scru")])
	_text(hint, c + Vector2(0.0, R_OUT + 54.0), 14, Color(0.0, 1.0, 0.6, 0.85))


func _wedge(c: Vector2, a0: float, a1: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var n := maxi(4, int((a1 - a0) / 0.08))
	for k in n + 1:
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, float(k) / n)) * R_OUT)
	for k in range(n, -1, -1):
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, float(k) / n)) * R_IN)
	_canvas.draw_colored_polygon(pts, color)


func _short(text: String) -> String:
	return text if text.length() <= 16 else text.substr(0, 15) + "…"


func _text(text: String, center: Vector2, size: int, color: Color) -> void:
	if _font == null or text == "":
		return
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(center.x - w * 0.5, center.y + _font.get_ascent(size) * 0.5)
	_canvas.draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
	_canvas.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
