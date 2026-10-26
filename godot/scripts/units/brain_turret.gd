extends UnitBrain

## UnitTurret. States: 0 hidden, 1 sweeping, 2 about to fire, 3 firing, 4 lost the target.
## turret0/turret4 hang from the ceiling, turret1 stands, turret2/turret5 sit on a wall,
## turret3 is the armoured one with a front shield, turret5 cannot be hurt.

const ACT_DROT := 0.10

var turrettip := 0
var hidden := 0
var sleep := false
var reprog := false
var no_turn := false
var abs_vis := false
var watch_drot := 0.015
var period := 120
var a_rot: Array = []
var n_rot := 0
var cur: UnitGun
var puha: AnimatedSprite2D


func configure() -> void:
	turrettip = int(id.trim_prefix("turret")) if id.trim_prefix("turret").is_valid_int() else 0
	hidden = int(u.get_meta("hidden", 0))
	if tr <= 0:
		tr = randi_range(1, 3)
	flips_sprite = false
	u.set("fixed_post", true)
	u.set("_can_lift", hidden == 0)
	acts_held = true
	if turrettip == 5:
		abs_vis = true
	match turrettip:
		0, 4:
			weapon_dy = -12.0
		1:
			weapon_dy = -60.0
		2, 5:
			weapon_dy = -20.0
		3:
			weapon_dy = -55.0


func ready() -> void:
	cur = gun("turretWep%d" % tr)
	if cur == null:
		cur = gun("turretWep1")
	if turrettip == 0 or turrettip == 4:
		cur.fix_rot = 1
		a_rot = [30, 150]
		if turrettip == 4:
			period = 80
			watch_drot = 0.05
	elif turrettip == 1:
		a_rot = [-15, -165]
		watch_drot = 0.1
	elif turrettip == 2 or turrettip == 5:
		a_rot = [45, 135, -135, -45]
		u.set("_v_konus", PI * 0.5)
		match str(u.get_meta("angle", "")):
			"down":
				a_rot = [45, 135]
			"up":
				a_rot = [-45, -135]
			"left":
				a_rot = [135, -135]
			"right":
				a_rot = [45, -45]
	elif turrettip == 3:
		if storona >= 0.0:
			a_rot = [-15, 15]
			cur.fix_rot = 2
		else:
			a_rot = [-165, 165]
			cur.fix_rot = 3
		watch_drot = 0.01
		u.set("_v_konus", PI * 0.25)
		no_turn = true
		flips_sprite = true
	n_rot = randi() % a_rot.size()
	cur.rot = deg_to_rad(float(a_rot[n_rot]))
	cur.force_rot = cur.rot
	cur.find_cel = false
	ai_state = 1
	if hidden > 0:
		cur.rot = PI * 0.5
		cur.force_rot = cur.rot
		ai_state = 0
		if has_clip("hidden"):
			anim("hidden")
	puha = make_part("puha")
	if puha != null:
		puha.frame = clampi(tr - 1, 0, puha.sprite_frames.get_frame_count("all") - 1)


func v_angle() -> float:
	if no_turn:
		return 0.0 if storona >= 0.0 else PI
	return cur.rot if cur != null else super.v_angle()


func expl() -> void:
	new_part("metal", 4)
	new_part("miniexpl")


func forces() -> void:
	if bool(u.get("fixed_post")):
		vel = Vector2.ZERO
	else:
		super.forces()


func move_body() -> void:
	if not bool(u.get("fixed_post")):
		super.move_body()


func after_move(pushed: Vector2) -> void:
	if bool(u.get("fixed_post")):
		vel = Vector2.ZERO
	else:
		super.after_move(pushed)


## Unit.levit: a fixed unit held past levit_r 75 is torn off (otryv). The
## hanging and wall turrets spark, shut down and pay their xp there and then.
func otryv() -> void:
	if turrettip == 5:
		return
	if turrettip == 0 or turrettip == 2 or turrettip == 4:
		new_part("iskr_bul", 20)
		sleep = true
		ai_state = 0
		cur.find_cel = false
		var xp := int(u.get("points"))
		if xp > 0:
			Progression.add_kill_xp(xp)
		u.set("points", 0)
	u.set("fixed_post", false)


func on_damage(amount: float, type: String, bullet: Node, tt: bool) -> float:
	if turrettip == 5:
		return 0.0
	if turrettip == 3 and not tt:
		var armor := 25.0
		if bullet != null and is_instance_valid(bullet):
			var d: Variant = bullet.get("direction")
			if d is Vector2 and (d as Vector2).x * storona > 0.0:
				armor = 0.0
		else:
			var p := player_node()
			if p != null and (u.global_position.x - p.global_position.x) * storona > 25.0:
				armor = 0.0
		return amount - armor
	return super.on_damage(amount, type, bullet, tt)


func find_cel(over: bool = false) -> bool:
	if _sided():
		return _find_hostile()
	if abs_vis and not reprog and not sleep and player_node() != null:
		set_cel(player_node())
		return true
	return super.find_cel(over)


## On the player's side: reprogrammed (hack 1/2), or placed in the home stable
## (Location.createUnit homeStable gives fraction F_PLAYER and warn 0).
func _sided() -> bool:
	return bool(u.get("_friendly")) and (reprog or bool(u.get_meta("player_side", false)))


## UnitTurret.findCel when reprogrammed: the first unit of another fraction it can see.
## The player and pets are on its own side and never chosen.
func _find_hostile() -> bool:
	if float(u.get("_detect_delay")) > 0.0:
		return false
	if cel_unit != null and is_instance_valid(cel_unit) and cel_unit.is_in_group("enemies") and not bool(cel_unit.get("_dead")) and float(u.call("_look", cel_unit)) > 0.0:
		set_cel(cel_unit)
		return true
	for un in u.get_tree().get_nodes_in_group("enemies"):
		if un == u or not un is Node2D or bool(un.get("_dead")) or bool(un.get("_friendly")):
			continue
		if float(u.call("_look", un)) > 0.0:
			set_cel(un)
			return true
	cel_unit = null
	return false


func command(com: String, _val: String = "") -> void:
	match com:
		"shoot":
			cur.attack()
		"alarma":
			if not sleep:
				find_cel()
				ai_spok = max_spok + 10
				ai_state = 3
		"hack":
			hack(0)


func hack(sposob: int) -> void:
	if sposob == 0:
		sleep = true
		ai_state = 0
		cur.force_rot = PI * 0.5
		cur.find_cel = false
	else:
		reprog = true
		# sposob 1 (the security terminal) pays the unit's xp; it is spent either way.
		if sposob == 1 and not bool(u.get("_friendly")) and int(u.get("points")) > 0 and Progression.has_method("add_kill_xp"):
			Progression.add_kill_xp(int(u.get("points")))
		u.set("points", 0)
		u.set("_friendly", true)
		ai_state = 1
		ai_spok = 0
		cel_unit = null


func control() -> void:
	var fixed := bool(u.get("fixed_post"))
	if bool(u.get("levitated")) and fixed and float(u.get_meta("levit_r", 0.0)) > 75.0:
		otryv()
		fixed = false
	if (bool(u.get("levitated")) and not _sided()) or (not stay and not fixed and float(u.get("_detect_delay")) <= 0.0):
		if ai_state <= 1 and not sleep:
			ai_state = 3
	if not (enemy_act() or _sided()) or sleep:
		return
	if ai_tch > 0:
		ai_tch -= 1
	elif ai_state == 2:
		if cel_unit != null:
			ai_spok = max_spok + 10
			ai_state = 3
			budilo(750.0)
		else:
			ai_state = 1
	else:
		if ai_spok <= 0:
			if ai_state == 1 and hidden > 0:
				ai_state = 0
				cur.force_rot = PI * 0.5
			elif ai_state > 0:
				ai_state = 1
			if ai_state == 1:
				n_rot = (n_rot + 1) % a_rot.size()
				cur.force_rot = deg_to_rad(float(a_rot[n_rot]))
			ai_tch = period
		else:
			ai_tch = randi_range(40, 89)
		if ai_spok > 0:
			ai_state = 4
		if ai_spok >= max_spok:
			ai_state = 3
	if ai_tch % 10 == 1:
		if not stunned() and find_cel():
			if ai_state <= 1:
				ai_state = 2
				ai_tch = randi_range(30, 39)
			elif ai_state >= 3:
				ai_state = 3
		else:
			set_cel(null, cel + Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0)))
		_state_look()
	if ai_state == 3 and not stunned():
		cur.attack()
	if cel_unit != null and dam > 0.0 and float(u.get("_detect_delay")) <= 0.0:
		att_korp(cel_unit, 1.0)


func _state_look() -> void:
	if ai_state == 0:
		_face_gun()
		cur.find_cel = false
		u.set("_overlook", true)
		cur.drot = 0.5
		set_vision(0.0 if hidden == 2 else 0.35)
		u.set("dexter", 10.0)
		# isVis = isSats = false: off the cursor and SATS while folded away.
		u.set_meta("no_vis", true)
	elif ai_state == 1:
		_face_gun()
		cur.find_cel = false
		cur.drot = watch_drot
		u.set("_overlook", false)
		set_vision(1.0)
		u.set("dexter", 1.0)
		u.set_meta("no_vis", false)
	else:
		u.set("dexter", 1.0)
		u.set_meta("no_vis", false)
		if not no_turn:
			storona = 1.0 if cel.x - u.global_position.x > 0.0 else -1.0
		cur.find_cel = true
		cur.drot = watch_drot if ai_state == 4 else ACT_DROT
		u.set("_overlook", true)
		set_vision(1.0)


func _face_gun() -> void:
	if not no_turn:
		storona = 1.0 if cur.rot > -PI * 0.5 and cur.rot <= PI * 0.5 else -1.0


func animate() -> void:
	var clip := str(u.anim.animation)
	if clip == "stay":
		if ai_state == 0 and hidden > 0 and has_clip("hide"):
			anim("hide")
	elif clip == "hidden":
		if ai_state > 0:
			anim("open")
	elif not u.anim.is_playing():
		anim("hidden" if clip == "hide" else "stay")
	if puha != null:
		puha.visible = str(u.anim.animation) == "stay"
		puha.rotation = cur.rot
	# UnitTurret.animate: a fixed turret held by telekinesis shakes by up to 3 degrees.
	if bool(u.get("levitated")) and bool(u.get("fixed_post")):
		u.anim.rotation = deg_to_rad(randf() * 6.0 - 3.0)
	elif u.anim.rotation != 0.0:
		u.anim.rotation = 0.0
