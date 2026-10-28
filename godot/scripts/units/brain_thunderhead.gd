extends UnitBrain

## UnitThunderHead: the storm-cloud core of the sky arena (thunder land, a zoom 3
## room 5760x3000 from the room origin). It flies in from the right (state 0),
## then cycles 1 orbit a quarter turn around the arena centre in 180 ticks,
## 2 and 3 hold for 30 and 100 ticks; from state 1 on its 29 bound ttur turrets
## fire. It pulls the player in (vsos) on its 800-tick cycle and harder as it
## weakens, releases dron minions as it loses hp, and only every 10-40th bullet
## that is not aimed at it lands (dopTest). Killed, it stays as a wreck
## (noDestr) that flashes for 150 ticks; the script's vsos keeps pulling.

const SPRITE := "res://assets/fx_blits/11_sprThunderHead.png"
## ThunderHeadMoln from OTHER art/strips, exported at 2×. Scale 0.5 keeps the old world size.
const MOLN_STRIP := "res://assets/fx_blits/ThunderHeadMoln.png"
const MOLN_FRAME := Vector2(500, 424)
const MOLN_ORIGIN := Vector2(250, 214)
const MOLN_COLS := 2
const MOLN_FRAMES := 3
## UnitThunderHead.run: the hit box is a 1370x580 window of the x3 hull, so the
## sprite centre (Unit.coordinates) sits off the box's feet.
const HIT_BOX := Vector2(4110.0, 1740.0)
const SPRITE_AT := Vector2(45.0, -750.0)
const ARENA := Vector2(1920.0 * 3.0, 3000.0)
const MOVE_TIME := 180
const VSOS_MAX := 450
const VSOS_POROG := 120
const VSOS_FORCE := 3.0
## createTurret(n, bindX, bindY, rot, mega) in hull pixels; the hull is drawn x3.
const TURRETS := [
	[1, -850, -340, 0, false], [1, -770, -340, 0, false], [1, -690, -340, 0, false],
	[2, -610, -340, 0, true], [2, -530, -340, 0, false],
	[3, 370, -336, 0, false], [3, 420, -336, 0, false], [3, 470, -336, 0, false], [3, 520, -336, 0, false],
	[4, 750, -173, 0, false], [4, 820, -173, 0, false], [4, 890, -173, 0, true],
	[5, 585, -17, 0, false], [5, -585, -17, 0, true],
	[6, 710, -17, 0, false], [6, 770, -17, 0, true],
	[1, 420, 402, 2, false], [1, 500, 402, 2, false],
	[2, 580, 402, 2, false], [2, 660, 402, 2, false], [2, 740, 402, 2, false],
	[3, -110, 304, 2, true], [3, -60, 304, 2, false],
	[4, -10, 304, 2, false], [4, 40, 304, 2, false],
	[5, 90, 304, 2, false],
	[5, -470, 470, 2, false], [6, -420, 470, 2, false], [6, -370, 470, 2, false],
]
## ThunderHeadMoln: two lightning clips on the hull, in hull pixels.
const MOLN_X := [500.0, 1700.0]
const MOLN_Y := 666.0

var control_on := true
var vsos_on := false
var t_vsos := 800
var kol_emit := 5
var max_emit := 15
var ugol := 90.0
var distanc := 6000.0
var t_doptest := 20
var att_tur := 0
var reload_div := 1.0
var is_att := false
var wrecked := false
var t_die := 0
var t_moln := 100
var arena := Rect2()
var turrets: Array = []
var hull: Sprite2D
var molns: Array[Sprite2D] = []


func configure() -> void:
	u.set("body_size", HIT_BOX)
	u.set("_trup", false)
	u.set("dexter", 0.0)
	flips_sprite = false
	u.set("_flying", true)
	u.set("_can_lift", false)
	always_active = true
	walk_speed = max_speed
	accel = 3.0
	ai_tch = 150
	ai_state = 0
	if global_dif() == 3:
		kol_emit = 3
		max_emit = 18
	elif global_dif() == 4:
		kol_emit = 1
		max_emit = 21
	var mult := 1.1 if global_dif() == 3 else (1.2 if global_dif() == 4 else 1.0)
	u.set("max_hp", int(round(float(u.get("max_hp")) * mult)))


func ready() -> void:
	u.hp = int(u.get("max_hp"))
	is_fly = true
	u.collision_mask = 0
	var origin := room_origin()
	if u.has_meta("room_x") and u.has_meta("room_y"):
		origin = Vector2(int(u.get_meta("room_x")) * 1920.0, int(u.get_meta("room_y")) * 1000.0)
	arena = Rect2(origin, ARENA)
	var tex := load(SPRITE) as Texture2D
	if tex != null:
		u.anim.visible = false
		hull = Sprite2D.new()
		hull.texture = tex
		hull.scale = Vector2(3.0, 3.0)
		hull.position = SPRITE_AT
		u.add_child(hull)
		_make_moln(tex)
	var res: Node = u.get_node_or_null("Resistances")
	if res != null:
		var mult: Dictionary = res.get("multipliers")
		mult["DAM_BALEFIRE"] = 0.7
		mult["DAM_DEATH"] = 0.8
		mult["DAM_ASTRO"] = 0.8
		mult["DAM_HARMONY"] = 0.8
		res.set("multipliers", mult)
	set_ugol_pos()
	for t in TURRETS:
		var metas := {"tr": int(t[0]), "head": u, "bind": Vector2(float(t[1]), float(t[2])) * 3.0,
			"korp_rot": int(t[3]), "mega": bool(t[4])}
		var un := spawn_unit("ttur", head_center(), metas, false)
		if un == null:
			continue
		un.set("fraction", int(u.get("fraction")))
		turrets.append(un)
	_follow()


func _make_moln(tex: Texture2D) -> void:
	var sheet := load(MOLN_STRIP) as Texture2D
	if sheet == null:
		return
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var hull_top_left := -Vector2(tex.get_width(), tex.get_height()) * 0.5
	for i in 2:
		var spr := Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = sheet
		spr.texture = at
		spr.material = mat
		spr.scale = Vector2(0.5, 0.5)
		spr.modulate.a = 0.0
		spr.position = hull_top_left + Vector2(MOLN_X[i], MOLN_Y)
		hull.add_child(spr)
		molns.append(spr)


## UnitThunderHead.setUgolPos: an ellipse around the arena centre, pinched at the
## diagonals (def) and pushed out at the axes (dif ^ 4).
func set_ugol_pos() -> void:
	var def := sin(ugol / 45.0 * PI)
	var dif := sin(ugol / 90.0 * PI)
	var ugol2 := -def * 12.0 + ugol
	var distanc2 := distanc + dif * dif * dif * dif * 1000.0
	var c := Vector2(ARENA.x / 2.0 + sin(deg_to_rad(ugol2)) * distanc2, ARENA.y / 2.0 + cos(deg_to_rad(ugol2)) * distanc2 / 1.6)
	u.global_position = arena.position + c - SPRITE_AT
	# The approach starts outside the arena; room_bounds.gd holds flyers at room_safe.
	u.set_meta("room_safe", u.global_position)
	_follow()


func head_center() -> Vector2:
	return u.global_position + SPRITE_AT


func _follow() -> void:
	var hc := head_center()
	for t in turrets:
		if is_instance_valid(t) and not bool(t.get("_dead")):
			var b: Variant = t.get("_brain")
			if b != null:
				b.follow(hc)


func die_turret() -> void:
	reload_div += 0.1


## dopTest: a bullet aimed at the head always lands, others only every 10-40th.
func dop_test(bullet: Node) -> bool:
	if bullet != null and is_instance_valid(bullet) and bullet.get("homing_target") == u:
		return true
	t_doptest -= 1
	if t_doptest > 0:
		return false
	t_doptest = randi_range(10, 39)
	return true


func forces() -> void:
	pass


func move_body() -> void:
	pass


func after_move(_pushed: Vector2) -> void:
	pass


func command(com: String, _val: String = "") -> void:
	if com == "off":
		walk = 0.0
		control_on = false
	elif com == "on":
		control_on = true
	elif com == "vsos":
		vsos_on = true


## noDestr: the hull stays as a wreck (sost 3); the death script still runs.
func on_die() -> bool:
	if wrecked:
		return true
	wrecked = true
	is_att = false
	sound(str(row.get("snd", {}).get("die", "")))
	var host := u.get_tree().get_first_node_in_group("land_props")
	if host != null and host.has_method("run_actions"):
		host.run_actions(u.get("die_actions"))
	GameState.enemy_defeated(int(u.get("points")))
	u.hp = 0
	u.collision_layer = 0
	u.remove_from_group("enemies")
	return true


func control() -> void:
	if vsos_on:
		_vsos()
	if wrecked or not control_on:
		is_att = false
		return
	if ai_tch > 0:
		ai_tch -= 1
	else:
		ai_state += 1
		if ai_state > 3:
			ai_state = 1
		ai_tch = [0, MOVE_TIME, 30, 100][ai_state]
	if ai_tch % 10 == 1:
		set_cel(player_node())
	att_tur -= 1
	if ai_state == 0:
		distanc -= 20.0 if ai_tch > 20 else float(ai_tch)
		is_att = false
	elif ai_state == 1:
		ugol += 90.0 / MOVE_TIME
		if ugol >= 360.0:
			ugol -= 360.0
		is_att = true
	else:
		is_att = true
	t_vsos -= 1
	var hp := float(u.hp)
	var top := float(u.get("max_hp"))
	if t_vsos < VSOS_POROG:
		_vsos(VSOS_FORCE, true)
	elif hp < top / 5.0:
		_vsos(1.0)
	elif hp < top / 2.0:
		_vsos(0.5)
	if t_vsos < 0:
		t_vsos = VSOS_MAX
	if (top - hp) / top * max_emit > kol_emit:
		_emit()
	set_ugol_pos()


func _vsos(n: float = 0.0, klob: bool = false) -> void:
	var p := player_node()
	if p == null or not ("velocity" in p):
		return
	var d := norma(head_center() - p.global_position, 5.0 if n == 0.0 else n)
	if n == 0.0:
		p.set("facing", 1.0 if p.velocity.x > 0.0 else -1.0)
	if klob and t_vsos % 3 == 0:
		emit_part("vsos", p.global_position + Vector2(0.0, -40.0), {"dx": d.x * 12.0 + randf() * 4.0 - 2.0, "dy": d.y * 12.0 + randf() * 4.0 - 2.0, "scale": 6.0})
	p.velocity += d * TPS


func _emit() -> void:
	kol_emit += 1
	var at := head_center()
	at.x = clampf(at.x, arena.position.x + 200.0, arena.end.x - 200.0)
	at.y = clampf(at.y, arena.position.y + 200.0, arena.end.y - 200.0)
	var un := spawn_unit("dron1", at, {"tr": 100})
	if un != null:
		un.set("fraction", int(u.get("fraction")))
		un.set("_detect_delay", 0.0)
		un.set("_loot_cont", "")


func animate() -> void:
	if wrecked and t_die < 150:
		t_die += 1
		_vzdrzhne(t_die)
	t_moln -= 1
	if t_moln <= 0:
		t_moln = randi_range(10, 29)
		var i := 0 if randf() < 0.5 else 1
		if i < molns.size():
			var m := molns[i]
			var fr := randi() % MOLN_FRAMES
			(m.texture as AtlasTexture).region = Rect2((fr % MOLN_COLS) * MOLN_FRAME.x, int(float(fr) / float(MOLN_COLS)) * MOLN_FRAME.y, MOLN_FRAME.x, MOLN_FRAME.y)
			m.offset = -MOLN_ORIGIN
			m.modulate.a = 1.0
			m.position = -Vector2(hull.texture.get_width(), hull.texture.get_height()) * 0.5 + Vector2(MOLN_X[i] + randf_range(-150.0, 150.0), MOLN_Y + randf_range(-15.0, 15.0))
			m.rotation = randf() * TAU
			var s := (randf() * 0.3 + 0.7) * 0.5
			m.scale = Vector2(s, s)
	for m in molns:
		if m.modulate.a > 0.0:
			m.modulate.a = maxf(0.0, m.modulate.a - (randf() * 0.2 - 0.03))


## vzdrzhne: dieTransform on the whole vis. redMultiplier 1 + n/15, and the
## green / blue offsets 1 + n/10 and 1 + n/5 are added in 0-255 units. Past
## tick 10, n = 10 - n/10, so the wreck ends darker than it started.
func _vzdrzhne(n: float) -> void:
	if n > 10.0:
		n = 10.0 - n / 10.0
	if hull == null:
		return
	hull.modulate = Color(1.0 + n / 15.0, 1.0, 1.0)
	if not hull.material is ShaderMaterial:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nuniform vec3 offset;\nvoid fragment() {\n\tCOLOR = texture(TEXTURE, UV) * COLOR;\n\tCOLOR.rgb += offset;\n}\n"
		var mat := ShaderMaterial.new()
		mat.shader = sh
		hull.material = mat
	(hull.material as ShaderMaterial).set_shader_parameter("offset", Vector3(0.0, (1.0 + n / 10.0) / 255.0, (1.0 + n / 5.0) / 255.0))
