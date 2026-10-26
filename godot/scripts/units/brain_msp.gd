extends UnitBrain

## UnitMsp (spider mine). States: 0 asleep, 1 searching, 2 waking, 3 runs at the
## target, 4 lost it. It clings to a ceiling or wall until it wakes, and blows up
## inside 100 px of its target.

var cep := 0
var fixed := false
var ai_napr := 1.0
var ai_v_napr := 0
var ai_t_turn := 0


func configure() -> void:
	ai_napr = storona


func ready() -> void:
	var at := u.global_position
	if not solid_at(at + Vector2(0.0, 10.0)):
		if solid_at(at + Vector2(0.0, -50.0)):
			cep = 1
		elif solid_at(at + Vector2(-40.0, -10.0)):
			cep = 2
		elif solid_at(at + Vector2(40.0, -10.0)):
			cep = 3
		fixed = cep > 0


func drop_loot() -> void:
	explode(dam, tip, 150.0)


func forces() -> void:
	if fixed:
		vel = Vector2.ZERO
		return
	super.forces()


func jump(v: float = 1.0) -> void:
	if stay:
		vel.y = -jumpdy * v


func control() -> void:
	if bool(u.get("levitated")) and ai_state <= 1:
		shok = 15
		ai_state = 3
		budilo()
	if stunned():
		ai_state = 0
		ai_tch = 3
		walk = 0.0
	var jmp := 0.0
	if not enemy_act():
		cel = Vector2(u.global_position.x + body().x * storona * 2.0, u.global_position.y - body().y)
		return
	if ai_state >= 3 and cep > 0:
		cep = 0
		fixed = false
	if ai_tch > 0:
		ai_tch -= 1
	elif ai_state == 2:
		if cel_unit != null:
			ai_spok = max_spok + 10
			var dx := cel.x - u.global_position.x
			if dx > 40.0:
				ai_napr = 1.0
			if dx < -40.0:
				ai_napr = -1.0
			ai_state = 3
		else:
			ai_state = 1
	else:
		if ai_spok <= 0:
			ai_state = 1
			ai_tch = randi_range(40, 79)
		else:
			ai_tch = randi_range(40, 89)
		if ai_spok > 0:
			ai_state = 4
		if ai_spok >= max_spok:
			ai_state = 3
	if ai_tch % 10 == 1:
		if find_cel():
			if ai_state <= 1:
				ai_state = 2
				ai_tch = randi_range(30, 39)
			elif ai_state >= 3:
				ai_state = 3
	if fixed:
		return
	var cdx := cel.x - u.global_position.x
	var cdy := cel.y - u.global_position.y + body().y
	ai_v_napr = 1 if cdy > 40.0 else (-1 if cdy < -40.0 else 0)
	if ai_state == 3:
		if ai_tch % 15 == 1:
			if rnd(0.9):
				if cdy > 80.0:
					throu = true
				if ai_v_napr < 0 and rnd(0.2):
					jmp = 1.0
			else:
				throu = false
				jmp = 0.0
			if cdx > 40.0:
				ai_napr = 1.0
			if cdx < -40.0:
				ai_napr = -1.0
			storona = ai_napr
		walk = ai_napr
		if ai_napr < 0.0:
			if vel.x > -max_speed:
				vel.x -= accel
		elif vel.x < max_speed:
			vel.x += accel
		if stay and rnd(0.5) and ai_v_napr != 1 and ledge(ai_napr):
			jmp = 0.5
		if turn_x != 0.0:
			ai_t_turn -= 1
			if rnd(0.03) or turn_y > 0.0:
				ai_t_turn -= 10
			else:
				jmp = 1.0
			if ai_t_turn < 0:
				ai_napr = turn_x
				storona = turn_x
				ai_t_turn = randi_range(5, 24)
			turn_x = 0.0
			turn_y = 0.0
		if jmp > 0.0:
			jump(jmp)
		if cel_unit != null and is_instance_valid(cel_unit):
			if u.global_position.distance_squared_to(center_of(cel_unit)) < 100.0 * 100.0:
				u.call("_begin_death")
	else:
		walk = 0.0


func animate() -> void:
	var half := body() * 0.5
	match cep:
		1:
			u.anim.rotation = PI
			u.anim.position = Vector2(0.0, -body().y)
		2:
			u.anim.rotation = PI * 0.5
			u.anim.position = Vector2(-half.x, -half.y)
		3:
			u.anim.rotation = -PI * 0.5
			u.anim.position = Vector2(half.x, -half.y)
		_:
			u.anim.rotation = 0.0
			u.anim.position = Vector2.ZERO
	if ai_state <= 1:
		anim("stay")
	elif ai_state == 2 or ai_state == 4:
		anim("wake")
	elif stay or bool(u.get("levitated")):
		anim("walk")
	else:
		anim("jump")


func expl() -> void:
	new_part("metal", 4)
	new_part("miniexpl")
