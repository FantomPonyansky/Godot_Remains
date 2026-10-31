extends Node

## Sats (З.П.С.). keySats freezes the world (allStat 2) over a blurred frame.
## keyAttack queues the hovered unit, or the cursor point, for satsCons action
## points; keyTele drops the last cel and exits on an empty queue; keyAction or
## keySats accepts. UnitPlayer.actions then fires at que[0] until it is spent.
## Targets are units and points only; the original has no limb targeting.
## Port extra for pads: weapon_prev/next and ui_left/right jump the cursor
## between the shown units, and the right stick aims while frozen. A pad
## button that is also bound to another action toggles only after HOLD.

const _Flags := preload("res://scripts/map/room_flags.gd")
const _StoryText := preload("res://scripts/story/story_text.gd")
const _BLUR := preload("res://assets/shaders/sats_blur.gdshader")
const _TINT := preload("res://assets/shaders/sats_tint.gdshader")
const _GLOW := preload("res://assets/shaders/glow_filter.gdshader")
const _OD := preload("res://assets/shaders/sats_od.gdshader")
const ART := "res://assets/sprites/sats/"
const FONT := "res://theme/hud_sans.tres"

const OD_START := 80.0
const OD_REGEN := 0.1
## Pers.meleeR, Pers.meleeS.
const MELEE_R := 100.0
const MELEE_S := 40.0
## SatsCel ramka: each extra cel on a unit grows its frame by 10 px.
const RAMKA := 10.0
## Trasser.liv, and WThrow skok / tormoz / brake.
const TRASS_LIV := 100
const SKOK := 0.4
const TORMOZ := 0.6
const BRAKE := 2.0
const HOLD := 0.4
const T_OD := 200

var active := false
var od := OD_START
var odv := OD_START
var skill_conf := 1.0
## {unit, at, cons, kol, begined, mark, land}
var que: Array = []
## {unit, rect, copies, glows, label}
var units: Array = []

var _player: Node2D
var _weapon: Dictionary = {}
var _paused_by_us := false
var _t_od := 0
var _grace := false
var _hold_left := -1.0
var _hover := -1
var _last_cursor := Vector2.INF
var _font: Font

var _world: Node2D
var _blur: ColorRect
var _copies: Node2D
var _line: Line2D
var _radius: Sprite2D
var _marks: Node2D
var _gui: CanvasLayer
var _frame: TextureRect
var _od_bar: Node2D
var _od_mask: Sprite2D
var _top: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_parent() as Node2D
	_font = load(FONT) if ResourceLoader.exists(FONT) else null
	_build_gui()
	if GameState.has_signal("weapon_changed"):
		GameState.weapon_changed.connect(_on_weapon_changed)
	Prompts.device_changed.connect(func(_pad: bool) -> void:
		if active:
			_top.text = _top_text())


## The signal also fires when the same weapon is republished (ammo spent on a reload).
func _on_weapon_changed(_n: String) -> void:
	if que.is_empty():
		return
	if str(_cur_weapon().get("id", "")) != str(que[0].get("weapon", "")):
		clear_all()


func _exit_tree() -> void:
	if active:
		_set_active(false)
	if _world != null and is_instance_valid(_world):
		_world.queue_free()


# --- queue side (UnitPlayer.actions, Sats.step2) ---

func queued() -> bool:
	return not que.is_empty()


## A ready que[0] steers the shot: UnitPlayer sets celX/celY to it.
func firing() -> bool:
	return not active and not que.is_empty() and _ready_cel()


func cel_point() -> Vector2:
	if que.is_empty():
		return Vector2.ZERO
	_run_cel(que[0])
	return que[0]["at"]


## Runs once per physics frame from the player, outside the freeze.
func step2(delta: float) -> void:
	var ticks := delta * 30.0
	if _t_od > 0:
		_t_od = maxi(0, _t_od - int(ceil(ticks)))
	if not que.is_empty():
		var w := _cur_weapon()
		var cons_mult := Progression.weapon_perk(w, "Cons", 1.0)
		# The key that accepted the queue is still down for a frame or more after the freeze.
		if _grace:
			_grace = Input.is_action_pressed("shoot") or _cancels_held()
		if not _grace and (Input.is_action_just_pressed("shoot") or _cancels()):
			clear_all()
		elif str(Travel.cur_land_id) != str(que[0].get("land", "")):
			clear_all()
		elif float(w.get("sats_cons", 10)) * cons_mult * cons_mult / skill_conf * Progression.pers("satsMult", 1.0) / maxf(float(w.get("sats_que", 1)), 1.0) > od:
			_notice(OriginalLines.info("noOd"))
			clear_all()
		elif w.is_empty() or bool(w.get("no_sats", false)) or _status() > 3:
			clear_all()
		elif not _ready_cel():
			unset_cel(true)
	if que.is_empty() and od < _max_od():
		od += OD_REGEN * ticks
		odv = od
		_set_od()
	_update_bar()


## Sats.act: one shot spent on que[0].
func act() -> void:
	if que.is_empty():
		return
	var cel: Dictionary = que[0]
	od -= float(cel["cons"])
	_set_od()
	if int(cel["kol"]) > 1 and _status() <= 1:
		cel["kol"] = int(cel["kol"]) - 1
		cel["begined"] = true
	else:
		_drop_mark(que.pop_front())
	_update_bar()


func clear_all() -> void:
	for cel in que:
		_drop_mark(cel)
	que.clear()
	odv = od
	_set_od()
	_update_bar()


# --- input ---

func _input(event: InputEvent) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if event.is_action("sats") and not event.is_echo():
		# World: keySats opens only with gg.ggControl.
		if not active and Travel.control_off():
			return
		if _needs_hold(event):
			_hold_left = HOLD if event.is_pressed() else -1.0
		elif event.is_pressed():
			_hold_left = -1.0
			_toggle()
		if active:
			get_viewport().set_input_as_handled()
		return
	if not active:
		return
	# The PipBuck stays shut and the pause menu does not open over the freeze.
	# Port extra: pause (Start / Esc) leaves without firing.
	if event.is_action("pause") or event.is_action("pip_toggle"):
		if event.is_action_pressed("pause"):
			clear_all()
			_set_active(false)
		get_viewport().set_input_as_handled()


## Sats.step: the keys are edges, so a held trigger queues one cel.
## Port: grenade / melee (LB / RB) also step between the targets.
func _poll_keys() -> void:
	if Input.is_action_just_pressed("shoot"):
		set_cel()
	elif Input.is_action_just_pressed("telekinesis"):
		unset_cel()
	elif Input.is_action_just_pressed("interact"):
		_set_active(false)
	elif Input.is_action_just_pressed("weapon_next") or Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("melee"):
		_cycle(1)
	elif Input.is_action_just_pressed("weapon_prev") or Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("grenade"):
		_cycle(-1)


func _needs_hold(event: InputEvent) -> bool:
	if not event is InputEventJoypadButton:
		return false
	for action in InputMap.get_actions():
		var name := str(action)
		if name == "sats" or name.begins_with("ui_"):
			continue
		if InputMap.action_has_event(name, event):
			return true
	return false


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _hold_left >= 0.0:
		_hold_left -= delta
		# A rebound shared button may also be climb: a held climb never opens Sats.
		if _hold_left < 0.0 and not bool(_player.get("_climbing")):
			_toggle()
	if not active:
		return
	# Something else (a script, travel) lifted the freeze: accept.
	if not get_tree().paused:
		_set_active(false)
		return
	_poll_keys()
	if not active:
		return
	_fit_blur()
	var cursor := _cursor()
	if cursor.distance_squared_to(_last_cursor) > 0.25:
		_last_cursor = cursor
		_trass(cursor)
	_hover_at(cursor)


func _toggle() -> void:
	if active:
		_set_active(false)
		return
	# ggControl, PipBuck closed, no catPause: nothing else holds the freeze.
	if get_tree().paused or GameState.health <= 0 or not _Flags.allows("weapons"):
		return
	_set_active(true)


## Sats.onoff.
func _set_active(on: bool) -> void:
	if on:
		if Travel.can_travel_here():
			return
		_weapon = _cur_weapon()
		var w := _weapon
		if w.is_empty() or bool(w.get("no_sats", false)) or str(w.get("delivery", "")) == "spell" or bool(w.get("spell", false)):
			_notice(OriginalLines.info("noSats"))
			return
		var st := _status()
		if st == 4:
			_notice(OriginalLines.info("noAmmo"))
			return
		if st == 5:
			_notice(OriginalLines.info("brokenWeapon"))
			return
		if st == 6:
			_notice(OriginalLines.info("noMana"))
			return
		var razn := int(_player.call("_razn", w))
		skill_conf = 1.0
		if razn == 1:
			skill_conf = 0.8
		elif razn == 2:
			skill_conf = 0.6
		elif razn > 2:
			_notice(OriginalLines.info("weaponSkillLevel"))
			return
		if not que.is_empty():
			clear_all()
		active = true
		_paused_by_us = true
		GameState.set_paused(true)
		_ensure_world()
		_world.visible = true
		_fit_blur()
		_get_units()
		odv = od
		_set_od()
		_last_cursor = Vector2.INF
		_trass(_cursor())
		_top.text = _top_text()
		_top.visible = true
		_frame.visible = true
		var cursor := _aim_cursor()
		if cursor != null:
			cursor.set_meta("sats", true)
	else:
		if not active:
			return
		active = false
		_off_units()
		if _world != null:
			_world.visible = false
		_frame.visible = false
		_top.visible = false
		var cursor := _aim_cursor()
		if cursor != null:
			cursor.remove_meta("sats")
		if _paused_by_us and get_tree().paused:
			GameState.set_paused(false)
		_paused_by_us = false
		_grace = true
	_update_bar()


## Sats.setCel.
func set_cel() -> void:
	var cost := _cost()
	if cost > odv:
		_notice(OriginalLines.info("noOd"))
		return
	var cel := {
		"unit": null, "at": _cursor(), "cons": cost / maxf(float(_weapon.get("sats_que", 1)), 1.0),
		"kol": maxi(1, int(_weapon.get("sats_que", 1))), "begined": false, "mark": null,
		"land": str(Travel.cur_land_id), "weapon": str(_weapon.get("id", "")),
	}
	if _hover >= 0 and _hover < units.size():
		var row: Dictionary = units[_hover]
		cel["unit"] = row["unit"]
		row["n"] = int(row.get("n", 0)) + 1
	_make_mark(cel)
	odv -= cost
	_set_od()
	que.append(cel)
	_update_bar()


## Sats.unsetCel.
func unset_cel(first: bool = false) -> void:
	if que.is_empty():
		_set_active(false)
		return
	var cel: Dictionary = que.pop_front() if first else que.pop_back()
	for row in units:
		if row["unit"] == cel["unit"] and cel["unit"] != null:
			row["n"] = maxi(0, int(row.get("n", 0)) - 1)
	_drop_mark(cel)
	odv += _cost()
	if que.is_empty():
		_set_active(false)
		odv = od
	_set_od()
	_update_bar()


func _cost() -> float:
	var w := _weapon if active else _cur_weapon()
	return float(w.get("sats_cons", 10)) * Progression.weapon_perk(w, "Cons", 1.0) / skill_conf * Progression.pers("satsMult", 1.0)


func _max_od() -> float:
	return Effects.stat("maxOd", Progression.pers("maxOd", 75.0))


## Sats.getReady.
func _ready_cel() -> bool:
	if que.is_empty():
		return false
	var cel: Dictionary = que[0]
	var unit: Variant = cel["unit"]
	if unit == null or bool(cel["begined"]):
		return unit == null or is_instance_valid(unit)
	return is_instance_valid(unit) and _alive(unit as Node)


func _run_cel(cel: Dictionary) -> void:
	var unit: Variant = cel["unit"]
	if unit != null and is_instance_valid(unit):
		cel["at"] = _player.call("_body_center", unit)


func _cancels() -> bool:
	# UnitPlayer: keyAction, keyTele, keyMagic and spells all call sats.clearAll().
	for action in ["interact", "telekinesis", "magic_attack", "cast_spell"]:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			return true
	return false


func _cancels_held() -> bool:
	for action in ["interact", "telekinesis", "magic_attack", "cast_spell"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			return true
	return false


# --- units ---

## Sats.getUnits.
func _get_units() -> void:
	_off_units()
	var melee := _is_melee(_weapon)
	var eye: Vector2 = (_player.get_node("Muzzle") as Node2D).global_position if _player.has_node("Muzzle") else _player.global_position
	var shown := _view_rect().grow(40.0)
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is Node2D or not is_instance_valid(node):
			continue
		var unit := node as Node2D
		if not unit.is_visible_in_tree() or not _alive(unit) or bool(unit.get("_invis")) or bool(unit.get("_buried")) or unit.get_meta("no_vis", false):
			continue
		var at: Vector2 = _player.call("_body_center", unit)
		if not shown.has_point(at):
			continue
		if melee and at.distance_to(_player.global_position) > MELEE_R * 1.2 + 100.0:
			continue
		if not Sight.los_clear(eye, at, unit):
			continue
		var row := {"unit": unit, "rect": _player.call("_aim_rect", unit), "n": 0, "glows": []}
		_draw_unit(row)
		units.append(row)
	_hover = -1


func _alive(unit: Node) -> bool:
	return not bool(unit.get("_dead")) and not bool(unit.get("_downed"))


func _off_units() -> void:
	for row in units:
		for item in [row.get("holder"), row.get("label"), row.get("info")]:
			if item != null and is_instance_valid(item):
				(item as Node).queue_free()
	units.clear()
	_hover = -1
	for cel in que:
		var mark: Variant = cel.get("mark")
		if mark != null and is_instance_valid(mark):
			(mark as CanvasItem).visible = false


## Sats.drawUnit: a ct-tinted copy of the body clip; fGlow on hover.
func _draw_unit(row: Dictionary) -> void:
	var unit: Node2D = row["unit"]
	var holder := Node2D.new()
	_copies.add_child(holder)
	var body: Variant = unit.get("anim")
	var parts: Array = []
	if body is CanvasItem:
		parts.append(body)
		_walk(body as Node, parts)
	else:
		_walk(unit, parts)
	var glows: Array = []
	var tint := ShaderMaterial.new()
	tint.shader = _TINT
	for part in parts:
		var tex := _texture_of(part)
		if tex == null or not (part as CanvasItem).is_visible_in_tree():
			continue
		var glow := _copy(part as Node2D, tex)
		var mat := ShaderMaterial.new()
		mat.shader = _GLOW
		mat.set_shader_parameter("glow_color", Color(1, 0, 0, 1))
		mat.set_shader_parameter("strength", 4.0)
		mat.set_shader_parameter("sigma", 0.9)
		# Rig parts are rasterised above display size: the glow is in unit pixels, not texels.
		var texel := absf(part.global_transform.get_scale().x / maxf(absf(unit.global_transform.get_scale().x), 0.0001)) if RigView.owns(part) else 1.0
		texel = 1.0 if texel <= 0.0 else texel
		mat.set_shader_parameter("spread", 1.0 / texel)
		mat.set_shader_parameter("margin", 4.0 / texel)
		mat.set_shader_parameter("region", _region_of(part, tex))
		mat.set_shader_parameter("flip", Vector2(-1.0 if glow.flip_h else 1.0, -1.0 if glow.flip_v else 1.0))
		glow.material = mat
		glow.visible = false
		holder.add_child(glow)
		glows.append(glow)
		var copy := _copy(part as Node2D, tex)
		copy.material = tint
		holder.add_child(copy)
	row["holder"] = holder
	row["glows"] = glows
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("00ff99"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	var text := OriginalLines.unit(str(unit.get_meta("unit_id", "")))
	if not bool(_weapon.get("no_perc", false)):
		text += "\n%d%%" % int(round(_prec(unit, row["rect"]) * 100.0))
	label.text = text
	var zoom := _view_scale()
	label.scale = Vector2.ONE / zoom
	_copies.add_child(label)
	label.reset_size()
	label.position = unit.global_position + Vector2(-label.size.x * 0.5 / zoom.x, 3.0 / zoom.y)
	row["label"] = label
	if Inventory != null and Inventory.count("mod_analis") > 0:
		row["info"] = _analis_info(unit, row["rect"], label)


## pers.modAnalis (implant mod_analis): su.info with level, HP, skin, armor and
## magic armor, shown only while the cursor is over the unit (mOver / mOut).
func _analis_info(unit: Node2D, rect: Rect2, like: Label) -> Label:
	var lines: Array[String] = []
	lines.append("%s: %d" % [OriginalLines.pip("level"), int(unit.get_meta("level", 0)) + 1])
	lines.append("%s: %d/%d" % [OriginalLines.pip("hp"), ceili(_num(unit, "hp")), ceili(_num(unit, "max_hp"))])
	var skin := _num(unit, "_skin")
	var qual := _num(unit, "_armor_qual")
	var armor := _num(unit, "_armor")
	var marmor := _num(unit, "_marmor")
	if skin > 0.0:
		lines.append("%s: %d" % [OriginalLines.pip("skin"), ceili(skin)])
	if qual > 0.0 and armor > 0.0:
		lines.append("%s: %d (%d%%)" % [OriginalLines.pip("armor"), ceili(armor + skin), roundi(qual * 100.0)])
	if qual > 0.0 and marmor > 0.0:
		lines.append("%s: %d (%d%%)" % [OriginalLines.pip("marmor"), ceili(marmor + skin), roundi(qual * 100.0)])
	var info := like.duplicate() as Label
	info.text = "\n".join(lines)
	info.visible = false
	_copies.add_child(info)
	info.reset_size()
	var zoom := _view_scale()
	var x := unit.global_position.x - info.size.x * 0.5 / zoom.x
	var screen_y := (get_viewport().get_canvas_transform() * unit.global_position).y
	if screen_y < 150.0:
		info.position = Vector2(x, like.position.y + 50.0 / zoom.y)
	else:
		info.position = Vector2(x, rect.position.y - (info.size.y + 20.0) / zoom.y)
	return info


static func _num(unit: Object, prop: String) -> float:
	var v: Variant = unit.get(prop)
	return float(v) if v is int or v is float else 0.0


func _copy(part: Node2D, tex: Texture2D) -> Sprite2D:
	var copy := Sprite2D.new()
	copy.texture = tex
	copy.centered = bool(part.get("centered"))
	var off: Variant = part.get("offset")
	copy.offset = off if off is Vector2 else Vector2.ZERO
	copy.flip_h = bool(part.get("flip_h"))
	copy.flip_v = bool(part.get("flip_v"))
	if part is Sprite2D and (part as Sprite2D).region_enabled:
		copy.region_enabled = true
		copy.region_rect = (part as Sprite2D).region_rect
	copy.global_transform = part.global_transform
	copy.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if RigView.owns(part) else part.texture_filter
	return copy


func _region_of(part: Node, tex: Texture2D) -> Vector4:
	var size := Vector2(maxf(tex.get_width(), 1), maxf(tex.get_height(), 1))
	if part is Sprite2D and (part as Sprite2D).region_enabled:
		var r := (part as Sprite2D).region_rect
		if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
			size = (tex as AtlasTexture).atlas.get_size()
		return Vector4(r.position.x / size.x, r.position.y / size.y, r.end.x / size.x, r.end.y / size.y)
	if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
		var atlas := tex as AtlasTexture
		size = atlas.atlas.get_size()
		return Vector4(atlas.region.position.x / size.x, atlas.region.position.y / size.y, atlas.region.end.x / size.x, atlas.region.end.y / size.y)
	return Vector4(0, 0, 1, 1)


func _walk(node: Node, found: Array) -> void:
	for child in node.get_children():
		if str(child.name) == "MagicAura" or str(child.name) == "Glow" or child.has_meta("no_tele_glow"):
			continue
		if child is Sprite2D or child is AnimatedSprite2D:
			found.append(child)
		_walk(child, found)


func _texture_of(node: Node) -> Texture2D:
	if node is Sprite2D:
		return (node as Sprite2D).texture
	if node is AnimatedSprite2D:
		var anim := node as AnimatedSprite2D
		if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim.animation):
			return null
		return anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	return null


func _hover_at(cursor: Vector2) -> void:
	var found := -1
	for i in units.size():
		var rect: Rect2 = units[i]["rect"]
		if rect.has_point(cursor):
			found = i
			break
	if found == _hover:
		return
	_hover = found
	var glow_on := not bool(_weapon.get("no_perc", false))
	for i in units.size():
		for glow in units[i]["glows"]:
			if is_instance_valid(glow):
				(glow as CanvasItem).visible = glow_on and i == found
		var info: Variant = units[i].get("info")
		if info != null and is_instance_valid(info):
			(info as CanvasItem).visible = i == found


func _cycle(step: int) -> void:
	if units.is_empty():
		return
	var order: Array = range(units.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return (units[a]["rect"] as Rect2).get_center().x < (units[b]["rect"] as Rect2).get_center().x)
	var at := order.find(_hover)
	var next: int
	if at < 0:
		var cx := _cursor().x
		next = 0 if step > 0 else order.size() - 1
		for k in order.size():
			var x := (units[order[k]]["rect"] as Rect2).get_center().x
			if step > 0 and x > cx:
				next = k
				break
			if step < 0 and x < cx:
				next = k
	else:
		next = posmod(at + step, order.size())
	var cursor := _aim_cursor()
	if cursor != null and cursor.has_method("warp_world"):
		cursor.warp_world((units[order[next]]["rect"] as Rect2).get_center())


## Sats.getPrec.
func _prec(unit: Node2D, rect: Rect2) -> float:
	var w := _weapon
	var prec := 1.0
	var sk := float(_player.call("_skill_mult", w))
	var from := (_player.get_node("Muzzle") as Node2D).global_position if _player.has_node("Muzzle") else _player.global_position
	var center: Vector2 = _player.call("_body_center", unit)
	var rasst := maxf(from.distance_to(center), 1.0)
	var dexter := float(unit.get("dexter")) if unit.get("dexter") != null else 1.0
	var precision := float(w.get("range", 0.0))
	var antiprec := float(w.get("antiprec", 0.0))
	if precision > 0.0:
		var result := precision * float(_player.call("_prec_mult", w, center - from)) * (1.0 + (sk - 1.0) * 0.5)
		prec = result / rasst / (dexter + 0.1) * skill_conf
	if antiprec > 0.0 and rasst < antiprec:
		prec = (rasst / antiprec * 0.75 + 0.25) / (dexter + 0.1) * skill_conf
	var deviation := float(w.get("spread", 0.0))
	var mazil := GameState.aim_mazil()
	if deviation > 0.0 or mazil > 0.0:
		var ug1 := rad_to_deg(atan2(rect.size.y, rasst))
		var ug2 := deviation / (sk + 0.01) + mazil
		if ug2 > ug1:
			prec *= ug1 / ug2
	return minf(minf(prec, 0.95), skill_conf)


# --- markers, trasser, radius ---

func _make_mark(cel: Dictionary) -> void:
	var mark := Sprite2D.new()
	var unit: Variant = cel["unit"]
	if unit == null:
		mark.texture = load(ART + "cel.png")
		mark.position = cel["at"]
	else:
		mark.texture = load(ART + "uncel.png")
		_run_cel(cel)
		mark.position = cel["at"]
		var rect: Rect2 = _player.call("_aim_rect", unit)
		var n := 0
		for row in units:
			if row["unit"] == unit:
				n = int(row.get("n", 1))
		mark.scale = (rect.size + Vector2.ONE * RAMKA * n) / 100.0
	_marks.add_child(mark)
	cel["mark"] = mark


func _drop_mark(cel: Dictionary) -> void:
	var mark: Variant = cel.get("mark")
	if mark != null and is_instance_valid(mark):
		(mark as Node).queue_free()
	cel["mark"] = null


## Weapon.setTrass / WThrow.setTrass with Trasser.trass, and Sats.trass radius.
func _trass(cursor: Vector2) -> void:
	var w := _weapon
	if _is_melee(w):
		_line.visible = false
		_radius.visible = true
		var half := 0.0
		var center: Vector2 = _player.call("_body_center", _player)
		half = _player.global_position.y - center.y
		_radius.position = Vector2(_player.global_position.x + MELEE_S * float(_player.get("facing")), _player.global_position.y - half)
		_radius.scale = Vector2.ONE * MELEE_R / 100.0
		return
	var from := (_player.get_node("Muzzle") as Node2D).global_position if _player.has_node("Muzzle") else _player.global_position
	var r := cursor - from
	var rot3 := r.angle()
	var vel := Vector2.ZERO
	var ddy := 0.0
	var skok := false
	var liv := TRASS_LIV
	if str(w.get("kind", "")) == "explosives":
		var sk := float(_player.call("_skill_mult", w)) * float(_player.call("_skill_conf", w))
		var speed := float(w.get("speed", 10.0))
		var bvel := maxf(minf(speed * sk, r.length() / 10.0 * sk - r.y / 10.0 * sk), 1.0)
		vel = Vector2.from_angle(rot3 - r.x / (bvel + 0.0001) / 100.0) * bvel
		ddy = 1.0
		liv = maxi(1, int(w.get("det_time", w.get("fuse", 75))))
		skok = int(w.get("throw_tip", 0)) == 0 and not bool(w.get("bumc", false))
	else:
		vel = Vector2.from_angle(rot3) * float(w.get("speed", 100.0)) * Progression.weapon_perk(w, "Speed", 1.0)
		if float(w.get("grav", 0.0)) > 0.0:
			ddy = 1.0
	var points := PackedVector2Array([from])
	var space := _player.get_world_2d().direct_space_state
	var pos := from
	var stay := false
	for i in liv:
		vel.y += ddy
		if stay:
			if vel.x > 1.0:
				vel.x -= BRAKE
			elif vel.x < -1.0:
				vel.x += BRAKE
			else:
				vel.x = 0.0
		var query := PhysicsRayQueryParameters2D.create(pos, pos + vel, 1)
		query.exclude = [(_player as CollisionObject2D).get_rid()] if _player is CollisionObject2D else []
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			pos += vel
		else:
			var n: Vector2 = hit["normal"]
			pos = (hit["position"] as Vector2) + n
			if not skok:
				points.append(pos)
				break
			if absf(n.x) > absf(n.y):
				vel.x = absf(vel.x * SKOK) * signf(n.x)
			elif n.y < 0.0:
				if vel.y > 2.0:
					vel.y = -absf(vel.y * SKOK)
					vel.x *= TORMOZ
				else:
					vel.y = 0.0
					stay = true
			else:
				vel.y = absf(vel.y * SKOK)
		points.append(pos)
		if not _view_rect().grow(400.0).has_point(pos):
			break
	_line.points = points
	_line.visible = true
	var expl := float(w.get("radius", 0.0))
	_radius.visible = expl > 0.0
	if expl > 0.0:
		_radius.position = pos
		_radius.scale = Vector2.ONE * expl / 100.0


# --- overlay and GUI ---

func _ensure_world() -> void:
	if _world != null and is_instance_valid(_world):
		return
	var host := get_tree().current_scene
	_world = Node2D.new()
	_world.name = "SatsVisual"
	_world.top_level = true
	_world.z_as_relative = false
	_world.z_index = 4000
	_world.visible = false
	(host if host != null else get_tree().root).add_child(_world)
	_blur = ColorRect.new()
	var blur_mat := ShaderMaterial.new()
	blur_mat.shader = _BLUR
	_blur.material = blur_mat
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_blur)
	_copies = Node2D.new()
	_world.add_child(_copies)
	_line = Line2D.new()
	_line.width = 5.0
	_line.default_color = Color(0.0, 1.0, 0.6, 0.5)
	_world.add_child(_line)
	_radius = Sprite2D.new()
	_radius.texture = load(ART + "radius.png")
	_radius.visible = false
	_world.add_child(_radius)
	_marks = Node2D.new()
	_world.add_child(_marks)


func _fit_blur() -> void:
	if _blur == null:
		return
	var rect := _view_rect()
	_blur.position = rect.position
	_blur.size = rect.size


func _build_gui() -> void:
	_gui = CanvasLayer.new()
	_gui.name = "SatsGui"
	_gui.layer = 2
	add_child(_gui)
	_frame = TextureRect.new()
	_frame.texture = load(ART + "frame.png")
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.visible = false
	_gui.add_child(_frame)
	_od_bar = Node2D.new()
	_od_bar.visible = false
	_gui.add_child(_od_bar)
	_od_mask = Sprite2D.new()
	_od_mask.texture = load(ART + "mask.png")
	_od_mask.centered = false
	_od_mask.position = Vector2(-60.5, -10.0)
	var mat := ShaderMaterial.new()
	mat.shader = _OD
	mat.set_shader_parameter("bar_tex", load(ART + "bar.png"))
	mat.set_shader_parameter("bar2_tex", load(ART + "bar2.png"))
	_od_mask.material = mat
	_od_bar.add_child(_od_mask)
	var ap := Label.new()
	ap.text = OriginalLines.pip("ap")
	ap.position = Vector2(-142.95, -18.0)
	ap.size = Vector2(80.0, 20.0)
	ap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _font != null:
		ap.add_theme_font_override("font", _font)
	ap.add_theme_font_size_override("font_size", 14)
	ap.add_theme_color_override("font_color", Color("00ff99"))
	_od_bar.add_child(ap)
	_top = Label.new()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_top = 40.0
	_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font != null:
		_top.add_theme_font_override("font", _font)
	_top.add_theme_font_size_override("font_size", 16)
	_top.add_theme_color_override("font_color", Color("00ff99"))
	_top.add_theme_color_override("font_outline_color", Color.BLACK)
	_top.add_theme_constant_override("outline_size", 4)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.visible = false
	_gui.add_child(_top)


## GUI.setOd.
func _set_od() -> void:
	_t_od = T_OD


func _update_bar() -> void:
	if _od_bar == null:
		return
	var w := _weapon if active else _cur_weapon()
	_od_bar.visible = (active or _t_od > 0) and not w.is_empty() and not bool(w.get("no_sats", false))
	var view := get_viewport().get_visible_rect().size
	_od_bar.position = view - Vector2(10.0, 10.0)
	var mat := _od_mask.material as ShaderMaterial
	mat.set_shader_parameter("od_w", 30.0 * od / 50.0)
	mat.set_shader_parameter("odv_w", 30.0 * odv / 50.0)


## gui infosats, @n keys, then "@" breaks the line.
func _top_text() -> String:
	var line := OriginalLines.gui("infosats")
	var keys := ["keyAttack", "keyTele", "keyAction", "keySats"]
	for i in keys.size():
		line = line.replace("@%d" % (i + 1), "[%s]" % _StoryText.key_label(keys[i]))
	var step := ["grenade", "melee"] if Prompts.pad else ["weapon_prev", "weapon_next"]
	var extra := Locale.tf("sats_port_keys", ["[%s]/[%s]" % [Prompts.action_plain(step[0]), Prompts.action_plain(step[1])], Prompts.action("pause")])
	return line.replace("@", "\n") + "\n" + extra


# --- helpers ---

func _cur_weapon() -> Dictionary:
	if _player == null or not is_instance_valid(_player):
		return {}
	return _player.call("_weapon")


func _status() -> int:
	return int(_player.call("weapon_status")) if _player.has_method("weapon_status") else 0


func _is_melee(w: Dictionary) -> bool:
	var kind := str(w.get("kind", ""))
	return kind == "melee" or kind == "internal" or str(w.get("delivery", "")) == "melee"


func _notice(text: String) -> void:
	if _player.has_method("_notice"):
		_player.call("_notice", text)


func _aim_cursor() -> Node:
	return get_tree().get_first_node_in_group("aim_cursor")


func _cursor() -> Vector2:
	var cursor := _aim_cursor()
	if cursor != null and cursor.has_method("world_position"):
		return cursor.world_position()
	return _player.get_global_mouse_position()


func _view_scale() -> Vector2:
	var s := get_viewport().get_canvas_transform().get_scale()
	return Vector2(maxf(absf(s.x), 0.01), maxf(absf(s.y), 0.01))


func _view_rect() -> Rect2:
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var view := get_viewport().get_visible_rect()
	var a := inv * view.position
	var b := inv * view.end
	return Rect2(a, b - a).abs()
