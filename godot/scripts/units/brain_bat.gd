extends UnitBrain

## UnitBat (bloodwing). States: 0 roosting, 1 drifting, 2 searching, 3 flying at the
## target, 4 biting or hurt, 5 winding up a dash, 6 dashing.

var ai_dx := 0.0
var ai_dy := 0.0
var ai_rasst := 0.0


func configure() -> void:
	is_fly = true
	elast = 0.5
	max_speed += randf() * 2.0 - 1.0
	walk_speed = max_speed
	run_speed = max_speed * 2.0
	acts_held = true
	u.set("_flying", true)


func ready() -> void:
	ai_state = 0
	ai_tch = randi_range(5, 14)


func command(com: String, _val: String = "") -> void:
	if com == "alarma" and ai_state <= 1:
		ai_spok = max_spok - 1
		ai_state = 2
		budilo(250.0)


func control() -> void:
	if not enemy_act() or stunned():
		return
	var hurt: bool = int(u.get("hp")) < int(u.get("max_hp"))
	if ai_tch > 0:
		ai_tch -= 1
	elif ai_state == 6:
		ai_state = 4
		ai_tch = randi_range(100, 199)
	elif ai_state == 5:
		ai_state = 6
		ai_tch = 20
	elif ai_spok == 0:
		if ai_state > 1:
			ai_state = 1
			ai_dx = 0.7 if rnd() else -0.7
			ai_dy = -0.7
			storona = signf(ai_dx)
		ai_tch = 10
	elif ai_spok >= max_spok:
		if ai_rasst < 380.0:
			if rnd():
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
		if find_cel():
			ai_spok = max_spok + 10
			if ai_state < 5:
				ai_state = 4 if hurt else 3
		if ai_state >= 2 and ai_state <= 5:
			var d := cel - center()
			if d != Vector2.ZERO:
				ai_dx = d.x
				ai_dy = d.y
			storona = 1.0 if ai_dx > 0.0 else -1.0
			ai_rasst = sqrt(ai_dx * ai_dx + ai_dy * ai_dy) + 0.00001
			ai_dx /= ai_rasst
			ai_dy /= ai_rasst
	set_vision(0.4 if ai_state == 0 else 1.0)
	u.set("_ear", 0.6 if ai_state == 0 else 1.0)
	if turn_x != 0.0:
		storona = turn_x
		ai_dx = absf(ai_dx) * turn_x
		turn_x = 0.0
	if turn_y != 0.0:
		if turn_y > 0.0 and ai_state == 1:
			vel = Vector2.ZERO
			ai_dx = 0.0
			ai_dy = 0.0
			ai_spok = 0
			ai_state = 0
		else:
			ai_dy = absf(ai_dy) * turn_y
		turn_y = 0.0
	if ai_state >= 1 and ai_state <= 4:
		max_speed = run_speed if ai_state == 4 else walk_speed
		if not bool(u.get("levitated")):
			vel += Vector2(ai_dx * accel + randf() * 2.0 - 1.0, ai_dy * accel + randf() * 2.0 - 1.0)
	elif ai_state == 5:
		max_speed = 0.0
	elif ai_state == 6:
		max_speed = run_speed * 2.5
		if not bool(u.get("levitated")):
			vel += Vector2(ai_dx, ai_dy) * accel * 3.0
	if ai_state == 3 and shok <= 0 and rnd(0.1):
		att_korp(cel_unit)
	if ai_state == 4 and shok <= 0:
		att_korp(cel_unit)
	if ai_state == 6:
		att_korp(cel_unit, 2.0)


## The fly clip still plays while held. The flight push must not fight Telekinesis.hold.
func levit_pull(_v: Vector2) -> Vector2:
	return Vector2.ZERO


func animate() -> void:
	if ai_state == 0:
		anim("stay")
	elif ai_state == 6:
		anim("attack")
	else:
		anim("fly")
