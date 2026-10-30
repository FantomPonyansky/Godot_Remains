extends UnitBrain

## UnitBossUltra (the ultra sentinel). It flies between five fixed points of its room
## (1), pauses to pick an attack (2), then fires it (3): a rocket salvo (attState 0),
## the gatling plasma (1), a fan of plasma grenades (2) or gas rockets (4). Below half
## hp it switches to the heavier gatling behind a 2000 hp shield.

const MOVE_POINTS := [Vector2(10, 7), Vector2(37, 7), Vector2(24, 13), Vector2(7, 18), Vector2(40, 18)]

var control_on := true
var shit_max_hp := 500.0
var usil := false
var mp := 3
var move := Vector2.ZERO
var att_state := 0
var t_turn := 15
var t_shit := 300
var ai_napr := 1.0
var origin := Vector2.ZERO
var cur: UnitGun
var cur2: UnitGun
var dop: UnitGun
var gas: UnitGun
var th: UnitGun
var visshit: AnimatedSprite2D
## The gatling arms (Weapon.vis of robogatp / robogatp2) at the weapon point.
var arm: Sprite2D
var arm2: Sprite2D


func configure() -> void:
	is_fly = true
	walk_speed = max_speed
	ai_tch = 80
	shit_armor = 15.0
	weapon_dy = -110.0
	ai_napr = storona
	timer_die = 150
	u.set("_flying", true)
	var d_mult := 1.0
	if global_dif() == 3:
		d_mult = 1.2
	elif global_dif() == 4:
		d_mult = 1.5
	u.set("max_hp", int(round(float(u.get("max_hp")) * d_mult)))
	shit_max_hp *= (1.0 + level * 0.12) * d_mult
	dam *= d_mult


func ready() -> void:
	u.hp = int(u.get("max_hp"))
	origin = room_origin()
	cur = gun("robogatp")
	cur2 = gun("robogatp2")
	dop = gun("robomlau2")
	gas = gun("robogas")
	th = gun("roboplagr")
	th.find_cel = false
	set_cel(null, u.global_position + Vector2(200.0 * storona, -50.0))
	visshit = make_overlay("shield", Vector2(0.0, -70.0), 1.7)
	arm = make_gun_vis(cur)
	arm2 = make_gun_vis(cur2)
	if arm2 != null:
		arm2.visible = false


func forces() -> void:
	pass


func command(com: String, _val: String = "") -> void:
	if com == "off":
		walk = 0.0
		control_on = false
	elif com == "on":
		control_on = true


func _hp_k() -> float:
	return float(u.hp) / maxf(1.0, float(u.get("max_hp")))


func control() -> void:
	if not control_on:
		return
	var p := player_node()
	if not enemy_act() or p == null:
		cel = Vector2(u.global_position.x + body().x * storona * 2.0, u.global_position.y - body().y)
		return
	if t_shit > 0:
		t_shit -= 1
	var res: Node = u.get_node_or_null("Resistances")
	if res != null:
		var mult: Dictionary = res.get("multipliers")
		mult["DAM_EMP"] = 0.2 if shithp > 0.0 else 1.0
		res.set("multipliers", mult)
	if ai_tch > 0:
		ai_tch -= 1
	else:
		ai_state += 1
		if ai_state > 3:
			ai_state = 2 if att_state == 4 else 1
		if ai_state == 1:
			var nmp := randi() % 5
			if nmp == mp:
				nmp += 1
			if nmp >= 5:
				nmp = 0
			mp = nmp
			var pt: Vector2 = MOVE_POINTS[mp]
			move = origin + Vector2(pt.x * 40.0 + 20.0, pt.y * 40.0 + 40.0)
			ai_tch = 60
			_cast_shit()
		elif ai_state == 2:
			ai_tch = 30
			if att_state != 4 and rnd(0.33):
				att_state = 4
			else:
				att_state = randi() % 2
			if u.global_position.y - origin.y < 17 * 40 and cel.y - origin.y > 16 * 40 and rnd(0.33):
				att_state = 2
				ai_tch = 5
			if att_state == 4:
				ai_tch = 15
			if att_state == 0:
				set_cel(p)
		elif ai_state == 3:
			match att_state:
				0:
					ai_tch = 80
				2:
					ai_tch = 120
				4:
					ai_tch = 60
				_:
					ai_tch = randi_range(150, 249)
	if (ai_state == 1 or (ai_state > 1 and att_state == 1)) and ai_tch % 10 == 1:
		set_cel(p)
	var dist := u.global_position.distance_squared_to(move)
	if ai_state == 0:
		if vel.x > 0.5:
			storona = 1.0
		if vel.x < -0.5:
			storona = -1.0
		walk = 0.0
	elif ai_state == 1:
		vel += norma(move - u.global_position, minf(accel, accel * dist / 10000.0))
		if dist < 1000.0:
			vel *= 0.8
	else:
		vel *= 0.7
	if ai_state == 2 and ai_tch % 5 == 1:
		match att_state:
			0:
				emit_part("laser", cel + Vector2(randf_range(-50.0, 50.0), -randf() * 50.0))
			1:
				emit_part("plasma", cel + Vector2(randf_range(-25.0, 25.0), -randf() * 20.0))
			4:
				emit_part("spark", cel + Vector2(randf_range(-50.0, 50.0), -randf() * 50.0))
	if ai_state > 0 and not (ai_state == 3 and att_state == 2):
		ai_napr = 1.0 if cel.x > u.global_position.x else -1.0
		if storona == ai_napr:
			t_turn = 15
		else:
			t_turn -= 1
			if t_turn <= 0:
				storona = ai_napr
				t_turn = 15
	attack()
	if not usil and _hp_k() < 0.5:
		usil = true
		shithp = shit_max_hp * 4.0
		t_shit = 2000


func _cast_shit() -> void:
	if shithp <= 0.0 and t_shit <= 0 and (global_dif() == 4 or (global_dif() == 3 and _hp_k() < 0.5)):
		shithp = shit_max_hp
		t_shit = 1000


func attack() -> void:
	if ai_state == 1 and cel_unit != null:
		att_korp(cel_unit, 1.0)
	elif ai_state == 3:
		match att_state:
			0:
				dop.attack()
			1:
				(cur2 if usil else cur).attack()
			4:
				gas.attack()
			_:
				th.force_rot += 0.1
				th.attack()
		if dist2_to_player() < 10000.0 and rnd(0.1):
			att_korp(player_node(), 0.5)


func animate() -> void:
	anim("stay")
	if arm != null and arm2 != null and arm2.visible != usil:
		arm.visible = not usil
		arm2.visible = usil
	animate_gun_vis(cur)
	animate_gun_vis(cur2)
	if visshit != null:
		if not visshit.visible and shithp > 0.0:
			visshit.visible = true
			visshit.play("stay")
		elif visshit.visible and shithp <= 0.0:
			visshit.visible = false
			emit_part("pole", u.global_position + Vector2(0.0, -50.0), {"kol": 12, "rx": 100, "ry": 100})


func drop_loot() -> void:
	new_part("baleblast")
	sound("bale_e")
	if arm != null:
		arm.visible = false


func expl() -> void:
	new_part("metal", 22)


func dying_tick() -> void:
	if rnd(0.3 - timer_die / 500.0):
		emit_part("expl", u.global_position + Vector2(randf_range(-60.0, 60.0), -randf() * 120.0))
		new_part("metal")
		sound("expl_e")
