extends UnitBrain

## UnitAIRobot with the UnitRobobrain and UnitSentinel bodies.
## States: 0 stands, 1 patrols, 2 hunts an unseen target, 3 runs and attacks,
## 4 stands and shoots, 5 surprised. The sentinel jump-jets and adds rockets
## against targets beyond 160 px.

var stroll := true
var ai_attack_t := 80
var ai_attack_och := 100
var ai_dist := 1000.0
var ai_napr := 1.0
var ai_v_napr := 0
var ai_t_turn := 0
var sit_speed := 10.0
var jump_n := 100
var sentinel := false
var cur: UnitGun
var dop: UnitGun


func configure() -> void:
	sentinel = id == "sentinel"
	if str(u.get_meta("ai_tip", "")) == "quiet":
		stroll = false
	walk_speed = max_speed
	sit_speed = max_speed
	run_speed = max_speed * 2.0
	ai_napr = storona
	weapon_dy = -90.0 if sentinel else -40.0


func ready() -> void:
	cur = xml_gun()
	if cur == null:
		cur = gun("robomlau" if sentinel else "robolaser")
	if sentinel:
		dop = gun("robomlau")
	make_gun_vis(cur)


## UnitSentinel.dropLoot hides the arm; the robobrain keeps its gun on the wreck.
func drop_loot() -> void:
	if sentinel and cur != null and cur.vis != null:
		cur.vis.visible = false


func on_damage(amount: float, type: String, bullet: Node, tt: bool) -> float:
	if ai_state <= 1:
		budilo()
	return super.on_damage(amount, type, bullet, tt)


func command(com: String, _val: String = "") -> void:
	if com == "alarma" and ai_state <= 1:
		ai_spok = max_spok + 10
		ai_state = 3
		shok = randi_range(5, 19)


func jump(v: float = 1.0) -> void:
	if sentinel:
		if stay:
			jump_n = 90
		else:
			jump_n -= 1
		if vel.y > -jumpdy and jump_n > 0:
			vel.y -= jumpdy * v / 4.0
		return
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
	var cdx := cel.x - u.global_position.x
	var cdy := cel.y - u.global_position.y + body().y
	if ai_tch > 0:
		ai_tch -= 1
	elif ai_state == 5:
		if cel_unit != null:
			ai_spok = max_spok + 10
			ai_state = 3
		else:
			ai_state = 1
	else:
		if ai_spok == 0:
			ai_state = (randi() % 2) if stroll else 0
		if ai_spok > 0:
			ai_state = 2
		if ai_spok >= max_spok:
			if ai_state != 3 and ai_state != 4:
				budilo()
			if ai_spok >= max_spok + 2 and cdx * cdx + cdy * cdy < ai_dist * ai_dist:
				ai_state = 3 if rnd(0.3) else 4
			else:
				ai_state = 3
		if ai_state <= 1:
			ai_tch = randi_range(40, 89)
		elif ai_state == 4:
			ai_tch = randi_range(10, 19)
		else:
			ai_tch = randi_range(100, 199)
	if ai_tch % 10 == 1:
		if find_cel(ai_state > 1):
			if cel_unit != null:
				if ai_state <= 1:
					ai_state = 5
					ai_tch = randi_range(20, 49)
				else:
					ai_spok = max_spok + 10
		else:
			if ai_spok % 5 == 1:
				set_cel(null, cel + Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0)))
			if ai_spok <= 0:
				set_cel(null, u.global_position + Vector2(storona * 100.0, -body().y * 0.75))
	cdx = cel.x - u.global_position.x
	cdy = cel.y - u.global_position.y + body().y
	ai_v_napr = 1 if cdy > 40.0 else (-1 if cdy < -40.0 else 0)
	max_speed = walk_speed
	if ai_state == 2:
		max_speed = run_speed
	elif ai_state <= 1:
		max_speed = sit_speed
	walk = 0.0
	if ai_state == 0:
		if stay and ledge(-1.0) and ai_napr < 0.0:
			turn_x = 1.0
		if stay and ledge(1.0) and ai_napr > 0.0:
			turn_x = -1.0
	if ai_state == 1:
		walk = ai_napr
		if ai_napr < 0.0:
			if vel.x > -max_speed:
				vel.x -= accel
		elif vel.x < max_speed:
			vel.x += accel
		if stay and ledge(-1.0) and ai_napr < 0.0:
			turn_x = 1.0
		if stay and ledge(1.0) and ai_napr > 0.0:
			turn_x = -1.0
		if stay and turn_x != 0.0:
			if turn_x * storona < 0.0 and cur != null:
				cur.rot = (PI - cur.rot) if cur.rot > 0.0 else (-PI - cur.rot)
			ai_napr = turn_x
			storona = turn_x
			turn_x = 0.0
	elif ai_state == 2 or ai_state == 3:
		if ai_tch % 15 == 1:
			if rnd(0.9):
				if cdy > 80.0:
					throu = true
			else:
				throu = false
			if rnd():
				if cdx > 100.0:
					ai_napr = 1.0
				if cdx < -100.0:
					ai_napr = -1.0
			if cdx > 40.0:
				storona = 1.0
			if cdx < -40.0:
				storona = -1.0
		jmp = 1.0 if ai_state == 2 and ai_v_napr < 0 else 0.0
		walk = ai_napr
		if ai_napr < 0.0:
			if vel.x > -max_speed:
				vel.x -= accel
		elif vel.x < max_speed:
			vel.x += accel
		if stay and rnd() and ai_v_napr != 1 and ledge(ai_napr):
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
	if ai_state == 4 or ai_state == 3:
		storona = 1.0 if cel.x > u.global_position.x else -1.0
	if ai_state == 3 or ai_state == 4:
		attack()


func attack() -> void:
	var cdx := cel.x - u.global_position.x
	var cdy := cel.y - center().y
	if sentinel:
		if cel_unit != null and absf(cdx) < 100.0 and absf(cdy) < 80.0:
			att_korp(cel_unit, 1.0)
		if cur != null:
			cur.attack()
		if cel_unit != null and dop != null and not (absf(cdx) < 160.0 and absf(cdy) < 80.0):
			dop.attack()
		return
	if cur == null:
		return
	if ai_attack_och == 0 and shok <= 0 and rnd(0.1):
		cur.attack()
	if ai_attack_och > 0:
		if ai_attack_t <= 0:
			ai_attack_t = int(round((randf() * 0.4 + 0.8) * ai_attack_och))
		if ai_attack_t > ai_attack_och * 0.25:
			cur.attack()
		ai_attack_t -= 1


func animate() -> void:
	if sentinel:
		anim("stay" if stay or jump_n <= 0 else "jump")
	elif ai_state == 0 or ai_state == 4:
		anim("stay")
	else:
		anim("walk")
	animate_gun_vis(cur)


func expl() -> void:
	new_part("metal", 4)
	new_part("miniexpl")
