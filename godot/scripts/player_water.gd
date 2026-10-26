extends RefCounted

## UnitPlayer in water and the room's air, for player.gd.
## - Unit.checkWater: isPlav when the tile at y - h * 0.75 is water (swimming,
##   stay and sit off), inWater when that or, for bodies taller than a tile,
##   the tile at y - h * 0.25 is (wading).
## - UnitPlayer.forces / control while isPlav: velocity.Y += ddy * ddyPlav,
##   then velocity.Y * 0.8; keyJump or keyBeUp swim up by plavdy (accel * 0.5), keySit
##   down by half that; maxSpeed plavSpeed (walkSpeed * 0.75) at accel * 0.3,
##   the airborne 0.1 * brake. Wading halves velocity.X each tick.
##   Coming up, jumpp is recharged to 5 ticks so a held jump leaves the water.
## - UnitPlayer.actions: drad += loc.rad, plus loc.wrad in water; Unit wdam
##   every 30 ticks in water; Unit 'namok' every 100 ticks swimming.
## Rates are per 30 Hz tick in the original; here they are px/s.

const TPS := 30.0
const TILE := 40.0
const DDY := 900.0
const MAXDY := 600.0
const DDY_PLAV := 1.0
const PLAV_DRAG := 0.8
## walkSpeed 7 * 0.75, accel 3.5 * 0.5, accel 3.5 * 0.3, brake 2 * 0.1, all per tick.
const PLAV_SPEED := 157.5
const PLAV_DY := 1575.0
const PLAV_ACCEL := 945.0
const PLAV_BRAKE := 180.0
const WADE_DRAG := 0.5
const JUMP_RECHARGE := 5.0 / 30.0
const _Flags := preload("res://scripts/map/room_flags.gd")
const _UnitWater := preload("res://scripts/map/unit_water.gd")
const _UnitMassa := preload("res://scripts/unit_massa.gd")
## player.gd BODY_SIZE.x.
const WIDTH := 50.0

var in_water := false
var is_plav := false
var _acc := 0.0
var _t_hp := 0
var _namok_t := 0
var _stay_dam := 0
var _electro_room := Vector2i(-9999, -9999)


func check(body: Node2D, height: float) -> void:
	var at := body.global_position
	var was := in_water
	is_plav = _Flags.water_at(at - Vector2(0, height * 0.75))
	GameState.set_swimming(is_plav)
	in_water = is_plav or (height > TILE and _Flags.water_at(at - Vector2(0, height * 0.25)))
	if (was != in_water or in_water) and body is CharacterBody2D:
		_UnitWater.splash(body.get_tree(), at, height, WIDTH, was, in_water, is_plav,
			(body as CharacterBody2D).velocity / TPS, _UnitMassa.massa_of("littlepip"), not GameState.is_dead())


## One swimming step. Returns the walk direction used.
func swim(body: CharacterBody2D, delta: float, up: bool, down: bool, key_left: bool, key_right: bool, speed_mult: float) -> int:
	var v := body.velocity
	# Pers speedPlavMult (top speed, accel, swim up) and gg.ddyPlav: potion_swim sets 2 and 0.
	var plav := Effects.stat("speedPlavMult", Progression.pers("speedPlavMult", 1.0))
	speed_mult *= plav
	v.y += DDY * Effects.stat("ddyPlav", DDY_PLAV) * delta
	v.y *= pow(PLAV_DRAG, delta * TPS)
	if up:
		v.y -= PLAV_DY * plav * delta
	elif down:
		v.y += PLAV_DY * 0.5 * delta
	var walk := 0
	if key_left and not key_right:
		walk = -1
	elif key_right and not key_left:
		walk = 1
	var top := PLAV_SPEED * speed_mult
	if walk != 0 and v.x * walk < top:
		v.x = minf(v.x * walk + PLAV_ACCEL * speed_mult * delta, top) * walk
	elif walk != 0:
		v.x = maxf(v.x * walk - PLAV_BRAKE * delta, top) * walk
	else:
		v.x = move_toward(v.x, 0.0, PLAV_BRAKE * delta)
	body.velocity = v
	return walk


func wade(body: CharacterBody2D, delta: float) -> void:
	if in_water and not is_plav:
		body.velocity.x *= pow(WADE_DRAG, delta * TPS)


## UnitPlayer.forces over Tile.gravity (Area grav lifts), read at y - h / 4:
## velocity.Y += ddy * gravity while below maxdy * gravity; a lift also brakes
## velocity.X by 0.8 per tick. The walk step already added ddy once when airborne.
## True inside a lift.
func lift(body: CharacterBody2D, delta: float, height: float) -> bool:
	var g := _Flags.gravity_at(body.global_position - Vector2(0, height * 0.25))
	if g == 1.0:
		return false
	var v := body.velocity
	if not body.is_on_floor():
		v.y -= DDY * delta
	if (g > 0.0 and v.y < MAXDY * g) or (g < 0.0 and v.y > MAXDY * g):
		v.y += DDY * g * delta
	if g < 0.0:
		v.x *= pow(0.8, delta * TPS)
	body.velocity = v
	return true


## Radiation and water damage at 30 Hz.
func tick(body: Node2D, delta: float) -> void:
	_acc += delta * TPS
	while _acc >= 1.0:
		_acc -= 1.0
		_step(body)


func _step(body: Node2D) -> void:
	var env := _Flags.env_at(body.global_position)
	if env.is_empty() or GameState.is_dead():
		return
	if not bool(body.get_meta("no_rad", false)):
		var drad := float(env.get("rad", 0.0))
		if in_water:
			drad += float(env.get("wrad", 1.0))
		if drad > 0.0:
			GameState.rad_exposure(drad)
	body.set_meta("no_rad", false)
	var wdam := float(env.get("wdam", 0.0))
	if in_water and wdam > 0.0:
		if _t_hp <= 0:
			_t_hp = 30
			GameState.apply_damage_f(wdam, str(env.get("wtipdam", "DAM_VENOM")), true)
	if _t_hp > 0:
		_t_hp -= 1
	if is_plav:
		_namok_t += 1
		if _namok_t >= 100:
			_namok_t = 0
			Effects.add(body, "namok")
	elif _namok_t > 0:
		_namok_t -= 1
	_electro_step(body, env)


## UnitPlayer electric field (Location.electroDam from closed elpanels): on
## entering the room "electroOn" and 45 ticks of grace; then, standing on or
## touching metal, on a ladder or in water, electroDamage every 20 ticks.
func _electro_step(body: Node2D, env: Dictionary) -> void:
	var cell := _Flags.cell_of(body.global_position)
	if not env.has("electro"):
		var land := _Flags.active_land()
		var actors := land.get_node_or_null("Actors") if land != null else null
		env["electro"] = actors.room_electro(cell) if actors != null and actors.has_method("room_electro") else 0.0
	var dam := float(env.electro)
	if cell != _electro_room:
		_electro_room = cell
		if dam > 0.0:
			_stay_dam = 45
			var hud := body.get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_notice"):
				hud.show_notice(OriginalLines.info("electroOn"))
	if _stay_dam > 0:
		_stay_dam -= 1
	if dam <= 0.0 or _stay_dam > 0:
		return
	if in_water or bool(body.get("_climbing")) or _touches_metal(body):
		_stay_dam = 20
		GameState.apply_damage_f(dam, "DAM_ELECTRIC", true)


func _touches_metal(body: Node2D) -> bool:
	if not body is CharacterBody2D:
		return false
	var cb := body as CharacterBody2D
	for i in cb.get_slide_collision_count():
		var hit := cb.get_slide_collision(i).get_collider()
		if hit is Object and str(hit.get_meta("surface", "")) == "metal":
			return true
	return false
