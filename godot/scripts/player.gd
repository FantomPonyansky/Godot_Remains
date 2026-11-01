extends CharacterBody2D

## Player body. _enter_tree calls Run.register_player (eid p<id>).
## _physics_process samples LocalInput once per tick: cooldowns run, then
## control_off or GameState.ui_hold() takes _control_off_step and skips the rest.
## After that: climb, water, move_and_slide, and the shot. GameState holds the pools.
## Pose, weapons, and spells are methods on this body.

# littlepip from units.xml and Pers.defaultParams. The original steps at
# 30 ticks/s (Engine.TPS) and a tile is 40px.
# walkSpeed 7 px/tick = 210 px/s. Pers.runSpeedMult defaults to 2, so
# runSpeed is 420 px/s while sprinting on the ground. Crouch stays at sitSpeed.
# jumpdy 12 px/tick = -360 px/s, reapplied for up to maxjumpp (8) ticks.
# djumpdy starts at 6 px/tick (-180 px/s) and gains 1 px/tick per Telekinesis point.
# The air jump lasts maxdjumpp (10) ticks and exists only with perk levitation.
# Hover is perk selflevit, and only after that air jump (or a second press without it).
# Gravity GameContainer.ddy is 1 px/tick^2 = 900 px/s^2.
# Terminal velocity maxdy is 20 px/tick = 600 px/s.
# lazSpeed = walk * 0.75 = 157.5 px/s.
# Self-levitation rises at levidy * 0.7 (levidy = accel 3.5 * 0.25) and
# Unit.forces multiplies velocity by 0.8 each tick, which balances near 92 px/s.
const _PS := preload("res://scripts/prop_state.gd")
const _BALANCE := "res://assets/data/balance/player.json"
static var _balance_loaded := false
static var SPEED := 210.0
# walkSpeed * runSpeedMult. Trauma legs scale this through sprint_speed_mult.
static var RUN_SPEED := 420.0
# littlepip accel 3.5 px/tick^2. !stay uses 0.1 * accel.
static var ACCEL := 3150.0
static var AIR_ACCEL := 315.0
# UnitPlayer.brake 2 px/tick^2. Sitting brakes at 0.4x, airborne at 0.1x.
static var BRAKE := 1800.0
# Holding keyRun, control() accelerates only once t_run > 3 (ticks).
static var RUN_DELAY := 3
# Air jump side kick may not leave |dx| above 25 px/tick.
static var DJUMP_CAP := 750.0
# Diagonal (stair) maxSpeed is walkSpeed * 0.75 and isRun has no effect there.
static var STAIR_SCALE := 0.75
# Unit.porog while walking on the ground. porog_jump is 10 only for (isRun || keyBeUp) with jumpNumb 0.
static var POROG := 20.0
static var POROG_JUMP := 10.0
# Unit.run plays sndFall above 5 px/tick and makes noise above 9 and 16 px/tick.
static var FALL_SOUND := 150.0
static var FALL_NOISE_HALF := 270.0
static var FALL_NOISE_FULL := 480.0
static var NOISE_RUN := 200.0
# Bullet.otbros for hits that carry no weapon knock. 5 is the usual char_knock.
static var KNOCK_DEFAULT := 5.0
# UnitPlayer.sitSpeed is walkSpeed * 0.5 while sitting on the ground.
static var SIT_SCALE := 0.5
static var CLIMB_SPEED := 157.5
# keySit on a ladder sets velocity.Y = lazSpeed * 1.5.
static var CLIMB_DOWN_MULT := 1.5
const TILE_HALF := 20.0
static var JUMP_VELOCITY := -360.0
static var GRAVITY := 900.0
static var LEVITATE_SPEED := 92.0
static var MAX_FALL := 600.0
# maxjumpp 8 ticks, maxdjumpp 10 ticks. Divided by the 30 Hz step in _load_balance.
static var JUMP_SUSTAIN := 8.0 / 30.0
static var AIR_JUMP_HOLD := 10.0 / 30.0
const PLATFORM_LAYER_BIT := 7
static var DROP_TIME := 0.28
# Pers.teleDist is 600*600. Perk telemaster raises the squared distance to 640000 (800px).
static var TELE_RADIUS := 600.0
static var TELE_RADIUS_MASTER := 800.0
# actTele snaps to the nearest object within 50px of the cursor (mindist 2500).
static var TELE_SNAP := 50.0
# GameContainer.maxdelta. Box.run tests tiles at least this often so a carry cannot tunnel.
static var CARRY_STEP := 9.0
# GameContainer.actionDist is 40000, a squared 200px. Walk cap is 3 px/tick.
static var ACTION_REACH := 200.0
static var ACTION_CREEP := 90.0
# units.xml littlepip sX is 50. stay frame 1 is 65 opaque pixels, drawn at 1.2
# so hoof-to-ear is 78px. Width stays 50 so an 80px shaft still fits.
# Crouch stays 34px tall so a 40px hatch still clears.
const BODY_SIZE := Vector2(50, 78)
## Collision width on a ladder: fits the 40 px tile when the 50 px body is pinned to its rail side.
const CLIMB_BOX_W := 28.0
const CROUCH_SIZE := Vector2(50, 34)
# UnitPlayer.ratX / ratY while potion_rat is on.
const RAT_SIZE := Vector2(30, 17)
# items.xml spells with atk='1'. Spell.cast refuses them while atkPoss is 0.
const _ATK_SPELLS := ["sp_mwall", "sp_blast", "sp_cryst", "sp_mshit", "sp_moon", "sp_gwall", "sp_invulner"]
# weapons.xml punch, swung by WKick. rapid is 13 ticks. The blow lands once
# t_attack has counted down to rapid - 8. Kick (keyRun) doubles damage,
# reaches 70px the other way, and breaks blocks with Pers.kickDestroy (30).
static var HOOF_DAMAGE := 10.0
static var HOOF_DESTROY := 4.0
static var KICK_DESTROY := 30.0
# rapid 13 ticks, windup 8 ticks. Divided by the 30 Hz step in _load_balance.
static var HOOF_RAPID := 13.0 / 30.0
static var HOOF_WINDUP := 8.0 / 30.0
static var HOOF_NEAR := 20.0
static var HOOF_FAR := 60.0
static var KICK_FAR := 70.0
const HOOF_TYPE := "DAM_BLUNT"
# Pers.meleeR / meleeS / meleeRun. The grip may travel at most meleeR from the
# shoulder anchor. meleeRun is px per 30 Hz tick. WClub steps the blade every 10px.
static var MELEE_RANGE := 100.0
static var MELEE_SIDE := 40.0
static var MELEE_RUN := 10.0
static var MELEE_SAMPLE := 10.0
static var MELEE_THRUST := 100.0
# UnitPon.footstepVol 0.2. Sound.stepVol scales walk and ladder steps. sndFall does not.
static var FOOT_VOL := 0.2
# mtip from weapons.json. Missing means a swing (0). 1 thrusts, 2 saws.
const MELEE_MTIP := {
	"spear": 1, "spear^1": 1, "tlance": 1, "mspear": 1, "mspear^1": 1,
	"ripper": 2, "ripper^1": 2, "autoaxe": 2, "bsaw": 2,
}
const _Block := preload("res://scripts/block_destroy.gd")
const _RoomActivity := preload("res://scripts/map/room_activity.gd")
const _Lock := preload("res://scripts/lock_use.gd")
const _WeaponVis := preload("res://scripts/weapon_vis.gd")
const _FxClip := preload("res://scripts/fx_clip.gd")
const _Aura := preload("res://scripts/magic_aura.gd")
const _ImpactFx := preload("res://scripts/impact_fx.gd")
const _WorkAnim := preload("res://scripts/player_work_anim.gd")
const _UnitMassa := preload("res://scripts/unit_massa.gd")
const _Water := preload("res://scripts/player_water.gd")
const _Move := preload("res://scripts/player_move.gd")
const _Weapons := preload("res://scripts/player_weapons.gd")
const _Spells := preload("res://scripts/player_spells.gd")
const _Melee := preload("res://scripts/player_melee.gd")
const _Senses := preload("res://scripts/player_senses.gd")
const _Flags := preload("res://scripts/map/room_flags.gd")
const _Sats := preload("res://scripts/sats.gd")
const _Wheel := preload("res://scripts/weapon_wheel.gd")
const _QuickKeys := preload("res://scripts/quick_keys.gd")
## UnitPlayer dash 22 and dash_dy -2 px a tick, dash_maxt 30 ticks.
## px/tick times the 30 Hz step, applied in _load_balance.
static var DASH_SPEED := 22.0 * 30.0
static var DASH_DY := -2.0 * 30.0
static var DASH_MAXT := 30.0
const _LandRegistry := preload("res://scripts/map/land_registry.gd")

var _water: _Water = _Water.new()
var _move: _Move
var _weapons_c: _Weapons
var _spells: _Spells
var _melee_c: _Melee
var _senses: _Senses
var sats: Node

@export var bullet_scene: PackedScene

@onready var puppet: Node2D = $Puppet
@onready var muzzle: Marker2D = $Muzzle
@onready var hurtbox: Area2D = $Hurtbox
@onready var ladder_detector: Area2D = $LadderDetector
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _hurt_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var _ladder_shape: CollisionShape2D = $LadderDetector/CollisionShape2D

var facing: float:
	get:
		return _move.facing
	set(v):
		_move.facing = v
var aim_dir: Vector2:
	get:
		return _weapons_c.aim_dir
	set(v):
		_weapons_c.aim_dir = v
var _fire_cd: float:
	get:
		return _weapons_c._fire_cd
	set(v):
		_weapons_c._fire_cd = v
var _invuln := 0
var control_off: bool:
	get:
		return _move.control_off
	set(v):
		_move.control_off = v
var _climbing: bool:
	get:
		return _move._climbing
	set(v):
		_move._climbing = v
var levit: int:
	get:
		return _spells.levit
	set(v):
		_spells.levit = v
var tele_holder: Node:
	get:
		return _spells.tele_holder
	set(v):
		_spells.tele_holder = v
var frac_levit: int:
	get:
		return _spells.frac_levit
	set(v):
		_spells.frac_levit = v
var dam_wall: float:
	get:
		return _spells.dam_wall
	set(v):
		_spells.dam_wall = v
var t_throw: int:
	get:
		return _spells.t_throw
	set(v):
		_spells.t_throw = v
var _shit_hp: float:
	get:
		return _spells._shit_hp
	set(v):
		_spells._shit_hp = v
var _tele_obj: Node2D:
	get:
		return _spells._tele_obj
	set(v):
		_spells._tele_obj = v
## Pers.portTime / portDown are ticks, portMagic the magic bar, portMana Pers.manaHP.
static var PORT_TIME := 25.0
static var PORT_DOWN := 300.0
static var PORT_MAGIC := 950.0
static var PORT_MANA := 25.0
const _PORT_CEL := "res://assets/sprites/gui/port_cel_%d.png"
var _weapons: Array:
	get:
		return _weapons_c._weapons
	set(v):
		_weapons_c._weapons = v
var _weapon_i: int:
	get:
		return _weapons_c._weapon_i
	set(v):
		_weapons_c._weapon_i = v
var _mag_rounds: Dictionary:
	get:
		return _weapons_c._mag_rounds
	set(v):
		_weapons_c._mag_rounds = v
var _reload_left: float:
	get:
		return _weapons_c._reload_left
	set(v):
		_weapons_c._reload_left = v
var _reload_id: String:
	get:
		return _weapons_c._reload_id
	set(v):
		_weapons_c._reload_id = v
var _semi_lock: bool:
	get:
		return _weapons_c._semi_lock
	set(v):
		_weapons_c._semi_lock = v
var _sit: bool:
	get:
		return _move._sit
	set(v):
		_move._sit = v
# Knock vector (px/tick, times otbros) of the bullet being applied right now.
# HitInfo.knock is copied here for the blood spray. Zero still means the
# contact scan, unless the hit is contact and names its source.
var _hit_knock: Vector2 = Vector2.ZERO
var eid: String = ""
## Run player id; input reads pass it to LocalInput.
var pid: int = 0


## This player's state (health, bag, effects...). The autoload facades read
## the local player's; code that must work for any player reads this.
func character() -> RefCounted:
	return Run.character(pid)
var kind: StringName = &"player"
var authority: bool = true
var faction: int = 100
var _use_node: Node = null
var _use_left: int = 0
var _use_max: int = 1
var _use_reach: float = 200.0
var _use_bar: Node2D = null
var _interact_frame := -1
var sky_mode:
	get:
		return _move.sky_mode
	set(v):
		_move.sky_mode = v
var _is_fly:
	get:
		return _move._is_fly
	set(v):
		_move._is_fly = v
var rat:
	get:
		return _move.rat
	set(v):
		_move.rat = v

const _Resistances := preload("res://scripts/resistances.gd")
const _Barrier := preload("res://scripts/magic_barrier.gd")
const _Moon := preload("res://scripts/moonblade.gd")
static var SHIT_ARMOR := 20
const TYPE_LABELS := {
	"DAM_PIERCE": "bullet",
	"DAM_LASER": "laser",
	"DAM_BURN": "fire",
	"DAM_PLASMA": "plasma",
	"DAM_EXPLOSION": "explosion",
}


func _init() -> void:
	_move = _Move.new(self)
	_weapons_c = _Weapons.new(self)
	_spells = _Spells.new(self)
	_melee_c = _Melee.new(self)
	_senses = _Senses.new(self)
	_load_balance()
	_move._max_speed = SPEED
	_use_reach = ACTION_REACH


## One read of balance/player.json. Tick counts stay in the file; * 30 and / 30 stay here.
static func _load_balance() -> void:
	if _balance_loaded:
		return
	_balance_loaded = true
	var raw: Variant = DataLib.load(_BALANCE)
	if raw is not Dictionary:
		return
	var d := raw as Dictionary
	SPEED = float(d.get("speed", SPEED))
	RUN_SPEED = float(d.get("run_speed", RUN_SPEED))
	ACCEL = float(d.get("accel", ACCEL))
	AIR_ACCEL = float(d.get("air_accel", AIR_ACCEL))
	BRAKE = float(d.get("brake", BRAKE))
	RUN_DELAY = int(d.get("run_delay", RUN_DELAY))
	DJUMP_CAP = float(d.get("djump_cap", DJUMP_CAP))
	STAIR_SCALE = float(d.get("stair_scale", STAIR_SCALE))
	POROG = float(d.get("porog", POROG))
	POROG_JUMP = float(d.get("porog_jump", POROG_JUMP))
	FALL_SOUND = float(d.get("fall_sound", FALL_SOUND))
	FALL_NOISE_HALF = float(d.get("fall_noise_half", FALL_NOISE_HALF))
	FALL_NOISE_FULL = float(d.get("fall_noise_full", FALL_NOISE_FULL))
	NOISE_RUN = float(d.get("noise_run", NOISE_RUN))
	KNOCK_DEFAULT = float(d.get("knock_default", KNOCK_DEFAULT))
	SIT_SCALE = float(d.get("sit_scale", SIT_SCALE))
	CLIMB_SPEED = float(d.get("climb_speed", CLIMB_SPEED))
	CLIMB_DOWN_MULT = float(d.get("climb_down_mult", CLIMB_DOWN_MULT))
	JUMP_VELOCITY = float(d.get("jump_velocity", JUMP_VELOCITY))
	GRAVITY = float(d.get("gravity", GRAVITY))
	LEVITATE_SPEED = float(d.get("levitate_speed", LEVITATE_SPEED))
	MAX_FALL = float(d.get("max_fall", MAX_FALL))
	JUMP_SUSTAIN = float(d.get("jump_sustain", 8.0)) / 30.0
	AIR_JUMP_HOLD = float(d.get("air_jump_hold", 10.0)) / 30.0
	DROP_TIME = float(d.get("drop_time", DROP_TIME))
	TELE_RADIUS = float(d.get("tele_radius", TELE_RADIUS))
	TELE_RADIUS_MASTER = float(d.get("tele_radius_master", TELE_RADIUS_MASTER))
	TELE_SNAP = float(d.get("tele_snap", TELE_SNAP))
	CARRY_STEP = float(d.get("carry_step", CARRY_STEP))
	ACTION_REACH = float(d.get("action_reach", ACTION_REACH))
	ACTION_CREEP = float(d.get("action_creep", ACTION_CREEP))
	HOOF_DAMAGE = float(d.get("hoof_damage", HOOF_DAMAGE))
	HOOF_DESTROY = float(d.get("hoof_destroy", HOOF_DESTROY))
	KICK_DESTROY = float(d.get("kick_destroy", KICK_DESTROY))
	HOOF_RAPID = float(d.get("hoof_rapid", 13.0)) / 30.0
	HOOF_WINDUP = float(d.get("hoof_windup", 8.0)) / 30.0
	HOOF_NEAR = float(d.get("hoof_near", HOOF_NEAR))
	HOOF_FAR = float(d.get("hoof_far", HOOF_FAR))
	KICK_FAR = float(d.get("kick_far", KICK_FAR))
	MELEE_RANGE = float(d.get("melee_range", MELEE_RANGE))
	MELEE_SIDE = float(d.get("melee_side", MELEE_SIDE))
	MELEE_RUN = float(d.get("melee_run", MELEE_RUN))
	MELEE_SAMPLE = float(d.get("melee_sample", MELEE_SAMPLE))
	MELEE_THRUST = float(d.get("melee_thrust", MELEE_THRUST))
	FOOT_VOL = float(d.get("foot_vol", FOOT_VOL))
	DASH_SPEED = float(d.get("dash_speed", 22.0)) * 30.0
	DASH_DY = float(d.get("dash_dy", -2.0)) * 30.0
	DASH_MAXT = float(d.get("dash_maxt", DASH_MAXT))
	PORT_TIME = float(d.get("port_time", PORT_TIME))
	PORT_DOWN = float(d.get("port_down", PORT_DOWN))
	PORT_MAGIC = float(d.get("port_magic", PORT_MAGIC))
	PORT_MANA = float(d.get("port_mana", PORT_MANA))
	SHIT_ARMOR = int(d.get("shit_armor", SHIT_ARMOR))


func _ready() -> void:
	# A 45 degree stair must stay floor, never wall.
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	ladder_detector.area_entered.connect(_move._on_ladder_entered)
	ladder_detector.area_exited.connect(_move._on_ladder_exited)
	_weapons_c._load_catalog()
	_spells._load_spellbook()
	var bags := get_node_or_null("/root/Inventory")
	if bags and bags.has_signal("changed") and not bags.changed.is_connected(_weapons_c._sync_owned):
		bags.changed.connect(_weapons_c._sync_owned)
	_weapons_c._sync_owned()
	# visualPlayer children: inh 3631, shit (visShit) and cryst 3687.
	_spells._inh_ring = _FxClip.make("fx_inh", Vector2(-1.0, -32.5), 1.54, [-1])
	_spells._inh_ring.z_index = -1
	add_child(_spells._inh_ring)
	_spells._shit_ring = _FxClip.make("fx_shit", Vector2(0, -40), 1.0, [20])
	_spells._shit_ring.z_index = 2
	add_child(_spells._shit_ring)
	_spells._crystal_ring = _FxClip.make("fx_cryst", Vector2(0, -40), 1.0, [5, 15])
	_spells._crystal_ring.z_index = 2
	add_child(_spells._crystal_ring)
	# invulnerFilter1/2 on vis.osn: GlowFilter(0xFF5555,1,2,2,3,3), GlowFilter(0xFF0000,1,7,7,1,3).
	for glow in [[Color(1.0, 0.333, 0.333), 3.0, 0.99], [Color(1.0, 0.0, 0.0), 1.0, 2.96]]:
		var aura := (load("res://scripts/magic_aura.gd") as GDScript).new() as Node2D
		aura.name = "BloodAura%d" % _spells._blood_auras.size()
		aura.set("host", puppet)
		aura.set("color", glow[0])
		aura.set("strength", glow[1])
		aura.set("sigma", glow[2])
		aura.set_meta("no_tele_glow", true)
		aura.set("alpha", 0.0)
		puppet.add_child(aura)
		_spells._blood_auras.append(aura)
	_melee_c._carried = Node2D.new()
	_melee_c._carried.name = "CarriedWeapon"
	_melee_c._carried.z_index = 3
	_melee_c._carried.visible = false
	add_child(_melee_c._carried)
	sats = _Sats.new()
	sats.name = "Sats"
	add_child(sats)
	var wheel := _Wheel.new()
	wheel.name = "WeaponWheel"
	add_child(wheel)
	var quick := _QuickKeys.new()
	quick.name = "QuickKeys"
	add_child(quick)


func _process(_delta: float) -> void:
	# Once per rendered frame, after the body moves. The edge is not read on the
	# next tick, or a door toggles back. Land props reads tk_claim after this.
	if GameState.paused or control_off or rat or GameState.ui_hold() or _WorkAnim.blocks_input(self):
		return
	_take_interact(_cursor_world())


## Subtractions of 1/30 until a seconds countdown hits 0, at 30 Hz.
func _hold_ticks(seconds: float) -> int:
	if seconds <= 0.0:
		return 0
	var left := seconds
	var n := 0
	var step := 1.0 / 30.0
	while left > 0.0 and n < 200000:
		left = maxf(0.0, left - step)
		n += 1
	return n


func _spend(ticks: int) -> int:
	return maxi(0, ticks - Sim.frame_steps)


func _physics_process(delta: float) -> void:
	if GameState.paused or _WorkAnim.blocks_input(self) or not authority:
		return

	_physics_cooldowns(delta)
	if control_off or GameState.ui_hold():
		_move._control_off_step(delta)
		return
	_physics_weapon_keys(delta)

	var cursor := Effects.forced_aim(_cursor_world())
	# changeWeapon("not") on potion_shadow / potion_rat; atkPoss 0 keeps it put away.
	if not GameState.attack_allowed() and not _weapon().is_empty():
		_weapons_c.holster()

	var move_x := LocalInput.axis(&"move_left", &"move_right", pid)
	if GameState.controls_swapped():
		move_x = -move_x
	var move_y := LocalInput.axis(&"aim_up", &"aim_down", pid)
	var key_left := move_x < -0.2
	var key_right := move_x > 0.2
	var on_ladder := _move._ladder_count > 0
	# A press that ended before this tick still hops for this one tick.
	var jump_held := LocalInput.held(&"jump", pid) or LocalInput.just_pressed(&"jump", pid)
	var jump_just := LocalInput.just_pressed(&"jump", pid)
	# pinok > 60 clears keyJump. The hold stays cut until the key comes up.
	if _move._jump_cut:
		if jump_held:
			jump_held = false
			jump_just = false
		else:
			_move._jump_cut = false
	var tk_held := LocalInput.held(&"telekinesis", pid) or LocalInput.just_pressed(&"telekinesis", pid)
	var down := LocalInput.held(&"aim_down", pid)
	var up := LocalInput.held(&"aim_up", pid)
	# A foe's Telekinesis.hold steers velocity. UnitPlayer.forces skips walking,
	# gravity and the 0.8 levit drag while teleHolder is set; jump only counts levit down.
	var tele_held := _spells._tick_held(jump_just)
	var held_v := velocity
	if tele_held:
		move_x = 0.0
		move_y = 0.0
		key_left = false
		key_right = false
		jump_held = false
		jump_just = false
		down = false
		up = false
		_climbing = false
		_move._levitating = false
	if not rat and not sky_mode and _senses._tick_lurk(delta, key_left, key_right, up, down, jump_just):
		move_x = 0.0
		move_y = 0.0
		key_left = false
		key_right = false
		jump_held = false
		jump_just = false
		down = false
		up = false
	var jump_step := _move._physics_jumps(delta, move_x, on_ladder, jump_held, jump_just, down, up)
	jump_held = bool(jump_step.jump_held)
	jump_just = bool(jump_step.jump_just)
	_move._physics_climb(delta, on_ladder, move_x, move_y, jump_just, up)
	_move._physics_traverse(delta, move_x, key_left, key_right, jump_held, jump_just, down, up)
	_physics_finish(delta, tk_held, cursor, tele_held, held_v, up, down, bool(jump_step.was_on_floor))

func _physics_cooldowns(delta: float) -> void:
	sats.step2(delta)
	_weapons_c._fire_ticks = _spend(_weapons_c._fire_ticks)
	_spells._spell_cd = _spend(_spells._spell_cd)
	_spells._cast_glow = maxf(0.0, _spells._cast_glow - delta)
	_invuln = _spend(_invuln)
	_move._drop_timer = _spend(_move._drop_timer)
	_melee_c._tick_hoof(delta)

func _physics_weapon_keys(delta: float) -> void:
	_move._poll_run(delta)
	_spells._tick_slow(delta)
	_spells._tick_spell_state(delta)
	_weapons_c._tick_weapon_change(delta)
	if _weapons_c._chw_left > 0.0 or rat or Effects.attack_forever():
		pass
	elif LocalInput.just_pressed(&"weapon_next", pid):
		_weapons_c._cycle_weapon(1)
	elif LocalInput.just_pressed(&"weapon_prev", pid):
		_weapons_c._cycle_weapon(-1)
	else:
		_weapons_c._poll_quick_slots()

func _physics_finish(delta: float, tk_held: bool, cursor: Vector2, tele_held: bool, held_v: Vector2, up: bool, down: bool, was_on_floor: bool) -> void:
	_tick_use(delta)
	_spells._update_telekinesis(tk_held and not rat, cursor, delta)
	_move._note_run_stamina()
	_move._step_up(delta, up, down)
	_move._auto_sit(delta, up)
	if tele_held:
		velocity = held_v
	var fall_vy := velocity.y
	var pre_v := velocity
	move_and_slide()
	_spells._tick_throw_wall(delta, pre_v)
	_move._landed(was_on_floor, fall_vy)
	_spells._tick_levit_glow(delta)
	_move._update_diagon()
	var pose := _move._pick_pose()
	# The punch label holds for t_work. Climb and hover keep their own clips.
	if _melee_c._hoof_work > 0.0 and pose != "climb" and pose != "levitate":
		pose = "kick" if _melee_c._hoof_kick else "punch"
	_move._pose = pose
	_move._apply_body_box(_sit)
	_move._footsteps(delta)
	_melee_c._tick_weapon_raise(delta, up)
	if puppet.has_method("set_magic_activity"):
		_spells._push_horn_glow()
	if puppet.has_method("update_pose") and not _WorkAnim.owns(self):
		puppet.update_pose(_move._pose, facing, aim_dir, delta)
	if rat:
		_move._pose_rat()
	if puppet.has_method("uses_lagged_aim") and puppet.uses_lagged_aim() and puppet.has_method("combat_aim_dir"):
		var lagged: Vector2 = puppet.combat_aim_dir()
		if lagged.length_squared() > 0.01:
			aim_dir = lagged
	_weapons_c._update_muzzle(cursor)
	var cursor_aim := aim_dir
	if _spells._spell_cd <= 0.0:
		# keyDef casts currentSpell, then keySpell1-4 cast their cells.
		if Inventory != null and LocalInput.just_pressed(&"cast_spell", pid):
			_spells._cast_quick(str(Inventory.spell_id), cursor_aim)
		var quick := ""
		if MagicBinds != null and MagicBinds.has_method("poll"):
			quick = str(MagicBinds.poll())
		if quick != "":
			_spells._cast_quick(quick, cursor_aim)
	_weapons_c._tick_weapon(delta)
	# currentWeapon.attack() runs only while t_work <= 0 (weapon change, punch).
	if _weapons_c._wants_shot(delta) and _fire_cd <= 0.0 and _weapons_c._magic_cd <= 0.0 and _reload_left <= 0.0 and _weapons_c._chw_left <= 0.0 and _melee_c._hoof_work <= 0.0:
		_weapons_c._try_shoot()
	_weapons_c._tick_throw_key(delta)
	_weapons_c._tick_magic_key(delta)
	_weapons_c._push_gun_state()
	# Attack is handled first, then keyReload, same order as UnitPlayer.
	_weapons_c._poll_reload()
	var blink := 0.45 if _invuln > 0 and fmod(float(_invuln) / 30.0, 0.1) < 0.05 else puppet.modulate.a
	puppet.modulate.a = blink
	_melee_c._tick_carried_weapon(delta, cursor)





func set_control_off(off: bool) -> void:
	_move.set_control_off(off)



func _cursor_world() -> Vector2:
	if sats != null and sats.firing():
		return sats.cel_point()
	return LocalInput.aim(pid)





func rat_on() -> void:
	_move.rat_on()


func rat_off() -> bool:
	return _move.rat_off()









func _weapon() -> Dictionary:
	return _weapons_c._weapon()



func _publish_weapon() -> void:
	_weapons_c._publish_weapon()










func _notice(text: String) -> void:
	Fx.notice(text, {"source": self})















func _razn(w: Dictionary) -> int:
	return _weapons_c._razn(w)



func _skill_mult(w: Dictionary) -> float:
	return _weapons_c._skill_mult(w)


func _skill_conf(w: Dictionary) -> float:
	return _weapons_c._skill_conf(w)







func weapon_status() -> int:
	return _weapons_c.weapon_status()











func _prec_mult(w: Dictionary, dir: Vector2) -> float:
	return _weapons_c._prec_mult(w, dir)









































func _play_if_present(name: String, volume: float = 1.0) -> void:
	if name == "":
		return
	var wav := "res://assets/sfx/%s.wav" % name
	var mp3 := "res://assets/sfx/%s.mp3" % name
	if ResourceLoader.exists(wav) or ResourceLoader.exists(mp3):
		Fx.sound(name, global_position, {"volume": volume, "source": self})































func _owns_perk(id: String) -> bool:
	return Progression.perk_rank(id) > 0







func _take_interact(cursor: Vector2) -> void:
	if not LocalInput.just_pressed(&"interact", pid):
		return
	var frame := Engine.get_process_frames()
	if _interact_frame == frame:
		return
	_interact_frame = frame
	if _tele_obj != null and is_instance_valid(_tele_obj):
		set_meta("tk_claim", true)
		_spells._throw_tele()
		return
	if _use_node != null:
		return
	_spells._try_tele_use(cursor)



















func _carried_massa(body: Node) -> float:
	return _spells._carried_massa(body)




func _drop_tele(trim: bool = true) -> void:
	_spells._drop_tele(trim)





func _tele_radius() -> float:
	return _spells._tele_radius()


func _tele_needs_los() -> bool:
	return _spells._tele_needs_los()



func _los_to(body: Node2D) -> bool:
	return _spells._los_to(body)


func tele_blocks_use(node: Node) -> bool:
	return _spells.tele_blocks_use(node)



func begin_use_timer(node: Node) -> void:
	if _use_node != null or node == null or not is_instance_valid(node):
		return
	var point := _use_point(node)
	var reach := ACTION_REACH
	if global_position.distance_squared_to(point) > ACTION_REACH * ACTION_REACH:
		reach = _tele_radius()
	var ticks := _Lock.action_ticks(node)
	_use_node = node
	_use_max = maxi(1, ticks)
	# actions() decrements on the same tick the use starts.
	_use_left = _use_max - 1
	_use_reach = reach
	_ensure_use_bar()
	_sync_use_bar()


func _tick_use(_delta: float) -> void:
	if _use_node == null:
		return
	if not LocalInput.held(&"interact", pid) or _use_blocked():
		_clear_use()
		return
	for _i in mini(Sim.frame_steps, 30):
		if _use_node == null:
			return
		if _use_left > 0:
			_use_left -= 1
		else:
			_sync_use_bar()
			_finish_use()
			return
	_sync_use_bar()


func _use_blocked() -> bool:
	if _use_node == null or not is_instance_valid(_use_node):
		return true
	if bool(_PS.getv(_use_node, "dead", false)) or bool(_PS.getv(_use_node, "spent", false)):
		return true
	if not bool(_PS.getv(_use_node, "usable", true)):
		return true
	var point := _use_point(_use_node)
	return global_position.distance_squared_to(point) > _use_reach * _use_reach


func _finish_use() -> void:
	var node := _use_node
	_clear_use()
	if node == null or not is_instance_valid(node):
		return
	for props in get_tree().get_nodes_in_group("land_props"):
		if props.has_method("commit_use"):
			props.commit_use(node)


func _clear_use() -> void:
	_use_node = null
	_use_left = 0
	if _use_bar:
		_use_bar.visible = false


func _use_point(node: Node) -> Vector2:
	if node is Node2D:
		return _body_center(node as Node2D)
	return global_position


func _ensure_use_bar() -> void:
	if _use_bar != null:
		return
	_use_bar = Node2D.new()
	_use_bar.name = "UseBar"
	_use_bar.z_index = 40
	var back := Polygon2D.new()
	back.name = "Back"
	back.color = Color(0.05, 0.05, 0.05, 0.8)
	back.polygon = PackedVector2Array([
		Vector2(-24, -3), Vector2(24, -3), Vector2(24, 3), Vector2(-24, 3)
	])
	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.color = Color(0.0, 154.0 / 255.0, 98.0 / 255.0, 1.0)
	var label := Label.new()
	label.name = "Caption"
	label.visible = false
	label.position = Vector2(-48, -20)
	label.size = Vector2(96, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("00ff99"))
	_use_bar.add_child(back)
	_use_bar.add_child(fill)
	_use_bar.add_child(label)
	add_child(_use_bar)


func _sync_use_bar() -> void:
	if _use_bar == null or _use_node == null or not is_instance_valid(_use_node):
		return
	_use_bar.visible = true
	var ratio := clampf(float(_use_max - _use_left) / float(_use_max), 0.0, 1.0)
	var width := 48.0 * ratio
	var fill := _use_bar.get_node("Fill") as Polygon2D
	fill.polygon = PackedVector2Array([
		Vector2(-24, -3), Vector2(-24 + width, -3), Vector2(-24 + width, 3), Vector2(-24, 3)
	])
	var label := _use_bar.get_node("Caption") as Label
	label.text = _Lock.action_text(_use_node)
	var point := _use_point(_use_node)
	var half_y := 16.0
	if _use_node is Node2D:
		var shape_node := (_use_node as Node2D).get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node and shape_node.shape is RectangleShape2D:
			half_y = (shape_node.shape as RectangleShape2D).size.y * 0.5
	_use_bar.global_position = point + Vector2(0, -half_y - 14)





func _cursor_gap(body: Node2D, cursor: Vector2) -> float:
	return _spells._cursor_gap(body, cursor)


func _body_center(body: Node2D) -> Vector2:
	return _spells._body_center(body)


func _aim_rect(body: Node2D) -> Rect2:
	return _spells._aim_rect(body)















func _levitate_difficulty(body: Node) -> float:
	return _spells._levitate_difficulty(body)


func _levitation_skill() -> float:
	return _spells._levitation_skill()
























func _roll_on_hit(node: Node, effect: String, dop: float, chance: float, dealt: int) -> void:
	if effect == "" or chance <= 0.0:
		return
	if chance < 1.0 and Rng.randf(&"combat") >= chance:
		return
	if node.has_method("apply_on_hit"):
		node.apply_on_hit(effect, dop, dealt)


## bullet.gd _roll_status: the weapon's dop effect on the player.
func apply_on_hit(effect: String, dop: float, dealt: int) -> void:
	Effects.player_hit(effect, dop, float(dealt))


## GameState health, magic and organ pools. The same dicts the run providers save.
func snapshot() -> Dictionary:
	return {"game": GameState.get_state(), "body": GameState.get_pools_state()}


func restore(d: Dictionary) -> void:
	if d.has("game"):
		GameState.set_state(d.game)
	if d.has("body"):
		GameState.set_pools_state(d.body)


func take_hit(hit: HitInfo) -> void:
	if hit == null:
		return
	if hit.tip != "" and not hit.resisted:
		set_meta("_hit_tip", hit.tip)
		_Resistances.apply_hit(self, hit)
		remove_meta("_hit_tip")
		return
	var tip := str(get_meta("_hit_tip", ""))
	var amount := _spells._shielded_amount(int(round(hit.amount)), tip)
	if amount <= 0:
		return
	if _invuln > 0.0 or control_off:
		return
	_invuln = _hold_ticks(GameState.hit_invuln_time())
	# UnitPlayer.damage: pinok grows with dam / maxhp, except for bleed, poison,
	# internal and pink cloud. Only a heavy pile-up breaks a climb or a hover.
	if not tip in ["DAM_BLEED", "DAM_POISON", "DAM_INTERNAL", "DAM_PINKCLOUD"]:
		var max_hp := maxi(1, int(GameState._max_health()))
		_move._pinok = minf(100.0, _move._pinok + float(amount) / float(max_hp) * 200.0)
		var owned := hit.knock != Vector2.ZERO
		if owned:
			_hit_knock = hit.knock
		var knock := _hit_knock
		if knock == Vector2.ZERO:
			if hit.contact and hit.source is Node2D and is_instance_valid(hit.source):
				knock = _knock_from(hit.source as Node2D)
			else:
				knock = _contact_knock()
		_otbros(knock)
	if _move._pinok > 60.0:
		if _move._levitating:
			_move._levitating = false
			_move._jump_cut = true
		if _tele_obj != null:
			_drop_tele()
	if _move._pinok > 30.0 and _climbing:
		_climbing = false
	GameState.apply_damage(amount, tip)
	_float_hit(amount, true)
	_blood_fx(float(amount), tip)
	if hit.knock != Vector2.ZERO:
		_hit_knock = Vector2.ZERO


## Unit.damage blood for the player: none in alicorn form.
func _blood_fx(dam: float, tip: String) -> void:
	if ScriptsEngine.alicorn or not tip in ["DAM_PIERCE", "DAM_CUT", "DAM_BLUNT", "DAM_BLEED", "DAM_BITE"]:
		return
	var shape := get_node_or_null("CollisionShape2D") as Node2D
	var mid := shape.global_position if shape != null else global_position
	if _hit_knock != Vector2.ZERO:
		var d := _hit_knock.normalized() * 5.0
		Fx.blood(mid, {"dx": d.x, "dy": d.y, "kol": int(Rng.randf(&"fx") * 5.0 + dam / 5.0), "source": self})
	else:
		Fx.blood(mid, {"kol": int(dam / 3.0), "source": self})


func _otbros(knock: Vector2) -> void:
	# Unit.otbros: sila = rnd(0.8..1.2) * knocked / massa, at most 3. littlepip is massa 1, knocked 1.
	if knock == Vector2.ZERO:
		return
	var sila := minf((Rng.randf(&"combat") * 0.4 + 0.8) * Effects.stat("knocked", 1.0), 3.0)
	velocity += knock * sila * 30.0


func _bullet_knock(area: Node) -> Vector2:
	# Bullet.knockx/knocky is the flight direction. otbros is the weapon's knock.
	var dir := Vector2.ZERO
	var vel: Variant = area.get("velocity")
	if area.get("use_velocity") == true and vel is Vector2 and (vel as Vector2).length_squared() > 0.01:
		dir = (vel as Vector2).normalized()
	else:
		var heading: Variant = area.get("direction")
		if heading is Vector2:
			dir = (heading as Vector2).normalized()
	var power := KNOCK_DEFAULT
	var own: Variant = area.get("otbros")
	if own != null:
		power = float(own)
	elif area.has_meta("otbros"):
		power = float(area.get_meta("otbros"))
	return dir * power


func _knock_from(body: Node2D) -> Vector2:
	var away := global_position - body.global_position
	if away.length_squared() < 1.0:
		away = Vector2(-facing, 0.0)
	return away.normalized() * KNOCK_DEFAULT


func _contact_knock() -> Vector2:
	# Melee and touch hits arrive without a bullet. Their blow flies from the
	# nearest enemy toward the player.
	var best: Node2D = null
	var best_d := 160.0
	for node in Units.near(global_position, best_d):
		var foe := node as Node2D
		if foe == null:
			continue
		var d := foe.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = foe
	if best == null:
		return Vector2.ZERO
	var away := global_position - best.global_position
	if away.length_squared() < 1.0:
		away = Vector2(-facing, 0.0)
	return away.normalized() * KNOCK_DEFAULT










func lurk_cut() -> float:
	return _senses.lurk_cut()


func dexter_now() -> float:
	return _senses.dexter_now()


func can_be_hit() -> bool:
	return _senses.can_be_hit()


func dodge_roll() -> bool:
	return _senses.dodge_roll()









func puppet_state() -> Dictionary:
	return {
		"a_jump": _move._did_jump,
		"sit": _sit,
		"walk": _move._walk_dir,
		"weapon_raised": _melee_c.weapon_raised,
	}


func _enter_tree() -> void:
	Run.register_player(self)


func _exit_tree() -> void:
	Run.unregister_player(self)
	if GameState:
		GameState.magic_locked = false
		GameState.set_running(false)











func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		take_hit(HitInfo.touching(12, body))


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_bullets"):
		var tip := "DAM_PIERCE"
		if "damage_type" in area:
			tip = str(area.damage_type)
		var shot := HitInfo.make(10, tip, area)
		shot.knock = _bullet_knock(area)
		shot.weapon_id = str(area.get("weapon_id"))
		take_hit(shot)
		area.queue_free()
	elif area.is_in_group("pickups"):
		if area.has_method("collect"):
			area.collect()


func _float_hit(amount: int, player_hit: bool) -> void:
	if amount <= 0:
		return
	Fx.float_number(amount, global_position, "player" if player_hit else "hit", {"source": self})
