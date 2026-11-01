extends RefCounted

## The generic brain: what a unit without a UnitBrain (u._brain) decides each
## tick. Brain.tick / pickAttack / act for raiders, zombies, dogs and the other
## catalog units, plus ground allies and pets. The body (enemy.gd) is the motor:
## movement, guns, damage, animation and water. u is that body; the ST_* states,
## the balance consts and the node stay on u. Call order and Rng draws match
## the code this came from, so a replay plays the same.

const _Body := preload("res://scripts/enemy.gd")

var u: _Body

## The UnitBrain interface the body calls through _ai(). These answer with the
## generic unit's behaviour; a custom UnitBrain answers with its own class.
var acts_held := false
var flips_sprite := false
var always_active := false
var storona := -1.0
## The TacticsDirector's order: {kind, at}. Empty (the default policy) leaves
## every decision as the original's. move, regroup and fall_back steer _goal
## to at; hold makes pick_attack hold.
var order: Dictionary = {}


func _init(body: _Body) -> void:
	u = body


func start() -> void:
	pass


func release() -> void:
	pass


func command(_com: String, _val: String = "") -> void:
	pass


func dop_test(_bullet: Node) -> bool:
	return true


func targets_player() -> bool:
	return not u._is_calm()


func held(_delta: float) -> void:
	pass


func animate() -> void:
	if u._class_anim:
		u._present_class()
	else:
		u._present(false)


## UnitRaider / UnitZombie / UnitHellhound / UnitAnt / UnitMonstrik / UnitAlicorn.control:
## a held unit after a target adds levitaccel to dx toward it while dx is under maxSpeed.
## vel and the result are px per tick.
func levit_pull(vel: Vector2) -> Vector2:
	if not u._levit_struggle or u._is_calm():
		return Vector2.ZERO
	var target := u._goal
	if u._track_player and u._senses._player_valid():
		target = u._player.global_position
	var dir := signf(target.x - u.global_position.x)
	var cap := (u.run_speed if u.ai_spok >= u.MAX_SPOK else u.move_speed) / u.TPS
	if dir == 0.0 or vel.x * dir >= cap:
		return Vector2.ZERO
	return Vector2(dir * u._levitaccel, 0.0)


func on_damage(amount: float, _type: String, _bullet: Node, _tt: bool) -> float:
	return amount


## A hit flinches a sprite unit; class rigs and custom brains animate it themselves.
func hit_anim() -> void:
	if not u._class_anim:
		u._play_anim("crouch")


func on_die() -> bool:
	return false


func died() -> void:
	pass


func drop_loot() -> void:
	pass


## The generic tail of _physics_process. A custom brain runs u._brain.physics instead.
func physics(delta: float) -> void:
	if u._downed:
		u._physics_downed(delta)
		return
	if u._stun_t > 0.0:
		u._physics_stunned(delta)
		return
	if u._senses._physics_senses(delta):
		return
	u._move._physics_move(delta)


## Brain.tick when the state timer runs out.
func decide() -> void:
	var was := u.ai_state
	if u.ai_state == u.ST_DASH_PREP:
		u.ai_state = u.ST_DASH
		u._state_left = u._ticks(u.DASH_TIME / u.TPS)
		return
	if u.ai_state == u.ST_SURPRISED:
		if u._track_player:
			u.ai_spok = u.MAX_SPOK + u.SIGHT_BONUS
			u.ai_state = u.ST_CHASE
		else:
			u.ai_state = u.ST_PATROL
	if u.ai_spok == 0:
		# Brain_Definition.stroll: units told to stay (un stay, aiTip stay) only stand.
		u.ai_state = u.ST_PATROL if u._move._stroll and Rng.randf(&"ai") < 0.5 else u.ST_IDLE
	elif u.ai_spok < u.MAX_SPOK:
		u.ai_state = u.ST_SEARCH
	else:
		if was != u.ST_CHASE and was != u.ST_HOLD:
			u._senses._wake_allies()
		u.ai_state = pick_attack()
	if u._is_calm():
		u._state_left = u._ticks(Rng.randf_range(&"ai", u.IDLE_MIN, u.IDLE_MAX) / u.TPS)
	elif u.ai_state == u.ST_DASH_PREP:
		u._state_left = u._ticks(u.DASH_PREP_TIME / u.TPS)
	else:
		u._state_left = u._ticks(Rng.randf_range(&"ai", u.ALERT_MIN, u.ALERT_MAX) / u.TPS)
	u._senses._sync_vision()
	u._calm_cast()


## Brain.pickAttack. Gunners hold for a fresh sighting inside aiDist (holdRange).
## Dashers (zebras) sometimes get ready to dash at a target in sight.
func pick_attack() -> int:
	if u.fixed_post or u.fight_style == "turret":
		return u.ST_HOLD
	if not order.is_empty() and str(order.get("kind", "")) == "hold":
		return u.ST_HOLD
	var state := u.ST_CHASE
	if u.fight_style == "gunner" and u._weapons._gunner_hold and u.ai_spok >= u.MAX_SPOK + u.HOLD_FRESH:
		var range := u._ai_dist if u._raider_type else u._weapons._hold_range
		if u._move._cel_dx * u._move._cel_dx + u._move._cel_dy * u._move._cel_dy < range * range and Rng.randf(&"ai") < u._weapons._hold_chance:
			state = u.ST_HOLD
	if u._move._can_dash and u._track_player and Rng.randf(&"ai") < u.DASH_CHANCE:
		state = u.ST_DASH_PREP
	return state


## Brain.act: one movement step for the current state. True while the unit moves.
func act() -> bool:
	if u._ground_ally:
		return _ally_act()
	if u._friendly:
		return _pet_act()
	if u._dig_left > 0.0 or u._prep_left > 0.0:
		u.velocity.x = 0.0
		if u._senses._player_valid():
			u.facing = signf(u._player.global_position.x - u.global_position.x)
		return false
	if u._move._jump_free:
		return absf(u.velocity.x) > 8.0
	if u._super_left > 0.0 and u._super != "jump":
		u.velocity.x = 0.0
		return false
	if u._move._loose_fly:
		u._move._wander_left -= u._frame_ticks
		if not u._track_player and u._move._wander_left <= 0.0:
			u._move._wander_left = u._ticks(Rng.randf_range(&"ai", 100.0, 200.0) / u.TPS)
			u._goal = u.global_position + Vector2(Rng.randf_range(&"ai", -700.0, 700.0), Rng.randf_range(&"ai", -100.0, 200.0))
	elif u._track_player and u._player != null and is_instance_valid(u._player):
		u._goal = u._move._player_goal()
	if not order.is_empty() and order.get("at") is Vector2 and str(order.get("kind", "")) in ["move", "regroup", "fall_back"]:
		u._goal = order.at
	if u._climbing or (u._move._climb and u.wall_check.is_colliding() and not u._flying):
		u._climbing = true
		return u._move._climb_step()
	if u._move._flyer:
		u._move._tick_flyer()
	if u._flying:
		var point := u._goal
		if u._move._flyer and not u._track_player:
			# UnitRaider: a calm flyer's celY is its floor line, so it sinks and lands.
			point = Vector2(u._goal.x, u.global_position.y + 40.0)
		elif not u._move._loose_fly:
			point += Vector2(0.0, -u._hover)
		return u._move._fly_toward(point, u.fight_style != "melee" and u._weapons._chase_shot and not u._weapons._gutsy_fire)
	if u.fixed_post:
		u.velocity.x = 0.0
		if u.ai_state == u.ST_HOLD or u.ai_state == u.ST_CHASE:
			aim()
			return hold()
		return false
	# Brain.act while alert: aim, maybe stop in reach, then chase or hold.
	if not u._is_calm() and u.ai_state != u.ST_SURPRISED:
		aim()
		if u.ai_state == u.ST_SEARCH or u.ai_state == u.ST_CHASE or u.ai_state == u.ST_DASH:
			reaim()
		elif u.ai_state == u.ST_FLEE and u._move._flee_dir != 0.0:
			u._move._heading = u._move._flee_dir
		hold_if_close()
	var st := u.ai_state
	if st == u.ST_PATROL or st == u.ST_SURPRISED:
		# Raiders set turnsWhenSurprised = false, so surprise keeps the patrol.
		return u._move._patrol()
	if st == u.ST_SEARCH or st == u.ST_CHASE or st == u.ST_FLEE or st == u.ST_DASH:
		return pursue()
	if st == u.ST_DASH_PREP:
		u.velocity.x = move_toward(u.velocity.x, 0.0, 900.0 * u.get_physics_process_delta_time())
		if absf(u._move._cel_dx) > 1.0:
			u.facing = signf(u._move._cel_dx)
		u._weapons._aim_probes()
		return false
	if st == u.ST_HOLD:
		return hold()
	# ST_IDLE and anything else stands.
	u.velocity.x = 0.0
	return false


## WalkMotor.hold, then Brain.backOffIfCrowded and the attack tick. True when it left hold.
func hold() -> bool:
	u._move._hold()
	var left := back_off_if_crowded()
	tick_attacks()
	return left


## WalkMotor.pursue, then the attack tick while chasing, fleeing or dashing.
func pursue() -> bool:
	var moving := u._move._pursue()
	if u._move.pursue_climbed:
		return moving
	if u.ai_state == u.ST_CHASE or u.ai_state == u.ST_FLEE or u.ai_state == u.ST_DASH:
		tick_attacks()
	return moving


## Brain.aim. Horizontal aim uses the doorway gap when the target is in another room.
## Vertical aim is the original celDY, and raiders freeze it in the air.
func aim() -> void:
	var mv := u._move
	var freeze := u._weapons._freeze_aim
	var my := u._body_center(u)
	var point := u._goal
	if u._track_player and u._senses._player_valid():
		point = mv._player_goal()
		mv._cel_dx = point.x - my.x
		if u.is_on_floor() or not freeze:
			var their := u._body_center(u._player)
			var top := their.y - u._body_size(u._player).y * 0.5
			mv._cel_dy = top - my.y + u.body_size.y
	else:
		mv._cel_dx = point.x - my.x
		if u.is_on_floor() or not freeze:
			mv._cel_dy = point.y - my.y + u.body_size.y
	if u.is_on_floor() or not freeze:
		if mv._cel_dy > u.LEVEL_SLACK:
			mv._vert = 1
		elif mv._cel_dy < -u.LEVEL_SLACK:
			mv._vert = -1
		else:
			mv._vert = 0
	# Brain.aim: porog off while the target is far below.
	mv._porog = 0.0 if mv._cel_dy > u.STEP_UP_OFF else mv._unit_porog


## Brain.reaim. Durak raiders turn toward a far target only half the time.
## The original tests aiTCh % reaimInterval == 1 once per tick.
func reaim() -> void:
	var w := u._weapons
	if u._frame_ticks <= 0 or w._reaim_every <= 0:
		return
	var fire := false
	for k in u._frame_ticks:
		if (u._ai_tick - k) % w._reaim_every == 1:
			fire = true
	if not fire:
		return
	if Rng.randf(&"ai") >= w._reaim_chance:
		return
	if u._move._cel_dx > w._reaim_dist:
		u._move._heading = 1.0
	elif u._move._cel_dx < -w._reaim_dist:
		u._move._heading = -1.0


## Brain.holdIfClose. Melee and scorpions stop inside their band. A miss keeps chasing.
func hold_if_close() -> void:
	if u._close_chance <= 0.0:
		return
	var mv := u._move
	var ax := absf(mv._cel_dx)
	var in_band := ax >= u._melee._band_min and ax <= u._melee._band_max and mv._cel_dy >= -u._melee._band_up and mv._cel_dy <= u._melee._band_down
	if u.ai_state == u.ST_HOLD and u._close_release and not in_band:
		u.ai_state = u.ST_CHASE
		return
	var searching := u.ai_state == u.ST_SEARCH and u._close_search
	if u.ai_state != u.ST_CHASE and not searching:
		return
	if not u._track_player or not in_band or mv._frame_ticks <= 0:
		return
	if Rng.randf(&"ai") < u._close_chance:
		if u.ai_state != u.ST_HOLD:
			u._state_left = u._ticks(Rng.randf_range(&"ai", u._close_tmin, u._close_tmax) / u.TPS)
		u.ai_state = u.ST_HOLD


## Brain.backOffIfCrowded. Inside the range the gunner always leaves hold, and sometimes hops back.
func back_off_if_crowded() -> bool:
	var mv := u._move
	if not u._weapons._do_backoff or u.fixed_post or u.fight_style == "melee" or u.fight_style == "turret":
		return false
	if mv._cel_dx * mv._cel_dx + mv._cel_dy * mv._cel_dy >= u.BACK_OFF_RANGE * u.BACK_OFF_RANGE:
		return false
	if mv._frame_ticks > 0 and Rng.randf(&"ai") < u.BACK_OFF_CHANCE:
		mv._leap_back()
	u.ai_state = u.ST_CHASE
	return true


## GunAttack.tick and WeaponAttack.tick, plus BodyAttack while chasing.
func tick_attacks() -> void:
	if u._frame_ticks <= 0 or u._cannot_fight() or u._weapons._gutsy_fire:
		return
	var chasing := u.ai_state == u.ST_CHASE
	var holding := u.ai_state == u.ST_HOLD
	var fleeing := u.ai_state == u.ST_FLEE
	if u.fight_style != "melee" and (holding or fleeing or (chasing and u._weapons._chase_shot)):
		if _slot(&"gun"):
			u._weapons._gun_try()
	if u.fight_style == "melee" and (holding or ((chasing or fleeing) and u._melee._melee_while_chase)):
		if _slot(&"melee"):
			u._melee._melee_try()
	if u._melee._ram_while_chase and (chasing or fleeing or u.ai_state == u.ST_DASH or (holding and u.fight_style == "melee")):
		if _slot(&"ram"):
			u._melee._ram_hit()


## TacticsDirector attack slot on the tracked player (no land: always granted).
func _slot(kind: StringName) -> bool:
	if AiWorld.tactics == null:
		return true
	var target: Node = u._player if u._track_player and u._senses._player_valid() else null
	return TacticsDirector.ask(u, target, kind)


## Order kinds this brain acts on; suppress and call_help wait for R6.7.
func takes_order(kind: StringName) -> bool:
	return kind in [&"move", &"regroup", &"fall_back", &"hold"]


## A ground ally (stable turret side): holds and shoots its prior target in sight, else patrols.
func _ally_act() -> bool:
	u.ai_spok = 0
	u._track_player = false
	var foe := u._prior_target()
	if foe != null and (not foe.is_in_group("enemies") or bool(foe.get("_dead")) or bool(foe.get("_friendly"))):
		u._prior = null
		foe = null
	if foe != null and u.global_position.distance_to(foe.global_position) < 800.0 and u._look(foe) > 0.0:
		u.ai_state = u.ST_HOLD
		u.velocity.x = move_toward(u.velocity.x, 0.0, 900.0 * u.get_physics_process_delta_time())
		if absf(foe.global_position.x - u.global_position.x) > 2.0:
			u.facing = signf(foe.global_position.x - u.global_position.x)
		u._move._heading = u.facing
		u._weapons._aim_probes()
		if u._weapons._gun_ready():
			u._weapons._shoot_at(foe.global_position)
		return false
	if u.ai_state != u.ST_PATROL:
		u.ai_state = u.ST_IDLE
	if u.ai_state == u.ST_PATROL:
		return u._move._patrol()
	u.velocity.x = 0.0
	return false


## A friendly flyer: follows the player and shoots the nearest foe in range.
func _pet_act() -> bool:
	if not u._senses._player_valid():
		u.velocity = u.velocity.move_toward(Vector2.ZERO, u.move_speed)
		return false
	var foe := nearest_foe()
	var dest := u._follow_point()
	var shooting := false
	if foe != null:
		var at := foe.global_position
		var dist := u.global_position.distance_to(at)
		if dist > u._pet_range:
			dest = at
		else:
			shooting = true
			u.facing = signf(at.x - u.global_position.x) if absf(at.x - u.global_position.x) > 2.0 else u.facing
			if u._weapons._gun_ready():
				u._weapons._shoot_at(at)
	var spd := u.run_speed if foe != null and u.run_speed > 0.0 else u.move_speed
	if spd <= 0.0:
		spd = u.SPEED
	var to := dest - u.global_position
	if to.length() > 36.0 and not shooting:
		u.velocity = to.limit_length(spd)
		if absf(to.x) > 4.0:
			u.facing = signf(to.x)
	elif to.length() > 36.0:
		u.velocity = to.limit_length(u.move_speed if u.move_speed > 0.0 else u.SPEED)
	else:
		u.velocity = u.velocity.move_toward(Vector2.ZERO, spd)
	u._weapons._aim_probes()
	return u.velocity.length() > 8.0


func nearest_foe() -> Node2D:
	var best: Node2D = null
	var best_d := 800.0
	for node in Units.near(u.global_position, best_d):
		if node == u or not is_instance_valid(node) or not node is Node2D:
			continue
		if int(node.get("hp")) <= 0:
			continue
		var d := u.global_position.distance_to((node as Node2D).global_position)
		if d < best_d:
			best = node as Node2D
			best_d = d
	return best
