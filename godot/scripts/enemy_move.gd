extends RefCounted

## Movement for an enemy body: walk, jump, climb, fly, and knockback.
## State lives here. The body forwards a name only when another script uses it.
## u is that body. Water is unit_water.gd, called from physics_move in the same place.

const _Body := preload("res://scripts/enemy.gd")

var u: _Body


func _init(body: _Body) -> void:
	u = body

static var _gap_cache: Dictionary = {}

static var _gap_frame: int = -1

var move_speed: float = 0.0

var run_speed: float = 180.0

## Unit.otbros push in px/s. The AI rewrites velocity.x every tick, so this rides on top and brakes away.
var _knock_x: float = 0.0

var _rest_skips := 0

var _rest_fixed := -1

var _rest_static_floor := false

var _flying: bool = false

var _loose_fly: bool = false

var _wander_left: int = 0

var _frame_ticks: int = 1

var _jump_free: bool = false

var _climb: bool = false

var _climbing: bool = false

var _climb_locked: bool = false

var _climb_face: float = -1.0

## On a ladder rail: the body box is narrowed to CLIMB_BOX_W and pinned to the rail side.
var _on_rail: bool = false

var _narrow: bool = false

## UnitRaider.t_laz / aiLaz / r_laz. Off-ladder t_laz must drop below -30 before a new grab.
var _t_laz: int = 0

var _ai_laz: int = 0

var _r_laz: int = 0

var _climb_y: float = 0.0

var _climb_stuck: int = 0

var _hop_vy: float = 0.0

var _can_crawl: bool = false

var _crawling: bool = false

var _flyer := false

var _t_fall := 0

var _t_landing := 0

var _walker := false

var _swimming := false

var _hover: float = 70.0

var _can_lift: bool = true

var _jet := false

var _jet_n := 100

var _jet_max := 90

## WalkMotor.pursue heading (aiNapr). It is not the way the sprite faces.
var _heading: float = -1.0

var _cel_dx: float = 0.0

var _cel_dy: float = 0.0

var _vert: int = 0

var _jump_cd: int = 0

var _wall_left: int = 10

var _accel_tick: float = 3.0

var _jump_tick: float = 0.0

var _jump_reach: bool = true

var _hop_gaps: bool = true

var _brake_ledge: bool = false

var _backpedal: bool = false

var _air_frac: float = 0.0

var _jump_boost: float = 0.0

var _wall_give: float = 0.0

var _turn_at_wall: bool = true

var _runs_alert: bool = true

var _runs_seen: bool = false

var _chase_mul: float = 1.0

var _stroll: bool = true

var _can_dash: bool = false

var _opens_doors: bool = false

var _climbs_ladders: bool = false

var _goal_tick: int = -1

var _goal_cached: Vector2 = Vector2.ZERO

var _goal_is_target := false

var _porog: float = 0.0

var _unit_porog: float = 0.0

var _throu: bool = false

var _throu_left: int = 0

var _flee_dir: float = 0.0

var _goal: Vector2 = Vector2.ZERO


func _physics_move(delta: float) -> void:
	var use_grav := not _flying and not _climbing and not _jump_free and not u._buried
	_swimming = false
	if use_grav and u._UnitWater.swim(u, delta, u.body_size.y):
		_swimming = true
	elif use_grav:
		var dvy := u._UnitWater.fall(u, delta, u.body_size.y)
		if dvy < 0.0 or not u.is_on_floor():
			u.velocity.y += dvy
	if _jet and not u._dead:
		for _i in _frame_ticks:
			_tick_jet()
	if u._dropping:
		u.velocity.x = move_toward(u.velocity.x, 0.0, 240.0 * delta)
		_commit_move()
		u.anim.flip_h = u.facing < 0.0
		if u.is_on_floor():
			u._dropping = false
			u.velocity.x = 0.0
		elif u._class_anim:
			u._present_class()
			return
		else:
			u._play_anim("fall")
			return

	if u._call_is_held():
		u.velocity.x = 0.0
		_commit_move()
		u.anim.flip_h = u.facing < 0.0
		u._play_anim("idle")
		return

	_crawling = _can_crawl and u.is_on_floor() and not _climbing and _low_ceiling()
	var moving := u._act()
	if _crawling:
		u.velocity.x = clampf(u.velocity.x, -2.0 * u.TPS, 2.0 * u.TPS)
	_commit_move()
	u._present(moving)

func _patrol() -> bool:
	if _climb and u.wall_check.is_colliding():
		_climbing = true
		return _climb_step()
	if _hop_vy > 0.0 and not u.floor_check.is_colliding() and u.is_on_floor():
		u.velocity.y = -_hop_vy
	elif not u.floor_check.is_colliding() or u.wall_check.is_colliding():
		u.facing *= -1.0
		u.floor_check.position.x = absf(u.floor_check.position.x) * u.facing
		u.wall_check.target_position.x = absf(u.wall_check.target_position.x) * u.facing
		u._weapons._aim_probes()
	u.velocity.x = u.facing * (move_speed if move_speed > 0.0 else u.SPEED) * 0.6
	_heading = u.facing
	return true

func _float_to_cursor() -> void:
	# The player integrates Telekinesis.hold and writes the position.
	if bool(u.get_meta("tele_driven", false)):
		u.velocity = Vector2.ZERO
		u.floor_snap_length = 0.0
		if is_instance_valid(u.anim):
			u.anim.flip_h = u.facing < 0.0
			u.anim.modulate = preload("res://scripts/magic_aura.gd").tele_tint()
		u._lev_anim()
		return
	var center_offset := Vector2.ZERO
	var shape_node := u.get_node_or_null("CollisionShape2D") as Node2D
	if shape_node:
		center_offset = shape_node.position
	var to := u._lev_point - (u.global_position + center_offset)
	var dist := to.length()
	if dist > 2.0:
		u.velocity = to * (u._lev_speed / dist)
	else:
		u.velocity = Vector2.ZERO
	_commit_move()
	u.anim.flip_h = u.facing < 0.0
	u.anim.modulate = Color(0.75, 0.9, 1.2)
	u._lev_anim()

func _hold() -> bool:
	# WalkMotor.hold: stop, face the target. Brain.backOffIfCrowded may leave hold.
	var delta := u.get_physics_process_delta_time()
	u.velocity.x = move_toward(u.velocity.x, 0.0, 900.0 * delta)
	if absf(_cel_dx) > 1.0:
		u.facing = signf(_cel_dx)
		_heading = u.facing
	elif u._senses._target_dx() != 0.0:
		u.facing = signf(u._senses._target_dx())
		_heading = u.facing
	u._weapons._aim_probes()
	var left := _back_off_if_crowded()
	u._tick_attacks()
	return left

func _leap_back() -> void:
	# WalkMotor.leapBack: runSpeed * LEAP_BACK_SPEED away, then jump(LEAP_BACK).
	var dx := _cel_dx if absf(_cel_dx) > 1.0 else u._senses._target_dx()
	var away := -signf(dx) if dx != 0.0 else -u.facing
	var spd := run_speed if run_speed > 0.0 else move_speed
	u.velocity.x = away * spd * u.LEAP_SPEED
	_do_jump(u.LEAP_POWER)

## Brain.holdIfClose. Melee and scorpions stop inside their band. A miss keeps chasing.
func _hold_if_close() -> void:
	if u._close_chance <= 0.0:
		return
	var ax := absf(_cel_dx)
	var in_band := ax >= u._melee._band_min and ax <= u._melee._band_max and _cel_dy >= -u._melee._band_up and _cel_dy <= u._melee._band_down
	if u.ai_state == u.ST_HOLD and u._close_release and not in_band:
		u.ai_state = u.ST_CHASE
		return
	var searching := u.ai_state == u.ST_SEARCH and u._close_search
	if u.ai_state != u.ST_CHASE and not searching:
		return
	if not u._track_player or not in_band or _frame_ticks <= 0:
		return
	if Rng.randf(&"ai") < u._close_chance:
		if u.ai_state != u.ST_HOLD:
			u._state_left = u._ticks(Rng.randf_range(&"ai", u._close_tmin, u._close_tmax) / u.TPS)
		u.ai_state = u.ST_HOLD



## Brain.backOffIfCrowded. Inside the range the gunner always leaves hold, and sometimes hops back.
func _back_off_if_crowded() -> bool:
	if not u._weapons._do_backoff or u.fixed_post or u.fight_style == "melee" or u.fight_style == "turret":
		return false
	if _cel_dx * _cel_dx + _cel_dy * _cel_dy >= u.BACK_OFF_RANGE * u.BACK_OFF_RANGE:
		return false
	if _frame_ticks > 0 and Rng.randf(&"ai") < u.BACK_OFF_CHANCE:
		_leap_back()
	u.ai_state = u.ST_CHASE
	return true



## WalkMotor.pursue. Accelerate along aiNapr, hop gaps, jump to a target above, hop a wall.
func _pursue() -> bool:
	var delta := u.get_physics_process_delta_time()
	if _jump_cd > 0.0:
		_jump_cd -= _frame_ticks
	var jump_power := 0.0
	if _frame_ticks > 0 and _jump_reach and _vert < 0 and _jump_cd <= 0.0 and u._ai_tick % 2 == 1 and _can_jump_up():
		jump_power = 1.0
	_aim_heading_probes()
	if _frame_ticks > 0 and u.is_on_floor() and _over_ledge():
		if _hop_gaps and _vert != 1 and Rng.randf(&"ai") < 0.5:
			jump_power = u.HOP_POWER
		elif _brake_ledge and absf(u.velocity.x) > u.LEDGE_BRAKE_AT * u.TPS:
			u.velocity.x *= u.LEDGE_BRAKE
	if _frame_ticks > 0 and u.is_on_floor() and _into_wall() and not _step_up():
		if _opens_doors:
			_open_door_ahead()
		jump_power = _bump_wall(jump_power)
	if u.ai_state == u.ST_SEARCH or u.ai_state == u.ST_CHASE:
		_climb_toward_target()
		if _climbing:
			return _climb_step()
	var cap := _speed_cap()
	var add := _accel_tick * 900.0 * delta
	if not u.is_on_floor() and not _climbing:
		add *= _air_frac
	var dir := _heading if _heading != 0.0 else u.facing
	if dir < 0.0:
		if u.velocity.x > -cap:
			u.velocity.x -= add
		elif u.velocity.x < -cap:
			u.velocity.x = minf(u.velocity.x + 900.0 * delta, -cap)
	elif dir > 0.0:
		if u.velocity.x < cap:
			u.velocity.x += add
		elif u.velocity.x > cap:
			u.velocity.x = maxf(u.velocity.x - 900.0 * delta, cap)
	if jump_power > 0.0:
		u.facing = dir
		_do_jump(jump_power)
	elif _backpedal and absf(_cel_dx) > 1.0:
		u.facing = signf(_cel_dx)
	else:
		u.facing = dir
	u._weapons._aim_probes()
	u._melee._maybe_smash()
	if u.ai_state == u.ST_CHASE or u.ai_state == u.ST_FLEE or u.ai_state == u.ST_DASH:
		u._tick_attacks()
	return absf(u.velocity.x) > 8.0

func _speed_cap() -> float:
	# Brain.speedFor + WalkMotor backpedal slowdown.
	var spd_run := run_speed if run_speed > 0.0 else (move_speed if move_speed > 0.0 else u.SPEED)
	if u.ai_state == u.ST_FLEE:
		return spd_run * u.FLEE_SPEED
	if u.ai_state == u.ST_DASH:
		return spd_run * u.DASH_SPEED
	var running := _runs_alert or (_runs_seen and u.ai_spok >= u.MAX_SPOK)
	var cap := move_speed if move_speed > 0.0 else u.SPEED
	if running and run_speed > 0.0:
		cap = run_speed
		if u.ai_state == u.ST_CHASE:
			cap *= _chase_mul
	if _backpedal and u.facing * _heading < 0.0:
		cap = move_speed if move_speed > 0.0 else u.SPEED
	return cap

func _into_wall() -> bool:
	if not u.is_on_wall():
		return false
	var dir := _heading if _heading != 0.0 else u.facing
	for i in u.get_slide_collision_count():
		var normal := u.get_slide_collision(i).get_normal()
		if normal.x * dir < -0.5:
			return true
	return false

func _bump_wall(jump_power: float) -> float:
	# WalkMotor.bumpWall. A target behind turns us at once. Otherwise hop the wall, then give up.
	var away := -_heading if _heading != 0.0 else -u.facing
	if _turn_at_wall and _cel_dx * _heading < 0.0:
		_heading = away
		_wall_left = Rng.randi_range(&"ai", u.TURN_MIN, u.TURN_MAX)
		return jump_power
	_wall_left -= _frame_ticks
	var blocked := Rng.randf(&"ai") < _wall_give or _cel_dy > u.FAR_BELOW or not _can_jump_up()
	if blocked:
		_wall_left -= 10
	else:
		jump_power = 1.0
	if _wall_left < 0 and u.is_on_floor():
		_heading = away
		_wall_left = Rng.randi_range(&"ai", u.TURN_MIN, u.TURN_MAX)
	return jump_power



## UnitAIRobot.control: walking into a wall calls jump(1) every tick.
func _tick_jet() -> void:
	if u.is_on_floor():
		_jet_n = _jet_max
	var ahead := _heading if _heading != 0.0 else u.facing
	if u.ai_state != u.ST_IDLE and u.is_on_wall() and u.get_wall_normal().x * ahead < 0.0:
		_jet_jump(1.0)



## UnitProtect.jump: on the floor jump_n refills, in the air it counts down;
## each call lifts by jumpdy / 4 while rising slower than jumpdy.
func _jet_jump(v: float) -> void:
	if u.is_on_floor():
		_jet_n = _jet_max
	else:
		_jet_n -= 1
	if u.velocity.y > -_jump_tick * u.TPS and _jet_n > 0:
		u.velocity.y -= _jump_tick * u.TPS * v / 4.0

func _do_jump(power: float) -> void:
	if _jet:
		_jump_cd = u._ticks(Rng.randf_range(&"ai", u.JUMP_CD_MIN, u.JUMP_CD_MAX) / u.TPS)
		_jet_jump(power)
		return
	# WalkMotor.jump. Hop strength is half; a leap back is 0.4. Rats keep their own hop.
	_jump_cd = u._ticks(Rng.randf_range(&"ai", u.JUMP_CD_MIN, u.JUMP_CD_MAX) / u.TPS)
	if u.is_on_floor() or _climbing:
		if power <= u.HOP_POWER and _hop_vy > 0.0:
			u.velocity.y = -_hop_vy
		else:
			u.velocity.y = -_jump_tick * u.TPS * power
		u.velocity.x += u.facing * _accel_tick * u.TPS * _jump_boost
		_end_climb()

func _can_jump_up() -> bool:
	# WalkMotor.canJumpUp. Clear at 85 and 125 above the feet, and the same a step ahead.
	var ahead := _heading if _heading != 0.0 else u.facing
	var feet := u.global_position
	var spots: Array[Vector2] = [
		feet + Vector2(0.0, -u.HEAD_NEAR),
		feet + Vector2(0.0, -u.HEAD_FAR),
		feet + Vector2(u.HEAD_AHEAD * ahead, -u.HEAD_NEAR),
		feet + Vector2(u.HEAD_AHEAD * ahead, -u.HEAD_FAR),
	]
	for spot in spots:
		if not _point_clear(spot):
			return false
	return true

func _point_clear(at: Vector2) -> bool:
	var space := u.get_world_2d().direct_space_state
	if space == null:
		return true
	var query := PhysicsPointQueryParameters2D.new()
	query.position = at
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_point(query, 1).is_empty()

func _over_ledge() -> bool:
	return u.is_on_floor() and not u.floor_check.is_colliding()

func _aim_heading_probes() -> void:
	var side := _heading if _heading != 0.0 else u.facing
	u.floor_check.position.x = absf(u.floor_check.position.x) * side
	u.wall_check.target_position.x = absf(u.wall_check.target_position.x) * side
	u.floor_check.force_raycast_update()
	u.wall_check.force_raycast_update()

## The doorway-aware goal toward the player, worked out once per 30 Hz tick.
func _player_goal() -> Vector2:
	if not u._senses._player_valid():
		return _goal
	var target := u._player.global_position
	if floori(target.x / u.ROOM_W) == floori(u.global_position.x / u.ROOM_W) and floori(target.y / u.ROOM_H) == floori(u.global_position.y / u.ROOM_H):
		return target
	# Another room: the opening search casts rays, so it is redone every GOAL_EVERY ticks.
	if _goal_tick < 0 or u._ai_tick < _goal_tick or u._ai_tick - _goal_tick >= u.GOAL_EVERY:
		_goal_tick = u._ai_tick
		_goal_cached = _opening_goal(target)
		_goal_is_target = _goal_cached == target
	return target if _goal_is_target else _goal_cached



## Chase across a carved opening. A side gap at body height is already on the
## way to the player's x. A floor hole is not, so aim at that gap. A closed
## door is solid on the same ray and is left alone.
func _opening_goal(target: Vector2) -> Vector2:
	var dx := int(floor(target.x / u.ROOM_W)) - int(floor(u.global_position.x / u.ROOM_W))
	var dy := int(floor(target.y / u.ROOM_H)) - int(floor(u.global_position.y / u.ROOM_H))
	if dx == 0 and dy == 0:
		return target
	if _ray_clear(u._senses._eye_pos(), target + Vector2(0.0, -28.0), 1):
		return target
	if dx != 0 and _side_open(signf(float(dx))):
		return target
	if dy != 0:
		var hole := _floor_gap_x(target, signf(float(dy)))
		if is_finite(hole):
			return Vector2(hole, target.y)
	return target

func _side_open(dir: float) -> bool:
	var edge: float = (floor(u.global_position.x / u.ROOM_W) + (1.0 if dir > 0.0 else 0.0)) * u.ROOM_W
	var chest_y := u._senses._eye_pos().y
	var foot_y := u.global_position.y - 8.0
	return _ray_clear(Vector2(edge - 10.0, chest_y), Vector2(edge + 10.0, chest_y), 1) \
		or _ray_clear(Vector2(edge - 10.0, foot_y), Vector2(edge + 10.0, foot_y), 1)

func _floor_gap_x(target: Vector2, dir: float) -> float:
	var edge_y: float = (floor(u.global_position.y / u.ROOM_H) + (1.0 if dir > 0.0 else 0.0)) * u.ROOM_H
	var x0: float = floor(u.global_position.x / u.ROOM_W) * u.ROOM_W
	# One scan of a room edge serves every enemy for a second. Doors opening there show up after.
	var frame := Engine.get_physics_frames()
	if frame - _gap_frame > 60:
		_gap_frame = frame
		_gap_cache.clear()
	var key := Vector2i(int(x0), int(edge_y))
	if not _gap_cache.has(key):
		var open: PackedFloat32Array = PackedFloat32Array()
		for i in 48:
			var gx: float = x0 + (float(i) + 0.5) * 40.0
			if _ray_clear(Vector2(gx, edge_y - 12.0), Vector2(gx, edge_y + 12.0), 65):
				open.append(gx)
		_gap_cache[key] = open
	var best := INF
	var best_d := INF
	for x in (_gap_cache[key] as PackedFloat32Array):
		var d := absf(x - target.x)
		if d < best_d:
			best_d = d
			best = x
	return best

func _ray_clear(a: Vector2, b: Vector2, mask: int) -> bool:
	var world := u.get_world_2d()
	if world == null:
		return true
	var query := PhysicsRayQueryParameters2D.create(a, b, mask)
	query.collide_with_areas = false
	query.hit_from_inside = false
	return world.direct_space_state.intersect_ray(query).is_empty()

func _commit_move() -> void:
	if not _climbing:
		_on_rail = false
	if _narrow and not _on_rail:
		_sync_climb_box()
	if u._slow_t > 0.0:
		u.velocity *= 0.75
	# freezing tormoz is 0.75 and stacks with the distortion slow.
	if u._ice_t > 0.0:
		u.velocity *= 0.75
	if _knock_x == 0.0:
		if _at_rest():
			return
		u.move_and_slide()
		_note_rest_floor()
		return
	u.velocity.x += _knock_x
	u.move_and_slide()
	u.velocity.x -= _knock_x
	if u.is_on_wall():
		_knock_x = 0.0
	else:
		var brake := float(u._catalog_row(u._species_id).get("move", {}).get("brake", 1.0))
		_knock_x = move_toward(_knock_x, 0.0, maxf(brake, 0.5) * u.TPS * u.TPS * u.get_physics_process_delta_time())



## A still unit on a static floor (or a fixed one) has nothing to slide; skip
## move_and_slide, but run it every REST_RECHECK calls so a floor that broke or
## moved away is noticed.
func _at_rest() -> bool:
	# throu turns the shelf off; skipping move_and_slide would leave them standing on it.
	if _throu or _throu_left > 0.0:
		_rest_skips = 0
		return false
	if u.velocity != Vector2.ZERO:
		_rest_skips = 0
		return false
	if _rest_fixed < 0:
		_rest_fixed = 1 if bool(u._catalog_row(u._species_id).get("fixed", false)) else 0
	if _rest_fixed == 0 and not (_rest_static_floor and u.is_on_floor()):
		return false
	_rest_skips += 1
	if _rest_skips >= u.REST_RECHECK:
		_rest_skips = 0
		return false
	return true

func _note_rest_floor() -> void:
	_rest_static_floor = false
	if not u.is_on_floor() or u.get_platform_velocity() != Vector2.ZERO:
		return
	for i in u.get_slide_collision_count():
		var col := u.get_slide_collision(i)
		if col.get_normal().y < -0.5:
			var body := col.get_collider()
			_rest_static_floor = body is StaticBody2D and not body is AnimatableBody2D
			return



## Unit.otbros: sila = rnd(0.8..1.2) * knocked / massa, at most 3; velocity += knock * otbros * sila.
func otbros(knock: Vector2, power: float) -> void:
	if knock != Vector2.ZERO and u._brain != null:
		u._brain.on_knock()
	if power <= 0.0 or knock == Vector2.ZERO or u._dead or bool(u._catalog_row(u._species_id).get("fixed", false)):
		return
	var knocked := float(u._catalog_row(u._species_id).get("move", {}).get("knocked", 1.0))
	var massa := maxf(u._UnitMassa.massa(u), 0.01)
	var sila := minf((Rng.randf(&"combat") * 0.4 + 0.8) * knocked / massa, 3.0)
	var push := knock * power * sila * u.TPS
	_knock_x += push.x
	u.velocity.y += push.y

func _fit_body() -> void:
	var shape_node := u.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node:
		var box := RectangleShape2D.new()
		box.size = u.body_size
		shape_node.shape = box
		shape_node.position = Vector2(0, -u.body_size.y * 0.5)
	if is_instance_valid(u.anim):
		if u._sheet_native:
			u.anim.position = Vector2.ZERO
			u.anim.scale = Vector2.ONE
			u.anim.centered = true
			u.anim.offset = u._sheet_offset
		else:
			u.anim.position = Vector2(0, -u.body_size.y * 0.5)
			u.anim.scale = Vector2(u.body_size.x / 48.0, u.body_size.y / 56.0)
	u.floor_check.position = Vector2(-u.body_size.x * 0.55, 0)
	u.wall_check.target_position = Vector2(-maxf(24.0, u.body_size.x * 0.7), -u.body_size.y * 0.4)
	u.muzzle.position = Vector2(u.facing * u.body_size.x * 0.5, -u.body_size.y * 0.6)

func _room_rect() -> Rect2:
	var size := Vector2(48 * 40, 25 * 40)
	var rx := int(u.get_meta("room_x", int(floor(u.global_position.x / size.x))))
	var ry := int(u.get_meta("room_y", int(floor(u.global_position.y / size.y))))
	return Rect2(Vector2(rx, ry) * size, size)



## Unit.collisionAll at a feet point: would the body overlap a wall there.
func _blocked_at(feet: Vector2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var box := RectangleShape2D.new()
	box.size = u.body_size - Vector2(2.0, 2.0)
	q.shape = box
	q.transform = Transform2D(0.0, feet + Vector2(0.0, -u.body_size.y * 0.5))
	q.collision_mask = 1
	q.exclude = [u.get_rid()]
	return not u.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()

func _low_ceiling() -> bool:
	var space := u.get_world_2d().direct_space_state
	if space == null:
		return false
	var top := u.global_position + Vector2(0.0, -u.body_size.y * 0.55)
	var query := PhysicsRayQueryParameters2D.create(u.global_position + Vector2(0.0, -4.0), top, 1)
	var skip: Array[RID] = []
	skip.append(u.get_rid())
	query.exclude = skip
	return not space.intersect_ray(query).is_empty()



func _flee(dx: float) -> void:
	u.ai_state = u.ST_FLEE
	u.ai_spok = u.MAX_SPOK + u.SIGHT_BONUS
	u._state_left = u._ticks(float(Rng.randi_range(&"ai", u.FLEE_TIME_MIN, u.FLEE_TIME_MAX)) / u.TPS)
	if dx > u.FLEE_SLACK:
		_flee_dir = -1.0
	elif dx < -u.FLEE_SLACK:
		_flee_dir = 1.0
	if _flee_dir != 0.0:
		_goal = u.global_position + Vector2(_flee_dir * 1000.0, 0.0)

## UnitRaider: throu = moving && celDY > 80 (every control tick, any aiState).
## Unit.setCel: celDY = celY - Y + scY with celY = target.Y - target.scY / 2.
## Patrol (aiSpok 0) aims at its own head, so celDY is 0 and it does not drop.
func _refresh_throu() -> void:
	var moving := not u.fixed_post and not _flying and move_speed > 0.0 and not u.levitated
	if not moving:
		_throu = false
		return
	var dy := 0.0
	if u._track_player and u._senses._player_valid():
		var pf := u._feet(u._player)
		dy = pf.y - u._body_size(u._player).y * 0.5 - u.global_position.y + u.body_size.y
	elif not u._is_calm():
		dy = _goal.y - u.global_position.y + u.body_size.y
	_throu = dy > u.DROP_THROUGH



## Unit.throu: collisionTile skips a shelf while this is set. Keep it on for a few
## ticks after the test so the body leaves the one-way lip.
func _apply_throu() -> void:
	_refresh_throu()
	var drop := _throu and u.is_on_floor() and not _flying and not u.levitated
	if drop:
		_throu_left = u._ticks(6.0 / u.TPS)
		if u.velocity.y < 40.0:
			u.velocity.y = 40.0
	elif _throu_left > 0.0:
		_throu_left -= _frame_ticks
	u.set_collision_mask_value(u.PLATFORM_LAYER_BIT, _throu_left <= 0.0)



## WalkMotor porog: a ledge up to porog pixels is stepped onto instead of blocking.
func _step_up() -> bool:
	if _porog <= 0.0 or _flying:
		return false
	var dir := u.facing if u.facing != 0.0 else 1.0
	var up := Transform2D(0.0, u.global_position + Vector2(0.0, -_porog))
	if u.test_move(u.global_transform, Vector2(0.0, -_porog)):
		return false
	if u.test_move(up, Vector2(dir * 4.0, 0.0)):
		return false
	u.global_position.y -= _porog
	u.global_position.x += dir * 2.0
	return true



## Unit.opensDoors: walking into a closed, unlocked door opens it.
func _open_door_ahead() -> void:
	if not u.wall_check.is_colliding():
		return
	var door := u.wall_check.get_collider() as Node
	if door == null or not u._PS.hasv(door, "lock"):
		return
	if float(u._PS.getv(door, "lock", 0.0)) > 0.0 or not bool(u._PS.getv(door, "usable", true)):
		return
	if int(u._PS.getv(door, "locktip", 1)) == 4:
		return
	if bool(u._PS.getv(door, "door_open", false)) or str(door.get_meta("door_id", "")) == "septum":
		return
	var host := u.get_tree().get_first_node_in_group("land_props")
	if host == null or not host.has_method("_apply_door"):
		return
	var doors: Variant = host.get("_doors")
	if doors is Array and (doors as Array).has(door):
		WorldOps.open_door(door, true)



## UnitRaider.mostLaz: grab when the tile at the feet (or 2 px below) is a stair, after the off-ladder wait.
func _climb_toward_target() -> void:
	if not _climbs_ladders or _climbing or _flying or not u._senses._player_valid():
		return
	if _ai_laz > 0 or _t_laz > -30:
		return
	if _vert == 0:
		return
	var rail := _try_stairs(-1.0 if _vert < 0 else 2.0)
	if rail == null:
		return
	_climbing = true
	_ai_laz = 30
	_hold_rail(rail)

func _climb_step() -> bool:
	# WalkMotor.face() does not turn while isLaz. checkStairs sets storona to the rail.
	if not _climb_locked:
		_climb_locked = true
		_climb_face = u.facing
	# UnitRaider: celY < Y climbs up; aiVNapr == 1 climbs down; otherwise isLaz clears.
	var go_down := _vert > 0
	var go_up := _vert < 0 or (not go_down and _r_laz < 0)
	if go_up and _r_laz <= 0:
		_r_laz = -1
	elif go_down and _r_laz >= 0:
		_r_laz = 1
	elif _t_laz > 20:
		_end_climb()
		return false
	var ny := 2.0 if _r_laz > 0 else -1.0
	var rail := _try_stairs(ny)
	if rail == null:
		if _on_rail or not _climb:
			_end_climb()
			return false
		u._weapons._aim_probes()
		if not u.wall_check.is_colliding():
			_end_climb()
			u.velocity = Vector2(u.facing * move_speed, -160.0)
			return true
	else:
		if _stuck_on_rail():
			_end_climb()
			return false
		_hold_rail(rail)
	u.facing = _climb_face
	u._weapons._aim_probes()
	u._melee._maybe_smash()
	var spd := move_speed if move_speed > 0.0 else u.SPEED
	if u._species_id.begins_with("hellhound") and run_speed > 0.0:
		spd = run_speed * 0.6
	else:
		spd *= 0.6
	u.velocity.x = 0.0
	u.velocity.y = spd if _r_laz > 0 else -spd
	return true



## Unit.checkStairs: the tile at (X, Y+ny) must be empty of phis and have stair.
func _try_stairs(ny: float) -> Area2D:
	var at := u.global_position + Vector2(0.0, ny)
	if _solid_at(at):
		return null
	return _ladder_tile_at(at)

func _hold_rail(rail: Area2D) -> void:
	var side := str(rail.get_meta("ladder_side", ""))
	if side == "left":
		_climb_face = -1.0
	elif side == "right":
		_climb_face = 1.0
	_on_rail = true
	u.floor_snap_length = 0.0
	u.set_collision_mask_value(u.PLATFORM_LAYER_BIT, false)
	_sync_climb_box()
	_snap_to_rail(rail, side)

func _end_climb() -> void:
	_climbing = false
	_climb_locked = false
	_on_rail = false
	_climb_stuck = 0
	u.floor_snap_length = u._base_snap
	u.set_collision_mask_value(u.PLATFORM_LAYER_BIT, _throu_left <= 0.0)
	_sync_climb_box()

func _stuck_on_rail() -> bool:
	if absf(u.global_position.y - _climb_y) < 0.4:
		_climb_stuck += 1
	else:
		_climb_stuck = 0
	_climb_y = u.global_position.y
	return _climb_stuck > 20



## Unit.checkStairs: X = phX1 + scX/2 or phX2 - scX/2. run() skips X while isLaz, so this
## may sit inside a wall tile; the 28 px box keeps the Godot body inside the 40 px column.
func _snap_to_rail(rail: Area2D, side: String) -> void:
	var half := _climb_half_width()
	var center := rail.global_position.x
	var target := center - u.TILE_W * 0.5 + half
	if side != "left":
		target = center + u.TILE_W * 0.5 - half
	u.global_position.x = target

func _climb_half_width() -> float:
	return minf(u.body_size.x, u.CLIMB_BOX_W) * 0.5



## The body box is CLIMB_BOX_W wide while on a rail. Off it, it widens again only where
## the full box fits, stepping clear of a wall when it has to.
func _sync_climb_box() -> void:
	if u._dead:
		_narrow = false
		return
	var shape_node := u.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not shape_node.shape is RectangleShape2D:
		return
	var box := shape_node.shape as RectangleShape2D
	var want := minf(u.body_size.x, u.CLIMB_BOX_W) if _on_rail else u.body_size.x
	if is_equal_approx(box.size.x, want):
		return
	if want > box.size.x:
		var spare := (want - box.size.x) * 0.5
		var shift := NAN
		for dx in [0.0, spare, -spare]:
			if _box_fits(u.global_position + Vector2(dx, 0.0), Vector2(want, box.size.y)):
				shift = dx
				break
		if is_nan(shift):
			return
		u.global_position.x += shift
	var fresh := RectangleShape2D.new()
	fresh.size = Vector2(want, box.size.y)
	shape_node.shape = fresh
	_narrow = want < u.body_size.x

func _box_fits(at: Vector2, size: Vector2) -> bool:
	var space := u.get_world_2d().direct_space_state
	if space == null:
		return true
	var query := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size - Vector2(2.0, 2.0)
	query.shape = rect
	query.transform = Transform2D(0.0, at + Vector2(0.0, -size.y * 0.5))
	query.collision_mask = 1
	query.exclude = [u.get_rid()]
	return space.intersect_shape(query, 1).is_empty()



## The stair tile, not the 36 px grab above the rail top (standing on the lip).
func _ladder_tile_at(at: Vector2) -> Area2D:
	var space := u.get_world_2d().direct_space_state
	if space == null:
		return null
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 32
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for dx in [0.0, u.TILE_W * 0.35, -u.TILE_W * 0.35]:
		query.position = at + Vector2(dx, 0.0)
		for hit in space.intersect_point(query, 4):
			var collider: Object = hit.get("collider")
			if not (collider is Area2D and (collider as Area2D).is_in_group("ladders")):
				continue
			var area := collider as Area2D
			var top := _area_rail_top(area)
			if at.y >= top - 0.5 and at.y < top + _ladder_tile_h(area):
				return area
	return null

func _ladder_tile_h(area: Area2D) -> float:
	for child in area.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
			return maxf(u.TILE_W, ((child as CollisionShape2D).shape as RectangleShape2D).size.y - u.LADDER_GRAB_UP)
	return u.TILE_W

func _solid_at(at: Vector2) -> bool:
	var space := u.get_world_2d().direct_space_state
	if space == null:
		return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = at
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [u.get_rid()]
	for hit in space.intersect_point(query, 4):
		var col: Object = hit.get("collider")
		if col is CollisionObject2D and _body_is_one_way(col as CollisionObject2D):
			continue
		return true
	return false

func _body_is_one_way(body: CollisionObject2D) -> bool:
	for child in body.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).one_way_collision:
			return true
	return false

func _area_rail_top(area: Area2D) -> float:
	var local_y := float(area.get_meta("rail_top_local", 0.0))
	return area.to_global(Vector2(0.0, local_y)).y



## UnitRaider.control for a flyer: take off when the target is over 80 px above, after more
## than 6 ticks off the floor, or in water; land after 20 ticks of floor contact (turnY < 0).
func _tick_flyer() -> void:
	if _frame_ticks <= 0:
		return
	var on_floor := u.is_on_floor()
	if not _flying:
		_t_fall = 0 if on_floor else _t_fall + _frame_ticks
		var above := u._track_player and u._senses._player_valid() and u._player.global_position.y - u.global_position.y < -80.0
		if _t_fall > 6 or _swimming or above:
			_flying = true
			_t_landing = 0
			_hover = 0.0
		return
	if on_floor:
		_t_landing += _frame_ticks
		# UnitAlicorn aiState 4: a calm alicorn flies down and lands on touch.
		if _t_landing > 20 or (u._species_id.begins_with("alicorn") and u._is_calm()):
			_t_landing = 0
			_flying = false
			u.velocity.y = 0.0

func _fly_toward(point: Vector2, shoot: bool) -> bool:
	var to := point - u.global_position
	var spd := run_speed if run_speed > 0.0 and u.ai_spok >= u.MAX_SPOK else move_speed
	if _loose_fly or spd <= 0.0:
		spd = move_speed if move_speed > 0.0 else u.SPEED
	if to.length() > 28.0:
		u.velocity = to.limit_length(spd)
		if absf(to.x) > 4.0:
			u.facing = signf(to.x)
	else:
		u.velocity = u.velocity.move_toward(Vector2.ZERO, spd)
	u._weapons._aim_probes()
	if u.fight_style == "melee":
		if _frame_ticks > 0 and not u._cannot_fight():
			u._melee._melee_swing()
			if u._shok <= 0:
				u._melee._body_bite()
	elif shoot and u._track_player and u._senses._player_valid() and u._weapons._gun_ready():
		var in_reach := not u._species_id.begins_with("bloat") or u._senses._target_distance() <= u._melee._attack_reach
		if in_reach and (u._v_konus <= 0.0 or u._look(u._player) > 0.0):
			u._weapons._shoot_at(u._player.global_position)
	return u.velocity.length() > 8.0



