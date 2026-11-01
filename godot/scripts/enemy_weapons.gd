extends RefCounted

## Guns for an enemy body: aim, burst, reload, arm, and launch.
## State lives here. The body forwards a name only when another script uses it.
## u is that body. The attack tick that orders gun, melee, and ram stays on the body.

const _Body := preload("res://scripts/enemy.gd")

var u: _Body


func _init(body: _Body) -> void:
	u = body

var _thrown: bool = false

var _blast: float = 0.0

var _fuse: float = 2.5

var _weapon: Dictionary = {}

var _burst_len: int = 0

var _burst_left: int = 0

var _side_id: String = ""

var _side_ammo: int = 0

var _side_wait: int = 31

var _side_chance: float = 1.0

var _gutsy_fire: bool = false

var _gutsy_scale: float = 1.0

var _gutsy_burst: int = 0

var _gutsy_cd: int = 0

var _ranger_side: bool = false

var _dop_effect: String = ""

var _dop_damage: float = 0.0

var _dop_chance: float = 1.0

var _encl_bonus: bool = false

## Raider gunners hold and hop back. Other families set these from their own class.
var _bullet_damage: int = 10

var _bullet_type: String = "DAM_PIERCE"

var _bullet_speed: float = 360.0

var _gunner_hold: bool = true

var _hold_range: float = 0.0

var _hold_chance: float = 0.0

var _do_backoff: bool = true

var _chase_shot: bool = true

var _reaim_every: int = 0

var _reaim_chance: float = 0.0

var _reaim_dist: float = 0.0

var _freeze_aim: bool = true

var _shot_chance: float = 0.0

var _blind_chance: float = 0.0

var _shoot_climb: bool = false

var _need_sight: bool = false

var _sniper: bool = false

var _mag_cap: int = 0

var _mag: int = 0

var _reload_left: int = 0

var _reload_time: float = 0.0

var _rashod: int = 1

var _pellets: int = 1

var _deviation: float = 0.0

var _mazil: float = 0.0


## GunAttack.tick (the generic brain calls it from tick_attacks).
func _gun_try() -> void:
	# GunAttack: bursts while chase, hold, or flee. Single shots are a roll each tick, only unshocked.
	if u._climbing and not _shoot_climb:
		return
	if u._v_konus > 0.0 and u._senses._player_valid() and u._look(u._player) <= 0.0:
		return
	var seen := u._track_player and u._senses._player_valid()
	if _need_sight and not seen:
		return
	if _sniper:
		_mazil = 0.0
	else:
		_mazil = u.HOLD_SPREAD if u.ai_state == u.ST_HOLD else u.MOVE_SPREAD
	var target := u._player.global_position if seen else u._goal
	# Turrets keep the weapon's own rate. Raider GunAttack rolls single shots.
	if u.fight_style == "turret":
		if u._attack_cd <= 0.0:
			_shoot_at(target)
		return
	if _burst_len > 0:
		if _sniper and not seen:
			return
		if _gun_ready():
			_shoot_at(target)
		return
	if u._attack_cd > 0.0:
		return
	if u._shok > 0 and not _thrown:
		return
	var chance := _shot_chance if seen else _blind_chance
	if chance <= 0.0:
		return
	for _i in u._frame_ticks:
		if Rng.randf(&"combat") < chance:
			_shoot_at(target)
			return

func _shoot_at(target: Vector2) -> void:
	if u._on_prior and u._prior_target() != null:
		target = u._body_center(u._prior)
	_launch(target, _weapon, u._friendly, true, u._fire_down)

func _aim_probes() -> void:
	var side := u.facing if u.facing != 0.0 else -1.0
	u.floor_check.position.x = absf(u.floor_check.position.x) * side
	u.wall_check.target_position.x = absf(u.wall_check.target_position.x) * side
	u.muzzle.position = Vector2(side * maxf(u.body_size.x * 0.5, 16.0), -u.body_size.y * 0.6)

## Weapon holder reload: no shots for reload ticks, then a full magazine.
func _tick_reload(delta: float) -> void:
	if _reload_left <= 0.0:
		return
	_reload_left -= u._frame_ticks
	if _reload_left <= 0.0:
		_reload_left = 0
		_mag = _mag_cap



func _gun_ready() -> bool:
	if u.fight_style == "melee" or _reload_left > 0.0:
		return false
	if _burst_len <= 0:
		return u._attack_cd <= 0.0
	if _burst_left <= 0:
		_burst_left = maxi(1, int(round(float(_burst_len) * Rng.randf_range(&"combat", 0.8, 1.2))))
	var firing := _burst_left > int(round(float(_burst_len) * 0.25))
	if u._frame_ticks > 0:
		_burst_left -= u._frame_ticks
	return firing and u._attack_cd <= 0.0

func _tick_side(delta: float) -> void:
	var grenades := _side_ammo > 0 and _side_id != ""
	if not grenades and not _ranger_side:
		return
	# SideWeaponAttack: the timer runs only while fighting. A due shot needs a target
	# in sight; without one only a blind weapon (ranger gas) fires.
	if not u._is_attacking() or u._cannot_fight():
		return
	_side_wait -= u._frame_ticks
	if _side_wait > 0.0:
		return
	_side_wait = u._ticks(float(Rng.randi_range(&"ai", 50, 200)) / u.TPS)
	var seen := u._track_player and u._senses._player_valid()
	if grenades:
		if seen and Rng.randf(&"ai") < _side_chance:
			_launch(u._player.global_position, _weapon_row(_side_id), u._friendly, false, false)
			_side_ammo -= 1
		return
	if seen:
		var rocket := _weapon_row("robomlau")
		rocket["damage_expl"] = float(rocket.get("damage_expl", 150.0)) * 0.8
		_launch(u._player.global_position, rocket, false, false, false)
	else:
		_launch(u._goal, _weapon_row("robogas"), false, false, false)

func _tick_gutsy() -> void:
	if not _gutsy_fire or u._is_calm() or not u._senses._player_valid():
		return
	var close := u._senses._target_distance() < 300.0
	if close or _gutsy_burst > 0:
		if _gutsy_burst <= 0:
			_gutsy_burst = maxi(1, int(round(100.0 * Rng.randf_range(&"ai", 0.8, 1.2))))
		var firing := _gutsy_burst > 25
		if u._frame_ticks > 0:
			_gutsy_burst -= u._frame_ticks
		if firing and _gutsy_cd <= 0.0:
			var fire := _weapon_row("robofire")
			fire["damage"] = float(fire.get("damage", 2.2)) * _gutsy_scale
			_launch(u._player.global_position, fire, false, false, false)
			_gutsy_cd = u._ticks(1.0 / u.TPS)
		return
	if u._frame_ticks <= 0 or u._attack_cd > 0.0:
		return
	for _i in u._frame_ticks:
		if Rng.randf(&"ai") < 0.1:
			_shoot_at(u._player.global_position)
			return

func _role_grenade(row: Dictionary) -> void:
	var grenader := int(row.get("grenader", 0))
	if grenader > 0:
		_side_id = "mercgr"
		_side_ammo = grenader
		_side_chance = 0.5
		_side_wait = u._ticks(Rng.randf_range(&"ai", 50.0, 200.0) / u.TPS)
	elif _ranger_side:
		_side_wait = u._ticks(Rng.randf_range(&"ai", 50.0, 200.0) / u.TPS)

func _role_arm(id: String, row: Dictionary) -> void:
	var rolled := ""
	if id.begins_with("scorp") or id == "necros" or id == "tarakan" or id.begins_with("zombie"):
		rolled = ""
	elif id.begins_with("ant") and id != "ant3":
		rolled = ""
	elif id.begins_with("alicorn"):
		rolled = "alilight"
	elif id.begins_with("bossencl"):
		rolled = "lmg"
		if id.ends_with("2"):
			rolled = "quick"
		elif id.ends_with("3"):
			rolled = "mlau"
	else:
		rolled = u._roll_pool(row.get("pool", []))
		if rolled == "":
			rolled = str(row.get("weapon", ""))
	if rolled != "":
		_arm(rolled)
	if id == "bossencl3" and not _weapon.is_empty():
		_weapon["speed"] = 12.0
		_weapon["rapid"] = 30.0
		_weapon["damage_expl"] = float(_weapon.get("damage_expl", 250.0)) * 0.6
		u._melee._strike_cd = 30.0 / u.TPS
		_bullet_speed = 12.0 * u.TPS
		_bullet_damage = maxi(1, int(round(float(_weapon["damage_expl"]))))

func _arm(wid: String) -> void:
	var w := _weapon_row(wid)
	if w.is_empty():
		return
	var kind := str(w.get("kind", ""))
	var delivery := str(w.get("delivery", ""))
	var thrown := kind == "explosives" or delivery == "grenade"
	var rapid := maxf(float(w.get("rapid", 15.0)), 1.0)
	if kind == "melee" or delivery == "melee":
		u.fight_style = "melee"
		_thrown = false
		_chase_shot = false
		_blast = 0.0
		var wd := float(w.get("damage", u._comb))
		if u._krep == 0:
			u.melee_damage = maxi(1, int(round(wd)))
		else:
			u.melee_damage = maxi(1, int(round(wd * 0.5 + float(u._comb))))
		_bullet_type = str(w.get("damage_type", _bullet_type))
		u._melee._strike_cd = rapid / u.TPS
		u._melee._swing_x = u.SWING_REACH
		var reach_y := rapid * 8.0
		u._melee._swing_above = reach_y
		u._melee._swing_below = reach_y
		_weapon = w
		_burst_len = 0
		u._move._backpedal = false
		# UnitRaider.arm: a gripped melee weapon is a body ram. A levitated one swings.
		if u._krep != 0:
			u._melee._contact_bite = true
			u._move._chase_mul = u.CHARGE_SPEED
			u._move._runs_seen = true
			u._close_chance = 0.0
			u._melee._melee_while_chase = false
			u._melee._ram_while_chase = true
			u._melee._ram_x = 0.0
			u._melee._ram_y = 0.0
			if u._comb > 0:
				u.melee_damage = maxi(1, int(round(float(wd) * 0.5 + float(u._comb))))
		else:
			u._melee._contact_bite = false
			u._move._chase_mul = 1.0
			u._melee._melee_while_chase = true
			u._melee._ram_while_chase = false
			u._close_chance = 1.0
			u._melee._band_min = u.SWING_MIN
			u._melee._band_max = u.SWING_MAX
			u._melee._band_up = u.SWING_HEIGHT
			u._melee._band_down = u.SWING_HEIGHT
			u._close_release = true
			u._close_search = false
			u._melee._swing_chance = u.SWING_CHANCE
		return
	var direct := float(w.get("damage", 0.0))
	var expl := float(w.get("damage_expl", 0.0))
	if _encl_bonus and not thrown:
		var scale := 1.2 * (1.2 if direct < 20.0 else 1.0)
		direct *= scale
		expl *= scale
	w["damage"] = direct
	w["damage_expl"] = expl
	_weapon = w
	_thrown = thrown
	u.fight_style = "gunner"
	u._melee._strike_cd = rapid / u.TPS
	var blast := float(w.get("radius", 0.0))
	var dam := direct
	if thrown or (expl > 0.0 and blast > 0.0):
		dam = expl if expl > 0.0 else direct
		_blast = blast
		_fuse = maxf(float(w.get("fuse", 75.0)) / u.TPS, 0.05)
	else:
		_blast = 0.0
	_bullet_damage = maxi(1, int(round(dam)))
	_bullet_type = str(w.get("damage_type", _bullet_type))
	_bullet_speed = maxf(float(w.get("speed", 12.0)) * u.TPS, 40.0)
	# Weapon holder: a magazine of mag rounds, rashod per shot, reload ticks to refill.
	_mag_cap = 0 if thrown else int(w.get("mag", 0))
	_mag = _mag_cap
	_rashod = maxi(1, int(w.get("ammo_per_shot", 1)))
	_reload_time = float(w.get("reload", 0.0)) / u.TPS
	_reload_left = 0
	_pellets = maxi(1, int(w.get("pellets", 1)))
	_deviation = float(w.get("spread", 0.0))
	_dop_effect = str(w.get("dop_effect", ""))
	_dop_damage = float(w.get("dop_damage", 0.0))
	_dop_chance = float(w.get("dop_chance", 1.0))
	if thrown:
		_burst_len = 0
		_shot_chance = u.THROW_CHANCE
		_blind_chance = 0.0
		_need_sight = true
	else:
		_shot_chance = u.SINGLE_SHOT
		_blind_chance = u.BLIND_SHOT
		_need_sight = false
		if _burst_len <= 0 and int(w.get("mag", 0)) > 10:
			_burst_len = int(round(float(w.get("mag", 0)) * 0.5))
	_chase_shot = true
	u._move._backpedal = u._krep != 0 and not u._flying
	u._melee._melee_while_chase = false
	u._melee._ram_while_chase = false
	u._close_chance = 0.0
	u._move._chase_mul = 1.0

func _weapon_row(wid: String) -> Dictionary:
	u._ensure_catalog()
	var found: Variant = u._weapon_catalog.get(wid, {})
	if found is Dictionary and not (found as Dictionary).is_empty():
		return (found as Dictionary).duplicate(true)
	return {}

func _launch(target: Vector2, w: Dictionary, friendly: bool, use_main_cd: bool, aim_down: bool) -> void:
	if u.bullet_scene == null or (u._cannot_fight() and not u._last_rites):
		return
	var main := use_main_cd
	if main and _mag_cap > 0:
		if _reload_left > 0.0:
			return
		if _mag < _rashod:
			_reload_left = u._ticks(_reload_time)
			return
		_mag -= _rashod
	if use_main_cd:
		u._attack_cd = u._ticks(u._melee._strike_cd)
	var start := _muzzle_clear()
	var shots := _pellets if main else maxi(1, int(w.get("pellets", 1)))
	var dev := _deviation if main else float(w.get("spread", 0.0))
	var mazil := _mazil if main else 0.0
	for _p in shots:
		_launch_one(start, target, w, friendly, aim_down, dev, mazil)



## Weapon.shoot from the barrel. A barrel inside a wall fires from the wall face instead.
func _muzzle_clear() -> Vector2:
	var at := u._held_weapon.muzzle() if u._held_weapon != null and u._held_weapon.shown() else u.muzzle.global_position
	var from := u.global_position + Vector2(0.0, -u._body_size(u).y * 0.5)
	var space := u.get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(from, at, 1)
	ray.exclude = [u.get_rid()]
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return at
	var dir := (at - from).normalized()
	return Vector2(hit["position"]) - dir * 2.0

func _launch_one(start: Vector2, target: Vector2, w: Dictionary, friendly: bool, aim_down: bool, dev: float, mazil: float) -> void:
	var bullet := u.bullet_scene.instantiate() as Area2D
	if bullet == null:
		return
	bullet.global_position = start
	var thrown := _thrown
	var dam := _bullet_damage
	var tip := _bullet_type
	var px_speed := _bullet_speed
	var blast := _blast
	var fuse := _fuse
	var dop := _dop_effect
	var dop_d := _dop_damage
	var dop_c := _dop_chance
	if not w.is_empty():
		var kind := str(w.get("kind", ""))
		var delivery := str(w.get("delivery", ""))
		thrown = kind == "explosives" or delivery == "grenade"
		dam = int(round(float(w.get("damage", dam))))
		tip = str(w.get("damage_type", tip))
		px_speed = maxf(float(w.get("speed", 12.0)) * u.TPS, 40.0)
		blast = float(w.get("radius", 0.0))
		var expl := float(w.get("damage_expl", 0.0))
		if thrown or (expl > 0.0 and blast > 0.0):
			dam = int(round(expl if expl > 0.0 else float(dam)))
		fuse = maxf(float(w.get("fuse", 75.0)) / u.TPS, 0.05)
		dop = str(w.get("dop_effect", ""))
		dop_d = float(w.get("dop_damage", 0.0))
		dop_c = float(w.get("dop_chance", 1.0))
	var aim := target - bullet.global_position
	var direction := aim.normalized() if aim.length_squared() > 1.0 else Vector2(u.facing, 0.0)
	if aim_down:
		direction = Vector2(0.2 * u.facing, 1.0).normalized()
	# Weapon.shoot: (rand - 0.5) * (deviation / skill + mazil) degrees.
	var spread := dev / (u._weapon_skill + 0.01) + mazil
	if spread > 0.0:
		direction = direction.rotated(deg_to_rad((Rng.randf(&"combat") - 0.5) * spread))
	if u._blind_t > 0.0 and Rng.randf(&"combat") < 0.6:
		direction = Vector2.from_angle(Rng.randf(&"combat") * TAU)
	bullet.from_player = friendly
	if not friendly and u.fraction > 0:
		bullet.fraction = u.fraction
	bullet.speed = px_speed
	bullet.damage = maxi(1, dam)
	bullet.damage_type = tip
	bullet.block_damage = u._Block.of(str(w.get("id", "")))
	bullet.dop_effect = dop
	bullet.dop_damage = dop_d
	bullet.dop_chance = dop_c
	if str(w.get("id", "")) == "bomb":
		bullet.global_position = u.global_position
		bullet.use_velocity = true
		bullet.velocity = Vector2(0.0, 40.0)
		bullet.direction = Vector2.DOWN
		bullet.fall_accel = u.GRAVITY
		bullet.lifetime = fuse
		bullet.blast_radius = blast
		bullet.explode_on_timeout = blast > 0.0
	elif thrown:
		bullet.use_velocity = true
		bullet.fall_accel = u.GRAVITY
		var arc := direction
		arc.y -= 0.65
		if arc.length_squared() < 0.01:
			arc = Vector2(u.facing, -0.6)
		bullet.velocity = arc.normalized() * px_speed
		bullet.direction = bullet.velocity.normalized()
		bullet.lifetime = fuse
		bullet.blast_radius = blast
		bullet.explode_on_timeout = blast > 0.0
	else:
		bullet.direction = direction
		if blast > 0.0:
			bullet.blast_radius = blast
	var host := u.get_tree().current_scene
	if host == null:
		bullet.queue_free()
		return
	bullet.weapon_id = str(w.get("id", ""))
	bullet.set_meta("owner_unit", u)
	host.add_child(bullet)

func _configure_vortex() -> void:
	u._species_id = "vortex"
	u._flying = true
	u._friendly = false
	u.fight_style = "melee"
	u._melee._contact_bite = true
	_chase_shot = false
	u.melee_damage = 12
	_bullet_type = "DAM_PIERCE"
	u.max_hp = 15
	u.points = 30
	u.body_size = Vector2(30.0, 30.0)
	u.move_speed = 4.0 * u.TPS
	u.run_speed = 12.0 * u.TPS
	u._melee._attack_reach = 80.0
	u._melee._strike_cd = 0.4
	u._sheet_native = false
	u._can_lift = false

