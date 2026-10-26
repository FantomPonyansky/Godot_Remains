extends UnitBrain

## UnitBossNecr. States: 0 stands, 1 runs away from the player and leaps about,
## 2 fires necrotic bolts, 3 casts a protection. Protections cycle heal / shadow
## (invulnerable) / full invisibility. Curse symbols land where the player is
## heading; summons come in waves of three. The first death starts phase 2: full hp,
## a ghostly look and faster curses.

const CURSES := ["stupor", "weak", "pinkcloud", "relat", "fetter", "sacrifice", "sacrifice", "antil", "antil"]
## effs.xml t, seconds.
const CURSE_TIME := {"stupor": 9.0, "weak": 15.0, "pinkcloud": 15.0, "relat": 10.0, "fetter": 7.0, "sacrifice": 10.0, "antil": 20.0}
const CURSE_RAD := 100.0
const TIME_PROTECT_CULD := 600
const TIME_ATTACK_CULD := 350
const TIME_PROTECT := 250
const KOL_EMIT := 6

var control_on := true
var time_curse_culd := 300
var phase := 1
var atk_t := 150
var throu_t := 0
var atk_n := -1
var prot_n := 1
var protculd_t := TIME_PROTECT_CULD / 3
var curseculd_t := 150
var prot_t := 0
var heal_hp := 100.0
var summon_atk_mult := 0.5
var is_shadow := false
var super_invis := false
var cur_a := 100
var cel_a := 100
var ai_napr := 1.0
var ai_t_turn := 0
var beg := Vector2.ZERO
var cur: UnitGun
var children: Array = []
var symbols: Array = []


func configure() -> void:
	walk_speed = max_speed
	run_speed = max_speed * 3.0
	ai_tch = 80
	ai_napr = storona
	weapon_dy = -body().y * 0.58
	timer_die = 90
	destroy = 110.0
	if global_dif() == 3:
		summon_atk_mult = 0.65
	elif global_dif() == 4:
		summon_atk_mult = 0.8
	var d_mult := 1.0
	if global_dif() == 3:
		d_mult = 1.2
	elif global_dif() == 4:
		d_mult = 1.5
	u.set("max_hp", int(round(float(u.get("max_hp")) * d_mult)))
	dam *= d_mult


func ready() -> void:
	u.hp = int(u.get("max_hp"))
	heal_hp = float(u.get("max_hp")) / 10.0
	beg = u.global_position
	cur = gun("necrbullet")


func on_damage(amount: float, type: String, bullet: Node, tt: bool) -> float:
	if is_shadow:
		return 0.0
	var td := super.on_damage(amount, type, bullet, tt)
	if ai_state == 0:
		ai_state = 1
	if protculd_t <= 0 and td > 0.0 and ai_state != 3 and ai_state != 2:
		ai_state = 3
		ai_tch = 30
	curseculd_t -= int(floor(td / 40.0))
	atk_t -= int(floor(td / 30.0))
	return td


func on_die() -> bool:
	if super.on_die():
		return true
	_reset_protect()
	if phase == 1:
		phase = 2
		u.hp = int(u.get("max_hp"))
		ai_state = 0
		ai_tch = 10
		time_curse_culd = 220
		u.set("dexter", 2.0)
		revive_from_dying(0)
		if has_clip("stay"):
			anim("stay")
		_set_look()
		return true
	for c in children:
		if is_instance_valid(c) and not bool((c as Node).get("_dead")):
			c.call("_begin_death")
	for s in symbols:
		if is_instance_valid(s.node):
			(s.node as Node).queue_free()
	symbols.clear()
	return false


func start_dying() -> void:
	new_part("necrblast2")
	if has_clip("die"):
		anim("die")


func drop_loot() -> void:
	new_part("necrblast")
	sound("unreal")


func command(com: String, _val: String = "") -> void:
	if com == "off":
		walk = 0.0
		control_on = false
	elif com == "on":
		control_on = true


func jump(v: float = 1.0) -> void:
	if stay:
		vel.y = -jumpdy * v
		if ai_napr < 0.0:
			vel.x *= 0.8
		else:
			vel.x += storona * accel * 2.0


func control() -> void:
	_tick_symbols()
	var jmp := 0.0
	if not control_on:
		return
	var p := player_node()
	if not enemy_act() or p == null:
		cel = Vector2(u.global_position.x + body().x * storona * 2.0, u.global_position.y - body().y)
		return
	if throu_t > 0:
		throu_t -= 1
	else:
		throu = false
	if prot_t > 0:
		prot_t -= 1
	if prot_t == 1:
		_reset_protect()
	if protculd_t > 0:
		protculd_t -= 1
	if curseculd_t > 0:
		curseculd_t -= 1
	else:
		if phase == 2 and rnd(0.25):
			for o in [0, 4, 8, 12, 16]:
				cast_curse(2, o)
		elif rnd(0.25):
			for o in [0, 10, 20]:
				cast_curse(1, o)
		else:
			cast_curse()
		curseculd_t = int(floor((randf() * 1.6 + 0.2) * time_curse_culd))
	if ai_state != 3 and ai_state != 2:
		if atk_t > 0:
			atk_t -= 1
		else:
			atk_n += 1
			if atk_n % 2 == 0:
				if not is_shadow and find_cel():
					ai_state = 2
					ai_tch = 140
					new_part("necrblast3")
					vel.x *= 0.5
					walk = 0.0
					_reset_protect()
				else:
					atk_n += 1
			if atk_n % 2 == 1:
				_spawn(atk_n % (6 if phase == 1 else 8))
			atk_t = int(floor((randf() * 0.6 + 0.7) * TIME_ATTACK_CULD))
	var cdx := cel.x - u.global_position.x
	if ai_tch > 0:
		ai_tch -= 1
	else:
		if ai_state == 3:
			ai_state = 0
			cast_protect()
		if ai_state == 0:
			ai_state = 1
			if rnd(0.8):
				ai_napr = -1.0 if cdx > 0.0 else 1.0
			else:
				ai_napr = 1.0 if cdx > 0.0 else -1.0
			storona = ai_napr
		else:
			if rnd():
				ai_napr = -1.0 if cdx > 0.0 else 1.0
			ai_state = 1 if rnd(0.7) else 0
			storona = ai_napr
		if rnd(0.3):
			jmp = 1.0
		if rnd(0.3):
			throu_t = 5
			throu = true
		ai_tch = randi_range(40, 139)
	if ai_tch % 10 == 1:
		set_cel(p)
	cdx = cel.x - u.global_position.x
	var cdy := cel.y - u.global_position.y + body().y
	if ai_tch % 10 == 1 and ai_state == 1 and cdy < 80.0 and cdy > -80.0:
		if cdx < 0.0 and cdx > -400.0:
			ai_napr = 1.0
			storona = 1.0
		if cdx > 0.0 and cdx < 400.0:
			ai_napr = -1.0
			storona = -1.0
	max_speed = run_speed if ai_state == 1 else walk_speed
	walk = 0.0
	if ai_state == 0:
		if vel.x > 0.5:
			storona = 1.0
		if vel.x < -0.5:
			storona = -1.0
	elif ai_state == 1:
		if stay:
			walk = ai_napr
			if ai_napr < 0.0:
				if vel.x > -max_speed:
					vel.x -= accel
			elif vel.x < max_speed:
				vel.x += accel
		elif ai_napr < 0.0:
			if vel.x > -max_speed:
				vel.x -= accel * 0.25
		elif vel.x < max_speed:
			vel.x += accel * 0.25
		if stay and ledge(ai_napr) and rnd(0.8):
			jmp = 0.4
		if stay and u.global_position.y - beg.y >= 35.0:
			jmp = 0.6
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
		if jmp > 0.0:
			storona = ai_napr
			jump(jmp)
	elif ai_state == 2:
		cel_a = 100
		vel.x *= 0.7
		ai_napr = 1.0 if cdx > 0.0 else -1.0
		storona = ai_napr
		if ai_tch < 120:
			cur.attack()


func cast_protect(n: int = 0) -> void:
	protculd_t = TIME_PROTECT_CULD
	new_part("black", 20)
	if n == 0 and prot_n == 0:
		u.hp = mini(int(u.get("max_hp")), u.hp + int(round(heal_hp)))
	elif n == 1 or prot_n == 1:
		is_shadow = true
		u.set("_can_lift", false)
		prot_t = TIME_PROTECT
		atk_t = 5
	else:
		super_invis = true
		cur_a = 0
		cel_a = 0
		prot_t = TIME_PROTECT
	prot_n = (prot_n + 1) % 3
	_set_look()


func _reset_protect() -> void:
	super_invis = false
	is_shadow = false
	u.set("_can_lift", true)
	_set_look()


func _set_look() -> void:
	if is_shadow:
		u.set("_tint", Color(0.35, 0.3, 0.4))
	elif phase == 2:
		u.set("_tint", Color(0.7, 0.75, 1.3))
	else:
		u.set("_tint", Color.WHITE)
	u.anim.modulate = u.get("_tint")


func _spawn(n: int) -> void:
	children = children.filter(func(c: Variant) -> bool: return is_instance_valid(c) and not bool((c as Node).get("_dead")))
	var uid := ""
	var hpmult := 1.0
	match n:
		1:
			uid = "zombie7"
			hpmult = 0.85
		3:
			uid = "zombie8"
			hpmult = 0.75
		5:
			uid = "necros"
			hpmult = 0.65
		7:
			uid = "zombie9"
			hpmult = 0.65
		_:
			return
	for i in 3:
		if children.size() >= KOL_EMIT:
			return
		var at := beg + Vector2(randf_range(-400.0, 400.0), 0.0)
		var un := spawn_unit(uid, at)
		if un == null:
			continue
		un.set("fraction", int(u.get("fraction")))
		un.set("_loot_cont", "")
		var top := maxi(1, int(round(float(un.get("max_hp")) * hpmult)))
		un.set("max_hp", top)
		un.set("hp", top)
		un.set("melee_damage", int(round(float(un.get("melee_damage")) * summon_atk_mult)))
		un.set("_bullet_damage", int(round(float(un.get("_bullet_damage")) * summon_atk_mult)))
		children.append(un)


## MagSymbol: a sigil that fires its curse 20 ticks (plus the delay) after landing,
## on the player if they are within 100 px of it then.
func cast_curse(n: int = 0, otlozh: int = 0) -> void:
	var p := player_node()
	if p == null:
		return
	var pv: Vector2 = p.velocity / TPS
	var pc := center_of(p)
	var at := pc + pv * 15.0 + Vector2((randf() - 0.5) * 50.0, (randf() - 0.5) * 30.0)
	if n == 2:
		var side := 1.0 if int(p.global_position.x) % 2 == 0 else -1.0
		at = Vector2(p.global_position.x + pv.x * 15.0 + float(otlozh - 8) * 20.0 * side, pc.y + pv.y * 15.0)
	if n == 1:
		at += Vector2(randf_range(-100.0, 100.0), randf_range(-50.0, 50.0))
	var spell: String = CURSES[randi() % (9 if phase == 2 else 5)]
	symbols.append({"at": at, "liv": 20 + otlozh, "spell": spell, "node": _symbol_node(at)})


func _symbol_node(at: Vector2) -> Node2D:
	var host := u.get_tree().current_scene
	if host == null:
		return null
	var mark := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(Vector2.from_angle(TAU * i / 12.0) * 14.0)
	mark.polygon = pts
	mark.color = Color(0.6, 0.2, 0.9, 0.55)
	host.add_child(mark)
	mark.global_position = at
	return mark


func _tick_symbols() -> void:
	if symbols.is_empty():
		return
	var p := player_node()
	var keep: Array = []
	for s_v in symbols:
		var s: Dictionary = s_v
		s.liv = int(s.liv) - 1
		if int(s.liv) == 1 and p != null and center_of(p).distance_to(s.at) < CURSE_RAD:
			GameState.start_effect(str(s.spell), float(CURSE_TIME.get(s.spell, 10.0)))
		if int(s.liv) <= 0:
			if is_instance_valid(s.node):
				(s.node as Node).queue_free()
			continue
		keep.append(s)
	symbols = keep


var _jump_f := -1

func animate() -> void:
	if ai_state == 3:
		_jump_f = -1
		anim("cast")
	elif stay:
		_jump_f = -1
		if absf(vel.x) < 1.0:
			anim("stay")
		elif ai_state == 1:
			anim("run")
		else:
			anim("trot")
	elif bool(u.get("levitated")) and bool(u.call("_has_clip", "derg")):
		_jump_f = -1
		anim("derg")
	else:
		# UnitBossNecr.animate: the pose is picked once, when the jump starts.
		if _jump_f < 0:
			_jump_f = clampi(int(round((16.0 + vel.y) / 2.0)), 0, 15)
		anim_frame("jump", _jump_f)
	cel_a = 0 if super_invis else 100
	if cur_a > cel_a:
		cur_a -= 5
	if cur_a < cel_a:
		cur_a += 5
	u.anim.modulate.a = cur_a / 100.0
