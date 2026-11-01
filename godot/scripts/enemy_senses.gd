extends RefCounted

## Senses for an enemy body: look, listen, alarm, and the shared world meters.
## State lives here. The body forwards a name only when another script uses it.
## u is that body. One set of _world_* meters is shared by every unit, as before.

const _Body := preload("res://scripts/enemy.gd")

var u: _Body


func _init(body: _Body) -> void:
	u = body

static var _sense_frame: int = -1

static var _known_shots: Dictionary = {}

## Per-frame world facts every enemy shares: player room, room darkness, sneak.
static var _world_room := Vector2i(-99999, -99999)

static var _world_vis_mult: float = 1.0

static var _world_sneak: float = 0.0

static var _world_stealth: float = 1.0

static var _world_visi: float = 1.0

static var _world_crit_invis: float = 0.0

static var _world_danger: Array = []

## Raider defaults. Turret / bloat / scorpion overrides come from the land's unit id.
var _v_konus: float = 0.0

var _ear: float = 0.0

## Land.setLocDif earMult, copied once from the difficulty row.
var _ear_mult: float = 1.0

var _calm_vision: float = 0.0

var _alert_vision: float = 0.0

## _sense is tracking the prior pet rather than the player.
var _on_prior := false

var _observ: float = 0.0

var _noise_run: float = 0.0

var _wake_radius: float = 0.0

var _alarm_radius: float = 0.0

var _alarm_shock_min: int = 0

var _alarm_shock_max: int = 0

var _vision: float = 0.0

var _overlook: bool = false

var _track_player: bool = false

var _aware: bool = false

var _scene_areas: Variant = null

var _memory_left: int = 0

var _unseen_looks: int = 0

var _sense_left: int = 10

var _detect_delay: Variant = 101:
	set(v):
		_detect_delay = u._as_ticks(v)


func _physics_senses(delta: float) -> bool:
	u._tick_role(delta)
	if u._buried and u._dig_left <= 0.0:
		u.velocity = Vector2.ZERO
		return true
	u._attack_cd = maxi(0, u._attack_cd - u._frame_ticks)
	if u._melee._windup_left > 0.0:
		if u._cannot_fight():
			u._melee._windup_left = 0
		else:
			u._melee._windup_left = maxi(0, u._melee._windup_left - u._frame_ticks)
			if u._melee._windup_left <= 0.0:
				u._melee._deliver_strike()
	if u._slow_t > 0.0:
		u._slow_t = maxi(0, u._slow_t - u._frame_ticks)
		u._slow_emit -= delta
		if u._slow_emit <= 0.0:
			u._slow_emit = 10.0 / 30.0
			if u.visible and (absf(u.velocity.x) > 90.0 or absf(u.velocity.y) > 150.0):
				Fx.particles("slow", u._feet(u) - Vector2(0.0, u._body_size(u).y * 0.25), {"source": u})
		if u._slow_t <= 0.0 and is_instance_valid(u.anim) and not u.levitated:
			u.anim.modulate = u._tint
		elif is_instance_valid(u.anim) and not u.levitated:
			u.anim.modulate = Color(u._tint.r * 0.7, u._tint.g * 0.82, minf(1.0, u._tint.b + 0.25))
	if u._player == null or not is_instance_valid(u._player):
		u._player = Run.nearest_player(u.global_position)
	if u._player != null:
		_tick_world_senses(u._player, delta)
	if _detect_delay > 0.0:
		_detect_delay = maxi(0, int(_detect_delay) - u._frame_ticks)
	_sense_left -= u._frame_ticks
	if _sense_left <= 0.0:
		_sense_left = u._ticks(u.SENSE_INTERVAL)
		_sense()
	u._state_left -= u._frame_ticks
	if u._state_left <= 0.0:
		u._decide()
	_refresh_overlook()
	u._weapons._tick_reload(delta)
	if u._frame_ticks > 0 and u._species_id == "eqd":
		u._eqd_port()
	if u._frame_ticks > 0 and u._raider_type:
		_watch_for_danger()
	u._move._apply_throu()
	return false

func _refresh_overlook() -> void:
	# looksBehindWhenAlert: 360° while searching, chasing, fleeing, or dashing. Calm stays forward.
	# Surprise does not change the flag.
	if u.ai_state == u.ST_SEARCH or u.ai_state == u.ST_CHASE or u.ai_state == u.ST_FLEE or u.ai_state == u.ST_DASH:
		_overlook = true
	elif u._is_calm():
		_overlook = false

func _player_valid() -> bool:
	return u._player != null and is_instance_valid(u._player)

func _target_dx() -> float:
	if _on_prior and u._prior_target() != null:
		return u._prior.global_position.x - u.global_position.x
	if _player_valid():
		return u._player.global_position.x - u.global_position.x
	return u._goal.x - u.global_position.x

func _target_distance() -> float:
	if _on_prior and u._prior_target() != null:
		return u.global_position.distance_to(u._prior.global_position)
	if _player_valid():
		return u.global_position.distance_to(u._player.global_position)
	return u.global_position.distance_to(u._goal)



func _sense() -> void:
	if u._friendly or u._buried or u._downed or u.ai_state == u.ST_FLEE:
		return
	if _detect_delay > 0.0:
		return
	if u._player == null or not is_instance_valid(u._player):
		_track_player = false
		return
	# Unit.findCel: a seen priorUnit comes before the player.
	_on_prior = false
	var pr := u._prior_target()
	if pr != null and _look(pr) > 0.5:
		_on_prior = true
		_track_player = true
		_aware = true
		u._goal = pr.global_position
		if u.ai_spok < u.MAX_SPOK:
			u.ai_spok = u.MAX_SPOK + u.SIGHT_BONUS
		_sync_vision()
		return
	# Unit.findCel skips loc.gg.invulner, which controlOff sets.
	if bool(u._player.get("control_off")):
		_lose()
		_sync_vision()
		return
	# Original rooms are separate locations; a room still waiting on its
	# scripted area must not see or hear the player past its edge.
	if not _aware and not u._move._room_rect().has_point(u._player.global_position) and _scene_pending():
		_lose()
		_sync_vision()
		return
	var heard := _listen(u._player)
	var seen := _look(u._player)
	if heard > 0.0:
		_add_obs(u._player, heard, -1000.0)
	if seen > 0.0:
		_add_obs(u._player, seen, _observ)
		if _obs(u._player) >= u.MAX_OBS:
			_track_player = true
			_aware = true
			_memory_left = u.TARGET_MEMORY
			u._goal = u._player.global_position
			_on_seen()
			_sync_vision()
			return
	elif heard > 0.0:
		if _obs(u._player) >= u.MAX_OBS:
			_track_player = false
			u._goal = u._player.global_position + Vector2(Rng.randf_range(&"ai", -100.0, 100.0), Rng.randf_range(&"ai", -100.0, 100.0))
		if heard > 1.0:
			u.ai_spok = u.MAX_SPOK - 1
			_sync_vision()
			return
	_lose()
	_sync_vision()

func _scene_pending() -> bool:
	if _scene_areas == null:
		_scene_areas = []
		var rect := u._move._room_rect()
		for a in u.get_tree().get_nodes_in_group("land_area"):
			if not (a.get_meta("actions", []) as Array).is_empty() and rect.has_point((a as Node2D).global_position):
				_scene_areas.append(a)
	for a in _scene_areas:
		if is_instance_valid(a) and bool(u._PS.getv(a, "enabled", false)):
			return true
	return false

func _on_seen() -> void:
	if _v_konus > 0.0:
		u.ai_spok = u.MAX_SPOK + u.SIGHT_BONUS
		u.ai_state = u.ST_HOLD
		u._state_left = u._ticks(Rng.randf_range(&"ai", u.ALERT_MIN, u.ALERT_MAX) / u.TPS)
		return
	if u._is_calm():
		u.ai_state = u.ST_SURPRISED
		u._state_left = u._ticks(float(Rng.randi_range(&"ai", int(u._surprise_min), int(u._surprise_max))) / u.TPS)
		return
	u.ai_spok = u.MAX_SPOK + u.SIGHT_BONUS

func _lose() -> void:
	# Six failed looks still follow the player's real position, then the guess drifts.
	if _memory_left > 0:
		_memory_left -= 1
		_track_player = true
		if u._player != null and is_instance_valid(u._player):
			u._goal = u._player.global_position
		return
	_track_player = false
	_unseen_looks += 1
	if _unseen_looks % u.DRIFT_INTERVAL == 0:
		u._goal.x += Rng.randf_range(&"ai", -u.SEARCH_DRIFT, u.SEARCH_DRIFT)
		u._goal.y += Rng.randf_range(&"ai", -u.SEARCH_DRIFT, u.SEARCH_DRIFT)
	if u.ai_spok > 0:
		u.ai_spok -= 1
	if u.ai_spok == 0:
		return
	if not _aware and u.ai_spok < u.GIVE_UP_SPOK:
		u.ai_spok = 0

func _sync_vision() -> void:
	_vision = _calm_vision if u.ai_spok == 0 else _alert_vision

func _become_alert(point: Vector2) -> void:
	_track_player = false
	u._goal = point
	u.ai_spok = u.MAX_SPOK + u.SIGHT_BONUS
	u.ai_state = u.ST_CHASE
	u._state_left = u._ticks(Rng.randf_range(&"ai", u.ALERT_MIN, u.ALERT_MAX) / u.TPS)
	_detect_delay = 0
	_vision = _alert_vision
	_overlook = true

func _wake_allies() -> void:
	if _wake_radius > 0.0:
		_budilo(_wake_radius)



## Unit.budilo: make a noise, and alarm awake units of the same fraction inside rad * their ear.
## Two robots hear each other at rad.
func _budilo(rad: float) -> void:
	var tree := u.get_tree()
	if tree == null:
		return
	u.set_meta("foe_noise", _noise_run * 1.2)
	var robot := u._is_machine()
	for node in tree.get_nodes_in_group("enemies"):
		if node == u or not node.has_method("_alarm_from"):
			continue
		if int(node.get("fraction")) != u.fraction or bool(node.get("_dead")) or bool(node.get("_downed")) or bool(node.get_meta("unres", false)):
			continue
		var other := node as Node2D
		var d2 := other.global_position.distance_squared_to(u.global_position)
		var reach := rad
		if not (robot and bool(node.call("_is_machine"))):
			reach = rad * float(node.get("_ear"))
		if d2 < reach * reach:
			other.call("_alarm_from", u.global_position)



## Unit.alarma then Brain.alarm. Only a calm unit wakes; it starts shocked.
func _alarm_from(at: Vector2) -> void:
	if u._dead or not u._is_calm():
		return
	_become_alert(at + Vector2(Rng.randf_range(&"ai", -125.0, 125.0), Rng.randf_range(&"ai", -125.0, 125.0)))
	u._shok = Rng.randi_range(&"ai", _alarm_shock_min, _alarm_shock_max)
	if _alarm_radius > 0.0:
		_budilo(_alarm_radius)

func _look(player: Node2D) -> float:
	if _vision <= 0.0:
		return 0.0
	var eye := _eye_pos()
	var point := _look_point(player)
	var cx := point.x - eye.x
	var cy := point.y - eye.y
	var r2 := cx * cx + cy * cy
	var vel := u._velocity_of(player)
	var vis := u.PLAYER_VIS_STILL
	if absf(vel.x) >= 2.0 * u.TPS or absf(vel.y) >= 2.0 * u.TPS:
		vis = u.PLAYER_VIS_MOVE
	vis *= float(player.get_meta("foe_vis_mult", 1.0))
	var detecting := float(player.get_meta("foe_detecting", u.DETECTING))
	# Unit.look: (visibility * stealthMult * loc.visMult + demask) * vision.
	var dist_vis := (vis * _world_stealth * _world_vis_mult + float(player.get_meta("foe_demask", 0.0))) * _vision
	# No cone: a target mostly below the eyes is harder to see, down to half range.
	if _v_konus == 0.0 and not _overlook and cy > 0.0 and cy * cy > cx * cx:
		dist_vis *= 0.5 + 0.5 * absf(cx / cy)
	# The original stops at 4x distVis inside its own room; the sight ray stops at a room width.
	if r2 > minf(dist_vis * dist_vis * 16.0, u.SIGHT_CAP * u.SIGHT_CAP):
		return 0.0
	# Calm raiders (overlook 0) see behind only inside detecting.
	if _v_konus == 0.0 and not _overlook and cx * u.facing < 0.0 and r2 > detecting * detecting:
		return 0.0
	if _v_konus > 0.0:
		var dug := wrapf(_aim_angle() - atan2(cy, cx), -PI, PI)
		if absf(dug) > _v_konus * 0.5:
			return 0.0
	if not Sight.los_clear(eye, point, player):
		return 0.0
	if r2 < detecting * detecting:
		return 20.0
	if r2 < dist_vis * dist_vis:
		return 4.0
	return dist_vis * dist_vis / r2 * 4.0

func _listen(player: Node2D) -> float:
	var noise := float(player.get_meta("foe_noise", 0.0)) * _ear * _ear_mult
	if noise <= 0.0:
		return 0.0
	var p_feet := u._feet(player)
	var e_feet := u._feet(u)
	var mouth := Vector2(p_feet.x, p_feet.y - u._body_size(player).y * 0.75)
	var ear := Vector2(e_feet.x, e_feet.y - u._body_size(u).y * 0.5)
	var dx := mouth.x - ear.x
	var dy := mouth.y - ear.y
	var r2 := dx * dx + dy * dy
	# Unit.listen is distance only: noise * ear reaches through walls.
	if noise * noise <= r2:
		return 0.0
	return (1.0 - r2 / (noise * noise)) * 4.0

func _tick_world_senses(player: Node, delta: float) -> void:
	var frame := Engine.get_physics_frames()
	if frame != _sense_frame:
		_sense_frame = frame
		var ticks := delta * u.TPS
		var is_obs := float(player.get_meta("foe_is_obs", 0.0))
		var obs := float(player.get_meta("foe_obs", 0.0))
		if is_obs > 0.0:
			is_obs -= ticks
			if is_obs < 0.0:
				obs = maxf(0.0, obs - u.MINUS_OBS * (-is_obs))
				is_obs = 0.0
		elif obs > 0.0:
			obs = maxf(0.0, obs - u.MINUS_OBS * ticks)
		player.set_meta("foe_is_obs", is_obs)
		player.set_meta("foe_obs", obs)
		var demask := maxf(0.0, float(player.get_meta("foe_demask", 0.0)) - u.DEMASK_DECAY * ticks)
		var vel := u._velocity_of(player)
		if absf(vel.x) > 10.0 * u.TPS or absf(vel.y) > 10.0 * u.TPS:
			demask = maxf(demask, u.FAST_DEMASK)
		player.set_meta("foe_demask", demask)
		_refresh_world(player)
		_world_danger = u._gather_grenades(u.get_tree())
		var noise := maxf(0.0, float(player.get_meta("foe_noise", 0.0)) - u.NOISE_DECAY * ticks)
		var step := _footstep_noise(player, vel)
		if step > noise:
			noise = step
		player.set_meta("foe_noise", noise)
		_scan_shots(player)



## Facts shared by every enemy this frame. Sneak skill: Pers sneak is the raw points,
## noiseRun 300 - 60 per level, critInvis 0.05 per level. Armor sneak scales visiMult.
func _refresh_world(player: Node) -> void:
	var p2 := player as Node2D
	var room := _world_room
	if p2 != null:
		room = u._room_of(p2.global_position)
	_world_vis_mult = _room_vis_mult(room)
	_world_sneak = 0.0
	_world_crit_invis = 0.0
	if Progression != null:
		_world_sneak = float(Progression.rank("sneak"))
		_world_crit_invis = 0.05 * float(Progression.skill_level_of("sneak"))
	_world_stealth = float(player.get_meta("stealth_mult", 1.0))
	_world_visi = 1.0
	if Inventory != null and Condition != null:
		# armorParameters: visiMult *= 1 - sneak for the suit, then the amulet.
		for worn in Inventory.worn_ids():
			_world_visi *= 1.0 - Progression.armor_sneak(worn)



## Location.visMult, the room's darkness factor. The fog keeps it as dist1 / 300. 1 without data.
func _room_vis_mult(room: Vector2i) -> float:
	var fog := u.get_tree().get_first_node_in_group("fog")
	if fog == null:
		return 1.0
	var state: Variant = fog.get("_state")
	if state == null or not (state is Object):
		return 1.0
	var rooms: Variant = (state as Object).get("rooms")
	if not (rooms is Dictionary) or not (rooms as Dictionary).has(room):
		return 1.0
	var r: Object = (rooms as Dictionary)[room]
	var dist1 := float(r.get("dist1"))
	if dist1 <= 0.0:
		return 1.0
	return dist1 / 300.0

func _footstep_noise(player: Node, vel: Vector2) -> float:
	if player is CharacterBody2D and not (player as CharacterBody2D).is_on_floor():
		return 0.0
	var run := u.NOISE_RUN
	if Progression != null:
		run = maxf(0.0, 300.0 - 60.0 * float(Progression.skill_level_of("sneak")))
	run = Effects.stat("noiseRun", run)
	var vx := absf(vel.x)
	if vx > 12.0 * u.TPS:
		return run
	if vx > 7.0 * u.TPS:
		return run * 0.5
	if vx > 3.0 * u.TPS:
		return run * 0.25
	return 0.0

func _scan_shots(player: Node) -> void:
	var tree := u.get_tree()
	if tree == null:
		return
	var live := {}
	var fresh := false
	for node in tree.get_nodes_in_group("player_bullets"):
		if not is_instance_valid(node):
			continue
		var id: int = node.get_instance_id()
		live[id] = true
		if not _known_shots.has(id):
			fresh = true
	_known_shots = live
	if not fresh:
		return
	var noise := maxf(float(player.get_meta("foe_noise", 0.0)), _shot_noise())
	player.set_meta("foe_noise", noise)
	var demask := maxf(float(player.get_meta("foe_demask", 0.0)), u.SHOT_DEMASK)
	player.set_meta("foe_demask", demask)

func _shot_noise() -> float:
	# weapons.xml snd noise for the guns this slice loads. Default is p10mm.
	var name := str(GameState.weapon_name).to_lower()
	if "laser" in name:
		return 300.0
	if "shotgun" in name or "sawed" in name:
		return 1200.0
	if "flame" in name:
		return 400.0
	if "fireball" in name:
		return 800.0
	if "magic" in name:
		return 500.0
	return 700.0



## UnitPlayer.observation. A look passes the unit's observ (nobs); hearing passes none.
## sneak - demask/20 against observ scales the look, then visiMult * stealthMult.
func _add_obs(player: Node, amount: float, nobs: float) -> void:
	if amount <= 0.0:
		return
	var nlook := amount
	if nobs > -1000.0:
		var nsneak := maxf(0.0, _world_sneak - float(player.get_meta("foe_demask", 0.0)) / 20.0)
		if nobs > nsneak:
			nlook *= 1.0 + (nobs - nsneak) * 0.2
		elif nobs < nsneak:
			nlook /= 1.0 - (nobs - nsneak) * 0.3
	nlook *= _world_visi * _world_stealth
	if player.has_method("lurk_cut"):
		var sneak_lurk := 2.5 + 0.5 * float(Progression.skill_level_of("sneak")) if Progression != null else 2.5
		nlook -= sneak_lurk * float(player.call("lurk_cut"))
	if nlook <= 0.0:
		return
	var obs := minf(float(player.get_meta("foe_obs", 0.0)) + nlook, u.MAX_OBS * 2.0)
	player.set_meta("foe_obs", obs)
	player.set_meta("foe_is_obs", u.OBS_GRACE)

func _obs(player: Node) -> float:
	return float(player.get_meta("foe_obs", 0.0))

func _eye_pos() -> Vector2:
	var size := u._body_size(u)
	var feet := u._feet(u)
	return Vector2(feet.x + size.x * 0.25 * u.facing, feet.y - size.y * 0.75)

func _look_point(body: Node2D) -> Vector2:
	var feet := u._feet(body)
	return Vector2(feet.x, feet.y - u._body_size(body).y * 0.6)

func _aim_angle() -> float:
	if u._brain != null:
		return u._brain.v_angle()
	if u._aim_down:
		return PI * 0.5
	return u.V_ANGLE if u.facing >= 0.0 else PI

## UnitRaider.watchForDanger: run from a grenade in view, react to a levitated mine.
func _watch_for_danger() -> void:
	if u._friendly or u._cannot_fight():
		return
	for k in u._frame_ticks:
		var t := u._ai_tick - k
		if u._fear_grenade and not _world_danger.is_empty() and t % u.GRENADE_CHECK == 1 and Rng.randf(&"ai") < u.GRENADE_CHECK_CHANCE:
			var nade: Variant = _grenade_in_view()
			if nade != null:
				u._move._flee(float(nade.x) - u.global_position.x)
				return
		if t % u.MINE_CHECK == 1 and not _track_player:
			u._watch_levitation()

func _grenade_in_view() -> Variant:
	var center := u.global_position + Vector2(0.0, -u._body_size(u).y * 0.5)
	var eye := u.global_position + Vector2(0.0, -u._body_size(u).y * 0.75)
	for g in _world_danger:
		var at: Vector2 = g
		if center.distance_squared_to(at) < 160000.0 and Sight.los_clear(eye, at, null):
			return at
	return null

