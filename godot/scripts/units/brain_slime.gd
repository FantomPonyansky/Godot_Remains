extends UnitBrain

## UnitSlime. State 0 crawls and turns at ledges, 1 hangs from the ceiling and drips,
## 2 lies hidden as a trap (tr 10+) and bursts when the player comes close.

const EXPL_DIST := 80.0

var pluh := 100
var ai_n := randi() % 5
var is_mine := false
var is_expl := false
var cur: UnitGun


func configure() -> void:
	if tr >= 10:
		is_mine = true
		tr -= 10
	max_speed *= randf() * 0.3 + 0.85
	accel *= randf() * 0.3 + 0.85
	walk_speed = max_speed
	brake = accel / 2.0


func ready() -> void:
	cur = xml_gun()
	u.set("_detect_delay", float(u.get("_detect_delay")) * 0.5)
	if is_mine:
		ai_state = 2
		u.set("_can_lift", false)
		_set_vis(false)
	elif solid_at(u.global_position + Vector2(0.0, 10.0)):
		ai_state = 0
	elif solid_at(u.global_position + Vector2(0.0, -50.0)):
		ai_state = 1
	else:
		ai_state = 0
	u.anim.frame = randi() % maxi(1, u.anim.sprite_frames.get_frame_count("stay"))


func _set_vis(v: bool) -> void:
	u.anim.modulate.a = 1.0 if v else 0.1
	u.set_meta("hidden_trap", not v)


func activate() -> void:
	if bool(u.get("_dead")):
		return
	_set_vis(true)
	u.set("points", 0)
	if not is_expl:
		explode(dam * 0.8, tip, 200.0)
	is_expl = true
	u.call("_begin_death")


func forces() -> void:
	if ai_state == 1 or ai_state == 2:
		vel = Vector2.ZERO
		return
	super.forces()


func control() -> void:
	if not enemy_act():
		return
	ai_n += 1
	if stay and ledge(-1.0) and storona < 0.0:
		turn_x = 1.0
	if stay and ledge(1.0) and storona > 0.0:
		turn_x = -1.0
	if turn_x != 0.0:
		storona = turn_x
		turn_x = 0.0
	var dd := float(u.get("_detect_delay"))
	if ai_state == 0:
		walk = storona
		if storona < 0.0:
			if vel.x > -max_speed:
				vel.x -= accel
		elif vel.x < max_speed:
			vel.x += accel
	elif ai_state == 1:
		if ai_n % 5 == 0 and not solid_at(u.global_position + Vector2(0.0, -50.0)):
			ai_state = 0
		pluh -= 1
		if pluh <= 0:
			set_cel(null, u.global_position + Vector2(0.0, 100.0))
			if cur != null:
				cur.attack()
			pluh = randi_range(40, 114)
	elif ai_state == 2:
		if dd <= 0.0 and ai_n % 4 == 0 and dist2_to_player() < EXPL_DIST * EXPL_DIST:
			activate()
			return
		if ai_n % 10 == 0 and u.anim.modulate.a < 1.0 and dist2_to_player() < 300.0 * 300.0:
			_set_vis(true)
	if dd <= 0.0 and ai_n % 5 == 0:
		var p := player_node()
		if p != null and att_korp(p):
			if tr == 0:
				GameState.start_effect("chemburn", 15.0)
			elif tr == 1:
				GameState.start_effect("freezing", 15.0)


func weapon_pos() -> Vector2:
	return u.global_position + Vector2(0.0, -40.0 if ai_state == 1 else -10.0)


func animate() -> void:
	if ai_state == 1:
		u.anim.rotation = PI
		u.anim.position = Vector2(0.0, -40.0)
	else:
		u.anim.rotation = 0.0
		u.anim.position = Vector2.ZERO
	if ai_state == 2:
		u.anim.pause()
	elif not u.anim.is_playing():
		u.anim.play("stay")
