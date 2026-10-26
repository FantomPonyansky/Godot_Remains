extends UnitBrain

## UnitDron. States: 0 patrols, 1 sees the target and flies at it, 2 lost it,
## 3 pulls away after a ram. dron3 sidesteps slow bullets.

var br := 0.0
var stuk := 0
var atk_dist := 250.0
var ai_agr := false
var t_float := randf()
var atk_rasst := 0.0
var t_krut := 0
var cur: UnitGun


func configure() -> void:
	if tr <= 0:
		tr = int(id.trim_prefix("dron")) if id.trim_prefix("dron").is_valid_int() else 1
	is_fly = true
	elast = 0.6
	walk_speed = max_speed
	run_speed = max_speed * 3.0
	ai_agr = tr == 2 or tr == 100
	snd_run_on = true
	u.set("_flying", true)


func ready() -> void:
	cur = xml_gun()
	weapon_dy = -body().y * 0.5 + (40.0 if tr >= 100 else 0.0)


func forces() -> void:
	if vel.length_squared() > max_speed * max_speed:
		vel = norma(vel, max_speed)


func on_damage(amount: float, type: String, bullet: Node, tt: bool) -> float:
	if t_krut > 0 or tr != 3 or bullet == null or not is_instance_valid(bullet):
		return super.on_damage(amount, type, bullet, tt)
	var bv := float(bullet.get("speed")) / TPS
	var w_rapid := 1.0
	var wid := str(bullet.get("weapon_id"))
	var wrow: Dictionary = u.call("_weapon_row", wid) if wid != "" else {}
	if not wrow.is_empty():
		w_rapid = maxf(1.0, float(wrow.get("rapid", 1)))
	if bv >= 1000.0 or randf() < bv / 300.0 or randf() < 6.0 / w_rapid:
		return super.on_damage(amount, type, bullet, tt)
	var d: Vector2 = bullet.get("direction")
	var p := Vector2(d.y, -d.x)
	if randf() < 0.5:
		p = -p
	vel += norma(p, max_speed * 3.0)
	u.velocity = vel * TPS
	t_krut = 45
	return 0.0


func command(com: String, _val: String = "") -> void:
	if com == "alarma":
		ai_state = 2
		ai_tch = 3


func control() -> void:
	if not enemy_act() or stunned():
		return
	if t_krut > 0:
		t_krut -= 1
	if ai_tch > 0:
		ai_tch -= 1
	else:
		if ai_spok == 0:
			ai_state = 0
		elif ai_spok >= max_spok:
			ai_state = 1
		else:
			ai_state = 2
		ai_tch = randi_range(100, 199)
		if ai_state == 0:
			cel = Vector2(u.global_position.x + randf_range(400.0, 700.0) * (1.0 if rnd() else -1.0), center().y)
	if ai_tch % 10 == 1:
		if find_cel():
			stuk = 0
			ai_spok = max_spok + 10
			if ai_state != 3:
				ai_state = 1
			storona = 1.0 if cel.x > u.global_position.x else -1.0
		elif ai_spok > 0 and ai_spok % 10 == 1:
			set_cel(null, cel + Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0)))
		var d := cel - center()
		atk_rasst = d.length_squared()
		var spd := norma(d, accel * 0.5 if ai_state == 0 else accel)
		if ai_state == 3:
			vel -= spd
		elif ai_agr or atk_rasst < atk_dist * atk_dist or ai_state == 2:
			vel += spd
		else:
			t_float += 0.97
			vel += Vector2(sin(t_float), cos(t_float)) * accel
	max_speed = walk_speed if ai_state == 0 else run_speed
	if tr == 1:
		storona = 1.0 if cel.x > u.global_position.x else -1.0
	if turn_x != 0.0:
		stuk += 1
		storona = turn_x
		turn_x = 0.0
		if ai_state == 0:
			cel.x = u.global_position.x + 400.0 * storona
		if stuk > 5:
			set_cel(null, cel + Vector2(randf_range(40.0, 120.0) * storona, randf_range(-40.0, 40.0)))
	if turn_y != 0.0:
		if turn_y < 0.0:
			vel.y = -6.0
		turn_y = 0.0
	if ai_state == 1 and cel_unit != null and shok <= 0:
		if cur != null and atk_rasst > atk_dist * atk_dist:
			cur.attack()
		if att_korp(cel_unit, 1.0):
			cel.y += 20.0
			ai_tch = randi_range(20, 39)
			ai_state = 3


func animate() -> void:
	br += (vel.x * 1.5 - br) / 4.0
	# vis.scaleX = storona mirrors osn.rotation = br * storona back to br on screen.
	tilt(br)
	anim("stay")


func expl() -> void:
	new_part("metal", 4)
	new_part("miniexpl")
