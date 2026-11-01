extends CharacterBody2D

## Unit body for enemies, allies, and pets. land_props spawns scenes/enemy.tscn;
## brains in units/brain_*.gd call this body, and a unit with no catalog brain
## runs _decide, _sense, and _act here. Movement, guns, melee, and senses are
## enemy_move.gd, enemy_weapons.gd, enemy_melee.gd, and enemy_senses.gd on this
## same body; this script keeps the node and forwards only names other scripts use. Water is
## unit_water.gd.
## Groups: enemies and foe_bodies, or allies when _friendly. Outside room reach
## the body sleeps with physics off; state and position are kept.
## fraction is the faction. take_hit rolls 0.7-1.3 on Rng combat. Snapshot is
## Entity.captured.

const _Resistances := preload("res://scripts/resistances.gd")
const _Block := preload("res://scripts/block_destroy.gd")
const _UnitWater := preload("res://scripts/map/unit_water.gd")
const _UnitMassa := preload("res://scripts/unit_massa.gd")
const _HeldWeapon := preload("res://scripts/units/held_weapon.gd")
const _Desintegr := preload("res://scripts/desintegr_fx.gd")
const _Tele := preload("res://scripts/units/unit_telekinesis.gd")
const _PS := preload("res://scripts/prop_state.gd")
const _Move := preload("res://scripts/enemy_move.gd")
var _move: _Move
const _Senses := preload("res://scripts/enemy_senses.gd")
var _senses: _Senses
const _Weapons := preload("res://scripts/enemy_weapons.gd")
var _weapons: _Weapons
const _Melee := preload("res://scripts/enemy_melee.gd")
var _melee: _Melee
## The decisions of a unit without a UnitBrain (units/brain_generic.gd).
const _Generic := preload("res://scripts/units/brain_generic.gd")
var _generic: _Generic
const _Difficulty := preload("res://scripts/difficulty.gd")
## Unit comb / loc.earMult from the difficulty row. Read once per unit.
var _hp_mult: float = 1.0
static var SPEED: float = 0.0
const TILE_W := 40.0
## The player's ladder box width (player.gd CLIMB_BOX_W).
const CLIMB_BOX_W := 28.0
const PLATFORM_LAYER_BIT := 7
## play_land._add_ladder grab above the tile. Not part of the stair tile.
const LADDER_GRAB_UP := 36.0
static var GRAVITY: float = 0.0
static var ATTACK_COOLDOWN: float = 0.0
## Gunners (UnitRaider): 70% chance to hold and shoot inside 1000px when the
## sighting is fresh, and a 60% chance per tick to hop back inside 200px.
## Melee stops in the 50–100px band. Chase slack is only so bodies don't stack.
static var HOLD_RANGE: float = 0.0
static var HOLD_CHANCE: float = 0.0
static var HOLD_FRESH: int = 0
static var BACK_OFF_RANGE: float = 0.0
static var BACK_OFF_CHANCE: float = 0.0
static var SWING_MIN: float = 0.0
static var SWING_MAX: float = 0.0
static var SWING_HEIGHT: float = 0.0
static var BODY_SLACK: float = 0.0
## WalkMotor / Brain alert movement. Distances are original pixels.
static var LEVEL_SLACK: float = 0.0
static var REAIM_EVERY: int = 0
static var REAIM_DIST: float = 0.0
static var DURAK_REAIM: float = 0.0
static var SMART_REAIM: float = 0.0
static var JUMP_TICK: float = 0.0
static var ACCEL_RATIO: float = 0.0
static var AIR_CONTROL: float = 0.0
static var JUMP_BOOST: float = 0.0
static var HOP_POWER: float = 0.0
static var LEAP_POWER: float = 0.0
static var LEAP_SPEED: float = 0.0
static var JUMP_CD_MIN: float = 0.0
static var JUMP_CD_MAX: float = 0.0
static var HEAD_NEAR: float = 0.0
static var HEAD_FAR: float = 0.0
static var HEAD_AHEAD: float = 0.0
static var FAR_BELOW: float = 0.0
static var LEDGE_BRAKE: float = 0.0
static var LEDGE_BRAKE_AT: float = 0.0
static var TURN_MIN: int = 0
static var TURN_MAX: int = 0
static var SINGLE_SHOT: float = 0.0
static var BLIND_SHOT: float = 0.0
static var THROW_CHANCE: float = 0.0
static var SWING_CHANCE: float = 0.0
static var SWING_REACH: float = 0.0
static var CHARGE_SPEED: float = 0.0
static var WALL_GIVE: float = 0.0
## One land is a continuous grid. A room is 48?25 tiles at 40px.
const ROOM_W := 1920.0
const ROOM_H := 1000.0

## Original sim is 30 ticks/second (Engine.TPS). Distances below are in those pixels.
const TPS := 30.0
const SENSE_INTERVAL := 10.0 / TPS
static var REST_RECHECK: int = 0
static var GOAL_EVERY: int = 0

## Raider family senses. Scene enemies are generic raiders (units.xml id="raider"),
## not separate raider1–raider9 spawns. None of those variants set vision, ear, or
## vKonus, so they share this profile. raider7's observ="3" is the only sense
## tweak; these instances use observ 0. vKonus stays 0: raiders have no sight cone.
## Turrets are the units that set one (90° or 45°).
static var CALM_VISION: float = 0.0
static var ALERT_VISION: float = 0.0
static var V_KONUS: float = 0.0
static var V_ANGLE: float = 0.0
static var DETECTING: float = 0.0
static var EAR: float = 0.0
static var MAX_SPOK: int = 0
static var SIGHT_BONUS: int = 0
static var TARGET_MEMORY: int = 0
static var DRIFT_INTERVAL: int = 0
static var SEARCH_DRIFT: float = 0.0
static var GIVE_UP_SPOK: int = 0
static var MAX_OBS: float = 0.0
static var MINUS_OBS: float = 0.0
static var OBS_GRACE: float = 0.0
static var SURPRISE_MIN: float = 0.0
static var SURPRISE_MAX: float = 0.0
static var IDLE_MIN: float = 0.0
static var IDLE_MAX: float = 0.0
static var ALERT_MIN: float = 0.0
static var ALERT_MAX: float = 0.0
static var DETECT_DELAY: float = 0.0
static var WAKE_RADIUS: float = 0.0
## UnitTurret cone width is vKonus, tested at half that angle. Wall and boss
## turrets set HALF_PI (90°). The arm turret (turrettip 3, id turret3) sets
## QUARTER_PI (45°). The ceiling turret on this land is id "turret" (cid floor,
## turrettip 0): it never sets vKonus, and its gun watches 30°–150°, so the
## cone below is the 90° one, centered straight down.
const TURRET_CONE := PI * 0.5
const ARM_CONE := PI * 0.25
## UnitBloat: attRasst 400 unless the id sets attr. bloat0 is 600, bloat4/6/7 are 700.
## Parent comb damage 8, charge and neujazMax both 20 ticks.
static var BLOAT_RANGE: float = 0.0
static var BLOAT_TICKS: float = 0.0
## ebloat (UnitBloatEmitter) comb damage. The nest has no cone and no attRasst.
const EBLOAT_DAMAGE := 30
## UnitMonstrik scorpion claw. closeRange 80 / 80 above / 40 below, hold chance 0.7.
## PUNCH_TIME is 15 ticks. WPunch connects when t_attack == rapid - 5.
## Map id "scorp" is rolled to scorp1 here (hp 40); scorppunch damage is 12.
static var SCORP_X: float = 0.0
static var SCORP_ABOVE: float = 0.0
static var SCORP_BELOW: float = 0.0
static var SCORP_HOLD: float = 0.0
static var PUNCH_TICKS: float = 0.0
static var PUNCH_HIT: float = 0.0
static var PLAYER_VIS_STILL: float = 0.0
static var PLAYER_VIS_MOVE: float = 0.0
static var NOISE_RUN: float = 0.0
static var NOISE_DECAY: float = 0.0
static var DEMASK_DECAY: float = 0.0
static var FAST_DEMASK: float = 0.0
static var SHOT_DEMASK: float = 0.0

const ST_IDLE := 0
const ST_PATROL := 1
const ST_SEARCH := 2
const ST_CHASE := 3
const ST_HOLD := 4
const ST_SURPRISED := 5
const ST_FLEE := 6
const ST_DASH := 7
const ST_DASH_PREP := 8

## Unit.damage armor lists and E_Resistances.ARMOR_DAMAGE_TYPES (armor wear).
const ARMOR_PHYS := ["DAM_PIERCE", "DAM_CUT", "DAM_EXPLOSION", "DAM_BLUNT", "DAM_BITE", "DAM_ACID"]
const ARMOR_MAGIC := ["DAM_BURN", "DAM_LASER", "DAM_PLASMA", "DAM_ELECTRIC", "DAM_COLD", "DAM_ASTRO"]
const ARMOR_WEAR := ["DAM_PIERCE", "DAM_CUT", "DAM_BLUNT", "DAM_BURN", "DAM_EXPLOSION", "DAM_LASER",
	"DAM_PLASMA", "DAM_VENOM", "DAM_ELECTRIC", "DAM_ACID", "DAM_COLD", "DAM_BITE", "DAM_BALEFIRE", "DAM_ASTRO"]
## Unit.maxShok. A hit shocks for round((rand*0.8+0.2) * maxShok*4 * dam/maxhp), under 5 is none.
static var MAX_SHOK: int = 0
## Brain.alarm shock, ticks. UnitMonstrik and UnitAnt use 3–8.
static var ALARM_SHOCK_MIN: int = 0
static var ALARM_SHOCK_MAX: int = 0
## Brain_Definition levitWakeShock / levitHoldShock. UnitRaider: 45 and 0.
static var LEVIT_WAKE_SHOCK: int = 0
static var LEVIT_HOLD_SHOCK: int = 0
static var RAIDER_LEVIT_WAKE: int = 0
## Brain.STUN_RECHECK: a stunned unit idles and decides again 3 ticks after.
static var STUN_RECHECK: float = 0.0
## GunAttack_Definition mazil (extra spread, degrees).
static var HOLD_SPREAD: float = 0.0
static var MOVE_SPREAD: float = 0.0
## UnitRaider: surprise lasts tupizna to tupizna + 19; close fighters a quarter of tupizna.
static var TUPIZNA: int = 0
static var SURPRISE_SPREAD: int = 0
## Brain_Definition default surprise for Brain units outside the raider family.
static var BRAIN_SURPRISE_MIN: float = 0.0
static var BRAIN_SURPRISE_MAX: float = 0.0
## UnitRaider.DEATH_THROWS and DROP_SCATTER.
static var DEATH_THROWS: int = 0
static var DROP_SCATTER: float = 0.0
## Unit.budilo: makeNoise(noiseRun * 1.2). Unit.noiseRun default 200.
static var UNIT_NOISE_RUN: float = 0.0
## A Location is one room. Only units in the player's room act there; here the
## rooms next to it act too. Sight is capped at one room width for the same reason.
static var ACTIVE_REACH: int = 0
static var CHASE_REACH: int = 0
const SIGHT_CAP := ROOM_W
static var ROOM_CHECK_TICKS: int = 0
## WalkMotor: porog step-up, Brain DROP_THROUGH / FLOOR_MARGIN / STEP_UP_OFF.
static var STEP_UP: float = 0.0
static var STEP_UP_OFF: float = 0.0
static var DROP_THROUGH: float = 0.0
static var FLOOR_MARGIN: float = 0.0
## UnitRaider dangers: GRENADE_CHECK 10 ticks at 0.2, MINE_CHECK 30, flee 20–84 ticks.
static var GRENADE_CHECK: int = 0
static var GRENADE_CHECK_CHANCE: float = 0.0
static var MINE_CHECK: int = 0
static var MINE_FLEE_RANGE: float = 0.0
static var MINE_SUSPICION: int = 0
static var FLEE_TIME_MIN: float = 0.0
static var FLEE_TIME_MAX: float = 0.0
static var FLEE_SLACK: float = 0.0
static var FLEE_SPEED: float = 0.0
static var DASH_CHANCE: float = 0.0
static var DASH_SPEED: float = 0.0
static var DASH_PREP_TIME: float = 0.0
static var DASH_TIME: float = 0.0

const AI_PATH := "res://assets/data/balance/ai.json"


static func _load_ai() -> bool:
	var data: Variant = DataLib.load(AI_PATH)
	var d: Dictionary = data if data is Dictionary else {}
	SPEED = float(d["speed"])
	GRAVITY = float(d["gravity"])
	ATTACK_COOLDOWN = float(d["attack_cooldown"])
	HOLD_RANGE = float(d["hold_range"])
	HOLD_CHANCE = float(d["hold_chance"])
	HOLD_FRESH = int(d["hold_fresh"])
	BACK_OFF_RANGE = float(d["back_off_range"])
	BACK_OFF_CHANCE = float(d["back_off_chance"])
	SWING_MIN = float(d["swing_min"])
	SWING_MAX = float(d["swing_max"])
	SWING_HEIGHT = float(d["swing_height"])
	BODY_SLACK = float(d["body_slack"])
	LEVEL_SLACK = float(d["level_slack"])
	REAIM_EVERY = int(d["reaim_every"])
	REAIM_DIST = float(d["reaim_dist"])
	DURAK_REAIM = float(d["durak_reaim"])
	SMART_REAIM = float(d["smart_reaim"])
	JUMP_TICK = float(d["jump_tick"])
	ACCEL_RATIO = float(d["accel_ratio"])
	AIR_CONTROL = float(d["air_control"])
	JUMP_BOOST = float(d["jump_boost"])
	HOP_POWER = float(d["hop_power"])
	LEAP_POWER = float(d["leap_power"])
	LEAP_SPEED = float(d["leap_speed"])
	JUMP_CD_MIN = float(d["jump_cd_min"])
	JUMP_CD_MAX = float(d["jump_cd_max"])
	HEAD_NEAR = float(d["head_near"])
	HEAD_FAR = float(d["head_far"])
	HEAD_AHEAD = float(d["head_ahead"])
	FAR_BELOW = float(d["far_below"])
	LEDGE_BRAKE = float(d["ledge_brake"])
	LEDGE_BRAKE_AT = float(d["ledge_brake_at"])
	TURN_MIN = int(d["turn_min"])
	TURN_MAX = int(d["turn_max"])
	SINGLE_SHOT = float(d["single_shot"])
	BLIND_SHOT = float(d["blind_shot"])
	THROW_CHANCE = float(d["throw_chance"])
	SWING_CHANCE = float(d["swing_chance"])
	SWING_REACH = float(d["swing_reach"])
	CHARGE_SPEED = float(d["charge_speed"])
	WALL_GIVE = float(d["wall_give"])
	REST_RECHECK = int(d["rest_recheck"])
	GOAL_EVERY = int(d["goal_every"])
	CALM_VISION = float(d["calm_vision"])
	ALERT_VISION = float(d["alert_vision"])
	V_KONUS = float(d["v_konus"])
	V_ANGLE = float(d["v_angle"])
	DETECTING = float(d["detecting"])
	EAR = float(d["ear"])
	MAX_SPOK = int(d["max_spok"])
	SIGHT_BONUS = int(d["sight_bonus"])
	TARGET_MEMORY = int(d["target_memory"])
	DRIFT_INTERVAL = int(d["drift_interval"])
	SEARCH_DRIFT = float(d["search_drift"])
	GIVE_UP_SPOK = int(d["give_up_spok"])
	MAX_OBS = float(d["max_obs"])
	MINUS_OBS = float(d["minus_obs"])
	OBS_GRACE = float(d["obs_grace"])
	SURPRISE_MIN = float(d["surprise_min"])
	SURPRISE_MAX = float(d["surprise_max"])
	IDLE_MIN = float(d["idle_min"])
	IDLE_MAX = float(d["idle_max"])
	ALERT_MIN = float(d["alert_min"])
	ALERT_MAX = float(d["alert_max"])
	DETECT_DELAY = float(d["detect_delay"])
	WAKE_RADIUS = float(d["wake_radius"])
	BLOAT_RANGE = float(d["bloat_range"])
	BLOAT_TICKS = float(d["bloat_ticks"])
	SCORP_X = float(d["scorp_x"])
	SCORP_ABOVE = float(d["scorp_above"])
	SCORP_BELOW = float(d["scorp_below"])
	SCORP_HOLD = float(d["scorp_hold"])
	PUNCH_TICKS = float(d["punch_ticks"])
	PUNCH_HIT = float(d["punch_hit"])
	PLAYER_VIS_STILL = float(d["player_vis_still"])
	PLAYER_VIS_MOVE = float(d["player_vis_move"])
	NOISE_RUN = float(d["noise_run"])
	NOISE_DECAY = float(d["noise_decay"])
	DEMASK_DECAY = float(d["demask_decay"])
	FAST_DEMASK = float(d["fast_demask"])
	SHOT_DEMASK = float(d["shot_demask"])
	MAX_SHOK = int(d["max_shok"])
	ALARM_SHOCK_MIN = int(d["alarm_shock_min"])
	ALARM_SHOCK_MAX = int(d["alarm_shock_max"])
	LEVIT_WAKE_SHOCK = int(d["levit_wake_shock"])
	LEVIT_HOLD_SHOCK = int(d["levit_hold_shock"])
	RAIDER_LEVIT_WAKE = int(d["raider_levit_wake"])
	STUN_RECHECK = float(d["stun_recheck"])
	HOLD_SPREAD = float(d["hold_spread"])
	MOVE_SPREAD = float(d["move_spread"])
	TUPIZNA = int(d["tupizna"])
	SURPRISE_SPREAD = int(d["surprise_spread"])
	BRAIN_SURPRISE_MIN = float(d["brain_surprise_min"])
	BRAIN_SURPRISE_MAX = float(d["brain_surprise_max"])
	DEATH_THROWS = int(d["death_throws"])
	DROP_SCATTER = float(d["drop_scatter"])
	UNIT_NOISE_RUN = float(d["unit_noise_run"])
	ACTIVE_REACH = int(d["active_reach"])
	CHASE_REACH = int(d["chase_reach"])
	ROOM_CHECK_TICKS = int(d["room_check_ticks"])
	STEP_UP = float(d["step_up"])
	STEP_UP_OFF = float(d["step_up_off"])
	DROP_THROUGH = float(d["drop_through"])
	FLOOR_MARGIN = float(d["floor_margin"])
	GRENADE_CHECK = int(d["grenade_check"])
	GRENADE_CHECK_CHANCE = float(d["grenade_check_chance"])
	MINE_CHECK = int(d["mine_check"])
	MINE_FLEE_RANGE = float(d["mine_flee_range"])
	MINE_SUSPICION = int(d["mine_suspicion"])
	FLEE_TIME_MIN = float(d["flee_time_min"])
	FLEE_TIME_MAX = float(d["flee_time_max"])
	FLEE_SLACK = float(d["flee_slack"])
	FLEE_SPEED = float(d["flee_speed"])
	DASH_CHANCE = float(d["dash_chance"])
	DASH_SPEED = float(d["dash_speed"])
	DASH_PREP_TIME = float(d["dash_prep_time"])
	DASH_TIME = float(d["dash_time"])
	return true


static var _ai_ready: bool = _load_ai()
static var _combat_catalog: Dictionary = {}
static var _combat_loaded: bool = false
static var _watch: Node = null
static var _unit_catalog: Dictionary = {}
static var _unit_aliases: Dictionary = {}
static var _catalog_loaded: bool = false
static var _weapon_catalog: Dictionary = {}
static var _weapons_loaded: bool = false
## Sheet path -> {tex, epoch, frames}. Decoding a sheet costs 60-70 ms, so lands
## prefetch them on worker threads and spawns share one SpriteFrames per clip set.
static var _sheets: Dictionary = {}
static var _sheet_epoch: int = 0
static var _keep_plans: int = 1
static var _sheet_lock := Mutex.new()
static var _data_lock := Mutex.new()
static var _prefetch_busy: int = 0

@export var max_hp: int = 60
@export var bullet_scene: PackedScene
@export var points: int = 100
@export var sheet_texture: Texture2D
@export var levitate_difficulty: float = 60.0

## gunner, melee, or turret. Authored creatures set this before they enter the tree.
var fight_style: String = "gunner"
var fixed_post: bool = false
var move_speed: float:
	get:
		return _move.move_speed
	set(v):
		_move.move_speed = v
var run_speed: float:
	get:
		return _move.run_speed
	set(v):
		_move.run_speed = v
var melee_damage: int:
	get:
		return _melee.melee_damage
	set(v):
		_melee.melee_damage = v
var body_size: Vector2 = Vector2(48, 56)
var body_tint: Color = Color.WHITE
var die_actions: Array = []
var _slow_t: int = 0
var _slow_emit: float = 0.0
var _stun_t: int = 0
## Variant so Effects can set seconds (e.t / TPS) or 0.0. The setter stores ticks.
var _ice_t: Variant = 0:
	set(v):
		_ice_t = _as_ticks(v)
var _blind_t: Variant = 0:
	set(v):
		_blind_t = _as_ticks(v)
var _cut: float = 0.0
var _poison: float = 0.0
var _cut_clock: int = 0
var _poison_clock: int = 0
var _burn_left: Variant = 0:
	set(v):
		_burn_left = _as_ticks(v)
var _burn_clock: int = 0
var _burn_dps: float = 2.0
var _acid_left: Variant = 0:
	set(v):
		_acid_left = _as_ticks(v)
var _acid_clock: int = 0
var _acid_dps: float = 2.0
var _pink_left: Variant = 0:
	set(v):
		_pink_left = _as_ticks(v)
var _pink_clock: int = 0
var _pink_dps: float = 20.0
var _tint: Color = Color.WHITE
var _v_konus: float:
	get:
		return _senses._v_konus
	set(v):
		_senses._v_konus = v
var _ear: float:
	get:
		return _senses._ear
	set(v):
		_senses._ear = v
var _calm_vision: float:
	get:
		return _senses._calm_vision
	set(v):
		_senses._calm_vision = v
var _alert_vision: float:
	get:
		return _senses._alert_vision
	set(v):
		_senses._alert_vision = v
var _aim_down: bool = false
var _species_id: String = ""
var _friendly: bool = false
## Map unit with fraction F_PLAYER (UnitRaider.as L451-455): stands or strolls, never follows the player.
var _ground_ally: bool = false
var _flying: bool:
	get:
		return _move._flying
	set(v):
		_move._flying = v
var _frame_ticks: int:
	get:
		return _move._frame_ticks
	set(v):
		_move._frame_ticks = v
var _pole_t := 0
var _necro_shot: bool = false
var _necro_cd: int = 0
var _fire_down: bool = false
var _climbing: bool:
	get:
		return _move._climbing
	set(v):
		_move._climbing = v
var _comb: int = 0
var _krep: int = 0
var _held_weapon: _HeldWeapon
var _class_anim := false
var _anim_class := ""
var _last_attack_left := 0
var _swimming:
	get:
		return _move._swimming
	set(v):
		_move._swimming = v
var _thrown: bool:
	get:
		return _weapons._thrown
	set(v):
		_weapons._thrown = v
var _blast: float:
	get:
		return _weapons._blast
	set(v):
		_weapons._blast = v
var _weapon: Dictionary:
	get:
		return _weapons._weapon
	set(v):
		_weapons._weapon = v
var _burst_left: int:
	get:
		return _weapons._burst_left
	set(v):
		_weapons._burst_left = v
var _show_attack: bool = false
var _attack_left: int = 0
var _cast: String = ""
var _cast_ready: int = 91
var _cast_gap: float = 16.7
var _cast_left: int = 0
var _invis: bool = false
var _vortex_left: int = 0
var _vortex_wait: int = 0
var _drop_id: String = ""
var _buried: bool = false
var _dig_left: int = -1
var _downed: bool = false
var _revive_left: int = 0
var _revives: bool = false
var _pet_revive: bool = false
var _pet_range: float = 200.0
var _prior: Node2D = null
var _on_prior:
	get:
		return _senses._on_prior
	set(v):
		_senses._on_prior = v
var _super: String = ""
var _spit_id: String = ""
var _rage: float = 0.0
var _zlo: float = 0.0
var _prep_need: float = 0.0
var _super_need: float = 0.0
var _prep_left: int = 0
var _super_left: int = 0
var _super_v: float = 900.0
## Telekinesis: UnitAlicorn tr 1-3 ("alicorn") or UnitZombie ss 2 / 7 ("ghoul").
var _tele: RefCounted = null
var _tele_kind := ""
var _tele_tr := 0
var _t_tele := -100
var _tele_throw_t := 60
var _tele_res := 600
var _throw_force := 30.0
var _opt_dist_tele := 600.0
## UnitZombie.teleUnit, superX / superY (room space) and ticks into the super.
var _tele_unit: Node2D = null
var _super_at := Vector2.ZERO
var _super_tick := 0
var _rad_left: float = 0.0
var _rad_power: float = 20.0
var _quake_step: int = 0
var _pink_death: bool = false
var _hover: float:
	get:
		return _move._hover
	set(v):
		_move._hover = v
var _bullet_damage: int:
	get:
		return _weapons._bullet_damage
	set(v):
		_weapons._bullet_damage = v
var _can_lift: bool:
	get:
		return _move._can_lift
	set(v):
		_move._can_lift = v
var _sheet_native: bool = false
## OTHER rig drawing this unit (`_setup_rig`); null on sheet units.
var rig: RigView = null
var _sheet_offset: Vector2 = Vector2.ZERO
var _sheet_cell: Vector2i = Vector2i(120, 120)
var _sheet_clips: Dictionary = {}
var _move_clip: String = "walk"
var _jump_tick: float:
	get:
		return _move._jump_tick
	set(v):
		_move._jump_tick = v
var _close_chance: float = 0.0
var _close_release: bool = false
var _close_search: bool = true
var _close_tmin: float = 0.0
var _close_tmax: float = 0.0
## units.xml comb / un / vis / param values (enemy_combat.json).
var _shok: int = 0
var _skin: float = 0.0
var _armor: float = 0.0
var _marmor: float = 0.0
var _armor_qual: float = 0.0
var _armor_hp: float = 0.0
## Unit.dexter: 1 is standard, 0 is always hit. Bullets read it.
var dexter: float = 1.0
var _weapon_skill: float = 1.0
var _levit_attack: float = 1.0
## Classes whose control pushes dx by levitaccel toward the target while held.
var _levit_struggle: bool = false
var _levitaccel: float = 1.6
var _ai_dist: float = 0.0
var _trup: bool = true
## Unit.damage tip of the last hit, for Desintegr sposob.
var _die_tip := ""
var _loot_cont: String = ""
var fraction: int = 0
var eid: String = ""
var kind: StringName = &"unit"
var authority: bool = true
var faction: int:
	get:
		return fraction
	set(value):
		fraction = value
var _drop_arm: bool = false
var _raider_type: bool = false
var _fear_grenade: bool = false
var _levit_wake_shock: int = 0
var _levit_hold_shock: int = 0
var _surprise_min: float = 0.0
var _surprise_max: float = 0.0
var _reload_left: int:
	get:
		return _weapons._reload_left
	set(v):
		_weapons._reload_left = v
var _ai_tick: int = 0
var _dead: bool = false
var _asleep: bool = false
var _room_check: int = 0
var _base_snap: float = 1.0
## Dying units still let go of their last throws (UnitRaider.dropLoot).
var _last_rites: bool = false
## vclass units (turrets, drones, bats, bosses, mines...) run their own class's
## control() in a brain, and draw from the packed unit sheet manifest entry.
var _brain: UnitBrain = null
var _unit_vis: Dictionary = {}

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var floor_check: RayCast2D = $FloorCheck
@onready var wall_check: RayCast2D = $WallCheck

var hp: int
var facing: float = -1.0
var _attack_cd: int = 0
var _player: Node2D
var _current_anim: String = ""
var levitated: bool = false
var _lev_point: Vector2 = Vector2.ZERO
var _lev_speed: float = 0.0
var _dropping: bool = false

var ai_state: int = ST_PATROL
var ai_spok: int = 0
var _vision: float:
	get:
		return _senses._vision
	set(v):
		_senses._vision = v
var _overlook: bool:
	get:
		return _senses._overlook
	set(v):
		_senses._overlook = v
var _track_player: bool:
	get:
		return _senses._track_player
	set(v):
		_senses._track_player = v
var _goal: Vector2:
	get:
		return _move._goal
	set(v):
		_move._goal = v
var _state_left: int = 31
var _detect_delay: Variant:
	get:
		return _senses._detect_delay
	set(v):
		_senses._detect_delay = v



func _init() -> void:
	_move = _Move.new(self)
	_senses = _Senses.new(self)
	_weapons = _Weapons.new(self)
	_melee = _Melee.new(self)
	_generic = _Generic.new(self)
	move_speed = SPEED
	_v_konus = V_KONUS
	_ear = EAR
	_calm_vision = CALM_VISION
	_alert_vision = ALERT_VISION
	_melee._swing_x = SWING_MAX
	_melee._swing_above = SWING_HEIGHT
	_melee._swing_below = SWING_HEIGHT
	_melee._strike_cd = ATTACK_COOLDOWN
	_weapons._hold_range = HOLD_RANGE
	_weapons._hold_chance = HOLD_CHANCE
	_jump_tick = JUMP_TICK
	_move._air_frac = AIR_CONTROL
	_move._jump_boost = JUMP_BOOST
	_move._wall_give = WALL_GIVE
	_weapons._reaim_every = REAIM_EVERY
	_weapons._reaim_chance = DURAK_REAIM
	_weapons._reaim_dist = REAIM_DIST
	_weapons._shot_chance = SINGLE_SHOT
	_weapons._blind_chance = BLIND_SHOT
	_melee._swing_chance = SWING_CHANCE
	_melee._band_min = SWING_MIN
	_melee._band_max = SWING_MAX
	_melee._band_up = SWING_HEIGHT
	_melee._band_down = SWING_HEIGHT
	_close_tmin = ALERT_MIN
	_close_tmax = ALERT_MAX
	_ai_dist = HOLD_RANGE
	_senses._noise_run = UNIT_NOISE_RUN
	_senses._wake_radius = WAKE_RADIUS
	_senses._alarm_shock_min = ALARM_SHOCK_MIN
	_senses._alarm_shock_max = ALARM_SHOCK_MAX
	_levit_wake_shock = LEVIT_WAKE_SHOCK
	_levit_hold_shock = LEVIT_HOLD_SHOCK
	_surprise_min = SURPRISE_MIN
	_surprise_max = SURPRISE_MAX
	_move._porog = STEP_UP
	_move._unit_porog = STEP_UP
	_vision = CALM_VISION


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_EXIT_TREE:
		Units.touch()
	if what == NOTIFICATION_PREDELETE and _brain != null:
		_brain.release()
		_brain = null


## The brain the body calls: the unit's UnitBrain, or the generic brain.
func _ai() -> Variant:
	return _brain if _brain != null else _generic


## Unit.dopTest: false lets the bullet fly on through this unit.
func dop_test(bullet: Node) -> bool:
	return _ai().dop_test(bullet)


## Interact on a unit with an action (the wild phoenix's tame).
func use_object(from_timer: bool = false) -> void:
	if _brain != null and _brain.has_method("use_object"):
		_brain.call("use_object", from_timer)


## Script targ commands (Unit.command), also for units outside the enemies group.
func script_command(act: String, val: String) -> void:
	_ai().command(act, val)


## Unit.priorUnit: the pet that last hit this unit. Null once it is gone or down.
func _prior_target() -> Node2D:
	if _prior == null:
		return null
	if not is_instance_valid(_prior) or not _prior.visible or int(_prior.get("hp")) <= 0:
		_prior = null
	return _prior


func _ready() -> void:
	_tint = body_tint
	_base_snap = floor_snap_length
	_hp_mult = _Difficulty.value("enemy_hp")
	_senses._ear_mult = _Difficulty.value("enemy_ear")
	_apply_species()
	if not _friendly and _hp_mult < 1.0:
		max_hp = maxi(1, int(round(float(max_hp) * _hp_mult)))
	hp = max_hp
	if _armor_hp <= 0.0:
		_armor_hp = float(max_hp)
	Units.touch()
	if _friendly:
		remove_from_group("enemies")
		add_to_group("allies")
	else:
		add_to_group("enemies")
		add_to_group("foe_bodies")
		GameState.register_enemy()
		_ensure_watch()
	Fx.ai(&"spawned", self, {"friendly": _friendly})
	# Layer 9 is a ghost wall. Enemies do not have transT, so they cannot walk through it.
	set_collision_mask_value(9, true)
	if _flying:
		motion_mode = MOTION_MODE_FLOATING
		floor_snap_length = 0.0
	if _buried:
		visible = false
		set_collision_layer_value(3, false)
	_player = Run.nearest_player(global_position)
	_goal = global_position
	_state_left = _ticks(Rng.randf_range(&"ai", IDLE_MIN, IDLE_MAX) / TPS)
	_senses._sense_left = _ticks(Rng.randf_range(&"ai", 0.05, SENSE_INTERVAL))
	_move._fit_body()
	_setup_animations()
	_move._heading = facing
	_play_anim("idle")
	anim.modulate = _tint
	_ai().start()


func is_alert() -> bool:
	return _ai().targets_player()


## Steps a `left -= 1/30` countdown takes before it is <= 0.
## 30 * (1/30) is a hair under 1, so 1.0 s lasts 31 steps.
func _ticks(seconds: float) -> int:
	var left := seconds
	var n := 0
	var step := 1.0 / TPS
	while left > 0.0 and n < 100000:
		left -= step
		n += 1
	return n


## Effects and a few brains still pass seconds (or 0.0). Int writes are already ticks.
func _as_ticks(value: Variant) -> int:
	if value is float:
		return _ticks(value)
	return int(value)


func apply_slow(seconds: float) -> void:
	_slow_t = maxi(_slow_t, _ticks(seconds))


func apply_stun(ticks: int) -> void:
	if ticks <= 0 or _is_machine():
		return
	_stun_t += ticks


func apply_on_hit(effect: String, dop: float, dealt: int) -> void:
	# psy is only UnitPlayer.damage: a roll of horror, vote, or disorient.
	# Those are not a damage-over-time, slow, or miss chance on the unit hit.
	if effect == "psy" or effect == "":
		return
	match effect:
		"cut":
			if _resist("DAM_BLEED") <= 0.1 or _is_machine():
				return
			if _cut <= 0.0:
				_cut_clock = 30
			_cut += dop
		"poison":
			if _resist("DAM_POISON") <= 0.1:
				return
			if _poison <= 0.0:
				_poison_clock = 30
			_poison += dop
		"igni":
			if _resist("DAM_BURN") <= 0.1:
				return
			_ice_t = 0
			_burn_left = _ticks(7.0)
			_burn_clock = 0
			_burn_dps = dop if dop > 0.0 else 2.0
		"ice":
			if _resist("DAM_COLD") <= 0.1 or _is_machine():
				return
			_burn_left = 0
			_ice_t = _ticks(15.0)
		"blind":
			if _resist("DAM_LASER") <= 0.1 or _is_machine():
				return
			_blind_t = _ticks(15.0)
		"acid":
			if _resist("DAM_ACID") <= 0.1:
				return
			_acid_left = _ticks(15.0)
			_acid_clock = 0
			_acid_dps = dop if dop > 0.0 else 2.0
		"pink":
			if _resist("DAM_PINKCLOUD") <= 0.1:
				return
			_pink_left = _ticks(15.0)
			_pink_clock = 0
			_pink_dps = dop if dop > 0.0 else 20.0
		"stun":
			if _is_machine():
				return
			if Rng.randf(&"combat") < float(dealt) / maxf(1.0, float(max_hp)):
				_stun_t = _ticks(float(dop) / 30.0)


func _is_machine() -> bool:
	return bool(get_meta("mech", false)) or bool(get_meta("robot", false))


func _resist(tip: String) -> float:
	var comp := _Resistances.of(self)
	if comp:
		return comp.multiplier_for(tip)
	return 1.0


func _tick_ailments(_delta: float) -> void:
	if _ice_t > 0:
		_ice_t = maxi(0, int(_ice_t) - _frame_ticks)
	if _blind_t > 0:
		_blind_t = maxi(0, int(_blind_t) - _frame_ticks)
	_cut_clock += _frame_ticks
	if _cut > 0.0 and _cut_clock >= 31:
		_cut_clock -= 30
		var bleed := int(round(sqrt(_cut)))
		if bleed > 0:
			_take_dot(bleed, "DAM_BLEED")
		_cut = maxf(0.0, _cut - 0.2)
	_poison_clock += _frame_ticks
	if _poison > 0.0 and _poison_clock >= 31:
		_poison_clock -= 30
		var venom := int(round(sqrt(_poison)))
		if venom > 0:
			_take_dot(venom, "DAM_POISON")
		_poison = maxf(0.0, _poison - 0.2)
	_dot_channel("burn")
	_dot_channel("acid")
	_dot_channel("pink")


func _dot_channel(which: String) -> void:
	var left := 0
	var clock := 0
	var dps := 0.0
	var tip := ""
	match which:
		"burn":
			left = int(_burn_left)
			clock = _burn_clock
			dps = _burn_dps
			tip = "DAM_BURN"
		"acid":
			left = int(_acid_left)
			clock = _acid_clock
			dps = _acid_dps
			tip = "DAM_ACID"
		"pink":
			left = int(_pink_left)
			clock = _pink_clock
			dps = _pink_dps
			tip = "DAM_PINKCLOUD"
		_:
			return
	if left <= 0:
		return
	clock += _frame_ticks
	left = maxi(0, left - _frame_ticks)
	if clock >= 31:
		clock -= 30
		var pulse := int(round(dps))
		if pulse > 0:
			_take_dot(pulse, tip)
	match which:
		"burn":
			_burn_left = left
			_burn_clock = clock
		"acid":
			_acid_left = left
			_acid_clock = clock
		"pink":
			_pink_left = left
			_pink_clock = clock


func _setup_animations() -> void:
	if _setup_rig():
		return
	if not _unit_vis.is_empty() and sheet_texture != null:
		var vkey := "unit:%s" % str(_unit_vis.get("sheet", ""))
		var vframes := _shared_frames(sheet_texture, vkey)
		if vframes == null:
			vframes = UnitBrain.frames_of(sheet_texture, _unit_vis, _unit_vis.get("clips", {}))
			_store_frames(sheet_texture, vkey, vframes)
		var anchor: Array = _unit_vis.get("anchor", [0, 0])
		anim.sprite_frames = vframes
		anim.centered = false
		anim.position = Vector2.ZERO
		anim.scale = Vector2.ONE
		anim.offset = -Vector2(float(anchor[0]), float(anchor[1]))
		return
	# Bloats and the nest loop a nested clip by themselves in Flash (wing flap, breathing),
	# so they use the packed multi-frame sheet. The cell is symmetric about the origin.
	var pack_key := str(_catalog_row(_species_id).get("pack", ""))
	if pack_key != "" and sheet_texture != null:
		var entry := UnitBrain.vis_of(pack_key)
		if not entry.is_empty():
			var pkey := "pack:%s" % pack_key
			var pframes := _shared_frames(sheet_texture, pkey)
			if pframes == null:
				pframes = UnitBrain.frames_of(sheet_texture, entry, entry.get("clips", {}))
				# One loop for flying and hovering: switching clips would restart the flap.
				if pframes.has_animation("fly"):
					pframes.remove_animation("fly")
				_store_frames(sheet_texture, pkey, pframes)
			anim.sprite_frames = pframes
			anim.centered = true
			anim.offset = _sheet_offset
			anim.scale = Vector2.ONE
			return
	if _sheet_native and sheet_texture != null and not _sheet_clips.is_empty():
		var key := "%d,%d,%d" % [_sheet_cell.x, _sheet_cell.y, _sheet_clips.hash()]
		var frames := _shared_frames(sheet_texture, key)
		if frames == null:
			frames = _frames_from_clips(sheet_texture, _sheet_cell, _sheet_clips)
			_store_frames(sheet_texture, key, frames)
		anim.sprite_frames = frames
		anim.centered = true
		anim.offset = _sheet_offset
		anim.scale = Vector2.ONE
		return
	# A named creature with no atlas stays untextured. It is not a recolored raider.
	if _read_species() != "":
		anim.sprite_frames = SpriteFrames.new()
		if anim.sprite_frames.has_animation("default"):
			anim.sprite_frames.remove_animation("default")
		return
	var tex := sheet_texture
	if tex == null:
		tex = _sheet_tex("raider.png")
	var shared := _shared_frames(tex, "raider")
	if shared == null:
		shared = SheetFrames.raider_frames(tex)
		_store_frames(tex, "raider", shared)
	anim.sprite_frames = shared
	anim.centered = true


func set_levitated(active: bool, target: Vector2 = Vector2.ZERO, speed: float = 0.0) -> void:
	if active and not _can_lift:
		return
	if _dead:
		set_physics_process(true)
	elif active:
		_wake_up()
	var was := levitated
	levitated = active
	_lev_point = target
	_lev_speed = speed
	if was and not active:
		_dropping = true
		if not _flying:
			floor_snap_length = _base_snap
		if velocity.y < 40.0:
			velocity.y = 40.0
		if is_instance_valid(anim):
			anim.modulate = _tint
		return
	# UnitPlayer.actTele: the grabbed unit is alarma'd.
	if active and not was and not _dead:
		_ai().command("alarma", "")
	if active and not was and not _dead and _is_calm():
		# Brain.reactToLevitation: a calm unit wakes, shocked. Movement stays frozen until release.
		_senses._wake_allies()
		_become_alert(_feet(self))
		_shok = maxi(_shok, _levit_wake_shock)


func _actors_live() -> bool:
	var run := get_node_or_null("/root/Run")
	if run == null:
		return true
	return run.land() != null and run.local_player() != null


func _physics_process(delta: float) -> void:
	if GameState.paused or not authority:
		return
	# Loading used to tick units for a variable number of frames before the
	# player existed. They stay put until the land and the local player are in.
	if not _actors_live():
		return
	if _dead:
		_corpse_process(delta)
		return
	_advance_ticks(delta)
	if not _room_still_active():
		return
	_tick_ailments(delta)
	_tick_tele()
	if levitated:
		_physics_levitated(delta)
		return
	if not GameState.enemies_think:
		velocity.x = 0.0
		if _flying:
			velocity.y = 0.0
		elif not is_on_floor():
			velocity.y += GRAVITY * delta
		_commit_move()
		return
	if _pole_hold():
		velocity.x = 0.0
		if not _flying and not is_on_floor():
			velocity.y += GRAVITY * delta
		_commit_move()
		return
	_ai().physics(delta)

func _physics_levitated(delta: float) -> void:
	if _downed:
		_revive_left -= _frame_ticks
		if _revive_left <= 0.0:
			_rise()
	elif _levit_hold_shock > 0 and _shok < _levit_hold_shock:
		_shok = _levit_hold_shock
	var ai: Variant = _ai()
	if ai.acts_held:
		ai.held(delta)
		if _dead or not levitated:
			return
	_move._float_to_cursor()

func _physics_downed(delta: float) -> void:
	var was_left := _revive_left
	_revive_left -= _frame_ticks
	# UnitZombie.control: t_res == 25 plays zombie_res.
	if was_left > 25 and _revive_left <= 25 and _species_id.begins_with("zombie"):
		UnitFx.snd("zombie_res")
	if not is_on_floor() and not _flying:
		velocity.y += GRAVITY * delta
	_commit_move()
	_play_anim("die")
	# UnitZombie.animate: the last 20 ticks of t_res play the die row backwards, with sparks.
	var t_res := float(_revive_left)
	if _anim_class == "zombie" and t_res < 20.0 and t_res >= 0.0 and _current_anim == "die":
		anim.pause()
		anim.frame = clampi(int(t_res), 0, anim.sprite_frames.get_frame_count("die") - 1)
		for _i in _frame_ticks * 3:
			Fx.particles("die_spark", global_position + Vector2((Rng.randf(&"fx") - 0.5) * body_size.x, -Rng.randf(&"fx") * 10.0), {"source": self})
	if _revive_left <= 0.0:
		_rise()

func _physics_stunned(delta: float) -> void:
	# Brain.tick with obeysStun: idle, decide again 3 ticks after the stun. No attacks.
	var was_tick := _stun_t
	_stun_t = maxi(0, _stun_t - _frame_ticks)
	if bool(get_meta("robot", false)) and was_tick / 10 != _stun_t / 10:
		var mid := _feet(self) - Vector2(0.0, _body_size(self).y * 0.5)
		Fx.particles("discharge", mid, {"source": self})
		Fx.particles("iskr", mid, {"kol": 5, "source": self})
	_melee._windup_left = 0
	_burst_left = 0
	ai_state = ST_IDLE
	_state_left = _ticks(STUN_RECHECK / TPS)
	velocity.x = 0.0
	if not is_on_floor() and not _flying:
		velocity.y += GRAVITY * delta
	_commit_move()
	_present(false)
func _call_is_held() -> bool:
	if not has_method("is_held"):
		return false
	return bool(call("is_held"))


func _cannot_fight() -> bool:
	return _dead or levitated or _dropping or _stun_t > 0.0 or _call_is_held()


func _is_calm() -> bool:
	return ai_state == ST_IDLE or ai_state == ST_PATROL


## UnitRaider.isAttacking / SideWeaponAttack.isActive.
func _is_attacking() -> bool:
	return ai_state == ST_CHASE or ai_state == ST_HOLD or ai_state == ST_FLEE or ai_state == ST_DASH
func _lev_anim() -> void:
	var ai: Variant = _ai()
	ai.animate()
	if ai.flips_sprite and is_instance_valid(anim):
		anim.flip_h = ai.storona < 0.0


## A held unit's push toward its target (the brain's levit_pull). vel and the result are px per tick.
func levit_pull(vel: Vector2) -> Vector2:
	if _dead or _downed or _stun_t > 0.0 or not levitated:
		return Vector2.ZERO
	return _ai().levit_pull(vel)


func _act() -> bool:
	return _generic.act()
func _body_center(body: Node2D) -> Vector2:
	var feet := _feet(body)
	return Vector2(feet.x, feet.y - _body_size(body).y * 0.5)


## GunAttack.tick and WeaponAttack.tick, plus BodyAttack while chasing.
func _tick_attacks() -> void:
	_generic.tick_attacks()
func _commit_move() -> void:
	_move._commit_move()
## Unit.otbros: sila = rnd(0.8..1.2) * knocked / massa, at most 3; velocity += knock * otbros * sila.
func otbros(knock: Vector2, power: float) -> void:
	_move.otbros(knock, power)
func take_hit(hit: HitInfo) -> void:
	if hit == null:
		return
	if hit.from_bullet:
		_from_bullet(hit)
		return
	if hit.resisted:
		var scaled := hit.dup()
		scaled.tip = ""
		_receive(scaled)
		return
	_receive(hit)


## A bullet or blast. Unit.udarBullet: dexter already decided the hit in the bullet.
## A direct hit rolls 0.7–1.3 of the damage, then Unit.damage runs.
func _from_bullet(hit: HitInfo) -> void:
	var bullet := hit.source
	var dam := hit.amount
	if not hit.explosion:
		dam *= Rng.randf_range(&"combat", 0.7, 1.3)
	var tip := hit.tip
	if tip == "" and bullet != null:
		tip = str(bullet.get("damage_type"))
	# Unit.udarBullet: priorUnit = bul.owner. Player shots clear it back to the player.
	if bullet != null and bool(bullet.get("from_player")):
		var owner_v: Variant = bullet.get_meta("owner_unit") if bullet.has_meta("owner_unit") else null
		_prior = owner_v if owner_v is Node2D and is_instance_valid(owner_v) and (owner_v as Node).is_in_group("pets") else null
	elif _ground_ally and bullet != null and bullet.has_meta("owner_unit"):
		# Unit.udarBullet: priorUnit = bul.owner, the shooter of another fraction.
		var shooter: Variant = bullet.get_meta("owner_unit")
		if shooter is Node2D and is_instance_valid(shooter) and shooter != self and (shooter as Node).is_in_group("enemies"):
			_prior = shooter
	var passed := hit.dup()
	passed.amount = dam
	passed.tip = tip
	passed.from_bullet = true
	_receive(passed)


## Damage over time (Effect burn/acid/poison/pink and bleeding) is tt: no armor, no shock.
func _take_dot(amount: int, type: String) -> void:
	_receive(HitInfo.dot(float(amount), type))


## The dict land_memory stores for this unit (pos, hp or corpse).
func snapshot() -> Dictionary:
	return Entity.captured(self)


func restore(d: Dictionary) -> void:
	Entity.apply_captured(self, d)


## Unit.damage after the bullet roll: resistance, armor wear, armor, critInvis, shock.
## An empty type is damage already scaled by Resistances.apply. resisted hits arrive that way.
func _receive(hit: HitInfo) -> void:
	if hit == null or _dead or _downed or (_buried and _dig_left <= 0.0):
		return
	var amount := hit.amount
	var type := hit.tip
	var bullet: Node = hit.source if hit.from_bullet else null
	var tt := hit.tt
	var dam := amount
	if type != "":
		dam *= _resist(type)
	if bullet != null and bool(bullet.get("from_player")):
		dam *= Progression.target_mult(self)
	if dam > 0.0:
		dam = _ai().on_damage(dam, type, bullet, tt)
	if dam <= 0.0:
		return
	if type == "DAM_ELECTRIC" and not is_on_floor() and not _climbing:
		dam *= 0.5
	if not tt and type in ARMOR_WEAR and _armor_hp > 0.0 and (_armor > 0.0 or _marmor > 0.0):
		var wear := dam
		if type == "DAM_ACID":
			wear *= 4.0
		elif type == "DAM_EXPLOSION":
			wear *= 2.0
		_armor_hp -= wear
		if _armor_hp <= 0.0:
			_armor_hp = 0.0
			_armor_qual = 0.0
	if not tt:
		var armor2 := 0.0
		if type in ARMOR_PHYS:
			armor2 = _skin
			if _armor_qual > 0.0 and Rng.randf(&"combat") < _armor_qual:
				armor2 += _armor
		elif type in ARMOR_MAGIC:
			armor2 = _skin
			if _armor_qual > 0.0 and Rng.randf(&"combat") < _armor_qual:
				armor2 += _marmor
		if bullet != null and bullet.get("pier") != null:
			armor2 -= float(bullet.get("pier"))
		if armor2 > 0.0:
			dam -= armor2
	if bullet != null and bool(bullet.get("from_player")) and not _track_player:
		var crit_invis := AiWorld.facts(_player).crit_invis
		if crit_invis > 0.0 and Rng.randf(&"combat") < crit_invis:
			dam *= 2.0
	var desintegr: Variant = bullet.get("desintegr") if bullet != null else null
	if desintegr != null and float(desintegr) > 0.0 and dam > 0.0 and type in ["DAM_LASER", "DAM_PLASMA"]:
		if hp <= dam * 10.0 and Rng.randf(&"combat") < float(desintegr):
			dam *= 12.0
	var dealt := int(round(dam))
	if dealt <= 0:
		return
	var nshok := int(round((Rng.randf(&"combat") * 0.8 + 0.2) * float(MAX_SHOK) * 4.0 * float(dealt) / maxf(1.0, float(max_hp))))
	nshok = mini(nshok, MAX_SHOK)
	if tt or nshok < 5:
		nshok = 0
	if nshok > _shok:
		_shok = nshok
	if nshok > 0:
		_melee._windup_left = 0
	_die_tip = type
	_blood_fx(float(dealt), type, bullet)
	# Unit.damage: mat 10 (only UnitThunderHead sets it) flashes pole2 where the bullet hit.
	if _species_id == "thunderhead" and bullet is Node2D:
		Fx.particles("pole2", (bullet as Node2D).global_position, {"source": self})
	_apply_damage(dealt, tt)
	Effects.unit_damaged(self, float(dealt), type, tt, bullet)


## Unit.damage blood: a spray along the shot, and on red-blooded heavy bodies
## a rare bloodexpl splatter behind the hit.
func _blood_fx(dam: float, type: String, bullet: Node) -> void:
	var blood := _Desintegr.blood_of(_species_id)
	if blood <= 0 or blood > 3 or not type in ["DAM_PIERCE", "DAM_CUT", "DAM_BLUNT", "DAM_BLEED", "DAM_BITE"]:
		return
	var pid: String = ["blood", "gblood", "pblood"][blood - 1]
	var size := _body_size(self)
	if bullet is Node2D:
		var d := (bullet.get("direction") as Vector2).normalized() * 5.0
		Fx.blood((bullet as Node2D).global_position, {"kind": pid, "dx": d.x, "dy": d.y, "kol": int(Rng.randf(&"fx") * 5.0 + dam / 5.0), "source": self})
	else:
		Fx.blood(_feet(self) - Vector2(0.0, size.y * 0.5), {"kind": pid, "kol": int(dam / 3.0), "source": self})
	if blood != 1 or type == "DAM_BLEED" or _UnitMassa.massa(self) <= 0.2:
		return
	var ver := Rng.randf(&"fx")
	if type == "DAM_CUT":
		ver *= ver
	if dam / 1000.0 <= ver:
		return
	var side := 1.0
	if bullet is Node2D:
		side = -1.0 if (bullet.get("direction") as Vector2).x < 0.0 else 1.0
	elif Rng.randf(&"fx") < 0.5:
		side = -1.0
	var at := _feet(self) + Vector2(80.0 * side + (Rng.randf(&"fx") - 0.5) * size.x * 0.5, -Rng.randf(&"fx") * size.y * 0.5 - 40.0)
	Fx.blood(at, {"kind": "bloodexpl%d" % Rng.randi_range(&"fx", 1, 3), "mirr": 1 if side < 0.0 else 0, "source": self})


func _apply_damage(amount: int, separate: bool = false) -> void:
	var calm := _is_calm()
	hp -= amount
	Fx.ai(&"damaged", self, {"amount": amount, "hp": hp})
	_float_hit(amount, false, separate)
	anim.modulate = Color(1.0, 0.5, 0.5)
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		if is_instance_valid(anim):
			anim.modulate = _tint
	)
	_ai().hit_anim()
	if calm:
		_senses._wake_allies()
	if calm and hp > 0:
		var size := _body_size(self)
		_become_alert(_feet(self) + Vector2(facing * size.x * 2.0, -size.y))
	if hp <= 0:
		_begin_death()


func _play_anim(name: String) -> void:
	var clip := _visual_clip(name)
	if _current_anim == clip:
		return
	if anim.sprite_frames and anim.sprite_frames.has_animation(clip):
		_current_anim = clip
		anim.play(clip)


func _visual_clip(name: String) -> String:
	if not _sheet_native or anim.sprite_frames == null:
		return name
	var frames := anim.sprite_frames
	if name == "idle" or name == "crouch":
		return "stay" if frames.has_animation("stay") else name
	if name == "walk":
		if _move_clip != "" and frames.has_animation(_move_clip):
			return _move_clip
		if frames.has_animation("walk"):
			return "walk"
		return "stay" if frames.has_animation("stay") else name
	if name == "fall":
		if frames.has_animation("fall"):
			return "fall"
		return "stay" if frames.has_animation("stay") else name
	return name


## UnitAIRobot isPort (UnitEqd): t_port ticks until the next jump, kol_port jumps left.
var _port_t := 0
var _port_kol := 5


## UnitAIRobot.actPort: hunting a target it cannot see, it teleports beside the
## player (or anywhere in the room) onto free floor.
func _eqd_port() -> void:
	_port_t = maxi(0, _port_t - _frame_ticks)
	if ai_spok == 0:
		_port_kol = 5
	if _port_t > 0 or _port_kol <= 0 or ai_state != ST_SEARCH or _track_player:
		return
	if _player == null or not is_instance_valid(_player) or _detect_delay > 0.0:
		return
	var room := _move._room_rect()
	var pf := float(_player.get("facing")) if "facing" in _player else 1.0
	var pp := _player.global_position
	for i in range(1, 21):
		var to := Vector2.ZERO
		if i < 5:
			var s := -pf if Rng.randf(&"ai") < 0.7 else pf
			to = Vector2(pp.x + s * (Rng.randf(&"ai") * 300.0 + 200.0), pp.y)
		elif i < 10:
			var s2 := -pf if Rng.randf(&"ai") < 0.5 else pf
			to = Vector2(pp.x + s2 * (Rng.randf(&"ai") * 800.0 + 200.0), pp.y + Rng.randf(&"ai") * 160.0 - 80.0)
		else:
			to = room.position + Vector2(Rng.randf(&"ai") * room.size.x, Rng.randf(&"ai") * room.size.y)
		to = Vector2(round(to.x / 40.0) * 40.0, ceil(to.y / 40.0) * 40.0 - 1.0)
		to.x = clampf(to.x, room.position.x + body_size.x, room.end.x - body_size.x)
		to.y = clampf(to.y, room.position.y + body_size.y + 40.0, room.end.y - 40.0)
		if _move._blocked_at(to):
			continue
		Fx.particles("tele", global_position + Vector2(0.0, -body_size.y * 0.5), {"rx": body_size.x, "ry": body_size.y, "kol": 30, "source": self})
		global_position = to
		velocity = Vector2.ZERO
		Fx.particles("teleport", global_position + Vector2(0.0, -body_size.y * 0.5), {"source": self})
		_sense()
		if _track_player:
			ai_spok = 0
			ai_state = ST_SURPRISED
			_state_left = _ticks(float(Rng.randi_range(&"ai", 20, 49)) / TPS)
			facing = 1.0 if pp.x > global_position.x else -1.0
			_port_t = Rng.randi_range(&"ai", 150, 239)
		else:
			_port_t = Rng.randi_range(&"ai", 30, 119)
		_port_kol -= 1
		return
func _decide() -> void:
	_generic.decide()
func _sense() -> void:
	_senses._sense()
func _become_alert(point: Vector2) -> void:
	_senses._become_alert(point)
## Unit.budilo: make a noise, and alarm awake units of the same fraction inside rad * their ear.
## Two robots hear each other at rad.
func _budilo(rad: float) -> void:
	_senses._budilo(rad)
## Unit.alarma then Brain.alarm. Only a calm unit wakes; it starts shocked.
func _alarm_from(at: Vector2) -> void:
	_senses._alarm_from(at)
func _look(player: Node2D) -> float:
	return _senses._look(player)
func _tick_world_senses(player: Node, delta: float) -> void:
	_senses._tick_world_senses(player, delta)
func _feet(body: Node2D) -> Vector2:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		var rect := shape_node.shape as RectangleShape2D
		return shape_node.global_position + Vector2(0.0, rect.size.y * 0.5)
	return body.global_position


func _body_size(body: Node2D) -> Vector2:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		return (shape_node.shape as RectangleShape2D).size
	return Vector2(48, 56)


func _velocity_of(body: Node) -> Vector2:
	if body is CharacterBody2D:
		return (body as CharacterBody2D).velocity
	return Vector2.ZERO
func _apply_species() -> void:
	if bool(get_meta("vortex_minion", false)) and str(_catalog_unit("vortex").get("brain", "")) == "":
		_weapons._configure_vortex()
		return
	var id := _read_species()
	if id == "":
		# Scene enemies with no species are raider gunners: they strafe while alert.
		_move._backpedal = fight_style != "melee" and fight_style != "turret"
		_apply_combat("raider")
		return
	_apply_species_id(id)
	_apply_combat(_species_id)
	var row := _catalog_unit(_species_id)
	var brain_id := str(get_meta("brain", row.get("brain", "")))
	# A phoenix placed in a land is the wild UnitPhoenix; Pets spawns the companion with meta brain.
	if brain_id == "" and _species_id == "phoenix":
		brain_id = "wild_phoenix"
	_brain = UnitBrains.make(brain_id)
	if _brain != null:
		_unit_vis = UnitBrain.vis_of(str(row.get("vis", "")))
		_brain.setup(self, row)
		_brain.configure()


func _apply_species_id(id: String) -> void:
	# Map id "bloat" has no tr. UnitBloat rolls int(Math.random() * 5), so bloat0–bloat4.
	if id == "bloat":
		id = "bloat%d" % (Rng.randi(&"spawn") % 5)
		set_meta("unit_id", id)
	_species_id = id
	var row := _catalog_unit(id)
	if not row.is_empty():
		_apply_catalog(row)
		_apply_role(id, row)
	# Cone, bite, and claw stay on the class that owns them, after the sheet stats.
	if id.contains("turret"):
		_apply_turret(id)
	elif id.begins_with("scorp"):
		_apply_scorp(id)
	elif id == "ebloat":
		_apply_emitter()
	elif id.begins_with("bloat"):
		_apply_bloat()


func _combat_row(id: String) -> Dictionary:
	_ensure_catalog()
	if _combat_catalog.has(id):
		return _combat_catalog[id]
	var alt := str(_unit_aliases.get(id, ""))
	if alt != "" and _combat_catalog.has(alt):
		return _combat_catalog[alt]
	return {}


## units.xml armor, dodge, senses and AI ranges, then the class settings that use them.
func _apply_combat(id: String) -> void:
	var row := _combat_row(id)
	_skin = float(row.get("skin", 0.0))
	_armor = float(row.get("armor", 0.0))
	_marmor = float(row.get("marmor", 0.0))
	_armor_qual = float(row.get("aqual", 0.0))
	_armor_hp = float(row.get("armorhp", 0.0))
	dexter = float(row.get("dexter", 1.0))
	_senses._observ = float(row.get("observ", 0.0))
	_weapon_skill = float(row.get("skill", 1.0))
	_levit_attack = float(row.get("levitatk", 1.0))
	_ai_dist = float(row.get("ai_dist", HOLD_RANGE))
	_trup = float(row.get("trup", 1.0)) > 0.0
	_loot_cont = str(row.get("cont", id))
	_senses._noise_run = float(row.get("noise", UNIT_NOISE_RUN))
	_move._unit_porog = float(row.get("porog", STEP_UP))
	_move._porog = _move._unit_porog
	_raider_type = id == "raider" or _raider_kin(id)
	if _raider_type and _held_weapon == null:
		_held_weapon = _HeldWeapon.new()
		_held_weapon.name = "HeldWeapon"
		add_child(_held_weapon)
		_held_weapon.setup(self, id)
		_move._walker = _HeldWeapon.unit_flag(id, "walker")
	_anim_class = _anim_class_of(id)
	_class_anim = _anim_class != ""
	_levit_struggle = (_anim_class in ["pony", "hellhound", "zombie", "ant", "monstrik"] and not id.begins_with("ranger")) \
			or id.begins_with("alicorn")
	_levitaccel = float(_catalog_row(id).get("move", {}).get("levitaccel", 1.6))
	fraction = int(row.get("fraction", 2 if _raider_type else 1))
	if bool(row.get("stay", false)) or str(get_meta("ai_tip", "")) in ["stay", "quiet", "sniper"]:
		_move._stroll = false
	if _raider_type:
		var tupizna := TUPIZNA
		if id.begins_with("encl") or id.begins_with("merc") or id.begins_with("ranger") or id.begins_with("zebra"):
			tupizna = 10
		if fight_style == "melee":
			tupizna = int(float(tupizna) * 0.25)
		_surprise_min = float(tupizna)
		_surprise_max = float(tupizna + SURPRISE_SPREAD)
		_levit_wake_shock = RAIDER_LEVIT_WAKE
		_levit_hold_shock = 0
		_fear_grenade = not bool(row.get("no_fear_grenade", false))
		_move._can_dash = id.begins_with("zebra")
		_weapons._sniper = bool(row.get("sniper", false))
		_drop_arm = not (id.begins_with("encl") or id.begins_with("ranger")) and not has_meta("nodrop")
		_move._opens_doors = true
		_move._climbs_ladders = not _flying
		_senses._wake_radius = WAKE_RADIUS
	elif id.begins_with("scorp") or id.begins_with("ant"):
		# UnitMonstrik / UnitAnt brains: default surprise, short alarm shock, alarm wakes 250 around.
		_surprise_min = BRAIN_SURPRISE_MIN
		_surprise_max = BRAIN_SURPRISE_MAX
		_senses._alarm_shock_min = 3
		_senses._alarm_shock_max = 8
		_senses._alarm_radius = 250.0
		_senses._wake_radius = 0.0
		_move._climbs_ladders = id.begins_with("ant")
	elif id.begins_with("hellhound"):
		_surprise_min = BRAIN_SURPRISE_MIN
		_surprise_max = BRAIN_SURPRISE_MAX
		_move._climbs_ladders = true


## enemies.json, enemy_combat.json and weapons.json. A prefetch may be parsing
## them on a worker; the lock makes the main thread wait for that instead.
static func _ensure_catalog() -> void:
	if _catalog_loaded and _combat_loaded and _weapons_loaded:
		return
	_data_lock.lock()
	if not _catalog_loaded:
		var units := _read_json("res://assets/data/enemies.json")
		_unit_catalog = units.get("units", {})
		_unit_aliases = units.get("aliases", {})
		_catalog_loaded = true
	if not _combat_loaded:
		_combat_catalog = _read_json("res://assets/data/enemy_combat.json").get("units", {})
		_combat_loaded = true
	if not _weapons_loaded:
		for item in _read_json("res://assets/data/weapons.json").get("weapons", []):
			if item is Dictionary:
				_weapon_catalog[str(item.get("id", ""))] = item
		_weapons_loaded = true
	_data_lock.unlock()


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing enemy data at %s" % path)
		return {}
	var parsed: Variant = DataLib.load(path)
	return parsed if parsed is Dictionary else {}


static func _catalog_row(id: String) -> Dictionary:
	_ensure_catalog()
	if _unit_catalog.has(id):
		return _unit_catalog[id]
	var alt := str(_unit_aliases.get(id, ""))
	if alt != "" and _unit_catalog.has(alt):
		return _unit_catalog[alt]
	return {}


func _catalog_unit(id: String) -> Dictionary:
	return _catalog_row(id)


static func set_keep_plans(n: int) -> void:
	_keep_plans = n


static func drop_cache() -> void:
	_sheet_lock.lock()
	_sheets.clear()
	_sheet_lock.unlock()


## Starts decoding the sheets of these unit ids (and the enemy data) off the main thread.
static func prefetch(ids: Array) -> void:
	var paths: Array = []
	var need_data := not (_catalog_loaded and _combat_loaded and _weapons_loaded)
	var want: Array = []
	for v in ids:
		var id := str(v).strip_edges().to_lower()
		if id == "bloat":
			for i in 5:
				want.append("bloat%d" % i)
		elif id != "" and not want.has(id):
			want.append(id)
	_sheet_epoch += 1
	if need_data:
		_sheet_lock.lock()
		_prefetch_busy += 1
		_sheet_lock.unlock()
		WorkerThreadPool.add_task(_prefetch_data.bind(want, _sheet_epoch))
		return
	for id in want:
		var path := _sheet_path(str(id))
		if path != "" and not paths.has(path):
			paths.append(path)
	_queue_sheets(paths, _sheet_epoch)


static func _prefetch_data(want: Array, epoch: int) -> void:
	_ensure_catalog()
	var paths: Array = []
	for id in want:
		var path := _sheet_path(str(id))
		if path != "" and not paths.has(path):
			paths.append(path)
	_sheet_lock.lock()
	_prefetch_busy -= 1
	_sheet_lock.unlock()
	_queue_sheets(paths, epoch)


static func _queue_sheets(paths: Array, epoch: int) -> void:
	_sheet_lock.lock()
	for path in paths:
		if _sheets.has(path):
			_sheets[path]["epoch"] = epoch
	# Sheets two plans old (one with ArtCache on) with no live owner are let go.
	for path in _sheets.keys():
		if int(_sheets[path].get("epoch", 0)) < epoch - _keep_plans:
			_sheets.erase(path)
	var todo: Array = []
	for path in paths:
		if not _sheets.has(path):
			_sheets[path] = {"tex": null, "epoch": epoch, "frames": {}}
			todo.append(path)
	_prefetch_busy += todo.size()
	_sheet_lock.unlock()
	# ArtCache on: load during the land build; worker-thread loads stay cached.
	for path in todo:
		if _keep_plans == 0:
			_prefetch_sheet(path)
		else:
			WorkerThreadPool.add_task(_prefetch_sheet.bind(path))


static func _prefetch_sheet(path: String) -> void:
	var tex := ResourceLoader.load(path) as Texture2D
	_sheet_lock.lock()
	if _sheets.has(path):
		_sheets[path]["tex"] = tex
	_prefetch_busy -= 1
	_sheet_lock.unlock()


## Families drawn by OTHER rigs (`assets/rigs/scenes/<id>.tscn`, tools/import_rig.py).
## Their old sheets are in `_trash/rig_sheets`.
const RIG_FAMILIES := ["bloat", "bat", "slime", "fish", "dron", "vortex", "spritebot", "transmitter", "msp", "scythe", "roller", "robot", "turret"]
## Units whose OTHER rig has another name.
const RIG_IDS := {"ttur": "tturret", "eant": "antemitter", "ebloat": "bloatemitter", "destr1": "stolp",
		"bossdron": "megadron", "bossultra": "ultrasentinel", "bossnecr": "necrboss", "bossraider": "raiderboss"}


static func rig_path(id: String) -> String:
	if not (RIG_IDS.has(id) or RIG_FAMILIES.has(str(_catalog_row(id).get("family", "")))):
		return ""
	var path := "res://assets/rigs/scenes/%s.tscn" % str(RIG_IDS.get(id, id))
	return path if ResourceLoader.exists(path) else ""


## The sheet's clips as frame counts with no textures: the sprite keeps the clock, names and
## transform the game code drives, the rig child draws. Readers of the frame texture (fog
## ghost, telekinesis glow, SATS) get null and use the rig's part sprites.
static var _ghost_cache := {}


static func _ghost_frames(key: String, clips: Dictionary) -> SpriteFrames:
	if _ghost_cache.has(key):
		return _ghost_cache[key]
	var blank: Texture2D = null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for clip_v in clips.keys():
		var clip := str(clip_v)
		var data: Dictionary = clips[clip_v]
		frames.add_animation(clip)
		frames.set_animation_speed(clip, float(data.get("speed", TPS)))
		frames.set_animation_loop(clip, bool(data.get("loop", true)))
		for _i in (data.get("frames", []) as Array).size():
			frames.add_frame(clip, blank)
	_ghost_cache[key] = frames
	return frames


func _setup_rig() -> bool:
	var path := rig_path(_species_id)
	# A brain can pick another rig of the same unit (bossraider tr 2: raiderboss2).
	if path != "" and has_meta("rig_name"):
		path = "res://assets/rigs/scenes/%s.tscn" % str(get_meta("rig_name"))
	if path == "" or not ResourceLoader.exists(path) or not is_instance_valid(anim):
		return false
	var packed := _unit_vis.is_empty()
	var entry := UnitBrain.vis_of(str(_catalog_row(_species_id).get("pack", _species_id))) if packed else _unit_vis
	var clips: Dictionary = entry.get("clips", {}).duplicate()
	# One loop for flying and hovering, as on the packed sheet.
	if packed and clips.has("stay"):
		clips.erase("fly")
	anim.sprite_frames = _ghost_frames(_species_id, clips)
	anim.centered = true
	anim.position = Vector2.ZERO
	anim.scale = Vector2.ONE
	anim.offset = _sheet_offset
	rig = (load(path) as PackedScene).instantiate() as RigView
	# A unit_vis sheet puts the Flash origin on the node; a packed cell is centred on
	# `offset` with the origin at `anchor` in the cell.
	var cell: Array = entry.get("cell", [0, 0])
	var anchor: Array = entry.get("anchor", [0, 0])
	if not packed:
		rig.position = Vector2.ZERO
	else:
		rig.position = _sheet_offset + Vector2(float(anchor[0]) - float(cell[0]) * 0.5,
				float(anchor[1]) - float(cell[1]) * 0.5)
	anim.add_child(rig)
	var osn := {}
	for c in clips:
		if clips[c] is Dictionary and clips[c].has("osn"):
			osn[c] = int(clips[c]["osn"])
	rig.follow(anim, {}, osn)
	return true


static func _sheet_path(id: String) -> String:
	if rig_path(id) != "":
		return ""
	var row := _catalog_row(id)
	var tex_name := str(row.get("texture", ""))
	if tex_name == "":
		return ""
	return "res://assets/sprites/sheets/%s" % tex_name


## False while this unit's sheet is still decoding on a worker.
static func species_ready(id: String) -> bool:
	if _prefetch_busy <= 0:
		return true
	if not (_catalog_loaded and _combat_loaded and _weapons_loaded):
		return false
	var path := _sheet_path(id.strip_edges().to_lower())
	if path == "":
		return true
	_sheet_lock.lock()
	var ok := not _sheets.has(path) or _sheets[path]["tex"] != null
	_sheet_lock.unlock()
	return ok


static func _sheet_tex(tex_name: String) -> Texture2D:
	var path := "res://assets/sprites/sheets/%s" % tex_name
	_sheet_lock.lock()
	var entry: Variant = _sheets.get(path)
	var tex: Texture2D = entry["tex"] if entry is Dictionary else null
	_sheet_lock.unlock()
	if tex != null:
		return tex
	# ResourceLoader waits on a worker that is already decoding this path.
	tex = load(path) as Texture2D
	if tex == null:
		return null
	_sheet_lock.lock()
	if _sheets.has(path):
		_sheets[path]["tex"] = tex
	else:
		_sheets[path] = {"tex": tex, "epoch": _sheet_epoch, "frames": {}}
	_sheet_lock.unlock()
	return tex


static func _shared_frames(tex: Texture2D, key: String) -> SpriteFrames:
	_sheet_lock.lock()
	var entry: Variant = _sheets.get(tex.resource_path)
	var frames: SpriteFrames = null
	if entry is Dictionary and entry["tex"] == tex:
		frames = (entry["frames"] as Dictionary).get(key)
	_sheet_lock.unlock()
	return frames


static func _store_frames(tex: Texture2D, key: String, frames: SpriteFrames) -> void:
	_sheet_lock.lock()
	var entry: Variant = _sheets.get(tex.resource_path)
	if entry is Dictionary and entry["tex"] == tex:
		(entry["frames"] as Dictionary)[key] = frames
	_sheet_lock.unlock()


func _apply_catalog(row: Dictionary) -> void:
	max_hp = int(row.get("hp", max_hp))
	points = int(row.get("xp", points))
	var body: Array = row.get("body", [])
	if body.size() >= 2:
		body_size = Vector2(float(body[0]), float(body[1]))
	move_speed = float(row.get("speed", move_speed))
	run_speed = float(row.get("run", run_speed))
	if move_speed > 0.0:
		_move._accel_tick = move_speed / TPS * ACCEL_RATIO
	var dmg := int(row.get("damage", melee_damage))
	melee_damage = dmg
	_bullet_damage = dmg
	_weapons._bullet_type = str(row.get("damage_type", _weapons._bullet_type))
	_weapons._bullet_speed = float(row.get("bullet_speed", _weapons._bullet_speed))
	fight_style = str(row.get("fight", fight_style))
	fixed_post = bool(row.get("fixed", fixed_post))
	_can_lift = bool(row.get("lift", true))
	_calm_vision = float(row.get("vision", _calm_vision))
	_alert_vision = float(row.get("alert", _alert_vision))
	_vision = _calm_vision
	_ear = float(row.get("ear", _ear))
	_v_konus = float(row.get("cone", 0.0))
	_aim_down = bool(row.get("aim_down", false))
	_weapons._gunner_hold = bool(row.get("hold", false))
	_weapons._hold_range = float(row.get("hold_range", _weapons._hold_range))
	_weapons._hold_chance = float(row.get("hold_chance", _weapons._hold_chance))
	_weapons._do_backoff = bool(row.get("backoff", false))
	_weapons._chase_shot = bool(row.get("chase_shot", fight_style == "gunner"))
	_melee._swing_x = float(row.get("swing_x", _melee._swing_x))
	_melee._swing_above = float(row.get("swing_above", _melee._swing_above))
	_melee._swing_below = float(row.get("swing_below", _melee._swing_below))
	_melee._strike_cd = float(row.get("strike_cd", _melee._strike_cd))
	_melee._strike_windup = float(row.get("windup", _melee._strike_windup))
	_melee._strike_hold = float(row.get("strike_hold", _melee._strike_hold))
	_melee._contact_bite = bool(row.get("contact", false))
	_melee._attack_reach = float(row.get("reach", _melee._attack_reach))
	_move_clip = str(row.get("move_clip", _move_clip))
	var cell: Array = row.get("cell", [])
	if cell.size() >= 2:
		_sheet_cell = Vector2i(int(cell[0]), int(cell[1]))
	var off: Array = row.get("offset", [])
	if off.size() >= 2:
		_sheet_offset = Vector2(float(off[0]), float(off[1]))
	var clips: Variant = row.get("clips", {})
	if clips is Dictionary:
		_sheet_clips = clips
	if str(row.get("senses", "")) == "robot":
		set_meta("robot", true)
	var tex_name := str(row.get("texture", ""))
	if tex_name == "":
		return
	if rig_path(_species_id) != "":
		_sheet_native = true
		_tint = Color.WHITE
		body_tint = Color.WHITE
		return
	var tex := _sheet_tex(tex_name)
	if tex == null:
		return
	sheet_texture = tex
	_sheet_native = true
	_tint = Color.WHITE
	body_tint = Color.WHITE


func _frames_from_clips(tex: Texture2D, cell: Vector2i, spec: Dictionary) -> SpriteFrames:
	var cols := maxi(int(float(tex.get_width()) / float(cell.x)), 1)
	var rows := maxi(int(float(tex.get_height()) / float(cell.y)), 1)
	var clips := {}
	var speeds := {}
	var loops := {}
	for key in spec.keys():
		var clip := str(key)
		var data: Dictionary = spec[key] if spec[key] is Dictionary else {}
		var row_i := int(data.get("y", 0))
		if row_i < 0 or row_i >= rows:
			continue
		var start := int(data.get("ff", 0))
		if start >= cols:
			continue
		var length := mini(maxi(int(data.get("len", 1)), 1), cols - start)
		if length <= 0:
			continue
		clips[clip] = SheetFrames.row_clip(row_i, length, start)
		speeds[clip] = float(data.get("df", 1.0)) * TPS
		loops[clip] = clip != "die" and clip != "fall" and int(data.get("rep", 0)) == 1
	if clips.is_empty():
		return SpriteFrames.new()
	return SheetFrames.build(tex, cell.x, cell.y, clips, speeds, loops)


func _apply_turret(id: String) -> void:
	fight_style = "turret"
	fixed_post = true
	move_speed = 0.0
	run_speed = 0.0
	_ear = 0.0
	_calm_vision = 1.0
	_alert_vision = 1.0
	_vision = 1.0
	# Arm turret is the only one whose data sets 45°. Everyone else uses 90°.
	if id == "armturret" or id == "turret3":
		_v_konus = ARM_CONE
	else:
		_v_konus = TURRET_CONE
	# Ceiling mount (cid floor): the gun's watch is downward, not along facing.
	_aim_down = id == "turret" or id == "turret0"
	_flying = false
	_weapons._gunner_hold = false
	_weapons._do_backoff = false
	_weapons._burst_len = 0
	_burst_left = 0


func _apply_bloat() -> void:
	var id := _species_id
	_flying = true
	_hover = 0.0
	_weapons._gunner_hold = false
	_weapons._do_backoff = false
	_move._loose_fly = false
	var reach := BLOAT_RANGE
	if id == "bloat0":
		reach = 600.0
	elif id == "bloat4" or id == "bloat6" or id == "bloat7":
		reach = 700.0
	_melee._attack_reach = reach
	# Spitters keep the weapon armed above. They fly and shoot inside attRasst.
	# They do not use the raider hold. The others bite on contact.
	var spit := id in ["bloat1", "bloat2", "bloat5", "bloat8", "bloat9", "bloat10"]
	if spit and not _weapon.is_empty():
		fight_style = "gunner"
		_weapons._chase_shot = true
		_melee._contact_bite = false
	else:
		fight_style = "melee"
		_melee._contact_bite = true
		_weapons._chase_shot = false
		_melee._strike_cd = BLOAT_TICKS / TPS
		_melee._strike_windup = 0.0
		_melee._strike_hold = 1.0


func _apply_emitter() -> void:
	fight_style = "melee"
	fixed_post = true
	move_speed = 0.0
	run_speed = 0.0
	_flying = false
	_weapons._gunner_hold = false
	_weapons._do_backoff = false
	_weapons._chase_shot = false
	_melee._contact_bite = true
	_melee._attack_reach = INF
	melee_damage = EBLOAT_DAMAGE
	_melee._strike_cd = BLOAT_TICKS / TPS
	_melee._strike_windup = 0.0
	_melee._strike_hold = 1.0


func _apply_scorp(id: String) -> void:
	fight_style = "melee"
	_melee._swing_x = SCORP_X
	_melee._swing_above = SCORP_ABOVE
	_melee._swing_below = SCORP_BELOW
	_melee._strike_hold = SCORP_HOLD
	_melee._strike_cd = PUNCH_TICKS / TPS
	_melee._strike_windup = PUNCH_HIT / TPS
	_show_attack = true
	var punch_id := "scorppunch"
	if id == "scorp2":
		punch_id = "scorp2punch"
	elif id == "scorp3":
		punch_id = "scorp3punch"
	var punch := _weapon_row(punch_id)
	if punch.is_empty():
		melee_damage = 12
	else:
		melee_damage = maxi(1, int(round(float(punch.get("damage", 12)))))
		_weapons._bullet_type = str(punch.get("damage_type", "DAM_BITE"))
	if _comb > 0:
		_melee._body_damage = _comb
	# UnitMonstrik: not a jumper. closeHoldChance 0.7, then WeaponAttack while holding.
	_move._jump_reach = false
	_move._hop_gaps = false
	_melee._ram_while_chase = false
	_melee._melee_while_chase = false
	_move._backpedal = false
	_close_chance = SCORP_HOLD
	_melee._band_min = 0.0
	_melee._band_max = SCORP_X
	_melee._band_up = SCORP_ABOVE
	_melee._band_down = SCORP_BELOW
	_close_release = false
	_close_search = true
	_close_tmin = PUNCH_TICKS
	_close_tmax = PUNCH_TICKS
	_melee._swing_chance = 1.0
	_melee._leap_above = 40.0
	_weapons._reaim_every = 10
	_weapons._reaim_chance = 0.7
	_weapons._reaim_dist = 80.0


func _read_species() -> String:
	for key in ["unit_id", "species", "cid", "id"]:
		if not has_meta(key):
			continue
		var raw := str(get_meta(key)).strip_edges().to_lower()
		if raw != "" and raw != "enemy":
			return raw
	for g in get_groups():
		var gl := str(g).to_lower()
		if gl == "enemies" or gl == "enemy":
			continue
		if _known_species(gl):
			return gl
	var base := String(name).to_lower()
	var at := base.find("@")
	if at > 0:
		base = base.substr(0, at)
	if _known_species(base):
		return base
	return ""


func _known_species(id: String) -> bool:
	if id.contains("turret") or id.begins_with("bloat") or id.begins_with("scorp") or id == "ebloat":
		return true
	if id in ["tarakan", "rat", "molerat"]:
		return true
	return not _catalog_unit(id).is_empty()
func _has_clip(clip: String) -> bool:
	return is_instance_valid(anim) and anim.sprite_frames != null and anim.sprite_frames.has_animation(clip)


func _present(moving: bool) -> void:
	if not is_instance_valid(anim):
		return
	if _climbing and _move._climb_locked:
		facing = _move._climb_face
	# UnitNecros.setVisPos keeps vis.scaleX = 1.
	anim.flip_h = facing < 0.0 and _species_id != "necros"
	if _climbing:
		var side := facing if facing != 0.0 else 1.0
		anim.rotation = -PI * 0.5 * side
	else:
		anim.rotation = 0.0
	if _invis:
		var faded := _tint
		faded.a = 0.12
		anim.modulate = faded
	elif _attack_left <= 0.0 and not levitated and _slow_t <= 0.0:
		anim.modulate = _tint
	if _class_anim:
		_present_class()
		return
	if _attack_left > 0.0 and _has_clip("attack"):
		_play_anim("attack")
	elif _dig_left > 0.0 and _has_clip("dig"):
		_play_anim("dig")
	elif _prep_left > 0.0 and _has_clip("pre"):
		_play_anim("pre")
	elif _super_left > 0.0 and _has_clip("super"):
		_play_anim("super")
	elif _climbing and _has_clip("laz"):
		_play_anim("laz")
	elif _move._crawling and _has_clip("polz"):
		if moving or not _has_clip("sit"):
			_play_anim("polz")
		else:
			_play_anim("sit")
	elif _flying:
		_play_anim("fly" if _has_clip("fly") else "idle")
	elif _move._jet:
		# UnitProtect.animate: fly while jump_n > 5 in the air, walk under 3 px a tick, else trot.
		if not is_on_floor():
			_play_anim("fly" if _move._jet_n > 5 else "jump")
		elif not moving:
			_play_anim("idle")
		else:
			_move_clip = "walk" if absf(velocity.x) < 3.0 * TPS else "trot"
			_play_anim("walk")
	elif not is_on_floor() and not _buried:
		if velocity.y < 0.0 and _has_clip("jump"):
			_play_anim("jump")
		else:
			_play_anim("fall")
	elif moving:
		_play_anim("walk")
	else:
		_play_anim("idle")


## Units whose AS3 class has its own animate(): pony (UnitRaider / UnitRanger), hellhound,
## zombie, eqd, ant (UnitAnt), monstrik (UnitMonstrik: rats, molerat, tarakan, scorpions).
static func _anim_class_of(id: String) -> String:
	if id.begins_with("raider") or id.begins_with("slaver") or id.begins_with("zebra") or id.begins_with("ranger"):
		return "pony"
	if id.begins_with("hellhound"):
		return "hellhound"
	if id.begins_with("zombie"):
		return "zombie"
	if id == "eqd":
		return "eqd"
	if id.begins_with("encl"):
		return "encl"
	if id.begins_with("merc"):
		return "merc"
	if id.begins_with("ant"):
		return "ant"
	if id in ["rat", "molerat", "tarakan"] or id.begins_with("scorp"):
		return "monstrik"
	return ""


## The class animate() rules, dx / dy in px per tick. Airborne pony / hellhound / zombie / eqd
## hold the jump row on frame len * (dy * 0.6 + 8) / 16 (setStab); ant / monstrik loop it.
func _present_class() -> void:
	var dx := absf(velocity.x) / TPS
	var still := dx < 0.2
	var on_floor := is_on_floor()
	var clip := "stay"
	var stab := false
	# UnitEncl / UnitMerc / UnitEqd: walking away from the facing side plays the row backwards.
	var back := false
	if _anim_class != "ant":
		anim.rotation = 0.0
	match _anim_class:
		"encl", "merc":
			if levitated or (_flying and not on_floor) or _swimming:
				clip = "fly"
			elif on_floor:
				if still:
					clip = "stay"
				elif _anim_class == "encl" and _move._walker and ai_state in [ST_IDLE, ST_PATROL, ST_HOLD]:
					clip = "walk"
				else:
					clip = "trot" if _anim_class == "encl" else "walk"
					back = signf(velocity.x) != signf(facing)
			elif _anim_class == "merc":
				clip = "jump"
				stab = true
		"pony":
			# UnitRaider.animate; UnitRanger.animate has no levitation or swim rows.
			var ranger := _species_id.begins_with("ranger")
			if levitated and not ranger:
				clip = "derg"
			elif _climbing:
				clip = "laz"
			elif on_floor:
				if still or ai_state == ST_DASH_PREP:
					clip = "stay"
				elif (_pony_rams() and _is_attacking()) or ai_state == ST_DASH:
					clip = "run"
				elif _move._walker and ai_state in [ST_IDLE, ST_PATROL, ST_HOLD]:
					clip = "walk"
				else:
					clip = "trot"
			elif _swimming and not ranger:
				clip = "plav"
			else:
				clip = "jump"
				stab = true
		"hellhound":
			if on_floor:
				if _move._crawling:
					clip = "polz" if dx > 1.0 else "sit"
				elif dx > 6.0:
					clip = "run"
				elif dx > 1.0:
					clip = "walk"
			elif _climbing:
				clip = "laz"
			else:
				clip = "jump"
				stab = true
		"zombie":
			if _prep_left > 0.0 and _has_clip("pre"):
				clip = "pre"
			elif _super_left > 0.0 and _has_clip("super"):
				clip = "super"
			elif _dig_left > 0.0 and _has_clip("dig"):
				clip = "dig"
			elif on_floor:
				if dx < 1.0:
					clip = "stay"
				elif ai_state == ST_CHASE:
					clip = "run"
				elif ai_state == ST_SEARCH or dx > 6.0:
					clip = "trot"
				else:
					clip = "walk"
			else:
				clip = "jump"
				stab = true
		"eqd":
			if on_floor:
				if still:
					clip = "stay"
				elif dx < 4.0:
					clip = "walk"
					back = signf(velocity.x) != signf(facing)
				elif dx > 9.0:
					clip = "run"
				else:
					clip = "trot"
					back = signf(velocity.x) != signf(facing)
			else:
				clip = "jump"
				stab = true
		"ant", "monstrik":
			if _attack_left > 0.0 and _has_clip("attack"):
				clip = "attack"
				# t_punch == 15 restarts the swing.
				if _attack_left > _last_attack_left + 0.001:
					_current_anim = ""
			elif on_floor:
				if still:
					clip = "stay"
				elif dx > 5.0:
					clip = "run"
				else:
					clip = "walk"
			elif _climbing and _anim_class == "ant":
				clip = "walk" if absf(velocity.y) / TPS > 1.0 else "stay"
			elif _swimming or levitated:
				clip = "plav"
			else:
				clip = "jump"
	_last_attack_left = _attack_left
	anim.speed_scale = -1.0 if back else 1.0
	if not _has_clip(clip):
		clip = "stay"
	if _current_anim != clip and anim.sprite_frames.has_animation(clip):
		_current_anim = clip
		anim.play(clip)
	if stab and clip == "jump":
		anim.pause()
		var n := anim.sprite_frames.get_frame_count(clip)
		var at := clampf((velocity.y / TPS * 0.6 + 8.0) / 16.0, 0.0, 0.999)
		anim.frame = clampi(int(float(n) * at), 0, n - 1)


## UnitRaider attackerType 0: no weapon, or a gripped melee one.
func _pony_rams() -> bool:
	return _weapon.is_empty() or (fight_style == "melee" and _krep == 1)
## The 30 Hz clock: whole AI ticks this frame, the shock countdown.
## One sim step per call at 30 Hz, so a `%` on _ai_tick cannot skip a tick.
func _advance_ticks(_delta: float) -> void:
	_frame_ticks = Sim.frame_steps
	_ai_tick += _frame_ticks
	if _shok > 0:
		_shok = maxi(0, _shok - _frame_ticks)
	if _move._ai_laz > 0:
		_move._ai_laz = maxi(0, _move._ai_laz - _frame_ticks)
	if _climbing:
		if _move._t_laz < 0:
			_move._t_laz = 0
		_move._t_laz += _frame_ticks
	else:
		if _move._t_laz > 0:
			_move._t_laz = 0
		_move._t_laz -= _frame_ticks
		_move._r_laz = 0


static func _room_of(at: Vector2) -> Vector2i:
	return Vector2i(int(floor(at.x / ROOM_W)), int(floor(at.y / ROOM_H)))


static func _room_near(room: Vector2i) -> bool:
	return absi(room.x - AiWorld.room.x) <= ACTIVE_REACH and absi(room.y - AiWorld.room.y) <= ACTIVE_REACH


## Only the player's Location runs in the original. Here the player's room and its
## neighbours run; a unit that ends up elsewhere sleeps until the player comes near.
func _room_still_active() -> bool:
	if (_friendly and not _ground_ally) or _ai().always_active:
		return true
	_room_check -= _frame_ticks
	if _room_check > 0:
		return true
	_room_check = ROOM_CHECK_TICKS
	if AiWorld.room.x == -99999 and _senses._player_valid():
		AiWorld.room = _room_of(_player.global_position)
	var here := _room_of(global_position)
	if _room_near(here):
		return true
	# Seamless rooms: a unit already after the player keeps going one room further.
	if not _is_calm() and absi(here.x - AiWorld.room.x) <= CHASE_REACH and absi(here.y - AiWorld.room.y) <= CHASE_REACH:
		return true
	_fall_asleep()
	return false


func _fall_asleep() -> void:
	_asleep = true
	velocity = Vector2.ZERO
	floor_check.enabled = false
	wall_check.enabled = false
	set_physics_process(false)


func _wake_up() -> void:
	if not _asleep or bool(get_meta("hacked", false)):
		return
	_asleep = false
	_room_check = ROOM_CHECK_TICKS
	floor_check.enabled = true
	wall_check.enabled = true
	set_physics_process(true)


func _ensure_watch() -> void:
	if _watch != null and is_instance_valid(_watch):
		return
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	_watch = RoomWatch.new()
	_watch.name = "EnemyRoomWatch"
	_watch.set("on_room", _watch_room)
	host.call_deferred("add_child", _watch)


static func _watch_room(room: Vector2i, tree: SceneTree) -> void:
	AiWorld.room = room
	for node in tree.get_nodes_in_group("foe_bodies"):
		if not bool(node.get("_asleep")):
			continue
		var n2 := node as Node2D
		if n2 != null and _room_near(_room_of(n2.global_position)):
			node.call("_wake_up")


## One node follows the player's room and wakes the units that come into reach.
class RoomWatch extends Node:
	var on_room: Callable
	var _room := Vector2i(-99999, -99999)
	var _player: Node2D = null

	func _physics_process(_delta: float) -> void:
		if _player == null or not is_instance_valid(_player):
			_player = Run.local_player() as Node2D
			if _player == null:
				return
		var p := _player.global_position
		var room := Vector2i(int(floor(p.x / 1920.0)), int(floor(p.y / 1000.0)))
		if room != _room:
			_room = room
			on_room.call(room, get_tree())


func _watch_levitation() -> void:
	if not _senses._player_valid():
		return
	var obj: Variant = _player.get("_tele_obj")
	if not is_instance_valid(obj) or not (obj is Node2D):
		return
	var held := obj as Node2D
	var gx := held.global_position.x - global_position.x
	if not _overlook and gx * facing < 0.0:
		return
	var half := _body_size(self).y * 0.5
	var gy := held.global_position.y - global_position.y + half
	var reach := _vision * 1000.0
	if gx * gx + gy * gy >= reach * reach:
		return
	if not Sight.los_clear(global_position + Vector2(0.0, -half * 1.5), held.global_position, held):
		return
	if held.is_in_group("mines"):
		_alarm_from(held.global_position)
		var dx := held.global_position.x - global_position.x
		var dy := held.global_position.y - global_position.y + half
		if dx * dx + dy * dy < MINE_FLEE_RANGE * MINE_FLEE_RANGE:
			_move._flee(dx)
		else:
			if fight_style == "gunner" and not _thrown:
				ai_state = ST_HOLD
			ai_spok = MAX_SPOK + SIGHT_BONUS
			_state_left = _ticks(float(Rng.randi_range(&"ai", FLEE_TIME_MIN, FLEE_TIME_MAX)) / TPS)
	else:
		ai_spok = MINE_SUSPICION
		_senses._sync_vision()


## Live grenades in the level (Location.grenades), gathered once per frame.
static func _gather_grenades(tree: SceneTree) -> Array:
	var out: Array = []
	for group in ["player_bullets", "enemy_bullets"]:
		for node in tree.get_nodes_in_group(group):
			if bool(node.get("explode_on_timeout")) and float(node.get("blast_radius")) > 0.0:
				out.append((node as Node2D).global_position)
	return out


## WalkMotor porog: a ledge up to porog pixels is stepped onto instead of blocking.
func _step_up() -> bool:
	return _move._step_up()
func _tick_role(delta: float) -> void:
	_melee._body_cd = maxi(0, _melee._body_cd - _frame_ticks)
	_attack_left = maxi(0, _attack_left - _frame_ticks)
	_weapons._gutsy_cd = maxi(0, _weapons._gutsy_cd - _frame_ticks)
	_necro_cd = maxi(0, _necro_cd - _frame_ticks)
	if _cast_left > 0.0:
		_cast_left -= _frame_ticks
		if _cast_left <= 0.0:
			_invis = false
	if _dig_left > 0.0:
		_dig_left -= _frame_ticks
		visible = true
		if _dig_left <= 0.0:
			_buried = false
			set_collision_layer_value(3, true)
		return
	if _buried:
		if _senses._player_valid() and global_position.distance_to(_player.global_position) < 480.0:
			_dig_left = _ticks(24.0 / TPS)
			visible = true
		return
	if _prep_left > 0.0:
		_prep_left -= _frame_ticks
		if _prep_left <= 0.0:
			_begin_super()
			_super_left = _ticks(_super_need)
	elif _super_left > 0.0:
		_run_super(delta)
		_super_left -= _frame_ticks
		if _super_left <= 0.0:
			_end_super()
	elif _super != "" and ai_state == ST_CHASE:
		_rage += float(_frame_ticks)
		if _rage >= _zlo and _senses._player_valid():
			_rage = 0.0
			_prep_left = _ticks(_prep_need)
			if _tele_kind == "ghoul":
				if _tele_unit == null and _track_player:
					_tele_unit = _player
				# UnitZombie.control calls findSuper for ss 1 and 2 only.
				if _tele_tr == 2:
					_find_super()
	if _cast != "" and not _is_calm():
		_cast_ready -= _frame_ticks
		if _cast_ready <= 0.0:
			_do_cast()
	_weapons._tick_side(delta)
	_weapons._tick_gutsy()
	_tick_necro()
	_tick_vortex(delta)
## Unit.checkStairs: X = phX1 + scX/2 or phX2 - scX/2. run() skips X while isLaz, so this
## may sit inside a wall tile; the 28 px box keeps the Godot body inside the 40 px column.
func _snap_to_rail(rail: Area2D, side: String) -> void:
	_move._snap_to_rail(rail, side)
func _box_fits(at: Vector2, size: Vector2) -> bool:
	return _move._box_fits(at, size)
func _solid_at(at: Vector2) -> bool:
	return _move._solid_at(at)


func _follow_point() -> Vector2:
	var face := 1.0
	if _senses._player_valid() and "facing" in _player:
		face = float(_player.facing)
	return _player.global_position + Vector2(face * -120.0, -80.0)


func _calm_cast() -> void:
	if _cast != "invis" or not _is_calm() or _invis or _cast_ready > 0.0:
		return
	if Rng.randf(&"ai") < 0.5:
		_do_cast()


func _do_cast() -> void:
	_cast_ready = _ticks(_cast_gap * Rng.randf_range(&"ai", 0.8, 1.2))
	if _cast == "invis":
		_invis = true
		_cast_left = _ticks(300.0 / TPS)
	elif _cast == "teleport" and _senses._player_valid():
		var face := 1.0
		if "facing" in _player:
			face = float(_player.facing)
		var behind := Rng.randf(&"ai") < 0.7
		var dist := Rng.randf_range(&"ai", 200.0, 500.0) if Rng.randf(&"ai") < 0.5 else Rng.randf_range(&"ai", 200.0, 1000.0)
		var ny := 0.0 if dist <= 500.0 else Rng.randf_range(&"ai", -80.0, 80.0)
		var side := -face if behind else face
		global_position = _player.global_position + Vector2(side * dist, ny)
	elif _cast == "telepathy" and _senses._player_valid():
		_weapons._launch(_player.global_position, _weapon_row("alipsy"), false, false, false)
func _tick_necro() -> void:
	if not _necro_shot or _is_calm() or not _senses._player_valid() or _necro_cd > 0.0:
		return
	if absf(_player.global_position.y - global_position.y) > 80.0:
		return
	if absf(_player.global_position.x - global_position.x) > 400.0:
		return
	if _frame_ticks <= 0:
		return
	for _i in _frame_ticks:
		if Rng.randf(&"ai") < 0.1:
			_weapons._launch(_player.global_position, _weapon_row("zombinecro"), false, false, false)
			_necro_cd = _ticks(60.0 / TPS)
			return


func _tick_vortex(delta: float) -> void:
	if _vortex_left <= 0 or _is_calm():
		return
	_vortex_wait -= _frame_ticks
	if _vortex_wait > 0.0:
		return
	_spawn_vortex()
	_vortex_left -= 1
	_vortex_wait = _ticks(500.0 / TPS)


func _spawn_vortex() -> void:
	var packed := load("res://scenes/enemy.tscn") as PackedScene
	if packed == null:
		return
	var node := packed.instantiate() as CharacterBody2D
	if node == null:
		return
	node.set_meta("vortex_minion", true)
	node.set_meta("unit_id", "vortex")
	var host := get_tree().current_scene
	if host == null:
		node.queue_free()
		return
	host.add_child(node)
	node.global_position = global_position + Vector2(Rng.randf_range(&"spawn", -24.0, 24.0), -body_size.y * 0.4)


## UnitBloat.dropLoot: tr >= 8 leaves two bloats of tr - 1 (same questId); bloat3 (units.xml
## bulb) bursts into two bloat0, four when it is a hero.
func _bloat_split(at: Vector2) -> void:
	var tr_b := int(_species_id.trim_prefix("bloat"))
	var kids: Array = []
	if tr_b >= 8:
		kids = ["bloat%d" % (tr_b - 1), "bloat%d" % (tr_b - 1)]
	elif _species_id == "bloat3":
		kids = ["bloat0", "bloat0"]
		if int(get_meta("hero", 0)) > 0:
			kids += ["bloat0", "bloat0"]
	if kids.is_empty():
		return
	var quest_steps: Array = []
	if tr_b >= 8:
		for step in die_actions:
			if step is Dictionary and str((step as Dictionary).get("act", "")) == "_qid":
				quest_steps.append(step)
	var tree := get_tree()
	var alert_at: Variant = _player.global_position if is_instance_valid(_player) else null
	# This body is freed right after death and a hit can land mid physics flush, so the
	# children are added on the next frame from values captured here, not from self.
	tree.process_frame.connect(func() -> void:
		_spawn_bloats(tree, kids, quest_steps, at, alert_at), CONNECT_ONE_SHOT)


static func _spawn_bloats(tree: SceneTree, kids: Array, quest_steps: Array, at: Vector2, alert_at: Variant) -> void:
	var packed := load("res://scenes/enemy.tscn") as PackedScene
	var host := tree.current_scene
	if packed == null or host == null:
		return
	for kid in kids:
		var node := packed.instantiate() as CharacterBody2D
		if node == null:
			continue
		node.set_meta("unit_id", kid)
		node.set("die_actions", quest_steps.duplicate())
		node.position = at
		host.add_child(node)
		node.global_position = at
		if alert_at is Vector2 and node.has_method("_become_alert"):
			node.call("_become_alert", alert_at)


func _begin_super() -> void:
	if _super == "jump" and _senses._player_valid():
		var dest := _player.global_position - global_position
		var dist := dest.length()
		if dist > 1.0:
			velocity = dest / dist * _super_v
			var ticks := dist / maxf(_super_v / TPS, 1.0)
			_super_need = minf(20.0, ticks) / TPS
		_move._jump_free = true
		velocity.y = velocity.y
	elif _super == "spit" and _spit_id != "" and _senses._player_valid():
		_weapons._launch(_player.global_position, _weapon_row(_spit_id), false, false, false)
	elif _super == "rad":
		_rad_power = 20.0
		_rad_left = _super_need
		_heal_zombies(1200.0, 30.0)
	elif _super == "quake":
		_quake_step = 0
	elif _super == "tele" and _tele != null:
		_super_tick = 0
		if _tele_unit != null and is_instance_valid(_tele_unit) and int(_tele_unit.get("levit")) != 1:
			_tele.grab(_tele_unit)


func _run_super(delta: float) -> void:
	if _super == "rad" and _senses._player_valid():
		var dist := global_position.distance_to(_player.global_position)
		if dist < 1200.0:
			var koef := (1200.0 - dist) / 1200.0
			GameState.rad += _rad_power * koef * float(_frame_ticks)
		if _super_need > 0.0:
			_rad_power = maxf(1.0, _rad_power - (19.0 / _super_need) * delta)
	elif _super == "quake":
		_quake_step -= _frame_ticks
		if _quake_step <= 0.0:
			_quake_step = _ticks(4.0 / TPS)
			if _senses._player_valid() and global_position.distance_to(_player.global_position) < 420.0:
				_player.global_position.y -= 12.0


func _end_super() -> void:
	_move._jump_free = false
	if _super == "jump":
		_super_need = 20.0 / TPS
	if _super == "rad":
		_rad_power = 1.0
	if _super == "tele" and _tele != null:
		_tele.release()
		_tele_unit = null


func _heal_zombies(radius: float, amount: float) -> void:
	for node in Units.near(global_position, radius):
		if node == self or not node is Node:
			continue
		if not (node as Node).has_method("receive_rad_heal"):
			continue
		var body := node as Node2D
		if body == null:
			continue
		var dist := global_position.distance_to(body.global_position)
		if dist >= radius:
			continue
		var koef := (radius - dist) / radius
		(node as Node).receive_rad_heal(int(round(amount * koef)))


func receive_rad_heal(amount: int) -> void:
	if amount <= 0 or _downed or not _species_id.begins_with("zombie"):
		return
	hp = mini(max_hp, hp + amount)


func _hurt_radius(radius: float, damage: int, tip: String) -> void:
	if damage <= 0:
		return
	if _senses._player_valid() and global_position.distance_to(_player.global_position) <= radius:
		if _player.has_method("take_hit"):
			WorldOps.damage(_player, HitInfo.make(damage, tip, self))
	for node in Units.near(global_position, radius):
		if node == self or not node is Node2D or not is_instance_valid(node):
			continue
		if global_position.distance_to((node as Node2D).global_position) > radius:
			continue
		if (node as Node).has_method("take_hit"):
			WorldOps.damage((node as Node), HitInfo.make(damage, tip, self))


## UnitAlicorn.pole (xml pole = allid, or aiTip pole): holds a force field. It
## does not move or react and sparks 'unlock' at the horn every 5 ticks, until
## hp falls under 70% or it dies; then it unlocks and opens that allid.
func _pole_hold() -> bool:
	if not has_meta("pole") and str(get_meta("ai_tip", "")) != "pole":
		return false
	if not _species_id.begins_with("alicorn"):
		return false
	if hp < max_hp * 0.7:
		_pole_release()
		return false
	_pole_t += _frame_ticks
	if _pole_t >= 5:
		_pole_t = 0
		Fx.particles("unlock", muzzle.global_position, {"rx": 20, "ry": 20, "source": self})
	return true


func _pole_release() -> void:
	if not has_meta("pole") and str(get_meta("ai_tip", "")) != "pole":
		return
	var allid := str(get_meta("pole", ""))
	remove_meta("pole")
	if str(get_meta("ai_tip", "")) == "pole":
		set_meta("ai_tip", "")
	if allid == "":
		return
	for props in get_tree().get_nodes_in_group("land_props"):
		if props.has_method("all_act"):
			props.call("all_act", "unlock", allid)
			props.call("all_act", "open", allid)


func _begin_death() -> void:
	if _dead:
		return
	Fx.ai(&"died", self)
	_pole_release()
	if _tele != null:
		_tele.release()
		_tele_unit = null
	if _ai().on_die():
		return
	_ai().died()
	_last_rites = true
	if not _friendly and not _revives:
		_drop_loot()
		if _species_id.begins_with("bloat"):
			_bloat_split(global_position)
		# Unit.incStat: the PipBuck Enemies page kill count. UnitBloat skips tr 7-9 (king splits).
		if _species_id != "" and not _species_id in ["bloat7", "bloat8", "bloat9"]:
			WorldOps.set_trigger("frag_" + _species_id, int(Travel.triggers.get("frag_" + _species_id, 0)) + 1)
	_ai().drop_loot()
	if _drop_id != "":
		_weapons._launch(_feet(self), _weapon_row(_drop_id), false, false, false)
		_drop_id = ""
	_last_rites = false
	if _pink_death:
		_hurt_radius(150.0, maxi(1, int(round(float(_comb) * 0.4))), "DAM_PINKCLOUD")
		_pink_death = false
	var host := get_tree().get_first_node_in_group("land_props")
	if host and host.has_method("run_actions"):
		WorldOps.run_actions(host, die_actions)
	if _friendly and _pet_revive:
		_downed = true
		hp = 0
		_revive_left = _ticks(30.0)
		visible = false
		velocity = Vector2.ZERO
		set_collision_layer_value(3, false)
		return
	if _friendly:
		queue_free()
		return
	if _revives:
		_downed = true
		hp = 0
		_revive_left = _ticks(300.0 / TPS)
		velocity = Vector2.ZERO
		return
	GameState.enemy_defeated(points)
	# Unit.die: an exotic death disintegrates; trup leaves a body unless the hit
	# overkilled it past -2 * maxhp; an overkilled bloody body dissolves in blood.
	var burn := _Desintegr.sposob(_die_tip, hp, max_hp, _trup)
	var blood := _Desintegr.blood_of(_species_id)
	if burn == 0 and _trup and hp <= -2 * max_hp and blood > 0:
		burn = 4 + blood
		UnitFx.snd("trup")
	if burn > 0:
		_become_corpse()
		remove_from_group("levitatable")
		_Desintegr.start(self, burn, body_size, _UnitMassa.massa(self))
	elif _trup and hp > -2 * max_hp:
		_become_corpse()
	else:
		queue_free()


## sost 3: a body with fraction 0. It falls, lies in the crouching box, and can be lifted.
func _become_corpse() -> void:
	_dead = true
	fraction = 0
	ai_state = ST_IDLE
	_track_player = false
	_burst_left = 0
	_melee._windup_left = 0
	_cut = 0.0
	_poison = 0.0
	_burn_left = 0
	_acid_left = 0
	_pink_left = 0
	remove_from_group("enemies")
	Units.touch()
	remove_from_group("foe_bodies")
	_asleep = false
	collision_layer = 0
	collision_mask = 1 | 64
	floor_snap_length = _base_snap
	motion_mode = MOTION_MODE_GROUNDED
	if not levitated:
		velocity.x = 0.0
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		var box := RectangleShape2D.new()
		box.size = Vector2(body_size.x, maxf(8.0, body_size.y * 0.5))
		shape_node.shape = box
		shape_node.position = Vector2(0.0, -box.size.y * 0.5)
	floor_check.enabled = false
	wall_check.enabled = false
	if is_instance_valid(anim):
		anim.modulate = _tint
	_current_anim = ""
	if _class_anim and not is_on_floor() and _has_clip("death"):
		_play_anim("death")
	else:
		_play_anim("die")
	if _can_lift:
		add_to_group("levitatable")
	set_physics_process(true)


func _corpse_process(delta: float) -> void:
	if levitated:
		if bool(get_meta("tele_driven", false)):
			velocity = Vector2.ZERO
			_corpse_anim()
			return
		var to := _lev_point - (global_position + Vector2(0.0, -body_size.y * 0.25))
		var dist := to.length()
		velocity = to * (_lev_speed / dist) if dist > 2.0 else Vector2.ZERO
		move_and_slide()
		_corpse_anim()
		return
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
	move_and_slide()
	_corpse_anim()
	if is_on_floor() and absf(velocity.x) < 1.0 and not levitated:
		velocity = Vector2.ZERO
		set_physics_process(false)


## UnitRaider.animate (sost 2/3): a body off the floor holds "death"; landing from it plays
## "fall" once, otherwise "die" stays.
func _corpse_anim() -> void:
	if not _class_anim or not _has_clip("death"):
		return
	if not is_on_floor():
		if _current_anim != "death":
			_play_anim("death")
	elif _current_anim == "death" and _anim_class not in ["ant", "monstrik"]:
		# UnitAnt / UnitMonstrik keep "death" once in it; the others land into "fall".
		_play_anim("fall")


## Unit.dropLoot: the unit's loot table, essence for a hero, a gem by dropTre.
## UnitRaider adds its weapon (isDropArm) and a grenadier's last three throws at its feet.
func _drop_loot() -> void:
	var host := get_tree().get_first_node_in_group("land_props")
	var center := global_position + Vector2(0.0, -_body_size(self).y * 0.5)
	if host != null:
		for drop in _loot_table(_loot_cont):
			_spawn_drop(host, str(drop.get("id", "")), int(drop.get("n", 1)), center)
		if int(get_meta("hero", 0)) > 0 and not _is_machine() and Rng.randf(&"loot") < 0.75:
			_spawn_drop(host, "essence", 1, center)
		var tre := _drop_tre()
		if tre > 0.0 and points > 0 and Rng.randf(&"loot") < tre * float(points) / 4000.0:
			_spawn_drop(host, "gem%d" % (Rng.randi(&"loot") % 3 + 1), 1, center)
		if _raider_type and _drop_arm and not _weapon.is_empty():
			var wid := str(_weapon.get("id", ""))
			if wid != "" and not wid.begins_with("robo"):
				# LootGen.lootId(..., 0): Item kol 0 gives a weapon sost 0.05-0.2.
				_spawn_drop(host, wid, 1, muzzle.global_position, Rng.randf_range(&"loot", 0.05, 0.2))
	if _raider_type and _thrown and not _weapon.is_empty():
		for _i in DEATH_THROWS:
			var feet := _feet(self) + Vector2(Rng.randf_range(&"loot", -DROP_SCATTER, DROP_SCATTER), 0.0)
			_weapons._launch(feet, _weapon, false, false, false)


func _drop_tre() -> float:
	if Inventory == null or Condition == null:
		return 0.0
	var worn := str(Inventory.get("worn"))
	if worn == "":
		return 0.0
	return float(Condition.armor_row(worn).get("tre", 0.0))


func _spawn_drop(host: Node, id: String, n: int, at: Vector2, sost := 1.0) -> void:
	if id == "" or n < 1:
		return
	var drop := GroundLoot.new()
	drop.item_id = id
	drop.stack = n
	if sost < 1.0:
		drop.set_meta("mult_hp", sost)
	host.add_child(drop)
	drop.global_position = at
	drop.shove_clear()


## LootGen.lootDrop tables for units. Each row: chance, loot type, id, count, flags.
## Flag "or" rolls only if the row before failed; "hero" needs a hero unit.
const LOOT_PATH := "res://assets/data/unit_loot.json"
static var UNIT_LOOT: Dictionary = {}
static var _loot_ready: bool = _load_unit_loot()


static func _load_unit_loot() -> bool:
	var data: Variant = DataLib.load(LOOT_PATH)
	if data is Dictionary:
		UNIT_LOOT = data
	return true


func _loot_table(cont: String) -> Array:
	var key := cont
	if key.begins_with("alicorn") and key.length() == 8:
		key = "alicorn"
	elif key in ["ranger1", "ranger2", "ranger3"]:
		key = "ranger"
	elif key in ["encl2", "encl3", "encl4"]:
		key = "encl"
	if not UNIT_LOOT.has(key):
		return []
	var gen := LootRoll.new()
	gen._drops = []
	gen._got = 0
	gen._stage = 1
	gen._locdif = 0.0
	gen._wlevel = 1.0
	gen._lockdif = 50.0
	var level := 1
	if Progression != null:
		level = maxi(1, int(Progression.get("level")))
	gen._cap = float(level - 1 + 3)
	LootRoll._ensure()
	var hero := int(get_meta("hero", 0)) > 0
	var last := true
	for row_v in UNIT_LOOT[key]:
		var row: Array = row_v
		var flag := str(row[4]) if row.size() > 4 else ""
		if flag == "or" and last:
			continue
		if flag == "hero" and not hero:
			continue
		var count := int(row[3]) if row.size() > 3 else -1
		if count < -1:
			# Math.floor(Math.random() * 3 + 1): 1 to 3.
			count = Rng.randi_range(&"loot", 1, -count)
		last = gen._new(float(row[0]), str(row[1]), str(row[2]), count)
	return gen._drops


func _rise() -> void:
	_downed = false
	visible = true
	set_collision_layer_value(3, true)
	velocity = Vector2.ZERO
	if _friendly:
		hp = maxi(1, int(round(float(max_hp) * 0.5)))
		if _senses._player_valid():
			global_position = _follow_point()
	else:
		hp = max_hp
	_play_anim("idle")


func _apply_role(id: String, row: Dictionary) -> void:
	_role_motion(id, row)
	_weapons._role_grenade(row)
	_role_faction(id)
	_weapons._role_arm(id, row)
	_role_critters(id)
	_role_chase(id)
	_apply_zombie(id, int(row.get("ss", 0)))
	_setup_tele(id, int(row.get("ss", 0)))
	if _flying and _sheet_clips.has("fly"):
		_move_clip = "fly"
	if _move._jet or (_move._flyer and _species_id.begins_with("alicorn") and _sheet_clips.has("walk")):
		_move_clip = "walk"

func _role_motion(id: String, row: Dictionary) -> void:
	_species_id = id
	_comb = int(row.get("comb", melee_damage))
	_krep = int(row.get("krep", 0))
	_flying = bool(row.get("fly", false))
	# UnitProtect is a UnitAIRobot walker; its jump() is a jet with jump_n ticks (jump_m 90, hero 500).
	_move._jet = id.begins_with("protect")
	if _move._jet:
		_flying = false
		_move._jet_max = 500 if int(get_meta("hero", 0)) == 1 else 90
		_move._jet_n = 100
	var pet_row := bool(row.get("pet", false)) or str(row.get("fraction", "")) == "player"
	_friendly = pet_row or bool(get_meta("player_side", false))
	_ground_ally = _friendly and not pet_row and (id == "raider" or _raider_kin(id)) and not _flying
	# UnitRaider flyer (Enclave, mercs): a walker that takes off and lands (isFly), not a hoverer.
	# UnitAlicorn has the same isFly / t_fall / t_landing rules.
	_move._flyer = _flying and (id.begins_with("encl") or id.begins_with("merc") or id.begins_with("alicorn"))
	if _move._flyer:
		_flying = false
	_cast = str(row.get("cast", ""))
	_revives = bool(row.get("revives", false))
	_drop_id = str(row.get("drop_weapon", ""))
	_weapons._burst_len = int(row.get("och", 0))
	_fire_down = id.begins_with("bossencl")
	_vortex_left = 8 if _fire_down else 0
	_weapons._encl_bonus = id.begins_with("encl")
	if _cast == "teleport":
		_cast_gap = (250.0 + 90.0) / TPS
	elif _cast != "":
		_cast_gap = (500.0 + 90.0) / TPS
	if _cast != "":
		_cast_ready = _ticks(90.0 / TPS)
	if id == "rat":
		_move._hop_vy = 8.0 * TPS
	elif id == "molerat":
		_move._hop_vy = 14.0 * TPS
	if id.begins_with("hellhound"):
		_move._climb = true
		_move._can_crawl = true
		_melee._smash = true
		_move._brake_ledge = true
		_move._air_frac = 1.0
		_move._wall_give = 0.5
		_move._turn_at_wall = false
		_move._backpedal = false
		_close_chance = 0.0
		_move._hop_gaps = true
		_move._jump_reach = true
	if id.begins_with("gutsy"):
		_weapons._gutsy_fire = true
		_weapons._chase_shot = false
		_weapons._gutsy_scale = 2.0 if id == "gutsy1" else 1.0
	if id.begins_with("ranger"):
		_weapons._ranger_side = true
		_weapons._shoot_climb = true
func _role_faction(id: String) -> void:
	if _ground_ally:
		fraction = 100
	elif _friendly:
		_pet_range = 400.0 if id == "owl" else 200.0
		_pet_revive = id == "phoenix"
		_hover = 80.0
func _role_critters(id: String) -> void:
	if id.begins_with("ant"):
		_move._climb = true
		_move._hop_gaps = false
		_move._jump_reach = false
		_move._jump_boost = 5.0
		_weapons._reaim_every = 10
		_weapons._reaim_chance = 0.7
		_weapons._reaim_dist = 80.0
		if id == "ant3":
			_melee._body_damage = _comb if _comb > 0 else 7
			# Fire ants breathe only while holding. closeHoldChance is 0.07.
			_weapons._gunner_hold = false
			_close_chance = 0.07
			_melee._band_min = 0.0
			_melee._band_max = 120.0
			_melee._band_up = 80.0
			_melee._band_down = 80.0
			_close_tmin = 40.0
			_close_tmax = 90.0
			_close_search = true
			_close_release = false
			_weapons._shot_chance = 1.0
			_weapons._blind_chance = 0.0
			_weapons._need_sight = true
			_weapons._chase_shot = false
			_move._backpedal = false
			_melee._ram_while_chase = true
			_melee._ram_x = 100.0
			_melee._ram_y = 120.0
			_melee._bite_hop = HOP_POWER
		else:
			fight_style = "melee"
			_melee._contact_bite = true
			_weapons._chase_shot = false
			melee_damage = _comb if _comb > 0 else melee_damage
			_melee._bite_hop = HOP_POWER
	if id == "tarakan":
		fight_style = "melee"
		_melee._contact_bite = true
		_weapons._chase_shot = false
		melee_damage = _comb if _comb > 0 else 4
		_move._hop_gaps = false
		_move._jump_reach = false
		_melee._bite_hop = HOP_POWER
		_weapons._reaim_every = 10
		_weapons._reaim_chance = 0.7
		_weapons._reaim_dist = 80.0
	if id == "necros":
		_move._loose_fly = true
		_flying = true
		fight_style = "melee"
		_melee._contact_bite = true
		_weapons._chase_shot = false
		melee_damage = _comb if _comb > 0 else 80
		_move_clip = "stay"
	if id == "rat" or id == "molerat":
		_melee._bite_hop = HOP_POWER
		_move._hop_gaps = true
		_move._jump_reach = true
		_weapons._reaim_every = 10
		_weapons._reaim_chance = 0.7
		_weapons._reaim_dist = 80.0

func _role_chase(id: String) -> void:
	if not _raider_kin(id) and _weapons._reaim_chance == DURAK_REAIM:
		_weapons._reaim_chance = SMART_REAIM
	if _flying:
		_move._runs_alert = false
		_move._jump_reach = false
		_move._backpedal = false
	if fixed_post or fight_style == "turret":
		_move._runs_alert = false
		_move._jump_reach = false
		_move._hop_gaps = false
	if fight_style == "melee" and not _melee._melee_while_chase and not id.begins_with("scorp"):
		_melee._ram_while_chase = true
		if _melee._ram_x <= 0.0 and not _melee._contact_bite:
			_melee._ram_x = _melee._swing_x
			_melee._ram_y = maxf(_melee._swing_above, _melee._swing_below)


## UnitAlicorn: teleSpeed 16, teleAccel 4, throwForce 30, tTeleRes 600 (purple 20, 5, 45,
## 400); teleFilter in tlColor. UnitZombie.setSuper ss 2 / 7: Telekinesis(8, 2), 0xFF0099.
func _setup_tele(id: String, ss: int) -> void:
	_tele = null
	_tele_kind = ""
	if id in ["alicorn1", "alicorn2", "alicorn3"]:
		_tele_kind = "alicorn"
		_tele_tr = int(id.substr(7))
		var speed := 16.0
		var accel := 4.0
		var color := Color("3366FF")
		if _tele_tr == 2:
			_throw_force = 45.0
			speed = 20.0
			accel = 5.0
			_tele_res = 400
			color = Color("BB33FF")
		elif _tele_tr == 3:
			color = Color("00FF55")
		_tele = _Tele.new(self, speed, accel, color)
	elif id.begins_with("zombie") and (ss == 2 or ss == 7):
		_tele_kind = "ghoul"
		_tele_tr = ss
		_tele = _Tele.new(self, 8.0, 2.0, Color("FF0099"))


## UnitAlicorn.control t_tele block and UnitZombie.superSila2, once per 30 Hz tick.
func _tick_tele() -> void:
	if _tele == null:
		return
	for _i in _frame_ticks:
		if _tele_kind == "alicorn":
			_alicorn_tele()
		else:
			_ghoul_tele()
		_tele.step_thrown()


func _alicorn_tele() -> void:
	if not GameState.enemies_think:
		return
	_t_tele += 1
	# The || short-circuits: a calm alicorn does not search.
	if _t_tele == 0 and (_is_calm() or _alicorn_find_box() == null):
		_t_tele = -int(Rng.randf(&"ai") * 100.0 + 50.0)
	if _t_tele >= _tele_throw_t + 10:
		_t_tele = -int(Rng.randf(&"ai") * 100.0 + 50.0)
	if _tele.held == null:
		return
	_tele.hold_beside(facing)
	if _tele.held == null:
		_t_tele = -_tele_res
	elif _t_tele >= _tele_throw_t:
		if _alicorn_cel() != null:
			# throwTele: damWall = dam / 2, t_throw = 30 on a thrown player.
			if _tele.held_is_player():
				_tele.held.set("dam_wall", float(_comb) / 2.0)
				_tele.held.set("t_throw", 30)
			_tele.throw_at(_cel_point(), _throw_force, facing)
			_t_tele = -_tele_res
		else:
			_tele.release()
			_t_tele = -_tele_res / 2


## UnitAlicorn.findBox: the target a quarter of the time (teleEnemy for purple,
## half for blue and green), else a crate within optDistTele.
func _alicorn_find_box() -> Node2D:
	var cel := _alicorn_cel()
	if cel != null and Rng.randf(&"ai") < 0.25:
		var lv := GameState.tele_enemy() if _tele_tr == 2 else int(GameState.tele_enemy() * 0.5)
		_tele.grab(cel, lv)
		return cel
	var box: Node2D = _tele.find_box(_opt_dist_tele)
	if box != null:
		_tele.grab(box)
	return box


func _alicorn_cel() -> Node2D:
	return _player if _track_player and _senses._player_valid() else null


## Unit.setCel: celX = X + width / 4 * storona, celY = the target's middle.
func _cel_point() -> Vector2:
	if not _senses._player_valid():
		return _goal
	var side := float(_player.get("facing")) if "facing" in _player else 1.0
	return _body_center(_player) + Vector2(_body_size(_player).x * 0.25 * side, 0.0)


## superSila2: the body is held at (superX, superY - halfHeight). 30 ticks before
## the end superX / superY become the ghoul's own feet. Leaving aiState 7 releases.
func _ghoul_tele() -> void:
	if _track_player and _senses._player_valid():
		_tele_unit = _player
	elif _is_calm():
		_tele_unit = null
	if _tele.held == null:
		return
	if _super != "tele" or _super_left <= 0.0 or _stun_t > 0.0 or levitated or _downed:
		_tele.release()
		_tele_unit = null
		return
	var origin := _room_origin()
	if int(round(_super_need * TPS)) - _super_tick == 30:
		_super_at = _feet(self) - origin
	_super_tick += 1
	_tele.hold(origin + Vector2(_super_at.x, _super_at.y - _tele.half_height(_tele.held)))


## UnitZombie.findSuper for ss 2, in room tiles: beside the target's column when
## it is more than 120 px above, else the ghoul's own feet.
func _find_super() -> void:
	var origin := _room_origin()
	var cel := _cel_point() - origin
	var me := _feet(self) - origin
	var sx := -1.0
	var sy := cel.y + 70.0
	var nx := int(cel.x / 40.0)
	var ny := int((cel.y + 40.0) / 40.0)
	if me.y - cel.y > 120.0:
		if _tile_open(nx, ny):
			if _tile_open(nx - 1, ny):
				sx = nx * 40.0
			elif _tile_open(nx + 1, ny):
				sx = (nx + 1) * 40.0
		if sx < 0.0 and _tile_open(nx - 2, ny):
			if _tile_open(nx - 1, ny):
				sx = (nx - 1) * 40.0
			elif _tile_open(nx - 3, ny):
				sx = (nx - 2) * 40.0
		if sx < 0.0 and _tile_open(nx + 2, ny):
			if _tile_open(nx + 1, ny):
				sx = (nx + 2) * 40.0
			elif _tile_open(nx + 3, ny):
				sx = (nx + 3) * 40.0
	else:
		sx = me.x
		sy = me.y
	_super_at = Vector2(sx, sy)


## Tile.collision == 0: no wall or platform in that room tile.
func _tile_open(nx: int, ny: int) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = _room_origin() + Vector2(nx * 40.0 + 20.0, ny * 40.0 + 20.0)
	q.collision_mask = 1 | 64
	q.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


## Rooms are 48 x 25 tiles of 40 px.
func _room_origin() -> Vector2:
	return Vector2(floor(global_position.x / ROOM_W) * ROOM_W, floor(global_position.y / 1000.0) * 1000.0)


func _raider_kin(id: String) -> bool:
	return id.begins_with("raider") or id.begins_with("encl") or id.begins_with("zebra") \
		or id.begins_with("merc") or id.begins_with("slaver") or id.begins_with("ranger")


func _apply_zombie(id: String, ss: int) -> void:
	if not id.begins_with("zombie"):
		return
	fight_style = "melee"
	_weapons._chase_shot = false
	_melee._melee_while_chase = false
	_melee._ram_while_chase = true
	_close_chance = 0.0
	_move._backpedal = false
	_melee._ram_x = 200.0
	_melee._ram_y = 80.0
	_weapons._reaim_chance = SMART_REAIM
	_move._hop_gaps = true
	_move._jump_reach = true
	_melee._contact_bite = true
	if _comb > 0:
		melee_damage = _comb
	if _sheet_clips.has("dig") and Rng.randf(&"ai") < 0.75:
		_buried = true
	match ss:
		1:
			_super = "jump"
			_zlo = 90.0
			_prep_need = 30.0 / TPS
			_super_need = 20.0 / TPS
			_super_v = 30.0 * TPS
		9:
			_super = "jump"
			_zlo = 75.0
			_prep_need = 30.0 / TPS
			_super_need = 20.0 / TPS
			_super_v = 40.0 * TPS
		2, 7:
			_super = "tele"
			_zlo = 120.0
			_prep_need = 10.0 / TPS
			_super_need = 50.0 / TPS
			_necro_shot = ss == 7
		3:
			_super = "spit"
			_spit_id = "zombivenom"
			_zlo = 150.0
			_prep_need = 18.0 / TPS
			_super_need = 10.0 / TPS
		4:
			_super = "spit"
			_spit_id = "zombiacid"
			_zlo = 150.0
			_prep_need = 18.0 / TPS
			_super_need = 10.0 / TPS
		5:
			_super = "rad"
			_zlo = 140.0
			_prep_need = 30.0 / TPS
			_super_need = 45.0 / TPS
		6:
			_super = "quake"
			_zlo = 220.0
			_prep_need = 15.0 / TPS
			_super_need = 45.0 / TPS
		8:
			_super = "spit"
			_spit_id = "zombipink"
			_zlo = 120.0
			_prep_need = 18.0 / TPS
			_super_need = 10.0 / TPS
			_pink_death = true


func _roll_pool(pool: Variant) -> String:
	if not pool is Array:
		return ""
	for item in pool:
		if not item is Dictionary:
			continue
		var entry: Dictionary = item
		if int(entry.get("dif", 0)) > 100:
			continue
		var wid := str(entry.get("id", ""))
		if wid == "":
			continue
		if not entry.has("ch") or Rng.randf(&"loot") < float(entry["ch"]):
			return wid
	return ""
func _arm(wid: String) -> void:
	_weapons._arm(wid)
func _weapon_row(wid: String) -> Dictionary:
	return _weapons._weapon_row(wid)
func _launch_one(start: Vector2, target: Vector2, w: Dictionary, friendly: bool, aim_down: bool, dev: float, mazil: float) -> void:
	_weapons._launch_one(start, target, w, friendly, aim_down, dev, mazil)
func _float_hit(amount: int, _player_hit: bool, separate: bool = false) -> void:
	if amount <= 0:
		return
	Fx.float_number(amount, global_position, "hit", {"source": self, "separate": separate})
