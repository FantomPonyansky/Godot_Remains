extends UnitBrain

## UnitBossAlicorn. Each cycle it teleports to one of seven points of its room (1),
## readies (2) and acts (3): lightning, blades or psychic bolts (attState 0-2),
## a telekinetic grab-and-throw (3), going invisible while scythes fly in (4), or the
## death ray on the hardest difficulties (5). Its first death only breaks the shield:
## hp is restored and six scythes circle it.

const MOVE_POINTS := [Vector2(24, 5), Vector2(8, 7), Vector2(40, 7), Vector2(7, 11), Vector2(42, 11), Vector2(11, 15), Vector2(38, 15)]
const THROW_FORCE := 60.0
const TELE_SPEED := 24.0
const TELE_ACCEL := 6.0
const OPT_DIST_TELE := 1000.0
const TELE_COLOR := Color(1.0, 0.0, 0.0)
const _Tele := preload("res://scripts/units/unit_telekinesis.gd")

var control_on := true
var is_shit := true
var t_float := 0.0
var super_invis := false
var cur_a := 100
var cel_a := 100
var mp := 3
var att_state := 0
var t_turn := 15
var t_fly := 3
var ai_napr := 1.0
var origin := Vector2.ZERO
var weaps: Array[UnitGun] = []
var cur: UnitGun
var tele: RefCounted
var is_blast := false
var visshit: AnimatedSprite2D


func configure() -> void:
	walk_speed = max_speed
	ai_tch = 80
	shit_armor = 15.0
	ai_napr = storona
	weapon_dy = -70.0
	timer_die = 90
	var d_mult := 1.0
	if global_dif() == 3:
		d_mult = 1.2
	elif global_dif() == 4:
		d_mult = 1.5
	u.set("max_hp", int(round(float(u.get("max_hp")) * d_mult)))
	dam *= d_mult


func ready() -> void:
	u.hp = int(u.get("max_hp"))
	tele = _Tele.new(u, TELE_SPEED, TELE_ACCEL, TELE_COLOR)
	origin = room_origin()
	for wid in ["alilight2", "aliblade", "alipsy2", "alimray"]:
		weaps.append(gun(wid))
	cur = weaps[0]
	set_cel(null, u.global_position + Vector2(200.0 * storona, -50.0))
	visshit = make_overlay("shield3", Vector2(0.0, -50.0), 1.5)
	if visshit != null:
		visshit.visible = true
		visshit.play("stay")


func forces() -> void:
	if is_fly:
		return
	super.forces()


func on_die() -> bool:
	if super.on_die():
		_release()
		return true
	super_invis = false
	_release()
	is_blast = false
	if is_shit:
		is_shit = false
		if visshit != null:
			visshit.play("break")
		u.hp = int(u.get("max_hp"))
		ai_state = 0
		ai_tch = 10
		emit_part("blood", center(), {"kol": 100, "rx": body().x * 0.5, "ry": body().y * 0.5})
		revive_from_dying(90)
		for i in 6:
			_emit(i)
		return true
	return false


func start_dying() -> void:
	if has_clip("die"):
		anim("die")
	if not is_blast:
		new_part("bloodblast2")
		is_blast = true


func drop_loot() -> void:
	new_part("bloodblast")
	sound("bale_e")


func expl() -> void:
	new_part("blood", 100)


func command(com: String, _val: String = "") -> void:
	if com == "off":
		walk = 0.0
		control_on = false
	elif com == "on":
		control_on = true


func teleport(at: Vector2, eff: bool = true) -> void:
	emit_part("telered", center(), {"rx": body().x, "ry": body().y, "kol": 30})
	u.global_position = at
	vel = Vector2.ZERO
	is_fly = not (solid_at(at + Vector2(0.0, 10.0)))
	if eff:
		emit_part("teleport", center())


func _emit(n: int = -1) -> void:
	var at := origin + Vector2(randf() * 1600.0 + 160.0, randf() * 500.0 + 100.0)
	var metas := {}
	if n >= 0:
		metas = {"bind": u, "bind_n": n}
	var un := spawn_unit("scythe", at, metas, false)
	if un == null:
		return
	un.set("fraction", int(u.get("fraction")))
	un.set("melee_damage", int(round(float(un.get("melee_damage")) * (1.0 + level * 0.1))))
	var b: Variant = un.get("_brain")
	if b != null:
		b.dam *= 1.0 + level * 0.1
	if n >= 0:
		var top := int(un.get("max_hp")) * 8
		un.set("max_hp", top)
		un.set("hp", top)


func control() -> void:
	if not control_on:
		return
	var p := player_node()
	if not enemy_act() or p == null:
		cel = Vector2(u.global_position.x + body().x * storona * 2.0, u.global_position.y - body().y)
		return
	if not stay and not is_fly:
		t_fly -= 1
		if t_fly <= 0:
			is_fly = true
	else:
		t_fly = 3
	if ai_tch > 0:
		ai_tch -= 1
	else:
		ai_state += 1
		if ai_state > 3:
			ai_state = 1
		if ai_state == 1:
			att_state = randi() % 5
			var nmp := randi() % 7
			if nmp == mp:
				nmp += 1
			if nmp >= 7:
				nmp = 0
			mp = nmp
			var pt: Vector2 = MOVE_POINTS[mp]
			teleport(origin + Vector2(pt.x * 40.0 + 20.0, pt.y * 40.0 + 40.0), att_state != 4)
			ai_tch = 30
			if (global_dif() == 4 and rnd(0.2)) or (global_dif() == 3 and rnd(0.1)):
				att_state = 5
			if att_state <= 2:
				cur = weaps[att_state]
			if att_state == 4:
				super_invis = true
				cur_a = 0
				cel_a = 0
			else:
				super_invis = false
			if att_state == 5:
				cur = weaps[3]
		elif ai_state == 2:
			ai_tch = 30
			if att_state == 3:
				ai_tch = 45
				if not _find_box():
					ai_tch = 15
			if att_state == 4:
				ai_tch = 20
		elif ai_state == 3:
			if att_state == 3:
				_throw_tele()
				ai_tch = 30
			elif att_state == 4:
				ai_tch = 120
			elif att_state == 5:
				ai_tch = 75
			else:
				ai_tch = randi_range(50, 149)
	if ((ai_state == 1 or (ai_state > 1 and att_state <= 2)) and ai_tch % 10 == 1) or (att_state == 5 and ai_state == 3):
		set_cel(p)
	if is_fly:
		t_float += 0.0726
		vel *= 0.9
		vel += Vector2(sin(t_float), cos(t_float)) * 2.0
	if ai_state == 0:
		if vel.x > 0.5:
			storona = 1.0
		if vel.x < -0.5:
			storona = -1.0
		walk = 0.0
	if ai_state > 0:
		ai_napr = 1.0 if cel.x > u.global_position.x else -1.0
		if storona == ai_napr:
			t_turn = 15
		else:
			t_turn -= 1
			if t_turn <= 0:
				storona = ai_napr
				t_turn = 15
	_attack()
	if tele != null:
		tele.hold_beside(storona)
		tele.step_thrown()


func _attack() -> void:
	if ai_state != 3:
		return
	if att_state <= 2 or att_state == 5:
		cur.attack()
	if att_state == 4 and ai_tch % 30 == 1:
		_emit()
	if att_state != 4 and dist2_to_player() < 100.0 * 100.0 and rnd(0.1):
		att_korp(cel_unit, 0.5)


## findBox: the target half the time, else a crate worth lifting.
func _find_box() -> bool:
	if tele == null:
		return false
	if cel_unit != null and is_instance_valid(cel_unit) and rnd():
		tele.grab(cel_unit, GameState.tele_enemy() if cel_unit.is_in_group("player") else 2)
		return true
	var box: Node2D = tele.find_box(OPT_DIST_TELE)
	if box != null:
		tele.grab(box)
		return true
	return false


## throwTele: softer near the arena walls.
func _throw_tele() -> void:
	if tele == null or tele.held == null:
		return
	var force := THROW_FORCE
	if tele.held_is_player():
		tele.held.set("dam_wall", dam / 2.0)
		tele.held.set("t_throw", 30)
	var hc: Vector2 = tele.center_of(tele.held)
	if hc.x - origin.x < 200.0 or hc.x - origin.x > 48 * 40 - 200.0:
		force *= 0.6
	tele.throw_at(cel, force, storona)


func _release() -> void:
	if tele != null:
		tele.release()


func animate() -> void:
	if is_fly:
		anim("fly")
	elif stay and absf(vel.x) > 1.0:
		anim("walk")
	else:
		anim("stay")
	cel_a = 0 if super_invis else 100
	if cur_a > cel_a:
		cur_a -= 5
	if cur_a < cel_a:
		cur_a += 5
	u.anim.modulate.a = cur_a / 100.0
	if visshit != null and not is_shit and not visshit.is_playing():
		visshit.visible = false
