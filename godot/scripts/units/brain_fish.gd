extends UnitBrain

## UnitFish. States: 0 still, 1 swimming about, 2 searching, 3 swimming at the target,
## 4 biting, 5 winding up a lunge, 6 lunging, 7 beached, 8 backing off.
## The fish swims below a water line: the surface of the room's water tiles in
## its column, else the water_y meta, else POOL_DEPTH above where it spawned.

const POOL_DEPTH := 120.0

var ai_dx := 0.0
var ai_dy := 0.0
var ai_rasst := 0.0
var water_y := 0.0


func configure() -> void:
	max_speed += randf() * 2.0 - 1.0
	walk_speed = max_speed
	run_speed = max_speed * 2.0
	elast = 0.2
	throu = true
	ai_state = 1
	ai_dx = storona


func ready() -> void:
	water_y = float(u.get_meta("water_y", u.global_position.y - POOL_DEPTH))


func in_water(node: Node2D) -> bool:
	return center_of(node).y > water_y


func physics(delta: float) -> void:
	var surface := _RoomFlags.water_y(u.global_position)
	if surface != INF:
		water_y = surface
	is_plav = center().y > water_y
	super.physics(delta)


func after_move(pushed: Vector2) -> void:
	super.after_move(pushed)
	if is_plav and u.is_on_floor() and pushed.y > 0.0:
		turn_y = -1.0
	stay = u.is_on_floor()


func command(com: String, _val: String = "") -> void:
	if com == "alarma" and ai_state <= 1:
		ai_spok = max_spok - 1
		ai_state = 2
		budilo(250.0)


func jump() -> void:
	if stay:
		vel.y = -jumpdy * randf()
		vel.x = jumpdy * (randf() - 0.5) * 0.5


func control() -> void:
	if not enemy_act() or stunned():
		return
	var hurt: bool = int(u.get("hp")) < int(u.get("max_hp"))
	if ai_tch > 0:
		ai_tch -= 1
	elif ai_state == 6:
		ai_state = 4
		ai_tch = randi_range(100, 199)
	elif ai_state == 7 and is_plav:
		ai_state = 4
		ai_tch = randi_range(100, 199)
	elif ai_state == 5:
		ai_state = 6
		ai_tch = 20
	elif ai_spok == 0:
		ai_state = randi() % 2
		ai_dx = 1.0 if rnd() else -1.0
		storona = ai_dx
		ai_dy = randf() * 0.2 + 0.1
		ai_tch = randi_range(40, 89)
	elif ai_spok >= max_spok:
		if ai_rasst < 380.0:
			if not is_plav and rnd():
				ai_state = 5
				ai_tch = 20
			else:
				ai_state = 4
				ai_tch = randi_range(100, 199)
		else:
			ai_state = 4 if hurt else 3
			ai_tch = randi_range(100, 199)
	else:
		ai_state = 2
		ai_tch = randi_range(100, 199)
	if ai_tch % 10 == 1 and ai_state < 6:
		if find_cel() and cel_unit != null and in_water(cel_unit):
			ai_spok = max_spok + 10
			if ai_state < 5:
				ai_state = 4 if hurt else 3
		elif cel_unit != null and not in_water(cel_unit):
			cel_unit = null
		if ai_state >= 2 and ai_state <= 5:
			var d := cel - center()
			if d != Vector2.ZERO:
				ai_dx = d.x
				ai_dy = d.y
			storona = 1.0 if ai_dx > 0.0 else -1.0
			ai_rasst = sqrt(ai_dx * ai_dx + ai_dy * ai_dy) + 0.00001
			ai_dx /= ai_rasst
			ai_dy /= ai_rasst
	if not is_plav and ai_tch % 10 == 1:
		ai_dy = absf(ai_dy)
		ai_state = 7
		if stay:
			jump()
	if is_plav and center().y + ai_dy * 10.0 < water_y:
		ai_dy = absf(ai_dy)
	if turn_x != 0.0:
		storona = turn_x
		ai_dx = absf(ai_dx) * turn_x
		turn_x = 0.0
	if turn_y != 0.0:
		ai_dy = absf(ai_dy) * turn_y
		turn_y = 0.0
	if ai_state == 1:
		max_speed = walk_speed / 5.0
		if is_plav:
			vel += Vector2(ai_dx, ai_dy) * accel * 0.2
	elif ai_state in [2, 3, 4, 8]:
		max_speed = run_speed if ai_state == 4 else walk_speed
		if ai_state == 8:
			max_speed = walk_speed / 2.0
		if is_plav:
			vel += Vector2(ai_dx, ai_dy) * accel
	elif ai_state == 5:
		max_speed = 0.0
	elif ai_state == 6:
		max_speed = run_speed * 2.5
		vel += Vector2(ai_dx, ai_dy) * accel * 3.0
	if (ai_state in [3, 4, 7] and shok <= 0) or ai_state == 6:
		if att_korp(cel_unit, 2.0 if ai_state == 6 else 1.0) and rnd(0.25):
			ai_state = 8
			set_cel(null, cel + Vector2(randf_range(-400.0, 400.0), randf_range(-400.0, 400.0)))
			ai_tch = 40


func animate() -> void:
	if is_plav:
		if ai_state <= 1:
			anim("plav")
		elif ai_state == 6:
			anim("attack")
		else:
			anim("run")
		tilt(vel.y * 3.0 * storona)
	else:
		anim("stay")
		tilt(vel.y * 4.0 * storona)
