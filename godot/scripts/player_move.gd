extends RefCounted

## Walk, jump, climb, swim, sky, sit, ladders and the rat body.
## p is the player body. Water stays player_water.gd. Tick order stays in player.gd.

const _Body := preload("res://scripts/player.gd")

var p: _Body

func _init(host: _Body) -> void:
	p = host

var facing: float = 1.0

## ggControl false (UnitPlayer.controlOff): no keys, invulner, the body still falls.
var control_off: bool = false

var _climbing: bool = false

var _levitating: bool = false

var _jumpp: int = 0

var _jump_count: int = 0

var _djump: bool = false

## dJump2: the air-jump boost ran this step.
var _djump2 := false

var _air_kicked: bool = false

var _did_jump: bool = false

var _drop_timer: int = 0

var _ladder_count: int = 0

var _ladder_lockout: bool = false

var _ladder_areas: Array[Area2D] = []

var _pose: String = "idle"

var _step_phase: int = 0

var _run_down: bool = false

var _run_held_for: int = 0

var _run_for_kick: bool = false

# isSit latch, downp (in seconds), last tick's walk and maxSpeed for forces(), t_run.
var _sit: bool = false

var _down_for: int = 0

var _walk_dir: int = 0

var _max_speed: float = 210.0

var _t_run: int = 0

var _kdash_left: int = 0

## UnitPlayer dash_t (ticks).
var _dash_t: int = 0

var _pinok: float = 0.0

var _jump_cut: bool = false

# Sign of diagon.X (the way the stair rises), 0 off stairs.
var _diagon: int = 0

var _gait: String = "idle"

## Location.sky (Land.ativateLoc): isFly, stay = false, no gravity. Set by sky_arena.gd.
var sky_mode := false: set = set_sky_mode

var _sky_t := 0.0

## UnitPlayer.isFly outside sky rooms: pers.ableFly, toggled by a jump in the air.
var _is_fly := false

## UnitPlayer.rat (potion_rat): a 30x17 body, vis.rat instead of vis.osn.
var rat := false

var _rat_vis: AnimatedSprite2D = null

func _physics_jumps(delta: float, move_x: float, on_ladder: bool, jump_held: bool, jump_just: bool, down: bool, up: bool) -> Dictionary:
	var was_on_floor := p.is_on_floor()
	_tick_pinok(delta, was_on_floor)
	if _ladder_count == 0:
		_ladder_lockout = false
	var fly_ok := GameState.can_fly() and p._Flags.allows("levit") and not rat
	if _is_fly and not fly_ok:
		_is_fly = false
	# keyJump in the air (or off a ladder) with pers.ableFly and loc.levitOn flips isFly.
	if jump_just and fly_ok and not sky_mode and not p._water.is_plav and (_climbing or (not p.is_on_floor() and _jump_count >= 1)):
		_is_fly = not _is_fly
		_sky_t = 0.0
		_climbing = false
		_levitating = false
		_jump_cut = true
		jump_held = false
		jump_just = false
	# throu = (keyJump || !stay) && keySit. On a one-way (stayPhis == 2) that
	# zeros jumpp, so down+jump falls through. On a ladder, keyJump && !keyBeUp
	# lets go. Down keeps jumpp at 0, so that jump drops off. A plain jump
	# still hops off when left or right is held, and falls off otherwise.
	# Holding up keeps the climb.
	var drop_off := down and jump_just and (_climbing or (p.is_on_floor() and _on_one_way()))
	if jump_just and not drop_off and (p.is_on_floor() or _climbing):
		GameState.spend_jump_stamina()
		if p.is_on_floor():
			Stash.jumped()
	if drop_off:
		_jumpp = 0
		_djump = false
		_air_kicked = false
		_did_jump = false
		_jump_count = 0
		_levitating = false
		if _climbing or on_ladder:
			_ladder_lockout = true
		_climbing = false
		p.floor_snap_length = 0.0
		_start_drop_through()
		jump_just = false
	elif _climbing and jump_just and not up:
		_ladder_lockout = true
		_climbing = false
		_levitating = false
		p.floor_snap_length = 0.0
		if absf(move_x) > 0.2:
			p.velocity.y = _jump_velocity()
			_jump_count = 1
			_did_jump = true
			_jumpp = p._hold_ticks(p.JUMP_SUSTAIN)
			_djump = false
		else:
			_jumpp = 0
			_did_jump = false
			_jump_count = 0
			p.velocity.y = maxf(p.velocity.y, 0.0)
		jump_just = false
	return {"was_on_floor": was_on_floor, "jump_held": jump_held, "jump_just": jump_just}

func _physics_climb(delta: float, on_ladder: bool, move_x: float, move_y: float, jump_just: bool, up: bool) -> void:
	var ladder := _ladder_under_feet()
	var climb := on_ladder and not _ladder_lockout and not rat and not _is_fly and (absf(move_y) > 0.25 or _climbing)
	if jump_just and not up:
		climb = false
	if climb and not _climbing:
		# Grabbing on keyBeUp needs pinok < 30. Down on the ground grabs only
		# when checkStairs(2) finds the ladder below the feet.
		if _pinok >= 30.0:
			climb = false
		elif move_y > 0.25 and p.is_on_floor() and (ladder == null or _rail_bottom(ladder) <= p.global_position.y + 2.0):
			climb = false
	# checkStairs(-1) reads the tile at the feet. Once those feet reach the top
	# of the rail, that tile is not a ladder, so up lets go. The lip is that edge.
	if climb and ladder != null and move_y < -0.25 and _reaching_rail_top(ladder, delta, move_y):
		if _climbing:
			_stand_on_rail(ladder)
		climb = false
	# Feet on the floor at the bottom of the rail: left or right walks away.
	if climb and _climbing and p.is_on_floor() and absf(move_x) > 0.2 and absf(move_y) <= 0.25:
		climb = false
	if climb:
		if not _climbing and ladder != null:
			_snap_to_rail(ladder)
		_climbing = true
		_levitating = false
		_jumpp = 0
		_djump = false
		_air_kicked = false
		_set_sit(false)
		_walk_dir = 0
		_t_run = 0
		# Ladder tops are one-way lips. Snapping to them, or keeping them solid,
		# wedges the 50px body in the 40px slot beside the lip.
		p.floor_snap_length = 0.0
		p.set_collision_mask_value(p.PLATFORM_LAYER_BIT, false)
		if ladder != null:
			# storona = ladderSide, and vis.scaleX = storona.X. Left is -1.
			facing = _ladder_facing(ladder)
		var move_scale := GameState.move_speed_mult()
		# Unit.checkStairs pins X to the ladder tile's edge; left/right only matter for a jump off.
		p.velocity.x = 0.0
		if ladder != null and _climbing:
			_snap_to_rail(ladder)
		var climb_mult := p.CLIMB_DOWN_MULT if move_y > 0.0 else 1.0
		p.velocity.y = move_y * p.CLIMB_SPEED * climb_mult * move_scale
		_jump_count = 0
		_did_jump = false
	else:
		_climbing = false

func _physics_traverse(delta: float, move_x: float, key_left: bool, key_right: bool, jump_held: bool, jump_just: bool, down: bool, up: bool) -> void:
	# storona follows the keys, then stays until the next step. The cursor does not turn the body.
	if not _climbing and absf(move_x) > 0.2:
		facing = signf(move_x)

	if not _climbing:
		_tick_sit(down, up, delta)
		# Jumping while sitting calls unsit() first. Under a low ceiling it stays down and does not jump.
		if _sit and jump_held:
			_try_unsit()
			if _sit:
				jump_held = false
				jump_just = false

	# Airborne keySit keeps throu set, so a held down passes later one-ways too.
	# kdash_t > 3 and pinok > 70 also set throu.
	var fall_through := (down and not p.is_on_floor() and not _climbing) or _pinok > 70.0 or _kdash_left > 3
	if fall_through:
		p.set_collision_mask_value(p.PLATFORM_LAYER_BIT, false)
	elif _drop_timer <= 0.0 and not _climbing:
		p.set_collision_mask_value(p.PLATFORM_LAYER_BIT, true)

	p._water.check(p, p.CROUCH_SIZE.y if _sit else p.BODY_SIZE.y)
	p._water.tick(p, delta)
	if sky_mode or _is_fly:
		_sky_step(delta, key_left, key_right, up, down)
	elif p._water.is_plav and not _climbing:
		_swim_step(delta, jump_held or up, down, key_left, key_right)
	elif not _climbing:
		_step_jump(delta, jump_held, jump_just, move_x, key_left, key_right)
		p._water.wade(p, delta)
		if not _levitating and p._water.lift(p, delta, p.CROUCH_SIZE.y if _sit else p.BODY_SIZE.y):
			p.floor_snap_length = 0.0
	if _drop_timer > 0.0 and _jumpp <= 0.0:
		p.floor_snap_length = 0.0

## UnitPlayer.controlOff: ctr.clearAll, dropTeleObj, isRun false, walk 0.
func set_control_off(off: bool) -> void:
	control_off = off
	if off:
		_run_down = false
		_walk_dir = 0
		_t_run = 0

## A tick with no keys held: gravity, water and the pose go on.
func _control_off_step(delta: float) -> void:
	p._spells._tick_slow(delta)
	p._spells._tick_spell_state(delta)
	p._weapons_c._tick_weapon_change(delta)
	if p._tele_obj != null and control_off:
		p._drop_tele()
	var was_on_floor := p.is_on_floor()
	_tick_pinok(delta, was_on_floor)
	p._water.check(p, p.CROUCH_SIZE.y if _sit else p.BODY_SIZE.y)
	p._water.tick(p, delta)
	if _climbing:
		p.velocity = Vector2.ZERO
	elif sky_mode or _is_fly:
		_sky_step(delta, false, false, false, false)
	elif p._water.is_plav:
		_swim_step(delta, false, false, false, false)
	else:
		_step_jump(delta, false, false, 0.0, false, false)
		p._water.wade(p, delta)
	var fall_vy := p.velocity.y
	p.move_and_slide()
	_landed(was_on_floor, fall_vy)
	_djump2 = false
	p._spells._tick_levit_glow(delta)
	_pose = _pick_pose()
	_apply_body_box(_sit)
	_footsteps(delta)
	if p.puppet.has_method("update_pose") and not p._WorkAnim.owns(p):
		p.puppet.update_pose(_pose, facing, p.aim_dir, delta)
	if rat:
		_pose_rat()

## UnitPlayer.ratOn (potion_rat).
func rat_on() -> void:
	p._weapons_c.holster()
	_set_sit(false)
	_climbing = false
	_levitating = false
	_is_fly = false
	p._drop_tele()
	p._clear_use()
	rat = true
	_apply_body_box(false)
	_pose_rat()

## UnitPlayer.ratOff: the standing box must fit here, 15px right or 15px left.
## False keeps the rat (Effect then holds potion_rat a second longer).
func rat_off() -> bool:
	if not rat:
		return true
	var spot := p.global_position
	var fits := false
	for dx in [0.0, 15.0, -15.0]:
		if _stand_fits(spot + Vector2(dx, 0.0)):
			p.global_position = spot + Vector2(dx, 0.0)
			fits = true
			break
	if not fits:
		return false
	rat = false
	_apply_body_box(false)
	p.puppet.visible = true
	if _rat_vis != null:
		_rat_vis.visible = false
	Fx.particles("black", p.global_position + Vector2(0, -39), {"kol": 30, "source": p})
	return true

func _stand_fits(at: Vector2) -> bool:
	var space := p.get_world_2d().direct_space_state
	if space == null:
		return true
	var query := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = p.BODY_SIZE - Vector2(2.0, 2.0)
	query.shape = rect
	query.transform = Transform2D(0.0, at + Vector2(0.0, -p.BODY_SIZE.y * 0.5 - 1.0))
	query.collision_mask = 1
	query.exclude = [p.get_rid()]
	for found in space.intersect_shape(query, 4):
		var node := found.collider as Node
		if node == null or node == p or p._spells._is_one_way(node):
			continue
		if node is CollisionObject2D and ((node as CollisionObject2D).collision_layer & 1) == 0:
			continue
		return false
	return true

## vis.rat: the rat sheet (units.xml rat, 70x30 cells; stay 0, walk/run 1-9, jump 10).
func _pose_rat() -> void:
	if _rat_vis == null:
		_rat_vis = AnimatedSprite2D.new()
		var tex := load("res://assets/sprites/sheets/rat.png") as Texture2D
		if tex != null:
			var steps := SheetFrames.row_clip(0, 9, 1)
			_rat_vis.sprite_frames = SheetFrames.build(tex, 70, 30,
				{"stay": [Vector2i(0, 0)], "walk": steps, "run": steps, "plav": steps, "jump": [Vector2i(10, 0)]},
				{"walk": 15.0, "run": 30.0, "plav": 7.5},
				{"stay": false, "jump": false})
		_rat_vis.offset = Vector2(-8.0, -12.0)
		p.add_child(_rat_vis)
	p.puppet.visible = false
	_rat_vis.visible = true
	_rat_vis.flip_h = facing < 0.0
	if _rat_vis.sprite_frames == null:
		return
	var clip := "stay"
	if p._water.is_plav:
		clip = "plav"
	elif not p.is_on_floor():
		clip = "jump"
	elif absf(p.velocity.x) > 30.0:
		clip = "run" if absf(p.velocity.x) > p.SPEED * 1.1 else "walk"
	if _rat_vis.animation != clip or not _rat_vis.is_playing():
		_rat_vis.play(clip)

func _start_drop_through() -> void:
	_drop_timer = p._hold_ticks(p.DROP_TIME)
	p.set_collision_mask_value(p.PLATFORM_LAYER_BIT, false)
	p.global_position.y += 4.0
	p.velocity.y = maxf(p.velocity.y, 80.0)

func _on_one_way() -> bool:
	# stayPhis == 2 only when a platform is under the body and no solid is.
	# A rest pose often has no slide contacts, so this probes the feet.
	var space := p.get_world_2d().direct_space_state
	if space == null:
		return false
	var platform_mask := 1 << (p.PLATFORM_LAYER_BIT - 1)
	var platform := false
	var solid := false
	for dx in [-20.0, 0.0, 20.0]:
		var from := p.global_position + Vector2(dx, -6.0)
		var to := p.global_position + Vector2(dx, 8.0)
		var down_ray := PhysicsRayQueryParameters2D.create(from, to, platform_mask)
		down_ray.exclude = [p.get_rid()]
		if not space.intersect_ray(down_ray).is_empty():
			platform = true
		var ground := PhysicsRayQueryParameters2D.create(from, to, 1)
		ground.exclude = [p.get_rid()]
		if not space.intersect_ray(ground).is_empty():
			solid = true
	return platform and not solid

func _poll_run(delta: float) -> void:
	# UnitPlayer isRun = keyRun: runs only while held, on the pad too.
	# A press that was part of a kick chord does not run.
	var held := InputMap.has_action("sprint") and LocalInput.held(&"sprint", p.pid)
	if held:
		if not _run_down:
			_run_held_for = 0
			# Melee already down: this press is the strong kick, not a run.
			_run_for_kick = LocalInput.held(&"melee", p.pid)
		_run_held_for += Sim.frame_steps
		_run_down = true
	elif _run_down:
		_run_down = false
		_run_held_for = 0
		_run_for_kick = false

func _run_chord_down() -> bool:
	return _run_down and not _run_for_kick

func _run_wants() -> bool:
	if not GameState.sprint_allowed():
		return false
	return _run_chord_down()

func _ground_sprint() -> bool:
	# isRun sets runSpeed only while stay and not sitting.
	if not _run_wants():
		return false
	if _climbing or _levitating or not p.is_on_floor():
		return false
	if _sitting_on_ground() or _diagon != 0:
		return false
	return true

func _note_run_stamina() -> void:
	# UnitPlayer drains stamRun * dstam only while moving on the ground.
	GameState.set_running(_ground_sprint() and absf(p.velocity.x) > 1.0)

func _footsteps(_delta: float) -> void:
	# UnitPon.sndStep. t_walk advances one tick at 30 Hz and only those frames
	# play. Stopping does not zero the phase, so a floor flicker cannot retrigger.
	var tip := _step_tip()
	if tip == 0:
		return
	for _i in mini(Sim.frame_steps, 3):
		_emit_step(tip, _step_phase)
		_step_phase += 1

func _step_tip() -> int:
	if _climbing:
		return 3 if absf(p.velocity.y) > 8.0 else 0
	if not p.is_on_floor() or _levitating or _sit:
		return 0
	# animate() calls sndStep from the gait branch it picked this tick:
	# walk (maxSpeed < 5) is tip 4, run is tip 2, trot and stairs are tip 1.
	match _gait:
		"walk":
			return 4
		"sprint":
			return 2
		"run", "stairs_up", "stairs_down":
			return 1
	return 0

func _emit_step(tip: int, phase: int) -> void:
	var leg := 0
	var step_vol := UiSettings.step_volume()
	var volume := p.FOOT_VOL * step_vol
	if tip == 1:
		match phase % 16:
			5:
				leg = 1
			7:
				leg = 4
			13:
				leg = 2
			15:
				leg = 3
	elif tip == 2:
		match phase % 8:
			1:
				leg = 4
			2:
				leg = 1
			5:
				leg = 2
			6:
				leg = 3
	elif tip == 3:
		volume = p.FOOT_VOL * 2.0 * step_vol
		match phase % 14:
			4:
				leg = 4
			6:
				leg = 1
			10:
				leg = 2
			12:
				leg = 3
	else:
		match phase % 24:
			4:
				leg = 4
			9:
				leg = 1
			16:
				leg = 2
			21:
				leg = 3
	if leg == 0:
		return
	Fx.sound("lazstep%d" % leg if tip == 3 else _step_clip(leg), p.global_position, {"volume": volume, "source": p})

## UnitPon.sndStep / sndFall: metalstep on a metal floor (stayMat), else footstep;
## the 'a' take half the time (isrnd).
func _step_clip(leg: int) -> String:
	var base := "footstep"
	for i in p.get_slide_collision_count():
		var c := p.get_slide_collision(i)
		if c.get_normal().y < -0.7:
			if p._ImpactFx.surface_of(c.get_collider()) == p._ImpactFx.METAL:
				base = "metalstep"
			break
	return "%s%d%s" % [base, leg, "a" if Rng.randf(&"fx") < 0.5 else ""]

func _sitting_on_ground() -> bool:
	if _climbing or _levitating or not p.is_on_floor():
		return false
	return _sit

func _set_sit(on: bool) -> void:
	if _sit == on:
		return
	_sit = on
	_apply_body_box(on)

func _try_unsit() -> void:
	# unsit() stands, then sits again if the standing box hits a ceiling.
	if _sit and not _ceiling_blocks_stand():
		_set_sit(false)

func _tick_sit(down: bool, up: bool, delta: float) -> void:
	# keySit sits on the tick downp == 1 on solid ground, or downp == 5 on a
	# platform (stayPhis 2), and never on a stair. The sit then holds until
	# keyBeUp without keySit, or until the feet leave the ground.
	if rat:
		return
	var on_floor := p.is_on_floor()
	if down:
		if on_floor and not _sit and not _levitating and _diagon == 0 and _kdash_left <= 0.0:
			var downp := _down_for
			var one_way := _on_one_way()
			if (not one_way and downp == 1) or (one_way and downp == 5):
				_set_sit(true)
		_down_for = mini(_down_for + Sim.frame_steps, 6)
	else:
		_down_for = 0
	if _sit and up and not down:
		_try_unsit()
		if not _sit:
			p._melee_c._up_for = 10
	if _sit and not on_floor:
		_try_unsit()
	# A low ceiling never lets the standing box in. Keep it down there.
	if not _sit and on_floor and _ceiling_blocks_stand():
		_set_sit(true)

func _ceiling_blocks_stand() -> bool:
	var space := p.get_world_2d().direct_space_state
	if space == null:
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	var band_h := p.BODY_SIZE.y - p.CROUCH_SIZE.y - 2.0
	rect.size = Vector2(p.BODY_SIZE.x - 4.0, band_h)
	query.shape = rect
	var center_y := -(p.CROUCH_SIZE.y + 1.0 + band_h * 0.5)
	query.transform = Transform2D(0.0, p.global_position + Vector2(0.0, center_y))
	# Layer 1 solids only. Floor crates are one-way shelves on layer 64.
	# Walking beside or onto them is not a low ceiling. A 40px hatch is.
	query.collision_mask = 1
	query.exclude = [p.get_rid()]
	for found in space.intersect_shape(query, 4):
		var node := found.collider as Node
		if node == null or node == p or p._spells._is_one_way(node):
			continue
		if node is CollisionObject2D and ((node as CollisionObject2D).collision_layer & 1) == 0:
			continue
		return true
	return false

func _pick_pose() -> String:
	if _climbing:
		_gait = ""
		return "climb"
	if p._water.is_plav:
		_gait = ""
		return "swim"
	if _levitating:
		_gait = ""
		return "levitate"
	if not p.is_on_floor() or _kdash_left > 0.0:
		_gait = ""
		# aJump > 0 keeps vis.osn "jump" for the whole flight. Walking off a ledge plays pinok.
		return "jump" if _did_jump else "fall"
	if p._senses._lurked or p._senses._lurk_work == "lurk":
		_gait = ""
		return "lurk%d" % clampi(p._senses._lurk_tip, 1, 3)
	if p._senses._lurk_work == "unlurk":
		_gait = ""
		return "unlurk%d" % clampi(p._senses._lurk_tip, 1, 3)
	if _sit:
		_gait = ""
		return "crouch"
	_gait = _pick_gait()
	return _gait

func _pick_gait() -> String:
	# animatePlayerMovement on the ground, from velocity and maxSpeed, not the stick.
	var vx := p.velocity.x
	if _diagon == 0:
		if (absf(vx) <= 30.0 and _walk_dir != 0) or (absf(vx) <= 120.0 and _walk_dir == 0):
			return "idle"
	elif absf(vx) < 1.0:
		return "stairs_up_still" if float(_diagon) * facing > 0.0 else "stairs_down_still"
	if _diagon != 0:
		return "stairs_up" if float(_diagon) * facing > 0.0 else "stairs_down"
	if _max_speed < 150.0:
		return "walk"
	var walk_speed := p.SPEED * GameState.move_speed_mult()
	if _max_speed > walk_speed * 1.6 and vx * facing > 0.0 and _run_wants() and _walk_dir != 0:
		return "sprint"
	if vx * facing > 0.0:
		return "run"
	# Sliding against storona leaves animState as it was.
	if _gait in ["walk", "run", "sprint", "idle"]:
		return _gait
	return "run"

func _update_diagon() -> void:
	# diagon.X is the way the stair rises. A 45 degree floor normal leans the other way.
	_diagon = 0
	if _climbing or not p.is_on_floor():
		return
	var n := p.get_floor_normal()
	if absf(n.x) > 0.2:
		_diagon = -1 if n.x > 0.0 else 1

func _apply_body_box(crouch: bool) -> void:
	var size := p.RAT_SIZE if rat else (p.CROUCH_SIZE if crouch else p.BODY_SIZE)
	var full := size
	if _climbing:
		size.x = minf(size.x, p.CLIMB_BOX_W)
	var box := p._body_shape.shape as RectangleShape2D
	if box == null or box.size == size:
		return
	if box.size.x < size.x and not _climbing:
		# Off a ladder beside a wall: step clear, or stay narrow until there is room.
		var dx := _widen_offset(size)
		if is_nan(dx):
			size.x = box.size.x
			if box.size == size:
				return
		else:
			p.global_position.x += dx
	box.size = size
	p._body_shape.position = Vector2(0, -size.y * 0.5)
	var hurt := p._hurt_shape.shape as RectangleShape2D
	if hurt:
		hurt.size = full + Vector2(4, 4)
		p._hurt_shape.position = Vector2(0, -full.y * 0.5)
	var ladder := p._ladder_shape.shape as RectangleShape2D
	if ladder:
		ladder.size = Vector2(40, size.y)
		p._ladder_shape.position = Vector2(0, -size.y * 0.5)

## X shift that lets a box of size stand here without touching a wall, or NAN.
func _widen_offset(size: Vector2) -> float:
	var box := p._body_shape.shape as RectangleShape2D
	var spare := (size.x - (box.size.x if box != null else size.x)) * 0.5
	for dx in [0.0, spare, -spare]:
		if _box_fits(p.global_position + Vector2(dx, 0.0), size):
			return dx
	return NAN

func _box_fits(at: Vector2, size: Vector2) -> bool:
	var space := p.get_world_2d().direct_space_state
	if space == null:
		return true
	var query := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size - Vector2(2.0, 2.0)
	query.shape = rect
	query.transform = Transform2D(0.0, at + Vector2(0.0, -size.y * 0.5))
	query.collision_mask = 1
	query.exclude = [p.get_rid()]
	for found in space.intersect_shape(query, 4):
		var node := found.collider as Node
		if node == null or node == p or p._spells._is_one_way(node):
			continue
		if node is CollisionObject2D and ((node as CollisionObject2D).collision_layer & 1) == 0:
			continue
		return false
	return true

func _swim_step(delta: float, up: bool, down: bool, key_left: bool, key_right: bool) -> void:
	# Unit.checkWater: isPlav clears stay and unsits. throu stays set while swimming.
	_set_sit(false)
	_levitating = false
	_djump = false
	_did_jump = false
	_jumpp = p._hold_ticks(p._Water.JUMP_RECHARGE)
	_jump_count = 1
	_t_run = 0
	p.floor_snap_length = 0.0
	p.set_collision_mask_value(p.PLATFORM_LAYER_BIT, false)
	_max_speed = p._Water.PLAV_SPEED
	_walk_dir = p._water.swim(p, delta, up, down, key_left, key_right, GameState.move_speed_mult())

func set_sky_mode(on: bool) -> void:
	sky_mode = on
	if on and p.is_node_ready():
		_climbing = false
		_levitating = false
		_set_sit(false)
		p.floor_snap_length = 0.0

## Unit.forces and UnitPlayer.control with isFly in a sky room: maxSpeed is
## walkSpeed * 3 * 1.3 and accel1 is 0.5 * accel; keyBeUp / keySit add levidy
## (accel * 0.25, alicorn 0.5). The alicorn holding keyRun with mana over 20
## takes full accel up to runSpeed * alicornFlyMult * 2 and pays
## alicornRunMana a tick. Over maxSpeed the velocity is cut by 0.7 a tick, and
## an axis under brake (2 px/tick) stops. Nothing else slows the flight.
## Steps whole 30 Hz ticks: the brake snap is larger than one tick of accel1.
func _sky_step(_delta: float, key_left: bool, key_right: bool, up: bool, down: bool) -> void:
	var max_speed := p.SPEED * GameState.move_speed_mult() * 1.3
	var accel := p.ACCEL * 0.5
	var alicorn := ScriptsEngine != null and ScriptsEngine.alicorn
	var levidy := p.ACCEL * (0.5 if alicorn else 0.25)
	if alicorn and LocalInput.held(&"sprint", p.pid) and GameState.magic > 20.0:
		accel = p.ACCEL
		max_speed = p.RUN_SPEED * GameState.move_speed_mult() * Progression.pers("alicornFlyMult", 1.0) * 2.0
		if key_left or key_right or up:
			GameState.channel(Progression.pers("alicornRunMana", 5.0), false)
	var walk := 0
	if key_left and not key_right:
		walk = -1
	elif key_right and not key_left:
		walk = 1
	var tick := 1.0 / 30.0
	var damp := 0.96 if LocalInput.held(&"sprint", p.pid) else 0.9
	for _step_i in Sim.frame_steps:
		var v := p.velocity * tick
		var ms := max_speed * tick
		v *= damp
		_sky_t += 0.1
		v.y += sin(_sky_t) / 5.0
		if v.length_squared() > ms * ms:
			v *= 0.7
		if walk != 0 and v.x * walk < ms:
			v.x = walk * minf(v.x * walk + accel * tick * tick, ms)
		if up:
			v.y -= levidy * tick * tick
		if down:
			v.y += levidy * tick * tick
		p.velocity = v / tick
	_walk_dir = walk
	_max_speed = max_speed
	_t_run = 0
	_jump_count = 1
	p.floor_snap_length = 0.0

## UnitPlayer jerk to the side: keyDash toward storona. The port triggers it by
## sprint pressed twice (PadGestures) instead of a direction double tap with
## keyRun held. Only standing, not sitting, dash_t spent, stam > 200, no
## overload, not the rat.
func _dash_step(_delta: float, _key_left: bool, _key_right: bool, on_floor: bool) -> bool:
	_dash_t = maxi(0, _dash_t - Sim.frame_steps)
	if not (InputMap.has_action("dash") and LocalInput.just_pressed(&"dash", p.pid)):
		return false
	var dir := 1 if facing >= 0.0 else -1
	if not on_floor or _sit or _dash_t > 0.0 or GameState.stam <= 200.0 or Inventory.overload_max_speed() < 100.0 or rat:
		return false
	if dir > 0:
		p.velocity.x = maxf(p.velocity.x, p.DASH_SPEED)
	else:
		p.velocity.x = minf(p.velocity.x, -p.DASH_SPEED)
	p.velocity.y += p.DASH_DY
	_dash_t = int(p.DASH_MAXT)
	_jump_count = 2
	_djump = false
	_jumpp = 0
	p.floor_snap_length = 0.0
	GameState.spend_dash_stamina()
	return true

func _step_jump(delta: float, jump_held: bool, jump_just: bool, move_x: float, key_left: bool, key_right: bool) -> void:
	# kdash_t keeps stay false, skips gravity and braking until its last tick.
	_djump2 = false
	var dashing := _kdash_left > 0.0
	var on_floor := p.is_on_floor() and not dashing
	if _dash_step(delta, key_left, key_right, on_floor):
		on_floor = false
		jump_held = false
		jump_just = false
	# trauma_mana stage 4 clears isDJ.
	# Location.levitOn (@levitoff) takes the double jump and self-levitation.
	var levit_on := p._Flags.allows("levit")
	var has_dj := p._owns_perk("levitation") and GameState.spells_allowed() and levit_on
	var has_hover := p._owns_perk("selflevit") and levit_on
	if on_floor and not jump_held:
		_jumpp = p._hold_ticks(p.JUMP_SUSTAIN)
		_djump = false
		_air_kicked = false
		_jump_count = 0
		_did_jump = false
	elif not on_floor and not jump_held and has_dj and _jump_count <= 1:
		_jumpp = p._hold_ticks(p.AIR_JUMP_HOLD)
		_djump = true
		_air_kicked = false
	elif not jump_held and _jump_count == 0:
		_jump_count = 1

	if jump_just:
		_jump_count += 1

	if not on_floor and jump_held:
		_jumpp = p._spend(_jumpp)
	if not on_floor and not jump_held and not (has_dj and _jump_count <= 1):
		_jumpp = 0

	var hover_after := 2 if has_dj else 1
	if jump_held and has_hover and GameState.hover_allowed() and not on_floor and _jumpp <= 0.0 and _jump_count > hover_after:
		_levitating = true
	elif not jump_held or on_floor:
		_levitating = false

	var kicked := false
	if _levitating and jump_held and not on_floor:
		p.floor_snap_length = 0.0
		var lift := LocalInput.axis(&"aim_up", &"aim_down", p.pid)
		p.velocity.y = move_toward(p.velocity.y, lift * p.LEVITATE_SPEED, 900.0 * delta)
	elif jump_held and _jumpp > 0.0 and not (_djump and (on_floor or not has_dj)):
		p.floor_snap_length = 0.0 if not on_floor else 1.0
		if _djump and has_dj and not on_floor:
			_djump2 = true
			p.velocity.y = _air_jump_velocity()
			if not _air_kicked:
				_air_kicked = true
				_jump_count = 3
				kicked = true
				# UnitPlayer.jump: Emitter.emit('quake') on the air jump's first push.
				Fx.particles("quake", p.global_position, {"source": p})
			_did_jump = true
		else:
			p.velocity.y = _jump_velocity()
			_did_jump = true
	elif dashing:
		p.floor_snap_length = 0.0
	elif not on_floor:
		p.floor_snap_length = 1.0
		p.velocity.y += p.GRAVITY * delta * (0.1 if _dash_t > p.DASH_MAXT - 11.0 else 1.0)
		p.velocity.y = minf(p.velocity.y, p.MAX_FALL)
	else:
		p.floor_snap_length = 1.0

	if _levitating:
		p.velocity.x = move_x * p.SPEED * GameState.move_speed_mult() * 0.75
		_walk_dir = 0
		_max_speed = p.SPEED
		_t_run = 0
	else:
		if not dashing:
			_forces_x(delta, on_floor)
		_control_x(delta, key_left, key_right, on_floor)
	if kicked:
		# One tick of djumpdy * 0.5 sideways. The result is capped at 25 px/tick.
		var kick := absf(_air_jump_velocity()) * 0.5
		if key_left:
			p.velocity.x -= kick
		if key_right:
			p.velocity.x += kick
		p.velocity.x = clampf(p.velocity.x, -p.DJUMP_CAP, p.DJUMP_CAP)
	if dashing:
		_kdash_left = p._spend(_kdash_left)
		if _kdash_left <= 0:
			_kdash_left = 0
			p.velocity *= 0.3

func _forces_x(delta: float, on_floor: bool) -> void:
	# Unit.forces runs before control(), with last tick's walk and maxSpeed.
	# Walking above maxSpeed bleeds brake1 per tick. No walk brakes to zero.
	var brake := p.BRAKE * (0.4 if _sit else 1.0)
	if not on_floor:
		brake = p.BRAKE * 0.1
	var step := brake * delta
	if _walk_dir < 0:
		if p.velocity.x < -_max_speed:
			p.velocity.x = minf(p.velocity.x + step, -_max_speed)
	elif _walk_dir > 0:
		if p.velocity.x > _max_speed:
			p.velocity.x = maxf(p.velocity.x - step, _max_speed)
	else:
		p.velocity.x = move_toward(p.velocity.x, 0.0, step)

func _control_x(delta: float, key_left: bool, key_right: bool, on_floor: bool) -> void:
	# UnitPlayer.control [speed] and [acceleration]. trauma_legs allSpeedMult is on every gait.
	var walk_speed := p.SPEED * GameState.move_speed_mult()
	var accel := p.ACCEL
	var max_speed := walk_speed
	# stay && keyAction: accel * 0.4 and maxSpeed 3. Run, sit and stairs are assigned after and replace it.
	if on_floor and p._use_node != null and max_speed > p.ACTION_CREEP:
		accel = p.ACCEL * 0.4
		max_speed = p.ACTION_CREEP
	if on_floor and _run_wants():
		max_speed = p.RUN_SPEED * GameState.move_speed_mult() * GameState.sprint_speed_mult()
	if on_floor and _sit:
		max_speed = walk_speed * p.SIT_SCALE
	if _diagon != 0:
		max_speed = walk_speed * p.STAIR_SCALE
	# Heavy weapons (massa = phis_massa / 50) slow running. bigsize sets bigGunsSlow to 0.
	var massa := float(p._weapon().get("phis_massa", 0.0)) / 50.0
	var big_slow := Progression.pers("bigGunsSlow", 1.0)
	if max_speed > walk_speed and massa >= 0.1 and big_slow > 0.0:
		max_speed *= 1.0 - massa * big_slow
	if not on_floor:
		accel = p.AIR_ACCEL
	var walk := 0
	if key_left and not key_right:
		walk = -1
	elif key_right and not key_left:
		walk = 1
	if walk != 0:
		if p.velocity.x * walk < max_speed and (not _run_wants() or _t_run > p.RUN_DELAY):
			p.velocity.x += walk * accel * delta
			if p.velocity.x * walk > max_speed:
				p.velocity.x = walk * max_speed
		_t_run += Sim.frame_steps
	else:
		_t_run = 0
	_walk_dir = walk
	_max_speed = max_speed

func _jump_velocity() -> float:
	# jumpdy 12, trauma_legs adds -2 at stage 3.
	return p.JUMP_VELOCITY * GameState.jump_velocity_mult()

func _air_jump_velocity() -> float:
	# djumpdy v0=6 vd=1 per Telekinesis level, in px/tick, times 30.
	return -30.0 * Progression.djump_dy()

func _tick_pinok(delta: float, on_floor: bool) -> void:
	# actions(): pinok drops 1 per tick standing or on a ladder, 3 in the air.
	if _pinok <= 0.0:
		return
	var rate := 30.0 if on_floor or _climbing else 90.0
	_pinok = maxf(0.0, _pinok - rate * delta)

func _landed(was_on_floor: bool, fall_vy: float) -> void:
	# Unit.run on touchdown: sndFall above 5 px/tick, makeNoise(noiseRun) above 16, half above 9.
	if was_on_floor or not p.is_on_floor() or _climbing:
		return
	if fall_vy > p.FALL_SOUND:
		# sndFall plays at footstepVol without Sound.stepVol.
		Fx.sound(_step_clip(Rng.randi_range(&"fx", 1, 4)), p.global_position, {"volume": p.FOOT_VOL, "source": p})
		Fx.sound(_step_clip(Rng.randi_range(&"fx", 1, 4)), p.global_position, {"volume": p.FOOT_VOL, "source": p})
	var noise := 0.0
	var run_noise := Effects.stat("noiseRun", p.NOISE_RUN)
	if fall_vy > p.FALL_NOISE_FULL:
		noise = run_noise
	elif fall_vy > p.FALL_NOISE_HALF:
		noise = run_noise * 0.5
	if noise > 0.0:
		var m := AiWorld.meters(p)
		m.noise = maxf(m.noise, noise)

func _step_up(delta: float, up: bool, down: bool) -> void:
	# Unit.run lifts onto a tile or platform whose top is within porog of the
	# feet. porog is 20 only while walking and 0 under keySit. In the air
	# porog_jump is 10 for (isRun || keyBeUp) before any jump, else 0.
	if _walk_dir == 0 or down or _climbing or _levitating:
		return
	var dx := p.velocity.x * delta
	if absf(dx) < 0.01:
		return
	var lift := 0.0
	if p.is_on_floor():
		lift = p.POROG
	elif (_run_wants() or up) and _jump_count == 0:
		lift = p.POROG_JUMP
	if lift <= 0.0:
		return
	var space := p.get_world_2d().direct_space_state
	if space == null:
		return
	var box := p._body_shape.shape as RectangleShape2D
	var half := box.size.x * 0.5 if box != null else p.BODY_SIZE.x * 0.5
	var probe_x := p.global_position.x + signf(dx) * half + dx
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(probe_x, p.global_position.y - lift - 0.5), Vector2(probe_x, p.global_position.y - 0.5), p.collision_mask)
	query.exclude = [p.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	# Stairs are slopes and Godot already walks them.
	if (hit.normal as Vector2).y > -0.9:
		return
	var rise := p.global_position.y - (hit.position as Vector2).y
	if rise <= 0.5 or rise > lift + 0.5:
		return
	# One pixel of air under the raised box so the step's own top is not a hit.
	if p.test_move(p.global_transform, Vector2(0.0, -rise - 1.0)):
		return
	if p.test_move(p.global_transform.translated(Vector2(0.0, -rise - 1.0)), Vector2(dx, 0.0)):
		return
	# Land over the step, not on its corner, which would stop the slide like a wall.
	p.global_position += Vector2(dx, -rise - 0.5)

## Unit.run (isUp && stay && !isSit): the tile at the head row ahead is open and
## the one under it a full block, so the pony climbs onto it crouched. unsit()
## follows in the same run and stands again when the gap is tall enough.
func _auto_sit(delta: float, up: bool) -> void:
	if not up or _sit or rat or _walk_dir == 0 or _climbing or _levitating or not p.is_on_floor():
		return
	var dir := signf(p.velocity.x) if absf(p.velocity.x) > 0.01 else float(_walk_dir)
	var space := p.get_world_2d().direct_space_state
	if space == null:
		return
	var box := p._body_shape.shape as RectangleShape2D
	var half := box.size.x * 0.5 if box != null else p.BODY_SIZE.x * 0.5
	const TILE = 40.0
	var probe_x := p.global_position.x + dir * (half + 1.0) + p.velocity.x * delta
	var row := floori((p.global_position.y - p.BODY_SIZE.y) / TILE)
	var top := float(row + 1) * TILE
	var rise := p.global_position.y - top
	if rise <= p.POROG + 0.5 or rise > TILE + 0.5:
		return
	var point := PhysicsPointQueryParameters2D.new()
	point.position = Vector2(probe_x, top - TILE * 0.5)
	point.collision_mask = p.collision_mask
	point.exclude = [p.get_rid()]
	if not space.intersect_point(point, 1).is_empty():
		return
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(probe_x, top - 2.0), Vector2(probe_x, top + TILE - 1.0), p.collision_mask)
	query.exclude = [p.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty() or absf((hit.position as Vector2).y - top) > 1.0 or (hit.normal as Vector2).y > -0.9:
		return
	_set_sit(true)
	var lifted := p.global_transform.translated(Vector2(0.0, -rise - 0.5))
	# Far enough in that _ceiling_blocks_stand's narrower band reaches under the lip.
	if p.test_move(lifted, Vector2(dir * (half + 6.0), 0.0)):
		_set_sit(false)
		return
	p.global_position += Vector2(dir * 6.0, -rise - 0.5)
	p.velocity.y = 0.0
	_try_unsit()

func _on_ladder_entered(area: Area2D) -> void:
	if area.is_in_group("ladders") and not _ladder_areas.has(area):
		_ladder_areas.append(area)
		_ladder_count = _ladder_areas.size()

func _on_ladder_exited(area: Area2D) -> void:
	if area.is_in_group("ladders"):
		_ladder_areas.erase(area)
		_ladder_count = _ladder_areas.size()
		if _ladder_count == 0:
			_climbing = false

func _ladder_under_feet() -> Area2D:
	var best: Area2D = null
	var best_score := INF
	for i in range(_ladder_areas.size() - 1, -1, -1):
		var area := _ladder_areas[i]
		if not is_instance_valid(area):
			_ladder_areas.remove_at(i)
			continue
		var score := absf(area.global_position.x - p.global_position.x)
		if p.global_position.y < _rail_top(area) - 1.0:
			score += 1000.0
		if score < best_score:
			best_score = score
			best = area
	_ladder_count = _ladder_areas.size()
	return best

func _rail_top(area: Area2D) -> float:
	var local_y := float(area.get_meta("rail_top_local", 0.0))
	return area.to_global(Vector2(0.0, local_y)).y

func _rail_bottom(area: Area2D) -> float:
	var local_y := float(area.get_meta("rail_top_local", 0.0))
	return area.to_global(Vector2(0.0, -local_y)).y

func _snap_to_rail(area: Area2D) -> void:
	# checkStairs puts the standing box edge on the ladder tile's rail side and
	# lets the far 10 px overlap a wall. The climbing box is narrower so it fits the tile.
	var box := p._body_shape.shape as RectangleShape2D
	var half := (p.RAT_SIZE if rat else p.BODY_SIZE).x * 0.5
	if box != null and box.size.x > p.CLIMB_BOX_W:
		box.size.x = p.CLIMB_BOX_W
	var center := area.global_position.x
	var target := center - p.TILE_HALF + half
	if _ladder_facing(area) > 0.0:
		target = center + p.TILE_HALF - half
	var dx := target - p.global_position.x
	if absf(dx) < 0.01 or p.test_move(p.global_transform, Vector2(dx, 0.0)):
		return
	p.global_position.x = target

func _ladder_facing(area: Area2D) -> float:
	var side := str(area.get_meta("ladder_side", "right"))
	return -1.0 if side == "left" else 1.0

func _reaching_rail_top(area: Area2D, delta: float, move_y: float) -> bool:
	var top := _rail_top(area)
	if p.global_position.y <= top + 1.0:
		return true
	var climb_vy := move_y * p.CLIMB_SPEED * GameState.move_speed_mult()
	return p.global_position.y + climb_vy * delta <= top

func _stand_on_rail(area: Area2D) -> void:
	# isLaz clears here. Drop onto the one-way lip instead of hanging in the grab zone.
	var top := _rail_top(area)
	p.global_position.y = top - 2.0
	p.velocity.y = 80.0
	_climbing = false
	p.floor_snap_length = 8.0
	p.set_collision_mask_value(p.PLATFORM_LAYER_BIT, true)

