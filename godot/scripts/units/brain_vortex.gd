extends UnitBrain

## UnitVortex: a spinning blade drone. States: 0 drifts, 1 sees the target and
## cuts into it, 2 lost it.

var br := 0.0


func configure() -> void:
	is_fly = true
	elast = 0.8
	walk_speed = max_speed
	run_speed = max_speed * 3.0
	destroy = 20.0
	snd_run_on = true
	u.set("_flying", true)


func ready() -> void:
	if bool(u.get_meta("vortex_minion", false)):
		u.set("_detect_delay", 0.0)
		ai_spok = max_spok + 10
		ai_state = 1


func expl() -> void:
	new_part("metal", 4)
	new_part("miniexpl")


## UnitVortex.destroyWall: its blades cut any tile it hits from the side.
func destroy_amount(dir: Vector2, _v: Vector2) -> int:
	if dying or absf(dir.x) < 0.5:
		return 0
	return int(destroy)


func forces() -> void:
	if vel.length_squared() > max_speed * max_speed:
		vel *= 0.95


func command(com: String, _val: String = "") -> void:
	if com == "alarma":
		ai_state = 2
		ai_tch = 3


func control() -> void:
	if not enemy_act() or stunned():
		return
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
			if rnd():
				cel = Vector2(u.global_position.x + randf_range(400.0, 700.0) * (1.0 if rnd() else -1.0), u.global_position.y + randf_range(-100.0, 100.0))
			else:
				cel = center()
	if ai_tch % 10 == 1:
		if find_cel():
			ai_spok = max_spok + 10
			ai_state = 1
			storona = 1.0 if cel.x > u.global_position.x else -1.0
		vel += norma(cel - center(), accel / 2.0 if ai_state == 0 else accel)
	max_speed = walk_speed if ai_state == 0 else run_speed
	if turn_x != 0.0:
		emit_part("iskr_bul", u.global_position + Vector2(15.0 * storona, -15.0), {"dx": vel.x, "kol": randi_range(3, 7)})
		sound("vortex_cut", UnitFx.hum_volume(sqrt(dist2_to_player())))
		storona = turn_x
		ai_tch = 0
		turn_x = 0.0
	if turn_y != 0.0:
		vel.y = -vel.y * 0.5
		turn_y = 0.0
	if ai_state == 1 and cel_unit != null and shok <= 0:
		att_korp(cel_unit, 1.0)


func animate() -> void:
	br += (vel.x * 2.5 - br) / 4.0
	# vis.scaleX = storona mirrors osn.rotation = br * storona back to br on screen.
	tilt(br)
	anim("attack" if ai_state == 1 and has_clip("attack") else "stay")
