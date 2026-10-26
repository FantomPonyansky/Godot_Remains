extends UnitBrain

## UnitBossRaider. States cycle 1..5: 1 charges and rams, 2 stands facing the target,
## 3 fires bursts, 4 stamps a quake, 5 calls a vortex (tr 1) and takes potshots.
## tr 1 carries a carbine, tr 2 (visualRaiderBoss2) a flamer and calls raider
## reinforcements at each quarter of its hp lost.

const QUAKE_TICKS := 40
const RAIDERS := ["raider1", "raider2", "raider3", "raider4"]

var control_on := true
var kol_emit := 8
var called := 0
var ai_napr := 1.0
var ai_v_napr := 0
var ai_t_turn := 0
var ai_jump := 0
var ai_attack_t := 0
var ai_attack_och := 12
var ai_dist := 2000.0
var beg := Vector2.ZERO
var cur: UnitGun


func configure() -> void:
	if tr <= 0:
		tr = 2 if id == "bossraider2" else 1
	walk_speed = max_speed
	run_speed = max_speed * 6.0
	ai_tch = 80
	ai_napr = storona
	weapon_dy = -body().y * 0.58
	if tr == 2:
		var vis2 := vis_of("bossraider2")
		if not vis2.is_empty():
			u.set("_unit_vis", vis2)
			var tex := load("res://assets/sprites/sheets/units/%s" % str(vis2.get("sheet", ""))) as Texture2D
			if tex != null:
				u.set("sheet_texture", tex)
	var d_mult := 1.0
	if global_dif() == 3:
		d_mult = 1.2
	elif global_dif() == 4:
		d_mult = 1.5
	u.set("max_hp", int(round(float(u.get("max_hp")) * d_mult)))
	dam *= d_mult


func ready() -> void:
	u.hp = int(u.get("max_hp"))
	beg = u.global_position
	cur = gun("flamer" if tr == 2 else "carbine")
	ai_dist = 500.0 if tr == 2 else 2000.0


func on_damage(amount: float, type: String, bullet: Node, tt: bool) -> float:
	var left := super.on_damage(amount, type, bullet, tt)
	if tr == 2 and global_dif() > 1:
		var mx := maxf(1.0, float(u.get("max_hp")))
		var tc := int(floor((mx - (float(u.hp) - left)) / mx * 4.0))
		if tc > called:
			called += 1
			for i in 2:
				spawn_unit(RAIDERS[randi() % RAIDERS.size()], beg + Vector2(randf_range(-300.0, 300.0), 0.0))
	return left


func drop_loot() -> void:
	if cur != null:
		var host := u.get_tree().current_scene
		if host != null:
			u.call("_spawn_drop", host, cur.id, 1, weapon_pos())


func command(com: String, _val: String = "") -> void:
	if com == "off":
		walk = 0.0
		control_on = false
	elif com == "on":
		control_on = true


func jump(v: float = 1.0) -> void:
	ai_jump = randi_range(30, 79)
	if stay:
		vel.y = -jumpdy * v
		if ai_napr < 0.0:
			vel.x *= 0.8
		else:
			vel.x += storona * accel * 2.0


func control() -> void:
	if stunned():
		ai_state = 0
		ai_tch = 3
		walk = 0.0
	var jmp := 0.0
	_quake_tick()
	if not control_on:
		return
	var p := player_node()
	if not enemy_act() or p == null:
		cel = Vector2(u.global_position.x + body().x * storona * 2.0, u.global_position.y - body().y)
		return
	if ai_jump > 0:
		ai_jump -= 1
	if ai_tch > 0:
		ai_tch -= 1
	else:
		ai_state += 1
		if ai_state > 5:
			ai_state = 1
		ai_tch = 30 if ai_state in [2, 4, 5] else randi_range(150, 249)
	if ai_tch % 10 == 1:
		set_cel(p)
	var cdx := cel.x - u.global_position.x
	var cdy := cel.y - u.global_position.y + body().y
	ai_v_napr = 1 if cdy > 40.0 else (-1 if cdy < -40.0 else 0)
	throu = cdy > 160.0
	storona = ai_napr
	max_speed = run_speed if ai_state == 1 else walk_speed
	walk = 0.0
	destroy = 0.0
	if ai_state == 0:
		if vel.x > 0.5:
			storona = 1.0
		if vel.x < -0.5:
			storona = -1.0
	elif ai_state == 1 or ((ai_state == 2 or ai_state == 3) and absf(cdx) > ai_dist):
		destroy = 50.0
		if ai_tch % 15 == 1 and rnd():
			if cdx > 100.0:
				ai_napr = 1.0
			if cdx < -100.0:
				ai_napr = -1.0
			storona = ai_napr
		if stay:
			walk = ai_napr
			if ai_napr < 0.0:
				if vel.x > -max_speed:
					vel.x -= accel
			elif vel.x < max_speed:
				vel.x += accel
		elif ai_napr < 0.0:
			if vel.x > -max_speed:
				vel.x -= accel / 4.0
		elif vel.x < max_speed:
			vel.x += accel / 4.0
		if stay and rnd() and ai_v_napr != 1 and ledge(ai_napr):
			jmp = 0.5
		if stay and u.global_position.y - beg.y >= 40.0:
			jmp = 1.0
		if stay and tr == 2 and cdy < -100.0:
			jmp = 1.0
		if turn_x != 0.0:
			if cdx * ai_napr < 0.0:
				ai_napr = turn_x
				storona = turn_x
				ai_t_turn = randi_range(5, 24)
			else:
				ai_t_turn -= 1
				if ai_t_turn < 0:
					ai_napr = turn_x
					storona = turn_x
					ai_t_turn = randi_range(5, 24)
			turn_x = 0.0
			turn_y = 0.0
		if jmp > 0.0 and ai_jump <= 0:
			storona = ai_napr
			jump(jmp)
	elif ai_state == 2 or ai_state == 3:
		ai_napr = 1.0 if cel.x > u.global_position.x else -1.0
		storona = ai_napr
		if cdx * cdx + cdy * cdy < 40000.0:
			ai_state = 1
	attack(cdx, cdy)


func attack(cdx: float, cdy: float) -> void:
	var near := cdx * cdx + cdy * cdy < 10000.0
	if ai_state == 1 and cel_unit != null:
		var other: Vector2 = cel_unit.get("velocity") if cel_unit.get("velocity") is Vector2 else Vector2.ZERO
		att_korp(cel_unit, 1.0 if absf(vel.x - other.x / TPS) > 8.0 else 0.5)
	elif ai_state == 3:
		if ai_attack_t <= 0:
			ai_attack_t = int(round((randf() * 0.4 + 0.8) * ai_attack_och))
		if ai_attack_t > ai_attack_och * 0.25:
			cur.attack()
		ai_attack_t -= 1
		if near and rnd(0.1):
			att_korp(cel_unit, 0.5)
	elif ai_state == 4:
		if ai_tch == 5:
			CamShake.add(QUAKE_TICKS, QUAKE_TICKS)
			emit_part("quake", u.global_position + Vector2(randf_range(-20.0, 20.0), 0.0))
	elif ai_state == 5:
		if ai_tch == 5 and kol_emit > 0 and tr == 1:
			var un := spawn_unit("vortex", center(), {"vortex_minion": true})
			if un != null:
				un.set("fraction", int(u.get("fraction")))
			kol_emit -= 1
		if cel_unit != null and rnd(0.02):
			cur.attack()
		if near and rnd(0.1):
			att_korp(cel_unit, 1.0 if absf(vel.x) > 8.0 else 0.5)


## UnitPlayer.run: while loc.quake counts down a standing player (massa 1) is tossed
## by 1.5 * quake, at most 10.
func _quake_tick() -> void:
	var q := CamShake.quake_left()
	if q <= 0:
		return
	var p := player_node()
	if p != null and p.is_on_floor():
		var pun := minf(10.0, 1.5 * q)
		p.velocity.y = -pun * randf() * TPS
		p.velocity.x += pun * (randf() * 2.0 - 1.0) * TPS


var _jump_f := -1

func animate() -> void:
	if ai_state == 4 or ai_state == 6:
		_jump_f = -1
		anim("bac")
	elif stay:
		_jump_f = -1
		if absf(vel.x) < 1.0:
			anim("stay")
		elif ai_state == 1:
			anim("run")
		else:
			anim("trot")
	else:
		# UnitBossRaider.animate: the pose is picked once, when the jump starts.
		if _jump_f < 0:
			_jump_f = clampi(int(round((16.0 + vel.y) / 2.0)), 0, 15)
		anim_frame("jump", _jump_f)
