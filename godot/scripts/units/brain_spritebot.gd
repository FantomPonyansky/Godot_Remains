extends UnitBrain

## UnitSpriteBot. State 0 wanders the air, 1 is angry (zlo): it saw a target and
## takes potshots with its laser.

var ai_dx := 0.0
var ai_dy := 0.0
var ai_rasst := 0.0
var cur: UnitGun


func configure() -> void:
	is_fly = true
	elast = 0.8
	max_speed += randf() * 2.0 - 1.0
	walk_speed = max_speed
	run_speed = max_speed * 1.5
	weapon_dy = -1.0
	u.set("_flying", true)


func ready() -> void:
	cur = gun("robolaser")
	set_vision(0.3)
	ai_state = 0
	ai_tch = randi_range(5, 54)


func forces() -> void:
	vel *= 0.95


func zlo() -> void:
	set_vision(1.0)
	ai_state = 1


func command(com: String, _val: String = "") -> void:
	if com == "alarma":
		zlo()
		ai_tch = 3


func control() -> void:
	if not enemy_act() or stunned():
		return
	if ai_tch > 0:
		ai_tch -= 1
	else:
		if cel_unit != null:
			max_speed = run_speed * (randf() * 0.6 + 0.7)
			ai_rasst = (cel - center()).length()
			ai_tch = randi_range(20, 69)
		else:
			max_speed = walk_speed * (randf() + 0.5)
			ai_rasst = 0.0
			ai_tch = randi_range(30, 179)
			storona = 1.0 if vel.x > 0.0 else -1.0
			set_cel(null, center() + vel * 10.0)
		if ai_rasst > 500.0:
			var d := cel - center()
			ai_dx = d.x / ai_rasst
			ai_dy = d.y / ai_rasst
		else:
			var napr := randf() * 360.0
			ai_dx = sin(napr)
			ai_dy = cos(napr)
		vel = Vector2(ai_dx, ai_dy) * max_speed
		if cel_unit != null:
			storona = 1.0 if cel.x - u.global_position.x > 0.0 else -1.0
		else:
			storona = 1.0 if vel.x > 0.0 else -1.0
	if ai_tch % 10 == 1:
		if find_cel():
			zlo()
			storona = 1.0 if cel.x - u.global_position.x > 0.0 else -1.0
	if turn_x != 0.0:
		storona = turn_x
		turn_x = 0.0
	turn_y = 0.0
	if ai_state == 1 and cel_unit != null and shok <= 0 and rnd(0.1) and cur != null:
		cur.attack()


func animate() -> void:
	anim("zlo" if ai_state == 1 and has_clip("zlo") else "stay")


func expl() -> void:
	new_part("metal", 4)
	new_part("miniexpl")
