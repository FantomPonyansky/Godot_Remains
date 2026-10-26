extends UnitBrain

## UnitBloat (bloat0..bloat10). It never paths: it drifts along aiDx / aiDy (±0.7), wall bumps
## flip the component that hit (turnX / turnY), and the forces are the plain flyer's.
## States: 0 drifting, 1 sees the target (spitters shoot), 2 diving at the target.
## units.xml `un` settings: attch / attr (dive chance and range), shootch, gryz (bloat6 clings).

const ATT := {"bloat0": [0.6, 600.0], "bloat4": [0.8, 700.0], "bloat6": [1.0, 700.0], "bloat7": [0.8, 700.0]}

var ai_dx := 0.0
var ai_dy := 0.0
var ai_rasst := 0.0
var att_rasst := 400.0
var att_ch := 0.4
var shoot_ch := 0.1
var sit_speed := 0.0
var gryz := false
var is_gryz := false
var cur: UnitGun = null


func configure() -> void:
	is_fly = true
	elast = 0.0
	var row_run := float(row.get("run", 0.0)) / TPS
	var explicit_run := row_run > 0.0 and absf(row_run - max_speed * 2.0) > 0.01
	max_speed *= 0.9 + randf() * 0.2
	sit_speed = max_speed * 0.5
	walk_speed = max_speed
	run_speed = row_run if explicit_run else max_speed * 2.0
	var att: Array = ATT.get(id, [0.4, 400.0])
	att_ch = float(att[0])
	att_rasst = float(att[1])
	gryz = id == "bloat6"
	ai_dx = 0.7 if rnd() else -0.7
	ai_dy = 0.7 if rnd() else -0.7
	storona = 1.0 if ai_dx > 0.0 else -1.0
	u.set("_flying", true)


func ready() -> void:
	if int(u.get_meta("hero", 0)) == 1:
		shoot_ch = 0.3
	cur = xml_gun()
	weapon_dy = -body().y * 0.5
	ai_state = 0
	ai_tch = randi_range(5, 14)


## Unit.run for a flyer: a wall hit zeroes that axis (elast 0) and sets turnX; the floor sets
## turnY up, the ceiling turnY down. A floating body reports every contact as is_on_wall, so
## the side is read from the contact normals; the base class would flip turnX while the
## bloat pressed into the floor and never turn it up, which pinned it there.
func after_move(pushed: Vector2) -> void:
	var got := u.velocity / TPS
	for i in u.get_slide_collision_count():
		var n := u.get_slide_collision(i).get_normal()
		if absf(n.x) > 0.3 and absf(pushed.x) > 0.01:
			turn_x = signf(n.x)
			got.x = 0.0
		if n.y < -0.3 and pushed.y > 0.01:
			turn_y = -1.0
			got.y = 0.0
		elif n.y > 0.3 and pushed.y < -0.01:
			turn_y = 1.0
			got.y = 0.0
	vel = got
	stay = false


func _dir_to_target() -> Vector2:
	if cel_unit == null or not is_instance_valid(cel_unit):
		return Vector2.ZERO
	return center_of(cel_unit) - center()


func control() -> void:
	if not enemy_act() or stunned():
		return
	if ai_tch > 0:
		ai_tch -= 1
	else:
		ai_tch = randi_range(20, 69)
		var d := _dir_to_target()
		if cel_unit != null and d != Vector2.ZERO:
			ai_rasst = d.length()
			if ai_rasst < att_rasst and rnd(att_ch):
				ai_dx = d.x / ai_rasst
				ai_dy = d.y / ai_rasst
				ai_state = 2
				ai_tch = 20
				max_speed = run_speed
			else:
				ai_state = 1
				max_speed = walk_speed
			storona = 1.0 if d.x > 0.0 else -1.0
		else:
			if rnd(0.1):
				ai_dx = 0.7 if rnd() else -0.7
				ai_dy = 0.7 if rnd() else -0.7
			storona = 1.0 if ai_dx > 0.0 else -1.0
			ai_state = 0
			max_speed = sit_speed
	if ai_tch % 10 == 1:
		find_cel()
	if is_plav:
		turn_y = -1.0
	if bool(u.get("levitated")):
		is_gryz = false
	if turn_x != 0.0:
		storona = turn_x
		ai_dx = absf(ai_dx) * turn_x
		turn_x = 0.0
	if turn_y != 0.0:
		ai_dy = absf(ai_dy) * turn_y
		turn_y = 0.0
	vel += Vector2(ai_dx * accel + randf() * 2.0 - 1.0, ai_dy * accel + randf() * 2.0 - 1.0)
	if is_gryz:
		if cel_unit != null and is_instance_valid(cel_unit) and boxes_touch(cel_unit):
			var tf: Vector2 = u.call("_feet", cel_unit)
			var ts: Vector2 = u.call("_body_size", cel_unit)
			var off := tf - u.global_position
			if off.length_squared() > 10000.0:
				is_gryz = false
			else:
				vel.x = off.x
				vel.y = off.y - ts.y * 0.5 + body().y * 0.5
		else:
			is_gryz = false
	if cel_unit != null and shok <= 0:
		if ai_state == 1 and cur != null and rnd(shoot_ch):
			cur.attack()
		if att_korp(cel_unit) and gryz:
			is_gryz = true


## UnitBloat.otbros: a knockback shot shakes a clinging bloat6 off.
func on_knock() -> void:
	is_gryz = false


func expl() -> void:
	new_part("shmatok", 4, 2)
	new_part("bloat_kap", randi_range(4, 6))


func animate() -> void:
	# The wing flap is one looping clip (nested `osn` in the symbol), no state clips.
	anim("stay")
