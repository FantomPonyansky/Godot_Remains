extends CanvasLayer

## Gameplay HUD from visualGUI in pfe.swf (1200×800, then resizeScreen).
## Text is the original Russian pack. The face is Flash device font _sans,
## which the player resolves as Arial. Bars, the visibility eye and the
## object progress bar are drawn on Root/Bars.

const GREEN := Color("00ff99")
const MANA_TEXT := Color("9999ff")
const YELLOW := Color("ffff33")
const ORANGE := Color("ff9900")
const RED := Color("ff3333")
const ROW_BACK := Color("004127")
const HP_TOP := Color("009a62")
const HP_BOTTOM := Color("035626")
const LOW_TOP := [Color("bf0101"), Color("ff0000")]
const LOW_BOTTOM := [Color("560303"), Color("b60000")]
const RAD_TOP := Color("ffa800")
const RAD_BOTTOM := Color("e74b00")
const MANA_FILL := Color("3c00ff")
const MANA_TIP := Color("00f7ff")
const XP_FILL := Color("ffff00")
const XP_TIP := Color("ffffff")
const BOSS_TOP := Color("ffa800")
const BOSS_BOTTOM := Color("a80053")
const TIP_FROM := 0.8625
const REACH := 200.0
const FPS := 30.0
const MAX_OBS := 20.0
const EFFECT_SLOTS := 12
const HISTORY := 200
const _Lock := preload("res://scripts/lock_use.gd")
const _RoomActivity := preload("res://scripts/map/room_activity.gd")
const _RoomFlags := preload("res://scripts/map/room_flags.gd")

const XP_RECT := Rect2(3.8, 1.0, 460.0, 4.0)
const HP_RECT := Rect2(4.35, 6.0, 228.95, 27.47)
const MANA_RECT := Rect2(4.0, 34.6, 229.6, 8.0)
const PET_RECT := Rect2(37.55, 43.55, 100.0, 6.0)

const NUMB := {
	"hit": {"color": Color("ff920e"), "size": 14},
	"player": {"color": Color("ff6666"), "size": 17},
	"true": {"color": Color("c86dff"), "size": 14},
	"heal": {"color": Color("66ff00"), "size": 14},
	"miss": {"color": Color("999999"), "size": 10},
	"pink": {"color": Color("fab0f7"), "size": 17},
	"status": {"color": Color("b4ff17"), "size": 10},
}

## Info log lines for PipBuck Меню → Лог (World.w.log in the original).
var history: PackedStringArray = PackedStringArray()

@onready var _root: Control = $Root
@onready var _bars: Control = $Root/Bars
@onready var _effects: Control = $Root/Effects
@onready var _blood: TextureRect = $Root/Blood
@onready var _hp_text: Label = $Root/HpText
@onready var _status: Label = $Root/StatusText
@onready var _item: Label = $Root/ItemText
@onready var _weapon: Label = $Root/WeaponName
@onready var _holder: Label = $Root/WeaponAmmo
@onready var _ammo_name: Label = $Root/AmmoName
@onready var _info: Label = $Root/InfoLog
@onready var _prompt: Label = $Root/Prompt
@onready var _mess: Label = $Root/Mess
@onready var _subtitle: Label = $Root/Subtitle
@onready var _od: Label = $Root/OdLabel
@onready var _selector: Control = $Root/Selector
@onready var _floats: Control = $Root/Floats

var _font: Font
var _hp_ratio := 1.0
var _rad_ratio := 0.0
var _mana_ratio := 1.0
var _xp_ratio := 0.0
var _boss_ratio := -1.0
var _pet_ratio := -1.0
var _pet_secs := -1
var _low_frame := 0.0
var _mess_left := 0.0
var _info_left := 0.0
var _info_lines: PackedStringArray = PackedStringArray()
var _item_left := 0.0
var _hook_progress := -1.0
var _progress := -1.0
var _progress_at := Vector2.ZERO
var _eye_frame := 0
var _eye_at := Vector2.ZERO
var _blood_frame := -1.0
var _sel_left := 0.0
var _sel_rows: Array[Dictionary] = []
var _eff_slots: Array[Dictionary] = []
var _eff_tex: Dictionary = {}
var _tick := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group("hud")
	_font = load("res://theme/hud_sans.tres")
	_bars.draw.connect(_draw_bars)
	_style_labels()
	_build_effects()
	_build_selector()
	if not GameState.health_changed.is_connected(_on_health):
		GameState.health_changed.connect(_on_health)
	if not GameState.ammo_changed.is_connected(_refresh):
		GameState.ammo_changed.connect(_refresh)
	if not GameState.magic_changed.is_connected(_refresh):
		GameState.magic_changed.connect(_refresh)
	if GameState.has_signal("mana_changed") and not GameState.mana_changed.is_connected(_refresh):
		GameState.mana_changed.connect(_refresh)
	if not GameState.weapon_changed.is_connected(_on_weapon):
		GameState.weapon_changed.connect(_on_weapon)
	if not GameState.pools_changed.is_connected(_refresh):
		GameState.pools_changed.connect(_refresh)
	if not Progression.changed.is_connected(_refresh):
		Progression.changed.connect(_refresh)
	_mess.visible = false
	_subtitle.visible = false
	_od.visible = false
	_prompt.visible = false
	_item.visible = false
	_layout()
	_refresh()
	_after_reset.call_deferred()


func _after_reset() -> void:
	# game.gd resets the run after its children are ready; a queued slot
	# load has to land after that.
	UiSettings.apply_audio()
	if SaveSlots.has_pending():
		SaveSlots.apply_pending()
	if Travel.exit_state == Travel.Exit.NONE:
		Travel.hide_load_screen()
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout()


func _process(delta: float) -> void:
	_tick += delta
	_tick_mess(delta)
	_tick_info(delta)
	_tick_item(delta)
	_tick_floats(delta)
	_tick_prompt()
	_tick_eye()
	_tick_blood(delta)
	_tick_selector(delta)
	_refresh_effects()
	_refresh_weapon()
	_refresh_status()
	if _hp_ratio < 0.2 and _hp_ratio > 0.0:
		_low_frame = fmod(_low_frame + delta * FPS, 17.0)
	else:
		_low_frame = 0.0
	_bars.queue_redraw()


func show_notice(text: String) -> void:
	info_line(text)


func info_line(text: String) -> void:
	var line := text.strip_edges()
	if line == "":
		return
	_info_lines.append(line)
	history.append(line)
	if history.size() > HISTORY:
		history.remove_at(0)
	while _info_lines.size() > 6:
		_info_lines.remove_at(0)
	_info.text = "\n".join(_info_lines)
	_info.visible = true
	_info_left = 150.0 / FPS


func show_message(text: String, down: bool = false) -> void:
	_mess.text = text
	_mess.visible = text != ""
	_mess.modulate.a = 0.0
	_mess_left = 150.0 / FPS
	_mess.set_meta("down", down)
	_place_mess()


func show_subtitle(text: String) -> void:
	_subtitle.text = text
	_subtitle.visible = text != ""
	if text != "":
		_place_tip(_subtitle, Vector2(_view().x * 0.5, _view().y - 120.0), 16, true)


func hide_subtitle() -> void:
	_subtitle.visible = false
	_subtitle.text = ""


func set_boss_hp(ratio: float) -> void:
	_boss_ratio = clampf(ratio, 0.0, 1.0) if ratio > 0.0 else -1.0


func set_pet_hp(ratio: float) -> void:
	_pet_ratio = clampf(ratio, 0.0, 1.0) if ratio >= 0.0 else -1.0
	_place_status()
	_bars.queue_redraw()


## GUI.setPet pet.txt: seconds until the companion is back, -1 for none.
func set_pet_timer(secs: int) -> void:
	if secs == _pet_secs:
		return
	_pet_secs = secs
	_bars.queue_redraw()


func set_ap(current: float, maximum: float) -> void:
	if maximum <= 0.0:
		_od.visible = false
		return
	_od.visible = true
	_od.text = "%s %d" % [OriginalLines.pip("ap"), int(round(current))]


func set_action_progress(ratio: float) -> void:
	## Lock/hack/alarm timers set this. -1 clears the hook.
	_hook_progress = ratio


func set_item_line(text: String) -> void:
	_item.text = text
	_item.visible = text != ""
	_item_left = 200.0 / FPS
	_place_status()


func float_number(world: Vector2, text: String, kind: String = "hit", source: Object = null, separate: bool = false) -> void:
	# Unit.damage showHit: 0 hides numbers, 1 spawns one per hit, 2 adds into
	# the unit's open number for 10 ticks (tt / separate hits stay their own).
	var mode := UiSettings.show_hit()
	if mode <= 0:
		return
	var damage := kind == "hit" or kind == "player" or kind == "true" or kind == "pink"
	if damage and mode == 2 and not separate:
		var open := _summed_hit(source)
		if open != null:
			var total := float(open.get_meta("sum_total", 0.0)) + text.to_float()
			open.set_meta("sum_total", total)
			open.text = str(int(round(total)))
			open.set_meta("age", 0.0)
			open.set_meta("merge", 10.0 / FPS)
			return
	var spec: Dictionary = NUMB.get(kind, NUMB["hit"])
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(label, int(spec["size"]), spec["color"])
	label.set_meta("world", world + Vector2(0, -80))
	label.set_meta("life", 0.9)
	label.set_meta("age", 0.0)
	label.custom_minimum_size = Vector2(80, 24)
	if damage and mode == 2 and not separate and source != null:
		label.set_meta("sum_source", source)
		label.set_meta("sum_total", text.to_float())
		label.set_meta("merge", 10.0 / FPS)
	_floats.add_child(label)


func _summed_hit(source: Object) -> Label:
	if source == null or not is_instance_valid(source):
		return null
	for child in _floats.get_children():
		if not child is Label:
			continue
		if float(child.get_meta("merge", 0.0)) <= 0.0:
			continue
		var saved: Variant = child.get_meta("sum_source", null)
		if is_instance_valid(saved) and saved == source:
			return child
	return null


func _on_health(_a = null, _b = null) -> void:
	var before := _hp_ratio
	_refresh()
	if before >= 0.2 and _hp_ratio < 0.2 and _hp_ratio > 0.0:
		_blood_frame = 0.0
		_blood.visible = true
		SfxBank.play("lowhp")


func _on_weapon(_name: String) -> void:
	_refresh()
	if Input.is_action_just_pressed("weapon_prev") or Input.is_action_just_pressed("weapon_next"):
		_show_selector()


func _refresh(_a = null, _b = null) -> void:
	_refresh_hp()
	_refresh_mana()
	_refresh_xp()
	_refresh_status()
	_refresh_weapon()


func _refresh_hp() -> void:
	var maximum := _max_health()
	var current := clampi(GameState.health, 0, maximum)
	_hp_ratio = 0.0 if maximum <= 0 else float(current) / float(maximum)
	if GameState.rad <= float(maximum):
		_rad_ratio = clampf(GameState.rad / float(maximum), 0.0, 1.0)
	if current <= 0:
		_hp_text.text = ""
	else:
		_hp_text.text = "%d/%d" % [ceili(float(current)), ceili(float(maximum))]


func _refresh_mana() -> void:
	# manaBar is the mana pool (pers.manaHP / inMaxMana); the magic line is gg.mana.
	if GameState.has_method("mana_max") and float(GameState.mana_max()) > 0.0:
		_mana_ratio = clampf(GameState.mana_hp / float(GameState.mana_max()), 0.0, 1.0)
	else:
		_mana_ratio = clampf(float(GameState.magic) / float(maxi(1, GameState.MAX_MAGIC)), 0.0, 1.0)


func _refresh_xp() -> void:
	var nxt := maxi(1, Progression.xp_next)
	var prev := 0
	if Progression.level > 1 and Progression.has_method("xp_progress"):
		prev = int(Progression.xp_progress(Progression.level - 1))
	var span := maxi(1, nxt - prev)
	_xp_ratio = clampf(float(Progression.xp - prev) / float(span), 0.0, 1.0)


func _refresh_status() -> void:
	var lines: PackedStringArray = PackedStringArray()
	var magic_pct := 0.0
	if GameState.MAX_MAGIC > 0:
		magic_pct = float(GameState.magic) / float(GameState.MAX_MAGIC) * 100.0
	if magic_pct < 1.0:
		lines.append(OriginalLines.gui("magiaover"))
	elif magic_pct < 99.5 or GameState.magic_locked:
		lines.append("%s %d%%" % [OriginalLines.gui("magia"), int(round(magic_pct))])
	var kg := _held_kg()
	if kg != "":
		if lines.is_empty():
			lines.append(kg)
		else:
			lines[0] += kg
	_status.modulate.a = 0.6 if GameState.magic_locked else 1.0
	var breath_pct := GameState.breath / GameState.BREATH_MAX * 100.0
	if GameState.breath < 500.0:
		if GameState.breath < 10.0:
			lines.append(OriginalLines.gui("h2over"))
		else:
			lines.append("%s %d%%" % [OriginalLines.gui("h2o"), int(round(breath_pct))])
	var stam_limit := 980.0 if _in_battle() else 500.0
	if GameState.stam < stam_limit:
		if GameState.stam < 10.0:
			lines.append("%s 0%%" % OriginalLines.gui("stam"))
		else:
			var stam_pct := GameState.stam / GameState.STAM_MAX * 100.0
			lines.append("%s %d%%" % [OriginalLines.gui("stam"), int(round(stam_pct))])
	var text := "\n".join(lines)
	if _status.text != text:
		_status.text = text
	_status.visible = lines.size() > 0


func _held_kg() -> String:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return ""
	var held: Variant = player.get("_tele_obj")
	if not is_instance_valid(held) or not held is Node:
		return ""
	var massa := 0.0
	if player.has_method("_carried_massa"):
		massa = float(player.call("_carried_massa", held))
	elif (held as Node).has_meta("massa"):
		massa = float((held as Node).get_meta("massa"))
	if massa <= 0.1:
		return ""
	return " %dkg" % int(round(massa * 50.0))


func _refresh_weapon() -> void:
	var id := ""
	if Inventory:
		id = str(Inventory.weapon_id)
	if id == "":
		_weapon.text = ""
		_holder.text = ""
		_ammo_name.text = ""
		return
	var defn := {}
	if Inventory and Inventory.has_method("weapon_def"):
		defn = Inventory.weapon_def(id)
	var title := OriginalLines.name_of(id)
	var pct := -1
	if Condition and Condition.has_method("weapon_hp") and Condition.has_method("weapon_max"):
		var cap := float(Condition.weapon_max(id))
		if cap > 0.0:
			pct = int(round(float(Condition.weapon_hp(id)) / cap * 100.0))
			pct = clampi(pct, 0, 100)
			title = "%s (%d%%)" % [title, pct]
	_weapon.text = title
	_weapon.add_theme_color_override("font_color", _condition_color(pct))
	var ammo_id := str(defn.get("ammo", ""))
	var mag := int(defn.get("mag", 0))
	var kind := str(defn.get("kind", ""))
	_holder.text = ""
	_ammo_name.text = ""
	if ammo_id != "" and kind == "explosives":
		_holder.text = str(Inventory.count(ammo_id))
		_holder.add_theme_color_override("font_color", GREEN)
	elif ammo_id != "" and mag > 0:
		var loaded := 0
		var player := get_tree().get_first_node_in_group("player")
		if player:
			var rounds: Variant = player.get("_mag_rounds")
			if rounds is Dictionary:
				loaded = int((rounds as Dictionary).get(id, 0))
		var reserve := Inventory.count(ammo_id)
		_holder.text = "%d/%d (%d)" % [loaded, mag, reserve]
		var tint := GREEN
		var per := maxi(1, int(defn.get("ammo_per_shot", 1)))
		if loaded + reserve < per:
			tint = RED
		elif loaded < per:
			tint = ORANGE
		elif float(loaded) < float(mag) * 0.25:
			tint = YELLOW
		_holder.add_theme_color_override("font_color", tint)
		_ammo_name.text = OriginalLines.name_of(ammo_id)
	_place_weapon_row()


# --- Weapon selector (visSelector): seven rows round the current weapon ---

func _build_selector() -> void:
	const ALPHA := [0.238, 0.488, 1.0, 1.0, 1.0, 0.488, 0.238]
	for i in 7:
		var row := Control.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.position = Vector2(0, (i - 3) * 30.0)
		row.modulate.a = ALPHA[i]
		var back := ColorRect.new()
		back.color = ROW_BACK
		back.position = Vector2(-181.5, -12.0)
		back.size = Vector2(363.0, 24.0)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(back)
		if i == 3:
			var glow := ReferenceRect.new()
			glow.border_color = GREEN
			glow.border_width = 1.0
			glow.editor_only = false
			glow.position = back.position
			glow.size = back.size
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(glow)
		var fav := _row_label(row, Vector2(-218.5, -11.0), 63.0, YELLOW, HORIZONTAL_ALIGNMENT_RIGHT)
		var nazv := _row_label(row, Vector2(-117.55, -11.0), 245.0, GREEN, HORIZONTAL_ALIGNMENT_LEFT)
		var ammo := _row_label(row, Vector2(129.95, -11.0), 47.8, GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
		_selector.add_child(row)
		_sel_rows.append({"row": row, "fav": fav, "nazv": nazv, "ammo": ammo})


func _row_label(row: Control, at: Vector2, width: float, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	_apply_font(label, 16, color)
	label.position = at
	label.size = Vector2(width, 22.0)
	label.horizontal_alignment = align
	label.clip_text = true
	row.add_child(label)
	return label


func _show_selector() -> void:
	var arr: Array[String] = []
	if Inventory.has_method("owned_weapon_ids"):
		for id in Inventory.owned_weapon_ids():
			if Inventory.has_method("is_spell") and Inventory.is_spell(str(id)):
				continue
			arr.append(str(id))
	if arr.size() <= 1:
		return
	var at := maxi(0, arr.find(str(Inventory.weapon_id)))
	for i in 7:
		var id := arr[posmod(at - 3 + i, arr.size())]
		var parts: Dictionary = _sel_rows[i]
		(parts["nazv"] as Label).text = OriginalLines.name_of(id)
		(parts["fav"] as Label).text = Favorites.cell_text(Favorites.cell_of(id))
		(parts["ammo"] as Label).text = _total_ammo(id)
	_sel_left = 60.0 / FPS
	_selector.visible = true


func _total_ammo(id: String) -> String:
	var defn: Dictionary = Inventory.weapon_def(id) if Inventory.has_method("weapon_def") else {}
	var ammo_id := str(defn.get("ammo", ""))
	if ammo_id == "":
		return ""
	var total := Inventory.count(ammo_id)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var rounds: Variant = player.get("_mag_rounds")
		if rounds is Dictionary:
			total += int((rounds as Dictionary).get(id, 0))
	return str(total)


func _tick_selector(delta: float) -> void:
	if _sel_left <= 0.0:
		return
	_sel_left -= delta
	if _sel_left <= 0.0 or get_tree().paused:
		_sel_left = 0.0
		_selector.visible = false


# --- Effect icons (eff0..eff11, _effectIco) ---

func _build_effects() -> void:
	for i in EFFECT_SLOTS:
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.position = Vector2(288.0 + 34.0 * i - 15.35, 18.0 - 15.25)
		icon.size = Vector2(30.75, 30.75)
		icon.visible = false
		_effects.add_child(icon)
		var num := Label.new()
		_apply_font(num, 12, GREEN)
		num.position = Vector2(288.0 + 34.0 * i - 12.5, 18.0 + 14.05 - 4.0)
		num.size = Vector2(37.85, 16.0)
		num.visible = false
		_effects.add_child(num)
		_eff_slots.append({"icon": icon, "num": num})


func _refresh_effects() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var shield: Variant = player.get("_shit_hp") if player != null else 0.0
	var rows: Array = Effects.hud_rows(float(shield) if shield != null else 0.0)
	_effects.modulate.a = 0.2 if get_tree().paused else 1.0
	for i in EFFECT_SLOTS:
		var slot: Dictionary = _eff_slots[i]
		var icon := slot["icon"] as TextureRect
		var num := slot["num"] as Label
		if i >= rows.size():
			icon.visible = false
			num.visible = false
			continue
		var row: Dictionary = rows[i]
		icon.texture = _effect_texture(str(row.icon))
		icon.visible = true
		var text := str(row.text)
		if num.text != text:
			num.text = text
		num.visible = true


func _effect_texture(id: String) -> Texture2D:
	if _eff_tex.has(id):
		return _eff_tex[id]
	var path := "res://assets/ui/effects/%s.png" % id
	# GUI.setEffects: an id without a frame label (alicorn) falls back to frame 1, cut.
	if not ResourceLoader.exists(path):
		path = "res://assets/ui/effects/cut.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_eff_tex[id] = tex
	return tex


# --- Visibility eye (vis.visibility over the player) ---

func _tick_eye() -> void:
	_eye_frame = 0
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player is Node2D or get_tree().paused:
		return
	if not _shows_obs(player):
		return
	var obs := float(player.get_meta("foe_obs", 0.0))
	if obs < 3.0:
		return
	_eye_frame = int(floor(obs / MAX_OBS * 40.0 + 1.0))
	_eye_at = _to_screen((player as Node2D).global_position + Vector2(0, -80))


func _shows_obs(player: Node) -> bool:
	if float(player.get_meta("stealth_mult", 1.0)) < 1.0:
		return true
	if Effects.stat("showObsInd", 0.0) > 0.0:
		return true
	for worn in Inventory.worn_ids():
		if Progression.armor_sneak(worn) > 0.0:
			return true
	return false


func _draw_eye() -> void:
	if _eye_frame <= 0:
		return
	var t := clampf(float(_eye_frame - 1) / 37.0, 0.0, 1.0)
	var spread := 40.0 * (1.0 - t)
	var alpha := lerpf(0.21, 1.0, t)
	const STROKES := [0.99, 0.5, 0.25]
	for k in 3:
		var a := alpha * float(STROKES[k])
		var c := Color(GREEN, a)
		var lx := _eye_at.x - 6.0 - spread - 6.0 * k
		var rx := _eye_at.x + 6.0 + spread + 6.0 * k
		var y := _eye_at.y
		_bars.draw_polyline(PackedVector2Array([Vector2(lx - 5, y - 6), Vector2(lx, y), Vector2(lx - 5, y + 6)]), c, 1.0)
		_bars.draw_polyline(PackedVector2Array([Vector2(rx + 5, y - 6), Vector2(rx, y), Vector2(rx + 5, y + 6)]), c, 1.0)
	if _eye_frame >= 39 and int(_tick * 8.0) % 2 == 0:
		var p := _eye_at
		_bars.draw_line(p + Vector2(-4, -4), p + Vector2(4, 4), GREEN, 1.0)
		_bars.draw_line(p + Vector2(-4, 4), p + Vector2(4, -4), GREEN, 1.0)


# --- Screen blood (vis.blood, critHP) ---

func _tick_blood(delta: float) -> void:
	if _blood_frame < 0.0:
		return
	_blood_frame += delta * FPS
	if _blood_frame >= 56.0:
		_blood_frame = -1.0
		_blood.visible = false
		return
	var a := 1.0
	if _blood_frame < 3.0:
		a = _blood_frame / 3.0
	elif _blood_frame >= 44.0:
		a = lerpf(1.0, 71.0 / 255.0, (_blood_frame - 44.0) / 12.0)
	_blood.modulate.a = a


# --- Bars ---

func _draw_bars() -> void:
	_draw_xp()
	_draw_hp()
	_draw_mana()
	if _pet_ratio >= 0.0:
		_vgrad(Rect2(PET_RECT.position, Vector2(PET_RECT.size.x * _pet_ratio, PET_RECT.size.y)), HP_TOP, HP_BOTTOM)
		_outline(PET_RECT.grow(0.5))
		if _pet_secs >= 0 and _font != null:
			_bars.draw_string(_font, PET_RECT.position + Vector2(PET_RECT.size.x + 6.0, 7.0), str(_pet_secs), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GREEN)
	if _boss_ratio > 0.0:
		var boss := Rect2(_view().x * 0.5 - 200.0, 60.5, 400.0, 12.0)
		_vgrad(Rect2(boss.position, Vector2(boss.size.x * _boss_ratio, boss.size.y)), BOSS_TOP, BOSS_BOTTOM)
		_outline(boss)
	if _progress >= 0.0:
		var bar := Rect2(_progress_at.x - 25.0, _progress_at.y - 11.0, 50.0, 6.0)
		_vgrad(Rect2(bar.position, Vector2(bar.size.x * _progress, bar.size.y)), HP_TOP, HP_BOTTOM)
		_outline(bar)
	_draw_eye()


func _draw_xp() -> void:
	_hgrad_tip(Rect2(XP_RECT.position, Vector2(XP_RECT.size.x * _xp_ratio, XP_RECT.size.y)), XP_FILL, XP_TIP)
	_outline(XP_RECT)
	for q in [0.25, 0.5, 0.75]:
		var x: float = XP_RECT.position.x + XP_RECT.size.x * q
		_bars.draw_line(Vector2(x, XP_RECT.position.y), Vector2(x, XP_RECT.end.y), GREEN, 1.0)


func _draw_hp() -> void:
	var top := HP_TOP
	var bottom := HP_BOTTOM
	if _low_frame > 0.0 or (_hp_ratio < 0.2 and _hp_ratio > 0.0):
		var k := 1.0 - absf(_low_frame / 8.5 - 1.0)
		top = (LOW_TOP[0] as Color).lerp(LOW_TOP[1], k)
		bottom = (LOW_BOTTOM[0] as Color).lerp(LOW_BOTTOM[1], k)
	var w := HP_RECT.size.x
	_vgrad(Rect2(HP_RECT.position, Vector2(w * _hp_ratio, HP_RECT.size.y)), top, bottom)
	if _rad_ratio > 0.0:
		var rw := w * _rad_ratio
		_vgrad(Rect2(HP_RECT.end.x - rw, HP_RECT.position.y, rw, HP_RECT.size.y), RAD_TOP, RAD_BOTTOM)
	_outline(HP_RECT)


func _draw_mana() -> void:
	_hgrad_tip(Rect2(MANA_RECT.position, Vector2(MANA_RECT.size.x * _mana_ratio, MANA_RECT.size.y)), MANA_FILL, MANA_TIP)
	_outline(MANA_RECT)


func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	if r.size.x <= 0.0:
		return
	_bars.draw_polygon(
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _hgrad_tip(r: Rect2, fill: Color, tip: Color) -> void:
	if r.size.x <= 0.0:
		return
	var split := r.position.x + r.size.x * TIP_FROM
	_bars.draw_rect(Rect2(r.position, Vector2(split - r.position.x, r.size.y)), fill)
	_bars.draw_polygon(
		PackedVector2Array([Vector2(split, r.position.y), Vector2(r.end.x, r.position.y), r.end, Vector2(split, r.end.y)]),
		PackedColorArray([fill, tip, tip, fill]))


func _outline(r: Rect2) -> void:
	_bars.draw_rect(r, GREEN, false, 1.0)


# --- Object tip (celObj) and pr_bar ---

func _tick_prompt() -> void:
	_progress = -1.0
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_prompt.visible = false
		return
	_hide_world_bar(player)
	var held := false
	var acting := false
	var node: Node = null
	var use: Variant = player.get("_use_node")
	if use != null and is_instance_valid(use) and use is Node:
		node = use
		acting = true
	else:
		node = _cursor_target(player)
	if node == null:
		_prompt.visible = false
		return
	var text := _prompt_text(node, player, acting, held)
	if text == "":
		_prompt.visible = false
		return
	_prompt.text = text
	_prompt.visible = true
	var screen := _to_screen(_object_base(player, node))
	var ratio := _action_ratio(player, node, held)
	if ratio >= 0.0:
		_progress = ratio
		_progress_at = screen
	_place_tip(_prompt, screen, 12, true)
	var lowest := _view().y - 40.0 - _prompt.size.y
	if _prompt.position.y > lowest:
		_prompt.position.y = maxf(0.0, lowest)


func _hide_world_bar(player: Node) -> void:
	# The use timer also builds a bar on the player; pr_bar is drawn at the object.
	var bar: Variant = player.get("_use_bar")
	if bar is CanvasItem and is_instance_valid(bar):
		(bar as CanvasItem).visible = false


func _cursor_target(player: Node) -> Node:
	if not player.has_method("_cursor_world") or not player.has_method("_cursor_gap"):
		return null
	var cursor: Vector2 = player.call("_cursor_world")
	var carried: Variant = player.get("_tele_obj")
	var best: Node = null
	var best_gap := 1.0
	for group_name in ["tk_use", "levitatable", "pickups", "ground_loot", "enemies"]:
		for node in _tip_candidates(group_name):
			if not is_instance_valid(node) or not node is Node2D or node == player:
				continue
			if node == carried or node.get("held") == true or node.has_meta("tele_holder"):
				continue
			if not (node as Node2D).is_visible_in_tree() or node.has_meta("fog_layer"):
				continue
			if node.get("_dead") == true or node.get_meta("dead", false) == true:
				continue
			var gap := float(player.call("_cursor_gap", node, cursor))
			if gap > 0.0 or gap >= best_gap:
				continue
			best = node
			best_gap = gap
	return best


func _tip_candidates(group_name: String) -> Array:
	var nodes: Array = _RoomActivity.near(get_tree(), group_name)
	if not nodes.is_empty():
		return nodes
	return get_tree().get_nodes_in_group(group_name)


func _action_ratio(player: Node, node: Node, held: bool) -> float:
	if held or player.get("_use_node") != node:
		return -1.0
	if _hook_progress >= 0.0:
		return clampf(_hook_progress, 0.0, 1.0)
	var total := int(player.get("_use_max"))
	if total <= 0:
		return -1.0
	var left := int(player.get("_use_left"))
	return clampf(float(total - left) / float(total), 0.0, 1.0)


func _prompt_text(node: Node, player: Node, acting: bool, held: bool) -> String:
	var id := str(node.get_meta("id", ""))
	var title := str(node.get_meta("title", ""))
	if title == "":
		title = OriginalLines.name_of(id) if id != "" else ""
	if title == "":
		title = id
	# UnitNPC.nazv: an npc shows its own name, not the unit class (vendor).
	if node.has_method("nazv"):
		title = str(node.call("nazv"))
	if held:
		var held_name := title if title != "" else OriginalLines.gui("tele")
		var drop := _tele_line(OriginalLines.gui("drop"))
		return held_name if drop == "" else "%s\n%s" % [held_name, drop]
	# GUI.setCelObj: nazv is always shown for the aimed object. The use line
	# only if celDist <= actionDist; tele only if it can be lifted.
	var can_tele := (not acting) and _can_tele(node, player)
	if node.is_in_group("enemies"):
		var unit_name := OriginalLines.unit(str(node.get_meta("unit_id", "")))
		if unit_name == "":
			unit_name = title
		var lift := _tele_line(OriginalLines.gui("tele")) if can_tele else ""
		return unit_name if lift == "" else "%s\n%s" % [unit_name, lift]
	var can_use := acting or _use_possible(node, player)
	var detail := _Lock.prompt_detail(node)
	var blocked := str(detail.get("blocked", ""))
	var in_reach := _in_use_reach(node, player)
	var lines: PackedStringArray = PackedStringArray()
	var state := _state_text(node) if (can_use or (in_reach and blocked != "")) else ""
	if title != "":
		lines.append(title if state == "" else "%s %s" % [title, state])
	elif state != "":
		lines.append(state)
	if can_tele:
		var lift := _tele_line(OriginalLines.gui("tele"))
		if lift != "":
			lines.append(lift)
	if in_reach and blocked != "":
		lines.append(blocked)
	elif can_use:
		var action := str(detail.get("action", ""))
		if acting:
			if action != "":
				lines.append(action)
		elif action != "":
			if bool(detail.get("hold", false)):
				lines.append("%s (%s) — %s" % [_action_key(), OriginalLines.gui("hold"), action])
			else:
				lines.append("%s — %s" % [_action_key(), action])
			var extra := str(detail.get("extra", ""))
			if extra != "":
				lines.append(extra)
	if lines.is_empty():
		return ""
	return "\n".join(lines)


## GUI.setCelObj hintTele: the name stays; the key line is optional.
func _tele_line(action: String) -> String:
	if not UiSettings.flag("hint_tele"):
		return ""
	return "%s — %s" % [_key_of("telekinesis"), action]


func _state_text(node: Node) -> String:
	var mine := int(node.get_meta("mine", 0))
	var lock := int(round(float(node.get_meta("lock", 0.0))))
	var tip := int(node.get_meta("locktip", 1))
	if mine > 0 and int(node.get_meta("mine_tip", 3)) == 6:
		return "[%s]" % OriginalLines.gui("signal")
	if mine > 0:
		return "[%s]" % OriginalLines.gui("mined")
	if lock >= 100 and tip == 2:
		return "[%s]" % OriginalLines.gui("block")
	if lock >= 100:
		return "[%s]" % OriginalLines.gui("zhopa")
	if lock > 0 and tip == 2:
		return "[%s]" % OriginalLines.gui("termlock")
	if lock > 0:
		return "[%s]" % OriginalLines.gui("lock")
	return ""


func _can_tele(node: Node, player: Node) -> bool:
	if not node is Node2D or not player is Node2D:
		return false
	# player._try_grab also takes live units (group enemies) unless _can_lift is off.
	var unit: bool = node.is_in_group("enemies") and node.get("_can_lift") != false
	if not node.is_in_group("levitatable") and not unit:
		return false
	if node.has_meta("levit_poss") and not bool(node.get_meta("levit_poss")):
		return false
	# GUI.as:1133: no telekinesis hint in a base (Location.base).
	if not _RoomFlags.allows("tele", (node as Node2D).global_position):
		return false
	if player.has_method("_levitate_difficulty") and player.has_method("_levitation_skill"):
		if float(player.call("_levitation_skill")) < float(player.call("_levitate_difficulty", node)):
			return false
	if player.has_method("_tele_needs_los") and bool(player.call("_tele_needs_los")):
		if player.has_method("_los_to") and not bool(player.call("_los_to", node)):
			return false
	var radius := REACH
	if player.has_method("_tele_radius"):
		radius = float(player.call("_tele_radius"))
	return (player as Node2D).global_position.distance_to((node as Node2D).global_position) <= radius


func _base_container(node: Node) -> bool:
	if not node.has_meta("cont") or not node is Node2D:
		return false
	var items: Variant = node.get_meta("items", [])
	if str(node.get_meta("cont", "")) == "" and (not items is Array or (items as Array).is_empty()):
		return false
	var at: Vector2 = node.get_meta("feet", (node as Node2D).global_position)
	return not _RoomFlags.allows("containers", at)


func _in_use_reach(node: Node, player: Node) -> bool:
	if not player is Node2D:
		return false
	var point := _node_point(node)
	if player.has_method("_use_point"):
		point = player.call("_use_point", node)
	return (player as Node2D).global_position.distance_to(point) <= REACH


func _use_possible(node: Node, _player: Node) -> bool:
	if bool(node.get_meta("spent", false)) or bool(node.get_meta("dead", false)):
		return false
	if node.has_meta("usable") and not bool(node.get_meta("usable")):
		return false
	if not node.is_in_group("tk_use"):
		return false
	if int(round(float(node.get_meta("lock", 0.0)))) >= 100:
		return false
	# Interact.as:291: in a base a container loses cont, lock and action, so it
	# is inactive and gives no tip (the player stash is not a cont).
	if _base_container(node):
		return false
	if not _in_use_reach(node, _player):
		return false
	var detail := _Lock.prompt_detail(node)
	if str(detail.get("blocked", "")) != "":
		return false
	return str(detail.get("action", "")) != ""


func _object_base(player: Node, node: Node) -> Vector2:
	# Obj coordinates in the original are the bottom centre.
	if node is Node2D and player.has_method("_aim_rect"):
		var rect: Rect2 = player.call("_aim_rect", node)
		return Vector2(rect.get_center().x, rect.end.y)
	return _node_point(node)


# --- Layout ---

func _layout() -> void:
	var view := _view()
	var info_w := minf(777.0, maxf(80.0, view.x - 40.0))
	_info.size = Vector2(info_w, 140.0)
	_info.position = Vector2(view.x - 17.5 - info_w, 14.7)
	_place_mess()
	if _subtitle.visible:
		_place_tip(_subtitle, Vector2(view.x * 0.5, view.y - 120.0), 16, true)
	_od.position = Vector2(view.x - 105.0 - _od.size.x, view.y - 28.0)
	_selector.position = view * 0.5
	_place_weapon_row()
	_place_status()


func _place_mess() -> void:
	if not _mess.visible:
		return
	var view := _view()
	var width := view.x - 550.0
	var x := 275.0
	if width <= 500.0:
		width = minf(500.0, view.x - 16.0)
		x = (view.x - width) * 0.5
	var down := bool(_mess.get_meta("down", false))
	_mess.size = Vector2(width, 0.0)
	_mess.position = Vector2(x, view.y - 130.0 if down else 50.0)


func _place_weapon_row() -> void:
	var view := _view()
	var top := view.y - 28.95
	var name_w := 0.0
	if _font and _weapon.text != "":
		name_w = _font.get_string_size(_weapon.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var x := 20.0 + name_w
	_weapon.position = Vector2(20.0, top)
	_weapon.size = Vector2(name_w + 4.0, 20.0)
	_holder.position = Vector2(x + 7.05, top)
	_holder.size = Vector2(124.0, 20.0)
	_ammo_name.position = Vector2(x + 148.05, top)


func _place_status() -> void:
	var base := 58.0 + (30.0 if _pet_ratio >= 0.0 else 0.0)
	_item.position = Vector2(47.55, base - 8.95)
	_status.position = Vector2(7.0, base - 8.95 + (35.0 if _item.visible else 0.0))


func _style_labels() -> void:
	_apply_font(_hp_text, 16, GREEN)
	_apply_font(_status, 16, MANA_TEXT)
	_apply_font(_item, 16, GREEN)
	_apply_font(_weapon, 16, GREEN)
	_apply_font(_holder, 16, GREEN)
	_apply_font(_ammo_name, 16, GREEN)
	_apply_font(_info, 14, Color("fc7fed"))
	_apply_font(_prompt, 12, GREEN)
	_apply_font(_mess, 20, GREEN)
	_apply_font(_subtitle, 16, GREEN)
	_apply_font(_od, 16, GREEN)


func _apply_font(label: Label, size: int, color: Color) -> void:
	if _font:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _condition_color(pct: int) -> Color:
	if pct < 0:
		return GREEN
	if pct <= 0:
		return RED
	if pct < 20:
		return ORANGE
	if pct < 50:
		return YELLOW
	return GREEN


# --- Timers ---

func _tick_mess(delta: float) -> void:
	if not _mess.visible:
		return
	if _mess_left > 0.0:
		_mess_left = maxf(0.0, _mess_left - delta)
		_mess.modulate.a = minf(1.0, _mess.modulate.a + 0.1 * delta * FPS)
	else:
		_mess.modulate.a -= 0.01 * delta * FPS
		if _mess.modulate.a <= 0.0:
			_mess.visible = false


func _tick_info(delta: float) -> void:
	if _info_lines.is_empty():
		return
	_info_left -= delta
	if _info_left > 0.0:
		return
	_info_lines.remove_at(0)
	_info.text = "\n".join(_info_lines)
	_info_left = 60.0 / FPS


func _tick_item(delta: float) -> void:
	if _item_left <= 0.0:
		return
	_item_left -= delta
	if _item_left <= 0.0:
		_item.visible = false
		_place_status()


func _tick_floats(delta: float) -> void:
	for child in _floats.get_children():
		if not child is Label:
			continue
		var label := child as Label
		var age := float(label.get_meta("age")) + delta
		var life := float(label.get_meta("life"))
		label.set_meta("age", age)
		if label.has_meta("merge"):
			label.set_meta("merge", maxf(0.0, float(label.get_meta("merge")) - delta))
		var world: Vector2 = label.get_meta("world")
		world.y -= 28.0 * delta
		label.set_meta("world", world)
		var screen := _to_screen(world)
		label.position = screen - Vector2(40, 12)
		label.modulate.a = clampf(1.0 - age / life, 0.0, 1.0)
		if age >= life:
			label.queue_free()


func _place_tip(label: Label, anchor: Vector2, base_size: int, pin_top: bool) -> void:
	var view := _view()
	var margin := 8.0
	var limit := maxf(32.0, view.x - margin * 2.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font := label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var draw := base_size
	var longest := 0.0
	for line in label.text.split("\n", false):
		for word in line.split(" ", false):
			longest = maxf(longest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, base_size).x)
	if longest > limit and longest > 1.0:
		draw = maxi(8, int(floor(float(base_size) * limit / longest)))
	label.add_theme_font_size_override("font_size", draw)
	var measured := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, limit, draw)
	var width := clampf(measured.x + 2.0, 8.0, limit)
	var height := maxf(float(draw) + 2.0, measured.y)
	var max_h := maxf(float(draw) + 2.0, view.y - margin * 2.0)
	if height > max_h and height > 1.0:
		draw = maxi(8, int(floor(float(draw) * max_h / height)))
		label.add_theme_font_size_override("font_size", draw)
		measured = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, limit, draw)
		width = clampf(measured.x + 2.0, 8.0, limit)
		height = maxf(float(draw) + 2.0, measured.y)
	label.size = Vector2(width, height)
	var x := clampf(anchor.x - width * 0.5, margin, maxf(margin, view.x - width - margin))
	var y := anchor.y if pin_top else anchor.y - height
	y = clampf(y, margin, maxf(margin, view.y - height - margin))
	label.position = Vector2(x, y)


func _to_screen(world: Vector2) -> Vector2:
	var canvas := get_viewport().get_canvas_transform()
	return canvas * world


func _view() -> Vector2:
	return get_viewport().get_visible_rect().size


func _node_point(node: Node) -> Vector2:
	if node is Node2D:
		return (node as Node2D).global_position
	return Vector2.ZERO


func _action_key() -> String:
	var key := _key_of("interact")
	return key if key != "" else "E"


## The binding on the last-used device (keyboard key or pad button).
func _key_of(action: String) -> String:
	return Prompts.action_plain(action)


func _max_health() -> int:
	if Progression and Progression.has_method("max_health"):
		return maxi(1, int(Progression.max_health()))
	return maxi(1, GameState.MAX_HEALTH)


func _in_battle() -> bool:
	return GameState._in_battle()
