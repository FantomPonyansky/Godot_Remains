extends UnitBrain

## UnitBossDron (the mega drone). It homes on the player, faster as it loses hp and
## when the player flies, rams, alternates a rocket volley with three plasma
## grenades, hatches a drone every 500 ticks (5 at most) and raises a 500 hp shield
## on the hardest difficulties.

const KOL_EMIT := 5

var shit_max_hp := 500.0
var emit_t := 120
var t_atk := 100
var t_shit := 300
var kolth := 0
var control_on := true
var cur: UnitGun
var th: UnitGun
var visshit: AnimatedSprite2D
var children: Array = []


func configure() -> void:
	is_fly = true
	walk_speed = max_speed
	ai_tch = 80
	shit_armor = 15.0
	timer_die = 150
	u.set("_flying", true)
	var d_mult := 1.0
	if global_dif() == 3:
		d_mult = 1.2
	elif global_dif() == 4:
		d_mult = 1.5
	u.set("max_hp", int(round(float(u.get("max_hp")) * d_mult)))
	shit_max_hp *= (1.0 + level * 0.12) * d_mult
	dam *= d_mult


func ready() -> void:
	u.hp = int(u.get("max_hp"))
	cur = gun("dronmlau")
	th = gun("drongr")
	visshit = make_overlay("shield", Vector2(0.0, -70.0), 1.7)
	# visualMegaDron's discharge plays on its own; UnitBossDron never hides it.
	var rig: RigView = u.get("rig")
	var dis := rig.attachment("dis") if rig != null else null
	if dis != null:
		dis.visible = true


func forces() -> void:
	pass


func command(com: String, _val: String = "") -> void:
	if com == "off":
		walk = 0.0
		control_on = false
	elif com == "on":
		control_on = true


func control() -> void:
	if not control_on or not enemy_act():
		return
	var p := player_node()
	if p == null:
		return
	if t_shit > 0:
		t_shit -= 1
	ai_state = 1
	ai_tch += 1
	if ai_tch % 10 == 1:
		set_cel(p)
	var speed_bonus := 1.6 if bool(p.get_meta("foe_flying", false)) else 1.0
	storona = 1.0 if cel.x - u.global_position.x > 0.0 else -1.0
	var move := p.global_position
	var dist := u.global_position.distance_squared_to(move)
	var spd := norma(move - u.global_position, minf(accel, accel * dist / 1000.0))
	var hp_k := float(u.hp) / maxf(1.0, float(u.get("max_hp")))
	max_speed = walk_speed * (2.0 - hp_k) * (1.0 - sin(ai_tch / 12.0) * 0.3) * speed_bonus
	vel += spd
	vel = norma(vel, max_speed) if vel.length() > 0.0 else vel
	if dist < 1000.0:
		vel *= 0.8
	attack()
	_cast_shit()
	emit_t -= 1
	if emit_t <= 0:
		_emit()


func _cast_shit() -> void:
	var hp_k := float(u.hp) / maxf(1.0, float(u.get("max_hp")))
	if shithp <= 0.0 and t_shit <= 0 and (global_dif() == 4 or (global_dif() == 3 and hp_k < 0.5)):
		shithp = shit_max_hp
		t_shit = 1000


func _emit() -> void:
	children = children.filter(func(c: Variant) -> bool: return is_instance_valid(c) and not bool((c as Node).get("_dead")))
	if children.size() >= KOL_EMIT:
		return
	var un := spawn_unit("dron%d" % randi_range(1, 2), center(), {"tr": 0})
	if un != null:
		un.set("fraction", int(u.get("fraction")))
		un.set("_detect_delay", 0.0)
		un.set("_loot_cont", "")
		children.append(un)
	emit_t = 500


func attack() -> void:
	if cel_unit != null:
		att_korp(cel_unit, 1.0)
	t_atk -= 1
	if t_atk <= 0:
		t_atk = randi_range(40, 99)
		if rnd():
			cur.attack()
		else:
			kolth = 3
	if kolth > 0:
		th.attack()
		if th.is_shoot:
			kolth -= 1
			th.is_shoot = false


func animate() -> void:
	anim("stay")
	if visshit != null:
		if not visshit.visible and shithp > 0.0:
			visshit.visible = true
			visshit.play("stay")
		elif visshit.visible and shithp <= 0.0:
			visshit.visible = false
			emit_part("pole", u.global_position + Vector2(0.0, -50.0), {"kol": 12, "rx": 100, "ry": 100})


func drop_loot() -> void:
	new_part("baleblast")
	sound("bale_e")


func expl() -> void:
	new_part("metal", 22)


func dying_tick() -> void:
	if rnd(0.3 - timer_die / 500.0):
		emit_part("expl", u.global_position + Vector2(randf_range(-60.0, 60.0), -randf() * 120.0))
		new_part("metal")
		sound("expl_e")
