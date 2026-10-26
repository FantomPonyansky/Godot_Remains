extends UnitBrain

## UnitPet: the phoenix and the robo owl out with the player (Pets autoload).
## States: 0 sits on a box, 1 follows, 2 attacks, 3 flies to an ordered point,
## 4 rams, 5 pulls away after a ram. Far from the player it is immaterial and
## flies through walls. Down (sost 4) it hides until Pets brings it back.

const RASST_GG := 200.0
const RASST_UNMAT := 400.0
const RASST_VIS_EN := 800.0
const RASST_OUT := 100.0
const DETECT := 60
const ROOM := Vector2(1920.0, 1000.0)
const VULNER := {
	"phoenix": {"DAM_BURN": 0.5, "DAM_PLASMA": 0.5, "DAM_LASER": 0.75, "DAM_EXPLOSION": 0.25},
	"owl": {"DAM_BURN": 0.5, "DAM_PIERCE": 0.75, "DAM_LASER": 0.75, "DAM_EXPLOSION": 0.25,
		"DAM_VENOM": 0.0, "DAM_POISON": 0.0, "DAM_DEATH": 0.2},
}

var rasst_weap := 200.0
var opt_en_w := true
var opt_sit := true
var opt_turn := true
var mater := false
var temp_unmat := false
var active := false
var down := false
var detection := 0
var fly := Vector2.ZERO
var fly_box: Node2D = null
var spd := Vector2.ZERO
var vulner_mult := 1.0
var cur: UnitGun
var _last_hp := -1


func configure() -> void:
	is_fly = true
	walk_speed = max_speed
	run_speed = max_speed * 2.0
	elast = 0.2
	ai_state = 1
	u.set("_flying", true)


func ready() -> void:
	rasst_weap = 400.0 if id == "owl" else 200.0
	u.add_to_group("pets")
	# The player layer: enemy bullets and blasts reach it, player shots do not.
	u.collision_layer = 2
	u.collision_mask = 0
	var res: Node = u.get_node_or_null("Resistances")
	if res != null:
		var mult: Dictionary = res.get("multipliers")
		var vul: Dictionary = VULNER.get(id, {})
		for k in vul.keys():
			mult[k] = float(vul[k])
		res.set("multipliers", mult)
	cur = gun(str(row.get("weapon", "")))
	set_level(true)
	var fresh := bool(u.get_meta("pet_call", false))
	if bool(Pets.down.get(id, true)):
		if Pets.autores(id):
			resurrect()
		else:
			call_up()
	else:
		active = true
		ai_state = 1
	if fresh:
		_fade_in()
	get_fly_point()


## UnitPet.setLevel: the stats follow the player's level, the hp share stays.
func set_level(from_store := false) -> void:
	var st := Pets.stats(id)
	var top := maxi(1, int(round(float(st.maxhp))))
	var koef := float(Pets.proc.get(id, 1.0)) if from_store else float(u.get("hp")) / maxf(1.0, float(u.get("max_hp")))
	u.set("max_hp", top)
	u.set("hp", int(round(koef * top)))
	dam = float(st.dam)
	u.set("_skin", float(st.skin))
	vulner_mult = float(st.vulner)
	if cur != null:
		cur.w = cur.w.duplicate()
		cur.w["damage"] = dam


## UnitPet.call for a pet that was not out (sost 4, no autores).
func call_up() -> void:
	if int(u.get("hp")) <= 0:
		_hide_down()
		return
	active = true
	down = false
	ai_state = 1
	Pets.down[id] = false
	_show()


## UnitPet.resurrect: half hp, at most 100, beside the player.
func resurrect() -> void:
	Pets._info(OriginalLines.info("petRes", Pets.pet_name(id)))
	set_level(true)
	var top := int(u.get("max_hp"))
	u.set("hp", int(round(minf(100.0, top * 0.5))))
	var p := player_node()
	if p != null:
		u.global_position = p.global_position + Vector2(0.0, -20.0)
	_fade_in()
	active = true
	down = false
	ai_state = 1
	Pets.down[id] = false
	Pets.note_hp(id, float(u.get("hp")), float(top))
	_show()
	Pets.refresh_hud()


## UnitPet.recall: sparks if it was showing.
func recall() -> void:
	active = false
	if u.visible and not down:
		Pets.note_hp(id, float(u.get("hp")), float(u.get("max_hp")))
		expl()
	down = true
	u.visible = false


func heal(hl: float) -> void:
	var top := int(u.get("max_hp"))
	u.set("hp", mini(top, int(u.get("hp")) + int(round(hl))))
	Pets.note_hp(id, float(u.get("hp")), float(top))
	Pets.refresh_hud()


## UnitPet.moveto: an order to fly somewhere (unmat: straight through walls).
func moveto(at: Vector2, unmat := false) -> void:
	if down or detection > 0:
		return
	temp_unmat = unmat
	fly_box = null
	fly = Vector2(at.x, at.y + 20.0)
	ai_state = 3
	if opt_turn:
		storona = 1.0 if fly.x > u.global_position.x else -1.0
	ai_tch = 100


## UnitPet.atk: an order to attack the unit under the cursor.
func atk(un: Node2D) -> void:
	temp_unmat = false
	if _vis_cel(un):
		set_cel(un)
		fly_box = null
		ai_state = 2


func on_damage(amount: float, type: String, bullet: Node, tt: bool) -> float:
	return super.on_damage(amount, type, bullet, tt) * vulner_mult


## UnitPet.die: the pet stays, hidden, until Pets revives it.
func on_die() -> bool:
	if not down:
		u.set("hp", 0)
		expl()
		_hide_down()
		Pets.pet_died(id)
	return true


func died() -> void:
	pass


func expl() -> void:
	new_part("orange_spark" if id == "owl" else "green_spark", 25)


func weapon_pos() -> Vector2:
	if id == "phoenix":
		return u.global_position + Vector2(15.0 * storona, -20.0)
	return u.global_position + Vector2(11.0 * storona, -18.0)


func move_body() -> void:
	u.collision_mask = 1 if mater else 0
	u.call("_commit_move")


func forces() -> void:
	if vel.length_squared() > max_speed * max_speed:
		vel *= 0.8
	if is_plav:
		vel *= 0.9
		if mater:
			vel.y += DDY * ddy_plav


func control() -> void:
	if detection > 0:
		detection -= 1
	if down or not active:
		vel = Vector2.ZERO
		return
	if not Pets.pet_on():
		u.visible = false
		vel = Vector2.ZERO
		return
	u.visible = true
	_track_hp()
	if stunned():
		return
	var gg := player_node()
	if gg == null:
		return
	var gpos := gg.global_position
	var rasst2 := u.global_position.distance_squared_to(gpos)
	if rasst2 < RASST_UNMAT * RASST_UNMAT or cel_unit != null:
		if not mater and ai_tch % 10 == 1 and not _in_wall():
			mater = true
	else:
		mater = false
	if temp_unmat:
		mater = false
	if ai_tch > 0:
		ai_tch -= 1
	else:
		temp_unmat = false
		if ai_state == 0 or ai_state == 1:
			if rasst2 > RASST_GG * RASST_GG or is_plav:
				ai_state = 1
				get_fly_point()
				if opt_turn:
					storona = 1.0 if fly.x > u.global_position.x else -1.0
			elif opt_turn:
				storona = -1.0 if fly.x > gpos.x else 1.0
		elif ai_state == 2:
			if rasst2 > RASST_GG * RASST_GG * 9.0:
				get_fly_point()
			if cel_unit == null:
				set_cel(null, cel + Vector2(randf() * 300.0 - 150.0, randf() * 120.0 - 60.0))
		elif ai_state == 4 or ai_state == 5:
			ai_state = 2
		elif ai_state == 3:
			ai_state = 2 if _battle() else 1
		var gvx := (gg as CharacterBody2D).velocity.x / TPS if gg is CharacterBody2D else 0.0
		ai_tch = randi_range(10, 29) if absf(gvx) > 2.0 else randi_range(30, 129)
	var fd := fly - u.global_position
	var fly_r := fd.length()
	if ai_state == 0:
		vel = Vector2.ZERO
		spd = Vector2.ZERO
		if fly_box != null and (not is_instance_valid(fly_box) or fly_box.get("resting") != true):
			ai_state = 1
			fly_box = null
	if ai_state == 2:
		if opt_turn:
			storona = 1.0 if cel.x > u.global_position.x else -1.0
		if fly_r > rasst_weap * 0.9 or not mater:
			spd = norma(fd, minf(accel * 2.0, accel * fly_r / 200.0))
		elif fly_r < RASST_OUT:
			spd = norma(Vector2(-fd.x, -fd.y / 2.0 - 3.0), accel)
		else:
			vel *= 0.85
			spd = Vector2.ZERO
		if turn_x != 0.0:
			vel.y += randf() * 8.0 - 4.0
			turn_x = 0.0
		if turn_y != 0.0:
			vel.x += randf() * 8.0 - 4.0
			turn_y = 0.0
	elif ai_state == 5:
		spd *= 0.95
		vel *= 0.9
	elif ai_state == 4:
		pass
	else:
		if fly_r < 20.0 and fly_box != null and mater:
			spd = Vector2.ZERO
			vel = fd
			ai_state = 0
		elif fly_r < 100.0 and mater:
			vel *= 0.95
			spd = Vector2.ZERO
		else:
			spd = norma(fd, minf(accel * 2.0, accel * fly_r / 200.0))
	vel += spd
	if cel_unit != null and (not is_instance_valid(cel_unit) or cel_unit.is_in_group("allies")):
		cel_unit = null
	if ai_state <= 1 and ai_tch % 30 == 1 and detection <= 0:
		if find_cel() or _battle():
			ai_state = 2
	if (ai_state == 2 or ai_state == 5) and ai_tch % 15 == 1:
		if _alive(cel_unit) and _vis_cel(cel_unit):
			pass
		elif find_cel():
			pass
		elif not _battle():
			ai_state = 1
	elif ai_state == 3:
		if fly_r < 20.0:
			ai_state = 2 if _battle() else 1
	if ai_state == 2 and fly_r < rasst_weap and cur == null and cel_unit != null:
		ai_state = 4
		ai_tch = 15
		spd = norma(center_of(cel_unit) - center(), run_speed)
	if ai_state == 4:
		if cel_unit != null:
			if att_korp(cel_unit):
				cel_unit.set("_prior", u)
				spd *= 0.5
				ai_state = 5
				ai_tch = 15
				u.call("_receive", dam * 0.02, "DAM_INTERNAL", null, true)
		else:
			ai_state = 2
	max_speed = walk_speed if ai_state <= 1 else run_speed
	if ai_state == 2 and cel_unit != null and not is_plav:
		cel = center_of(cel_unit)
		fly = cel_unit.global_position + Vector2(0.0, -80.0)
		if fly_r <= rasst_weap and cur != null:
			cur.attack()


## UnitPet.findCel: the nearest-listed foe in 800 that the gun can hurt and the pet can see.
func find_cel(_over: bool = false) -> bool:
	cel_unit = null
	var p := player_node()
	if p == null or p.get("invulnerable") == true:
		return false
	for node in u.get_tree().get_nodes_in_group("enemies"):
		var un := node as CharacterBody2D
		if un == null or not un.has_method("_resist") or not _alive(un) or un.get("_invis") == true or un.has_meta("noagro"):
			continue
		if str(un.get("_species_id")).contains("turret") and int(un.get("ai_state")) <= 1:
			continue
		if u.global_position.distance_squared_to(un.global_position) > RASST_VIS_EN * RASST_VIS_EN:
			continue
		if cur != null:
			var tipw := str(cur.w.get("damage_type", tip))
			var k := float(un.call("_resist", tipw))
			var armor := float(un.get("_marmor") if opt_en_w else un.get("_armor"))
			if dam * k < armor + float(un.get("_skin")) + 1.0 - float(cur.w.get("pier", 0.0)):
				continue
		if _vis_cel(un):
			set_cel(un)
			return true
	return false


func animate() -> void:
	if detection > 30:
		u.anim.modulate.a = 0.0
	elif detection > 0:
		u.anim.modulate.a = 1.0 - detection / 30.0
	else:
		u.anim.modulate.a = 1.0
	anim("stay" if ai_state == 0 else "fly")


## UnitPet.getFlyPoint: behind and above the player, or on a box there; out
## of a wall into the next open tile.
func get_fly_point() -> void:
	var gg := player_node()
	if gg == null:
		return
	var face := float(gg.get("facing")) if gg.get("facing") != null else 1.0
	if face == 0.0:
		face = 1.0
	var org := room_origin_of(gg.global_position)
	fly_box = null
	fly = gg.global_position + Vector2(face * -120.0, -80.0)
	fly.x = clampf(fly.x, org.x + 60.0, org.x + ROOM.x - 60.0)
	fly.y = clampf(fly.y, org.y + 80.0, org.y + ROOM.y - 40.0)
	if opt_sit:
		for b_v in u.get_tree().get_nodes_in_group("floor_box"):
			var b := b_v as Node2D
			if b == null or not b.has_method("crate_top") or b.get("resting") != true or not b.visible or b.get("held") == true:
				continue
			var top := float(b.call("crate_top"))
			if float(b.call("crate_left")) < fly.x and float(b.call("crate_right")) > fly.x and fly.y - top < 80.0 and fly.y - top > -40.0:
				fly = Vector2(float(b.call("crate_center_x")), top)
				fly_box = b
				break
	if not _blocked(fly):
		return
	fly = Vector2(floor(fly.x / TILE) * TILE + 20.0, floor(fly.y / TILE) * TILE + 39.0)
	if not solid_at(fly):
		return
	fly += Vector2(TILE * face, TILE)
	if not solid_at(fly):
		return
	fly.y += TILE
	if not solid_at(fly):
		return
	fly.x += TILE * face
	if not solid_at(fly):
		return
	fly = gg.global_position + Vector2(0.0, -1.0)


func room_origin_of(at: Vector2) -> Vector2:
	return Vector2(floor(at.x / ROOM.x) * ROOM.x, floor(at.y / ROOM.y) * ROOM.y)


func _vis_cel(un: Node2D) -> bool:
	if un == null or not is_instance_valid(un):
		return false
	return Sight.los_clear(u.global_position + Vector2(0.0, -30.0), center_of(un), un)


func _alive(un: Node2D) -> bool:
	return un != null and is_instance_valid(un) and un.get("hp") is int and int(un.get("hp")) > 0 and un.get("_dead") != true and un.get("_downed") != true


## GameContainer.t_battle: some foe is on the player.
func _battle() -> bool:
	for node in u.get_tree().get_nodes_in_group("enemies"):
		if node.get("_track_player") == true:
			return true
	return false


## loc.collisionUnit at the pet's box.
func _blocked(feet_at: Vector2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = body()
	q.shape = shape
	q.transform = Transform2D(0.0, feet_at + Vector2(0.0, -body().y * 0.5))
	q.collision_mask = 1
	q.exclude = [u.get_rid()]
	return not u.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func _in_wall() -> bool:
	return _blocked(u.global_position)


func _fade_in() -> void:
	detection = DETECT
	u.set("_detect_delay", 0.0)


func _show() -> void:
	u.visible = true
	u.collision_layer = 2


func _hide_down() -> void:
	active = false
	down = true
	u.visible = false
	u.collision_layer = 0
	vel = Vector2.ZERO
	Pets.down[id] = true


func _track_hp() -> void:
	var hp := int(u.get("hp"))
	if hp == _last_hp:
		return
	_last_hp = hp
	Pets.note_hp(id, float(hp), float(u.get("max_hp")))
	Pets.refresh_hud()
