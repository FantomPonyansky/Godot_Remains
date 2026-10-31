extends CharacterBody2D

const _Resistances := preload("res://scripts/resistances.gd")
const _Block := preload("res://scripts/block_destroy.gd")
const _UnitWater := preload("res://scripts/map/unit_water.gd")
const _UnitMassa := preload("res://scripts/unit_massa.gd")
const _HeldWeapon := preload("res://scripts/units/held_weapon.gd")
const _Desintegr := preload("res://scripts/desintegr_fx.gd")
const _Tele := preload("res://scripts/units/unit_telekinesis.gd")
const SPEED := 90.0
const TILE_W := 40.0
## The player's ladder box width (player.gd CLIMB_BOX_W).
const CLIMB_BOX_W := 28.0
const PLATFORM_LAYER_BIT := 7
## play_land._add_ladder grab above the tile. Not part of the stair tile.
const LADDER_GRAB_UP := 36.0
const GRAVITY := 900.0
const ATTACK_COOLDOWN := 1.1
## Gunners (UnitRaider): 70% chance to hold and shoot inside 1000px when the
## sighting is fresh, and a 60% chance per tick to hop back inside 200px.
## Melee stops in the 50–100px band. Chase slack is only so bodies don't stack.
const HOLD_RANGE := 1000.0
const HOLD_CHANCE := 0.7
const HOLD_FRESH := 8
const BACK_OFF_RANGE := 200.0
const BACK_OFF_CHANCE := 0.6
const SWING_MIN := 50.0
const SWING_MAX := 100.0
const SWING_HEIGHT := 80.0
const BODY_SLACK := 36.0
## WalkMotor / Brain alert movement. Distances are original pixels.
const LEVEL_SLACK := 40.0
const REAIM_EVERY := 15
const REAIM_DIST := 100.0
const DURAK_REAIM := 0.5
const SMART_REAIM := 0.8
const JUMP_TICK := 18.0
const ACCEL_RATIO := 0.75
const AIR_CONTROL := 0.25
const JUMP_BOOST := 2.0
const HOP_POWER := 0.5
const LEAP_POWER := 0.4
const LEAP_SPEED := 2.0
const JUMP_CD_MIN := 30.0
const JUMP_CD_MAX := 79.0
const HEAD_NEAR := 85.0
const HEAD_FAR := 125.0
const HEAD_AHEAD := 40.0
const FAR_BELOW := 100.0
const LEDGE_BRAKE := 0.6
const LEDGE_BRAKE_AT := 5.0
const TURN_MIN := 5
const TURN_MAX := 24
const SINGLE_SHOT := 0.1
const BLIND_SHOT := 0.03
const THROW_CHANCE := 0.02
const SWING_CHANCE := 0.3
const SWING_REACH := 120.0
const CHARGE_SPEED := 1.5
const WALL_GIVE := 0.1
## One land is a continuous grid. A room is 48?25 tiles at 40px.
const ROOM_W := 1920.0
const ROOM_H := 1000.0

## Original sim is 30 ticks/second (Engine.TPS). Distances below are in those pixels.
const TPS := 30.0
const SENSE_INTERVAL := 10.0 / TPS
const REST_RECHECK := 8
const GOAL_EVERY := 5

## Raider family senses. Scene enemies are generic raiders (units.xml id="raider"),
## not separate raider1–raider9 spawns. None of those variants set vision, ear, or
## vKonus, so they share this profile. raider7's observ="3" is the only sense
## tweak; these instances use observ 0. vKonus stays 0: raiders have no sight cone.
## Turrets are the units that set one (90° or 45°).
const CALM_VISION := 1.0
const ALERT_VISION := 1.5
const V_KONUS := 0.0
const V_ANGLE := 0.0
const DETECTING := 80.0
const EAR := 1.0
const MAX_SPOK := 30
const SIGHT_BONUS := 10
const TARGET_MEMORY := 6
const DRIFT_INTERVAL := 5
const SEARCH_DRIFT := 40.0
const GIVE_UP_SPOK := 15
const MAX_OBS := 20.0
const MINUS_OBS := 0.10
const OBS_GRACE := 30.0
const SURPRISE_MIN := 40.0
const SURPRISE_MAX := 59.0
const IDLE_MIN := 40.0
const IDLE_MAX := 90.0
const ALERT_MIN := 100.0
const ALERT_MAX := 200.0
const DETECT_DELAY := 100.0
const WAKE_RADIUS := 500.0
## UnitTurret cone width is vKonus, tested at half that angle. Wall and boss
## turrets set HALF_PI (90°). The arm turret (turrettip 3, id turret3) sets
## QUARTER_PI (45°). The ceiling turret on this land is id "turret" (cid floor,
## turrettip 0): it never sets vKonus, and its gun watches 30°–150°, so the
## cone below is the 90° one, centered straight down.
const TURRET_CONE := PI * 0.5
const ARM_CONE := PI * 0.25
## UnitBloat: attRasst 400 unless the id sets attr. bloat0 is 600, bloat4/6/7 are 700.
## Parent comb damage 8, charge and neujazMax both 20 ticks.
const BLOAT_RANGE := 400.0
const BLOAT_TICKS := 20.0
## ebloat (UnitBloatEmitter) comb damage. The nest has no cone and no attRasst.
const EBLOAT_DAMAGE := 30
## UnitMonstrik scorpion claw. closeRange 80 / 80 above / 40 below, hold chance 0.7.
## PUNCH_TIME is 15 ticks. WPunch connects when t_attack == rapid - 5.
## Map id "scorp" is rolled to scorp1 here (hp 40); scorppunch damage is 12.
const SCORP_X := 80.0
const SCORP_ABOVE := 80.0
const SCORP_BELOW := 40.0
const SCORP_HOLD := 0.7
const PUNCH_TICKS := 15.0
const PUNCH_HIT := 5.0
const PLAYER_VIS_STILL := 1500.0
const PLAYER_VIS_MOVE := 2000.0
const NOISE_RUN := 200.0
const NOISE_DECAY := 20.0
const DEMASK_DECAY := 5.0
const FAST_DEMASK := 200.0
const SHOT_DEMASK := 500.0

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
const MAX_SHOK := 30
## Brain.alarm shock, ticks. UnitMonstrik and UnitAnt use 3–8.
const ALARM_SHOCK_MIN := 5
const ALARM_SHOCK_MAX := 20
## Brain_Definition levitWakeShock / levitHoldShock. UnitRaider: 45 and 0.
const LEVIT_WAKE_SHOCK := 15
const LEVIT_HOLD_SHOCK := 15
const RAIDER_LEVIT_WAKE := 45
## Brain.STUN_RECHECK: a stunned unit idles and decides again 3 ticks after.
const STUN_RECHECK := 3.0
## GunAttack_Definition mazil (extra spread, degrees).
const HOLD_SPREAD := 5.0
const MOVE_SPREAD := 16.0
## UnitRaider: surprise lasts tupizna to tupizna + 19; close fighters a quarter of tupizna.
const TUPIZNA := 40
const SURPRISE_SPREAD := 19
## Brain_Definition default surprise for Brain units outside the raider family.
const BRAIN_SURPRISE_MIN := 10.0
const BRAIN_SURPRISE_MAX := 50.0
## UnitRaider.DEATH_THROWS and DROP_SCATTER.
const DEATH_THROWS := 3
const DROP_SCATTER := 15.0
## Unit.budilo: makeNoise(noiseRun * 1.2). Unit.noiseRun default 200.
const UNIT_NOISE_RUN := 200.0
## A Location is one room. Only units in the player's room act there; here the
## rooms next to it act too. Sight is capped at one room width for the same reason.
const ACTIVE_REACH := 1
const CHASE_REACH := 2
const SIGHT_CAP := ROOM_W
const ROOM_CHECK_TICKS := 15
## WalkMotor: porog step-up, Brain DROP_THROUGH / FLOOR_MARGIN / STEP_UP_OFF.
const STEP_UP := 10.0
const STEP_UP_OFF := 70.0
const DROP_THROUGH := 80.0
const FLOOR_MARGIN := 80.0
## UnitRaider dangers: GRENADE_CHECK 10 ticks at 0.2, MINE_CHECK 30, flee 20–84 ticks.
const GRENADE_CHECK := 10
const GRENADE_CHECK_CHANCE := 0.2
const MINE_CHECK := 30
const MINE_FLEE_RANGE := 400.0
const MINE_SUSPICION := 8
const FLEE_TIME_MIN := 20.0
const FLEE_TIME_MAX := 84.0
const FLEE_SLACK := 30.0
const FLEE_SPEED := 1.5
const DASH_CHANCE := 0.3
const DASH_SPEED := 2.5
const DASH_PREP_TIME := 20.0
const DASH_TIME := 35.0

static var _sense_frame: int = -1
static var _known_shots: Dictionary = {}
static var _combat_catalog: Dictionary = {}
static var _combat_loaded: bool = false
## Per-frame world facts every enemy shares: player room, room darkness, sneak.
static var _world_room := Vector2i(-99999, -99999)
static var _world_vis_mult: float = 1.0
static var _world_sneak: float = 0.0
static var _world_stealth: float = 1.0
static var _world_visi: float = 1.0
static var _world_crit_invis: float = 0.0
static var _world_danger: Array = []
static var _gap_cache: Dictionary = {}
static var _gap_frame: int = -1
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
var move_speed: float = SPEED
var run_speed: float = 180.0
var melee_damage: int = 12
var body_size: Vector2 = Vector2(48, 56)
var body_tint: Color = Color.WHITE
var die_actions: Array = []
var _slow_t: float = 0.0
var _slow_emit: float = 0.0
## Unit.otbros push in px/s. The AI rewrites velocity.x every tick, so this rides on top and brakes away.
var _knock_x: float = 0.0
var _rest_skips := 0
var _rest_fixed := -1
var _rest_static_floor := false
var _stun_t: float = 0.0
var _ice_t: float = 0.0
var _blind_t: float = 0.0
var _cut: float = 0.0
var _poison: float = 0.0
var _cut_clock: float = 0.0
var _poison_clock: float = 0.0
var _burn_left: float = 0.0
var _burn_clock: float = 0.0
var _burn_dps: float = 2.0
var _acid_left: float = 0.0
var _acid_clock: float = 0.0
var _acid_dps: float = 2.0
var _pink_left: float = 0.0
var _pink_clock: float = 0.0
var _pink_dps: float = 20.0
var _tint: Color = Color.WHITE
## Raider defaults. Turret / bloat / scorpion overrides come from the land's unit id.
var _v_konus: float = V_KONUS
var _ear: float = EAR
var _calm_vision: float = CALM_VISION
var _alert_vision: float = ALERT_VISION
var _swing_x: float = SWING_MAX
var _swing_above: float = SWING_HEIGHT
var _swing_below: float = SWING_HEIGHT
var _strike_cd: float = ATTACK_COOLDOWN
var _strike_windup: float = 0.0
var _strike_hold: float = 1.0
var _contact_bite: bool = false
var _attack_reach: float = INF
var _aim_down: bool = false
var _windup_left: float = 0.0
var _species_id: String = ""
var _friendly: bool = false
## Map unit with fraction F_PLAYER (UnitRaider.as L451-455): stands or strolls, never follows the player.
var _ground_ally: bool = false
var _flying: bool = false
var _loose_fly: bool = false
var _wander_left: float = 0.0
var _sim: float = 0.0
var _frame_ticks: int = 1
var _pole_t := 0
var _necro_shot: bool = false
var _necro_cd: float = 0.0
var _jump_free: bool = false
var _fire_down: bool = false
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
var _smash: bool = false
var _body_damage: int = 0
var _body_cd: float = 0.0
var _comb: int = 0
var _krep: int = 0
var _held_weapon: _HeldWeapon
var _class_anim := false
var _flyer := false
var _t_fall := 0
var _t_landing := 0
var _anim_class := ""
var _last_attack_left := 0.0
var _walker := false
var _swimming := false
var _thrown: bool = false
var _blast: float = 0.0
var _fuse: float = 2.5
var _weapon: Dictionary = {}
var _burst_len: int = 0
var _burst_left: int = 0
var _show_attack: bool = false
var _attack_left: float = 0.0
var _cast: String = ""
var _cast_ready: float = 3.0
var _cast_gap: float = 16.7
var _cast_left: float = 0.0
var _invis: bool = false
var _side_id: String = ""
var _side_ammo: int = 0
var _side_wait: float = 1.0
var _side_chance: float = 1.0
var _gutsy_fire: bool = false
var _gutsy_scale: float = 1.0
var _gutsy_burst: int = 0
var _gutsy_cd: float = 0.0
var _ranger_side: bool = false
var _vortex_left: int = 0
var _vortex_wait: float = 0.0
var _drop_id: String = ""
var _buried: bool = false
var _dig_left: float = -1.0
var _downed: bool = false
var _revive_left: float = 0.0
var _revives: bool = false
var _pet_revive: bool = false
var _pet_range: float = 200.0
var _prior: Node2D = null
## _sense is tracking the prior pet rather than the player.
var _on_prior := false
var _super: String = ""
var _spit_id: String = ""
var _rage: float = 0.0
var _zlo: float = 0.0
var _prep_need: float = 0.0
var _super_need: float = 0.0
var _prep_left: float = 0.0
var _super_left: float = 0.0
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
var _quake_step: float = 0.0
var _pink_death: bool = false
var _dop_effect: String = ""
var _dop_damage: float = 0.0
var _dop_chance: float = 1.0
var _encl_bonus: bool = false
var _hover: float = 70.0
## Raider gunners hold and hop back. Other families set these from their own class.
var _bullet_damage: int = 10
var _bullet_type: String = "DAM_PIERCE"
var _bullet_speed: float = 360.0
var _gunner_hold: bool = true
var _hold_range: float = HOLD_RANGE
var _hold_chance: float = HOLD_CHANCE
var _do_backoff: bool = true
var _chase_shot: bool = true
var _can_lift: bool = true
var _sheet_native: bool = false
## OTHER rig drawing this unit (`_setup_rig`); null on sheet units.
var rig: RigView = null
var _sheet_offset: Vector2 = Vector2.ZERO
var _sheet_cell: Vector2i = Vector2i(120, 120)
var _sheet_clips: Dictionary = {}
var _move_clip: String = "walk"
var _jet := false
var _jet_n := 100
var _jet_max := 90
## WalkMotor.pursue heading (aiNapr). It is not the way the sprite faces.
var _heading: float = -1.0
var _cel_dx: float = 0.0
var _cel_dy: float = 0.0
var _vert: int = 0
var _jump_cd: float = 0.0
var _wall_left: int = 10
var _accel_tick: float = 3.0
var _jump_tick: float = JUMP_TICK
var _jump_reach: bool = true
var _hop_gaps: bool = true
var _brake_ledge: bool = false
var _backpedal: bool = false
var _air_frac: float = AIR_CONTROL
var _jump_boost: float = JUMP_BOOST
var _wall_give: float = WALL_GIVE
var _turn_at_wall: bool = true
var _reaim_every: int = REAIM_EVERY
var _reaim_chance: float = DURAK_REAIM
var _reaim_dist: float = REAIM_DIST
var _runs_alert: bool = true
var _runs_seen: bool = false
var _chase_mul: float = 1.0
var _freeze_aim: bool = true
var _shot_chance: float = SINGLE_SHOT
var _blind_chance: float = BLIND_SHOT
var _swing_chance: float = SWING_CHANCE
var _band_min: float = SWING_MIN
var _band_max: float = SWING_MAX
var _band_up: float = SWING_HEIGHT
var _band_down: float = SWING_HEIGHT
var _close_chance: float = 0.0
var _close_release: bool = false
var _close_search: bool = true
var _close_tmin: float = ALERT_MIN
var _close_tmax: float = ALERT_MAX
var _leap_above: float = 0.0
var _ram_while_chase: bool = false
var _melee_while_chase: bool = false
var _ram_x: float = 0.0
var _ram_y: float = 0.0
var _bite_hop: float = 0.0
var _shoot_climb: bool = false
var _need_sight: bool = false
## units.xml comb / un / vis / param values (enemy_combat.json).
var _shok: int = 0
var _skin: float = 0.0
var _armor: float = 0.0
var _marmor: float = 0.0
var _armor_qual: float = 0.0
var _armor_hp: float = 0.0
## Unit.dexter: 1 is standard, 0 is always hit. Bullets read it.
var dexter: float = 1.0
var _observ: float = 0.0
var _weapon_skill: float = 1.0
var _levit_attack: float = 1.0
## Classes whose control pushes dx by levitaccel toward the target while held.
var _levit_struggle: bool = false
var _levitaccel: float = 1.6
var _ai_dist: float = HOLD_RANGE
var _stroll: bool = true
var _trup: bool = true
## Unit.damage tip of the last hit, for Desintegr sposob.
var _die_tip := ""
var _loot_cont: String = ""
var fraction: int = 0
var _noise_run: float = UNIT_NOISE_RUN
var _drop_arm: bool = false
var _raider_type: bool = false
var _fear_grenade: bool = false
var _can_dash: bool = false
var _sniper: bool = false
var _opens_doors: bool = false
var _climbs_ladders: bool = false
var _wake_radius: float = WAKE_RADIUS
var _alarm_radius: float = 0.0
var _alarm_shock_min: int = ALARM_SHOCK_MIN
var _alarm_shock_max: int = ALARM_SHOCK_MAX
var _levit_wake_shock: int = LEVIT_WAKE_SHOCK
var _levit_hold_shock: int = LEVIT_HOLD_SHOCK
var _surprise_min: float = SURPRISE_MIN
var _surprise_max: float = SURPRISE_MAX
var _mag_cap: int = 0
var _mag: int = 0
var _reload_left: float = 0.0
var _reload_time: float = 0.0
var _rashod: int = 1
var _pellets: int = 1
var _deviation: float = 0.0
var _mazil: float = 0.0
var _ai_tick: int = 0
var _dead: bool = false
var _asleep: bool = false
var _room_check: int = 0
var _goal_tick: int = -1
var _goal_cached: Vector2 = Vector2.ZERO
var _goal_is_target := false
var _base_snap: float = 1.0
var _porog: float = STEP_UP
var _unit_porog: float = STEP_UP
var _throu: bool = false
var _throu_left: float = 0.0
var _flee_dir: float = 0.0
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
var _attack_cd: float = 0.0
var _player: Node2D
var _current_anim: String = ""
var levitated: bool = false
var _lev_point: Vector2 = Vector2.ZERO
var _lev_speed: float = 0.0
var _dropping: bool = false

var ai_state: int = ST_PATROL
var ai_spok: int = 0
var _vision: float = CALM_VISION
var _overlook: bool = false
var _track_player: bool = false
var _aware: bool = false
var _scene_areas: Variant = null
var _goal: Vector2 = Vector2.ZERO
var _memory_left: int = 0
var _unseen_looks: int = 0
var _state_left: float = 1.0
var _sense_left: float = 0.3
var _detect_delay: float = DETECT_DELAY / TPS


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _brain != null:
		_brain.release()
		_brain = null


## Unit.dopTest: false lets the bullet fly on through this unit.
func dop_test(bullet: Node) -> bool:
	return _brain == null or _brain.dop_test(bullet)


## Interact on a unit with an action (the wild phoenix's tame).
func use_object(from_timer: bool = false) -> void:
	if _brain != null and _brain.has_method("use_object"):
		_brain.call("use_object", from_timer)


## Script targ commands (Unit.command), also for units outside the enemies group.
func script_command(act: String, val: String) -> void:
	if _brain != null:
		_brain.command(act, val)


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
	_apply_species()
	if not _friendly:
		max_hp = GameState.enemy_max_hp(max_hp)
	hp = max_hp
	if _armor_hp <= 0.0:
		_armor_hp = float(max_hp)
	if _friendly:
		remove_from_group("enemies")
		add_to_group("allies")
	else:
		add_to_group("enemies")
		add_to_group("foe_bodies")
		GameState.register_enemy()
		_ensure_watch()
	# Layer 9 is a ghost wall. Enemies do not have transT, so they cannot walk through it.
	set_collision_mask_value(9, true)
	if _flying:
		motion_mode = MOTION_MODE_FLOATING
		floor_snap_length = 0.0
	if _buried:
		visible = false
		set_collision_layer_value(3, false)
	_player = get_tree().get_first_node_in_group("player")
	_goal = global_position
	_state_left = randf_range(IDLE_MIN, IDLE_MAX) / TPS
	_sense_left = randf_range(0.05, SENSE_INTERVAL)
	_fit_body()
	_setup_animations()
	_heading = facing
	_play_anim("idle")
	anim.modulate = _tint
	if _brain != null:
		_brain.start()


func is_alert() -> bool:
	if _brain != null:
		return _brain.targets_player()
	return not _is_calm()


func apply_slow(seconds: float) -> void:
	_slow_t = maxf(_slow_t, seconds)


func apply_stun(ticks: int) -> void:
	if ticks <= 0 or _is_machine():
		return
	_stun_t += float(ticks) / 30.0


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
				_cut_clock = 1.0
			_cut += dop
		"poison":
			if _resist("DAM_POISON") <= 0.1:
				return
			if _poison <= 0.0:
				_poison_clock = 1.0
			_poison += dop
		"igni":
			if _resist("DAM_BURN") <= 0.1:
				return
			_ice_t = 0.0
			_burn_left = 7.0
			_burn_clock = 0.0
			_burn_dps = dop if dop > 0.0 else 2.0
		"ice":
			if _resist("DAM_COLD") <= 0.1 or _is_machine():
				return
			_burn_left = 0.0
			_ice_t = 15.0
		"blind":
			if _resist("DAM_LASER") <= 0.1 or _is_machine():
				return
			_blind_t = 15.0
		"acid":
			if _resist("DAM_ACID") <= 0.1:
				return
			_acid_left = 15.0
			_acid_clock = 0.0
			_acid_dps = dop if dop > 0.0 else 2.0
		"pink":
			if _resist("DAM_PINKCLOUD") <= 0.1:
				return
			_pink_left = 15.0
			_pink_clock = 0.0
			_pink_dps = dop if dop > 0.0 else 20.0
		"stun":
			if _is_machine():
				return
			if randf() < float(dealt) / maxf(1.0, float(max_hp)):
				_stun_t = float(dop) / 30.0


func _is_machine() -> bool:
	return bool(get_meta("mech", false)) or bool(get_meta("robot", false))


func _resist(tip: String) -> float:
	var comp := _Resistances.of(self)
	if comp:
		return comp.multiplier_for(tip)
	return 1.0


func _tick_ailments(delta: float) -> void:
	if _ice_t > 0.0:
		_ice_t = maxf(0.0, _ice_t - delta)
	if _blind_t > 0.0:
		_blind_t = maxf(0.0, _blind_t - delta)
	_cut_clock += delta
	if _cut > 0.0 and _cut_clock >= 1.0:
		_cut_clock -= 1.0
		var bleed := int(round(sqrt(_cut)))
		if bleed > 0:
			_take_dot(bleed, "DAM_BLEED")
		_cut = maxf(0.0, _cut - 0.2)
	_poison_clock += delta
	if _poison > 0.0 and _poison_clock >= 1.0:
		_poison_clock -= 1.0
		var venom := int(round(sqrt(_poison)))
		if venom > 0:
			_take_dot(venom, "DAM_POISON")
		_poison = maxf(0.0, _poison - 0.2)
	_dot_channel("burn", delta)
	_dot_channel("acid", delta)
	_dot_channel("pink", delta)


func _dot_channel(which: String, delta: float) -> void:
	var left := 0.0
	var clock := 0.0
	var dps := 0.0
	var tip := ""
	match which:
		"burn":
			left = _burn_left
			clock = _burn_clock
			dps = _burn_dps
			tip = "DAM_BURN"
		"acid":
			left = _acid_left
			clock = _acid_clock
			dps = _acid_dps
			tip = "DAM_ACID"
		"pink":
			left = _pink_left
			clock = _pink_clock
			dps = _pink_dps
			tip = "DAM_PINKCLOUD"
		_:
			return
	if left <= 0.0:
		return
	clock += delta
	left = maxf(0.0, left - delta)
	if clock >= 1.0:
		clock -= 1.0
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
	if active and not was and not _dead and _brain != null:
		_brain.command("alarma", "")
	if active and not was and not _dead and _is_calm():
		# Brain.reactToLevitation: a calm unit wakes, shocked. Movement stays frozen until release.
		_wake_allies()
		_become_alert(_feet(self))
		_shok = maxi(_shok, _levit_wake_shock)


func _physics_process(delta: float) -> void:
	if GameState.paused:
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
		if _downed:
			_revive_left -= delta
			if _revive_left <= 0.0:
				_rise()
		elif _levit_hold_shock > 0 and _shok < _levit_hold_shock:
			_shok = _levit_hold_shock
		if _brain != null and _brain.acts_held:
			_brain.held(delta)
			if _dead or not levitated:
				return
		_float_to_cursor()
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
	if _brain != null:
		_brain.physics(delta)
		return
	if _downed:
		var was_left := _revive_left
		_revive_left -= delta
		# UnitZombie.control: t_res == 25 plays zombie_res.
		if was_left > 25.0 / TPS and _revive_left <= 25.0 / TPS and _species_id.begins_with("zombie"):
			UnitFx.snd("zombie_res")
		if not is_on_floor() and not _flying:
			velocity.y += GRAVITY * delta
		_commit_move()
		_play_anim("die")
		# UnitZombie.animate: the last 20 ticks of t_res play the die row backwards, with sparks.
		var t_res := _revive_left * TPS
		if _anim_class == "zombie" and t_res < 20.0 and t_res >= 0.0 and _current_anim == "die":
			anim.pause()
			anim.frame = clampi(int(t_res), 0, anim.sprite_frames.get_frame_count("die") - 1)
			for _i in _frame_ticks * 3:
				UnitFx.emit(get_tree(), "die_spark", global_position + Vector2((randf() - 0.5) * body_size.x, -randf() * 10.0))
		if _revive_left <= 0.0:
			_rise()
		return
	if _stun_t > 0.0:
		# Brain.tick with obeysStun: idle, decide again 3 ticks after the stun. No attacks.
		var was_tick := int(ceil(_stun_t * 30.0))
		_stun_t = maxf(0.0, _stun_t - delta)
		if bool(get_meta("robot", false)) and was_tick / 10 != int(ceil(_stun_t * 30.0)) / 10:
			var mid := _feet(self) - Vector2(0.0, _body_size(self).y * 0.5)
			UnitFx.emit(get_tree(), "discharge", mid)
			UnitFx.emit(get_tree(), "iskr", mid, {"kol": 5})
		_windup_left = 0.0
		_burst_left = 0
		ai_state = ST_IDLE
		_state_left = STUN_RECHECK / TPS
		velocity.x = 0.0
		if not is_on_floor() and not _flying:
			velocity.y += GRAVITY * delta
		_commit_move()
		_present(false)
		return
	_tick_role(delta)
	if _buried and _dig_left <= 0.0:
		velocity = Vector2.ZERO
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if _windup_left > 0.0:
		if _cannot_fight():
			_windup_left = 0.0
		else:
			_windup_left = maxf(0.0, _windup_left - delta)
			if _windup_left <= 0.0:
				_deliver_strike()
	if _slow_t > 0.0:
		_slow_t = maxf(0.0, _slow_t - delta)
		_slow_emit -= delta
		if _slow_emit <= 0.0:
			_slow_emit = 10.0 / 30.0
			if visible and (absf(velocity.x) > 90.0 or absf(velocity.y) > 150.0):
				UnitFx.emit(get_tree(), "slow", _feet(self) - Vector2(0.0, _body_size(self).y * 0.25))
		if _slow_t <= 0.0 and is_instance_valid(anim) and not levitated:
			anim.modulate = _tint
		elif is_instance_valid(anim) and not levitated:
			anim.modulate = Color(_tint.r * 0.7, _tint.g * 0.82, minf(1.0, _tint.b + 0.25))
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player != null:
		_tick_world_senses(_player, delta)
	if _detect_delay > 0.0:
		_detect_delay = maxf(0.0, _detect_delay - delta)
	_sense_left -= delta
	if _sense_left <= 0.0:
		_sense_left = SENSE_INTERVAL
		_sense()
	_state_left -= delta
	if _state_left <= 0.0:
		_decide()
	_refresh_overlook()
	_tick_reload(delta)
	if _frame_ticks > 0 and _species_id == "eqd":
		_eqd_port()
	if _frame_ticks > 0 and _raider_type:
		_watch_for_danger()
	_apply_throu()

	var use_grav := not _flying and not _climbing and not _jump_free and not _buried
	_swimming = false
	if use_grav and _UnitWater.swim(self, delta, body_size.y):
		_swimming = true
	elif use_grav:
		var dvy := _UnitWater.fall(self, delta, body_size.y)
		if dvy < 0.0 or not is_on_floor():
			velocity.y += dvy
	if _jet and not _dead:
		for _i in _frame_ticks:
			_tick_jet()
	if _dropping:
		velocity.x = move_toward(velocity.x, 0.0, 240.0 * delta)
		_commit_move()
		anim.flip_h = facing < 0.0
		if is_on_floor():
			_dropping = false
			velocity.x = 0.0
		elif _class_anim:
			_present_class()
			return
		else:
			_play_anim("fall")
			return

	if _call_is_held():
		velocity.x = 0.0
		_commit_move()
		anim.flip_h = facing < 0.0
		_play_anim("idle")
		return

	_crawling = _can_crawl and is_on_floor() and not _climbing and _low_ceiling()
	var moving := _act()
	if _crawling:
		velocity.x = clampf(velocity.x, -2.0 * TPS, 2.0 * TPS)
	_commit_move()
	_present(moving)


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


func _refresh_overlook() -> void:
	# looksBehindWhenAlert: 360° while searching, chasing, fleeing, or dashing. Calm stays forward.
	# Surprise does not change the flag.
	if ai_state == ST_SEARCH or ai_state == ST_CHASE or ai_state == ST_FLEE or ai_state == ST_DASH:
		_overlook = true
	elif _is_calm():
		_overlook = false


func _patrol() -> bool:
	if _climb and wall_check.is_colliding():
		_climbing = true
		return _climb_step()
	if _hop_vy > 0.0 and not floor_check.is_colliding() and is_on_floor():
		velocity.y = -_hop_vy
	elif not floor_check.is_colliding() or wall_check.is_colliding():
		facing *= -1.0
		floor_check.position.x = absf(floor_check.position.x) * facing
		wall_check.target_position.x = absf(wall_check.target_position.x) * facing
		_aim_probes()
	velocity.x = facing * (move_speed if move_speed > 0.0 else SPEED) * 0.6
	_heading = facing
	return true


func _float_to_cursor() -> void:
	# The player integrates Telekinesis.hold and writes the position.
	if bool(get_meta("tele_driven", false)):
		velocity = Vector2.ZERO
		floor_snap_length = 0.0
		if is_instance_valid(anim):
			anim.flip_h = facing < 0.0
			anim.modulate = preload("res://scripts/magic_aura.gd").tele_tint()
		_lev_anim()
		return
	var center_offset := Vector2.ZERO
	var shape_node := get_node_or_null("CollisionShape2D") as Node2D
	if shape_node:
		center_offset = shape_node.position
	var to := _lev_point - (global_position + center_offset)
	var dist := to.length()
	if dist > 2.0:
		velocity = to * (_lev_speed / dist)
	else:
		velocity = Vector2.ZERO
	_commit_move()
	anim.flip_h = facing < 0.0
	anim.modulate = Color(0.75, 0.9, 1.2)
	_lev_anim()


func _lev_anim() -> void:
	if _brain != null:
		_brain.animate()
		if _brain.flips_sprite and is_instance_valid(anim):
			anim.flip_h = _brain.storona < 0.0
	elif _class_anim:
		_present_class()
	else:
		_present(false)


## UnitRaider / UnitZombie / UnitHellhound / UnitAnt / UnitMonstrik / UnitAlicorn.control:
## a held unit after a target adds levitaccel to dx toward it while dx is under maxSpeed.
## vel and the result are px per tick.
func levit_pull(vel: Vector2) -> Vector2:
	if _dead or _downed or _stun_t > 0.0 or not levitated:
		return Vector2.ZERO
	if _brain != null:
		return _brain.levit_pull(vel)
	if not _levit_struggle or _is_calm():
		return Vector2.ZERO
	var target := _goal
	if _track_player and _player_valid():
		target = _player.global_position
	var dir := signf(target.x - global_position.x)
	var cap := (run_speed if ai_spok >= MAX_SPOK else move_speed) / TPS
	if dir == 0.0 or vel.x * dir >= cap:
		return Vector2.ZERO
	return Vector2(dir * _levitaccel, 0.0)


func _act() -> bool:
	if _ground_ally:
		return _ally_act()
	if _friendly:
		return _pet_act()
	if _dig_left > 0.0 or _prep_left > 0.0:
		velocity.x = 0.0
		if _player_valid():
			facing = signf(_player.global_position.x - global_position.x)
		return false
	if _jump_free:
		return absf(velocity.x) > 8.0
	if _super_left > 0.0 and _super != "jump":
		velocity.x = 0.0
		return false
	if _loose_fly:
		_wander_left -= get_physics_process_delta_time()
		if not _track_player and _wander_left <= 0.0:
			_wander_left = randf_range(100.0, 200.0) / TPS
			_goal = global_position + Vector2(randf_range(-700.0, 700.0), randf_range(-100.0, 200.0))
	elif _track_player and _player != null and is_instance_valid(_player):
		_goal = _player_goal()
	if _climbing or (_climb and wall_check.is_colliding() and not _flying):
		_climbing = true
		return _climb_step()
	if _flyer:
		_tick_flyer()
	if _flying:
		var point := _goal
		if _flyer and not _track_player:
			# UnitRaider: a calm flyer's celY is its floor line, so it sinks and lands.
			point = Vector2(_goal.x, global_position.y + 40.0)
		elif not _loose_fly:
			point += Vector2(0.0, -_hover)
		return _fly_toward(point, fight_style != "melee" and _chase_shot and not _gutsy_fire)
	if fixed_post:
		velocity.x = 0.0
		if ai_state == ST_HOLD or ai_state == ST_CHASE:
			_aim()
			return _hold()
		return false
	# Brain.act while alert: aim, maybe stop in reach, then chase or hold.
	if not _is_calm() and ai_state != ST_SURPRISED:
		_aim()
		if ai_state == ST_SEARCH or ai_state == ST_CHASE or ai_state == ST_DASH:
			_reaim()
		elif ai_state == ST_FLEE and _flee_dir != 0.0:
			_heading = _flee_dir
		_hold_if_close()
	match ai_state:
		ST_IDLE:
			velocity.x = 0.0
			return false
		ST_PATROL, ST_SURPRISED:
			# Raiders set turnsWhenSurprised = false, so surprise keeps the patrol.
			return _patrol()
		ST_SEARCH, ST_CHASE, ST_FLEE, ST_DASH:
			return _pursue()
		ST_DASH_PREP:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * get_physics_process_delta_time())
			if absf(_cel_dx) > 1.0:
				facing = signf(_cel_dx)
			_aim_probes()
			return false
		ST_HOLD:
			return _hold()
		_:
			velocity.x = 0.0
			return false


func _hold() -> bool:
	# WalkMotor.hold: stop, face the target. Brain.backOffIfCrowded may leave hold.
	var delta := get_physics_process_delta_time()
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	if absf(_cel_dx) > 1.0:
		facing = signf(_cel_dx)
		_heading = facing
	elif _target_dx() != 0.0:
		facing = signf(_target_dx())
		_heading = facing
	_aim_probes()
	var left := _back_off_if_crowded()
	_tick_attacks()
	return left


func _leap_back() -> void:
	# WalkMotor.leapBack: runSpeed * LEAP_BACK_SPEED away, then jump(LEAP_BACK).
	var dx := _cel_dx if absf(_cel_dx) > 1.0 else _target_dx()
	var away := -signf(dx) if dx != 0.0 else -facing
	var spd := run_speed if run_speed > 0.0 else move_speed
	velocity.x = away * spd * LEAP_SPEED
	_do_jump(LEAP_POWER)


func _melee_swing() -> void:
	if not _player_valid() or _attack_cd > 0.0 or _windup_left > 0.0 or not _in_swing_band():
		return
	_attack_cd = _strike_cd
	if _show_attack:
		_attack_left = PUNCH_TICKS / TPS
	if _strike_windup > 0.0:
		_windup_left = _strike_windup
		return
	_deliver_strike()


func _deliver_strike() -> void:
	if not _player_valid() or not _in_swing_band():
		return
	if _player.has_method("take_hit") and not _player_dodges():
		_udar_fx(_bullet_type)
		_player.take_hit(melee_damage)
	if _zlo > 0.0 and _rage > 80.0:
		_rage = maxf(0.0, _rage - 25.0)


func _in_swing_band() -> bool:
	if not _player_valid():
		return false
	if _contact_bite:
		if _target_distance() > _attack_reach:
			return false
		return _boxes_touch()
	var dx := absf(_player.global_position.x - global_position.x)
	var dy := _player.global_position.y - global_position.y
	if dx > _swing_x:
		return false
	if dy >= 0.0:
		return dy <= _swing_below
	return -dy <= _swing_above


func _boxes_touch() -> bool:
	var mine := _body_size(self)
	var theirs := _body_size(_player)
	var dx := absf(_player.global_position.x - global_position.x)
	if dx > (mine.x + theirs.x) * 0.5:
		return false
	var dy := _player.global_position.y - global_position.y
	return -mine.y < dy and dy - theirs.y < 0.0


## Brain.aim. Horizontal aim uses the doorway gap when the target is in another room.
## Vertical aim is the original celDY, and raiders freeze it in the air.
func _aim() -> void:
	var my := _body_center(self)
	var point := _goal
	if _track_player and _player_valid():
		point = _player_goal()
		_cel_dx = point.x - my.x
		if is_on_floor() or not _freeze_aim:
			var their := _body_center(_player)
			var top := their.y - _body_size(_player).y * 0.5
			_cel_dy = top - my.y + body_size.y
	else:
		_cel_dx = point.x - my.x
		if is_on_floor() or not _freeze_aim:
			_cel_dy = point.y - my.y + body_size.y
	if is_on_floor() or not _freeze_aim:
		if _cel_dy > LEVEL_SLACK:
			_vert = 1
		elif _cel_dy < -LEVEL_SLACK:
			_vert = -1
		else:
			_vert = 0
	# Brain.aim: porog off while the target is far below.
	_porog = 0.0 if _cel_dy > STEP_UP_OFF else _unit_porog


## Brain.reaim. Durak raiders turn toward a far target only half the time.
## The original tests aiTCh % reaimInterval == 1 once per tick.
func _reaim() -> void:
	if _frame_ticks <= 0 or _reaim_every <= 0:
		return
	var fire := false
	for k in _frame_ticks:
		if (_ai_tick - k) % _reaim_every == 1:
			fire = true
	if not fire:
		return
	if randf() >= _reaim_chance:
		return
	if _cel_dx > _reaim_dist:
		_heading = 1.0
	elif _cel_dx < -_reaim_dist:
		_heading = -1.0


## Brain.holdIfClose. Melee and scorpions stop inside their band. A miss keeps chasing.
func _hold_if_close() -> void:
	if _close_chance <= 0.0:
		return
	var ax := absf(_cel_dx)
	var in_band := ax >= _band_min and ax <= _band_max and _cel_dy >= -_band_up and _cel_dy <= _band_down
	if ai_state == ST_HOLD and _close_release and not in_band:
		ai_state = ST_CHASE
		return
	var searching := ai_state == ST_SEARCH and _close_search
	if ai_state != ST_CHASE and not searching:
		return
	if not _track_player or not in_band or _frame_ticks <= 0:
		return
	if randf() < _close_chance:
		if ai_state != ST_HOLD:
			_state_left = randf_range(_close_tmin, _close_tmax) / TPS
		ai_state = ST_HOLD


## Brain.backOffIfCrowded. Inside the range the gunner always leaves hold, and sometimes hops back.
func _back_off_if_crowded() -> bool:
	if not _do_backoff or fixed_post or fight_style == "melee" or fight_style == "turret":
		return false
	if _cel_dx * _cel_dx + _cel_dy * _cel_dy >= BACK_OFF_RANGE * BACK_OFF_RANGE:
		return false
	if _frame_ticks > 0 and randf() < BACK_OFF_CHANCE:
		_leap_back()
	ai_state = ST_CHASE
	return true


## WalkMotor.pursue. Accelerate along aiNapr, hop gaps, jump to a target above, hop a wall.
func _pursue() -> bool:
	var delta := get_physics_process_delta_time()
	if _jump_cd > 0.0:
		_jump_cd -= delta
	var jump_power := 0.0
	if _frame_ticks > 0 and _jump_reach and _vert < 0 and _jump_cd <= 0.0 and _ai_tick % 2 == 1 and _can_jump_up():
		jump_power = 1.0
	_aim_heading_probes()
	if _frame_ticks > 0 and is_on_floor() and _over_ledge():
		if _hop_gaps and _vert != 1 and randf() < 0.5:
			jump_power = HOP_POWER
		elif _brake_ledge and absf(velocity.x) > LEDGE_BRAKE_AT * TPS:
			velocity.x *= LEDGE_BRAKE
	if _frame_ticks > 0 and is_on_floor() and _into_wall() and not _step_up():
		if _opens_doors:
			_open_door_ahead()
		jump_power = _bump_wall(jump_power)
	if ai_state == ST_SEARCH or ai_state == ST_CHASE:
		_climb_toward_target()
		if _climbing:
			return _climb_step()
	var cap := _speed_cap()
	var add := _accel_tick * 900.0 * delta
	if not is_on_floor() and not _climbing:
		add *= _air_frac
	var dir := _heading if _heading != 0.0 else facing
	if dir < 0.0:
		if velocity.x > -cap:
			velocity.x -= add
		elif velocity.x < -cap:
			velocity.x = minf(velocity.x + 900.0 * delta, -cap)
	elif dir > 0.0:
		if velocity.x < cap:
			velocity.x += add
		elif velocity.x > cap:
			velocity.x = maxf(velocity.x - 900.0 * delta, cap)
	if jump_power > 0.0:
		facing = dir
		_do_jump(jump_power)
	elif _backpedal and absf(_cel_dx) > 1.0:
		facing = signf(_cel_dx)
	else:
		facing = dir
	_aim_probes()
	_maybe_smash()
	if ai_state == ST_CHASE or ai_state == ST_FLEE or ai_state == ST_DASH:
		_tick_attacks()
	return absf(velocity.x) > 8.0


func _speed_cap() -> float:
	# Brain.speedFor + WalkMotor backpedal slowdown.
	var spd_run := run_speed if run_speed > 0.0 else (move_speed if move_speed > 0.0 else SPEED)
	if ai_state == ST_FLEE:
		return spd_run * FLEE_SPEED
	if ai_state == ST_DASH:
		return spd_run * DASH_SPEED
	var running := _runs_alert or (_runs_seen and ai_spok >= MAX_SPOK)
	var cap := move_speed if move_speed > 0.0 else SPEED
	if running and run_speed > 0.0:
		cap = run_speed
		if ai_state == ST_CHASE:
			cap *= _chase_mul
	if _backpedal and facing * _heading < 0.0:
		cap = move_speed if move_speed > 0.0 else SPEED
	return cap


func _into_wall() -> bool:
	if not is_on_wall():
		return false
	var dir := _heading if _heading != 0.0 else facing
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if normal.x * dir < -0.5:
			return true
	return false


func _bump_wall(jump_power: float) -> float:
	# WalkMotor.bumpWall. A target behind turns us at once. Otherwise hop the wall, then give up.
	var away := -_heading if _heading != 0.0 else -facing
	if _turn_at_wall and _cel_dx * _heading < 0.0:
		_heading = away
		_wall_left = randi_range(TURN_MIN, TURN_MAX)
		return jump_power
	_wall_left -= _frame_ticks
	var blocked := randf() < _wall_give or _cel_dy > FAR_BELOW or not _can_jump_up()
	if blocked:
		_wall_left -= 10
	else:
		jump_power = 1.0
	if _wall_left < 0 and is_on_floor():
		_heading = away
		_wall_left = randi_range(TURN_MIN, TURN_MAX)
	return jump_power


## UnitAIRobot.control: walking into a wall calls jump(1) every tick.
func _tick_jet() -> void:
	if is_on_floor():
		_jet_n = _jet_max
	var ahead := _heading if _heading != 0.0 else facing
	if ai_state != ST_IDLE and is_on_wall() and get_wall_normal().x * ahead < 0.0:
		_jet_jump(1.0)


## UnitProtect.jump: on the floor jump_n refills, in the air it counts down;
## each call lifts by jumpdy / 4 while rising slower than jumpdy.
func _jet_jump(v: float) -> void:
	if is_on_floor():
		_jet_n = _jet_max
	else:
		_jet_n -= 1
	if velocity.y > -_jump_tick * TPS and _jet_n > 0:
		velocity.y -= _jump_tick * TPS * v / 4.0


func _do_jump(power: float) -> void:
	if _jet:
		_jump_cd = randf_range(JUMP_CD_MIN, JUMP_CD_MAX) / TPS
		_jet_jump(power)
		return
	# WalkMotor.jump. Hop strength is half; a leap back is 0.4. Rats keep their own hop.
	_jump_cd = randf_range(JUMP_CD_MIN, JUMP_CD_MAX) / TPS
	if is_on_floor() or _climbing:
		if power <= HOP_POWER and _hop_vy > 0.0:
			velocity.y = -_hop_vy
		else:
			velocity.y = -_jump_tick * TPS * power
		velocity.x += facing * _accel_tick * TPS * _jump_boost
		_end_climb()


func _can_jump_up() -> bool:
	# WalkMotor.canJumpUp. Clear at 85 and 125 above the feet, and the same a step ahead.
	var ahead := _heading if _heading != 0.0 else facing
	var feet := global_position
	var spots: Array[Vector2] = [
		feet + Vector2(0.0, -HEAD_NEAR),
		feet + Vector2(0.0, -HEAD_FAR),
		feet + Vector2(HEAD_AHEAD * ahead, -HEAD_NEAR),
		feet + Vector2(HEAD_AHEAD * ahead, -HEAD_FAR),
	]
	for spot in spots:
		if not _point_clear(spot):
			return false
	return true


func _point_clear(at: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var query := PhysicsPointQueryParameters2D.new()
	query.position = at
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_point(query, 1).is_empty()


func _over_ledge() -> bool:
	return is_on_floor() and not floor_check.is_colliding()


func _aim_heading_probes() -> void:
	var side := _heading if _heading != 0.0 else facing
	floor_check.position.x = absf(floor_check.position.x) * side
	wall_check.target_position.x = absf(wall_check.target_position.x) * side
	floor_check.force_raycast_update()
	wall_check.force_raycast_update()


func _udar_fx(damage_type: String) -> void:
	preload("res://scripts/impact_fx.gd").udar_unit(get_tree(), _body_center(_player), _body_center(self), damage_type)


func _body_center(body: Node2D) -> Vector2:
	var feet := _feet(body)
	return Vector2(feet.x, feet.y - _body_size(body).y * 0.5)


## GunAttack.tick and WeaponAttack.tick, plus BodyAttack while chasing.
func _tick_attacks() -> void:
	if _frame_ticks <= 0 or _cannot_fight() or _gutsy_fire:
		return
	var chasing := ai_state == ST_CHASE
	var holding := ai_state == ST_HOLD
	var fleeing := ai_state == ST_FLEE
	if fight_style != "melee" and (holding or fleeing or (chasing and _chase_shot)):
		_gun_try()
	if fight_style == "melee" and (holding or ((chasing or fleeing) and _melee_while_chase)):
		_melee_try()
	if _ram_while_chase and (chasing or fleeing or ai_state == ST_DASH or (holding and fight_style == "melee")):
		_ram_hit()


func _gun_try() -> void:
	# GunAttack: bursts while chase, hold, or flee. Single shots are a roll each tick, only unshocked.
	if _climbing and not _shoot_climb:
		return
	if _v_konus > 0.0 and _player_valid() and _look(_player) <= 0.0:
		return
	var seen := _track_player and _player_valid()
	if _need_sight and not seen:
		return
	if _sniper:
		_mazil = 0.0
	else:
		_mazil = HOLD_SPREAD if ai_state == ST_HOLD else MOVE_SPREAD
	var target := _player.global_position if seen else _goal
	# Turrets keep the weapon's own rate. Raider GunAttack rolls single shots.
	if fight_style == "turret":
		if _attack_cd <= 0.0:
			_shoot_at(target)
		return
	if _burst_len > 0:
		if _sniper and not seen:
			return
		if _gun_ready():
			_shoot_at(target)
		return
	if _attack_cd > 0.0:
		return
	if _shok > 0 and not _thrown:
		return
	var chance := _shot_chance if seen else _blind_chance
	if chance <= 0.0:
		return
	for _i in _frame_ticks:
		if randf() < chance:
			_shoot_at(target)
			return


func _melee_try() -> void:
	# WeaponAttack: chance per tick inside the weapon's reach. Scorpions leap at a target above.
	# A raider's levitated swing stops while shocked (stopsWhenShocked).
	if _attack_cd > 0.0 or _windup_left > 0.0:
		return
	if _raider_type and _shok > 0:
		return
	if not _in_swing_band():
		return
	var swung := false
	for _i in _frame_ticks:
		if randf() < _swing_chance:
			swung = true
			break
	if not swung:
		return
	if _leap_above > 0.0 and _cel_dy < -_leap_above and is_on_floor():
		_do_jump(1.0)
		velocity.x = 0.0
	_melee_swing()


## Unit.udarUnit returns at once while the target's neujaz runs: no hit, no udar sound.
func _player_dodges() -> bool:
	if _player.has_method("can_be_hit") and not bool(_player.call("can_be_hit")):
		return true
	return _player.has_method("dodge_roll") and bool(_player.call("dodge_roll"))


func _ram_hit() -> void:
	# BodyAttack.attKorp when the boxes overlap. The player's own invuln spaces the hits.
	if not _player_valid():
		return
	if _ram_x > 0.0 and absf(_cel_dx) > _ram_x:
		return
	if _ram_y > 0.0 and absf(_cel_dy) > _ram_y:
		return
	if not _boxes_touch():
		return
	if _player.has_method("take_hit") and not _player_dodges():
		var dmg := _body_damage if _body_damage > 0 else melee_damage
		_udar_fx(_bullet_type)
		_player.take_hit(dmg)
	if _bite_hop > 0.0 and is_on_floor():
		_do_jump(_bite_hop)


## The doorway-aware goal toward the player, worked out once per 30 Hz tick.
func _player_goal() -> Vector2:
	if not _player_valid():
		return _goal
	var target := _player.global_position
	if floori(target.x / ROOM_W) == floori(global_position.x / ROOM_W) and floori(target.y / ROOM_H) == floori(global_position.y / ROOM_H):
		return target
	# Another room: the opening search casts rays, so it is redone every GOAL_EVERY ticks.
	if _goal_tick < 0 or _ai_tick < _goal_tick or _ai_tick - _goal_tick >= GOAL_EVERY:
		_goal_tick = _ai_tick
		_goal_cached = _opening_goal(target)
		_goal_is_target = _goal_cached == target
	return target if _goal_is_target else _goal_cached


## Chase across a carved opening. A side gap at body height is already on the
## way to the player's x. A floor hole is not, so aim at that gap. A closed
## door is solid on the same ray and is left alone.
func _opening_goal(target: Vector2) -> Vector2:
	var dx := int(floor(target.x / ROOM_W)) - int(floor(global_position.x / ROOM_W))
	var dy := int(floor(target.y / ROOM_H)) - int(floor(global_position.y / ROOM_H))
	if dx == 0 and dy == 0:
		return target
	if _ray_clear(_eye_pos(), target + Vector2(0.0, -28.0), 1):
		return target
	if dx != 0 and _side_open(signf(float(dx))):
		return target
	if dy != 0:
		var hole := _floor_gap_x(target, signf(float(dy)))
		if is_finite(hole):
			return Vector2(hole, target.y)
	return target


func _side_open(dir: float) -> bool:
	var edge: float = (floor(global_position.x / ROOM_W) + (1.0 if dir > 0.0 else 0.0)) * ROOM_W
	var chest_y := _eye_pos().y
	var foot_y := global_position.y - 8.0
	return _ray_clear(Vector2(edge - 10.0, chest_y), Vector2(edge + 10.0, chest_y), 1) \
		or _ray_clear(Vector2(edge - 10.0, foot_y), Vector2(edge + 10.0, foot_y), 1)


func _floor_gap_x(target: Vector2, dir: float) -> float:
	var edge_y: float = (floor(global_position.y / ROOM_H) + (1.0 if dir > 0.0 else 0.0)) * ROOM_H
	var x0: float = floor(global_position.x / ROOM_W) * ROOM_W
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
	var world := get_world_2d()
	if world == null:
		return true
	var query := PhysicsRayQueryParameters2D.create(a, b, mask)
	query.collide_with_areas = false
	query.hit_from_inside = false
	return world.direct_space_state.intersect_ray(query).is_empty()


func _player_valid() -> bool:
	return _player != null and is_instance_valid(_player)


func _target_dx() -> float:
	if _on_prior and _prior_target() != null:
		return _prior.global_position.x - global_position.x
	if _player_valid():
		return _player.global_position.x - global_position.x
	return _goal.x - global_position.x


func _target_distance() -> float:
	if _on_prior and _prior_target() != null:
		return global_position.distance_to(_prior.global_position)
	if _player_valid():
		return global_position.distance_to(_player.global_position)
	return global_position.distance_to(_goal)


## Brain.pickAttack. Gunners hold for a fresh sighting inside aiDist (holdRange).
## Dashers (zebras) sometimes get ready to dash at a target in sight.
func _pick_attack() -> int:
	if fixed_post or fight_style == "turret":
		return ST_HOLD
	var state := ST_CHASE
	if fight_style == "gunner" and _gunner_hold and ai_spok >= MAX_SPOK + HOLD_FRESH:
		var range := _ai_dist if _raider_type else _hold_range
		if _cel_dx * _cel_dx + _cel_dy * _cel_dy < range * range and randf() < _hold_chance:
			state = ST_HOLD
	if _can_dash and _track_player and randf() < DASH_CHANCE:
		state = ST_DASH_PREP
	return state


func _commit_move() -> void:
	if not _climbing:
		_on_rail = false
	if _narrow and not _on_rail:
		_sync_climb_box()
	if _slow_t > 0.0:
		velocity *= 0.75
	# freezing tormoz is 0.75 and stacks with the distortion slow.
	if _ice_t > 0.0:
		velocity *= 0.75
	if _knock_x == 0.0:
		if _at_rest():
			return
		move_and_slide()
		_note_rest_floor()
		return
	velocity.x += _knock_x
	move_and_slide()
	velocity.x -= _knock_x
	if is_on_wall():
		_knock_x = 0.0
	else:
		var brake := float(_catalog_row(_species_id).get("move", {}).get("brake", 1.0))
		_knock_x = move_toward(_knock_x, 0.0, maxf(brake, 0.5) * TPS * TPS * get_physics_process_delta_time())


## A still unit on a static floor (or a fixed one) has nothing to slide; skip
## move_and_slide, but run it every REST_RECHECK calls so a floor that broke or
## moved away is noticed.
func _at_rest() -> bool:
	# throu turns the shelf off; skipping move_and_slide would leave them standing on it.
	if _throu or _throu_left > 0.0:
		_rest_skips = 0
		return false
	if velocity != Vector2.ZERO:
		_rest_skips = 0
		return false
	if _rest_fixed < 0:
		_rest_fixed = 1 if bool(_catalog_row(_species_id).get("fixed", false)) else 0
	if _rest_fixed == 0 and not (_rest_static_floor and is_on_floor()):
		return false
	_rest_skips += 1
	if _rest_skips >= REST_RECHECK:
		_rest_skips = 0
		return false
	return true


func _note_rest_floor() -> void:
	_rest_static_floor = false
	if not is_on_floor() or get_platform_velocity() != Vector2.ZERO:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_normal().y < -0.5:
			var body := col.get_collider()
			_rest_static_floor = body is StaticBody2D and not body is AnimatableBody2D
			return


## Unit.otbros: sila = rnd(0.8..1.2) * knocked / massa, at most 3; velocity += knock * otbros * sila.
func otbros(knock: Vector2, power: float) -> void:
	if knock != Vector2.ZERO and _brain != null:
		_brain.on_knock()
	if power <= 0.0 or knock == Vector2.ZERO or _dead or bool(_catalog_row(_species_id).get("fixed", false)):
		return
	var knocked := float(_catalog_row(_species_id).get("move", {}).get("knocked", 1.0))
	var massa := maxf(_UnitMassa.massa(self), 0.01)
	var sila := minf((randf() * 0.4 + 0.8) * knocked / massa, 3.0)
	var push := knock * power * sila * TPS
	_knock_x += push.x
	velocity.y += push.y


func _fit_body() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node:
		var box := RectangleShape2D.new()
		box.size = body_size
		shape_node.shape = box
		shape_node.position = Vector2(0, -body_size.y * 0.5)
	if is_instance_valid(anim):
		if _sheet_native:
			anim.position = Vector2.ZERO
			anim.scale = Vector2.ONE
			anim.centered = true
			anim.offset = _sheet_offset
		else:
			anim.position = Vector2(0, -body_size.y * 0.5)
			anim.scale = Vector2(body_size.x / 48.0, body_size.y / 56.0)
	floor_check.position = Vector2(-body_size.x * 0.55, 0)
	wall_check.target_position = Vector2(-maxf(24.0, body_size.x * 0.7), -body_size.y * 0.4)
	muzzle.position = Vector2(facing * body_size.x * 0.5, -body_size.y * 0.6)


func _shoot_at(target: Vector2) -> void:
	if _on_prior and _prior_target() != null:
		target = _body_center(_prior)
	_launch(target, _weapon, _friendly, true, _fire_down)


func take_hit(amount: int = 15, type: String = "") -> void:
	_receive(float(amount), type, null, false)


## A bullet or blast. Unit.udarBullet: dexter already decided the hit in the bullet.
## A direct hit rolls 0.7–1.3 of the damage, then Unit.damage runs.
func hit_by_bullet(bullet: Node, amount: float, blast: bool) -> void:
	var dam := amount
	if not blast:
		dam *= randf_range(0.7, 1.3)
	var tip := str(bullet.get("damage_type")) if bullet != null else ""
	# Unit.udarBullet: priorUnit = bul.owner. Player shots clear it back to the player.
	if bullet != null and bool(bullet.get("from_player")):
		var owner_v: Variant = bullet.get_meta("owner_unit") if bullet.has_meta("owner_unit") else null
		_prior = owner_v if owner_v is Node2D and is_instance_valid(owner_v) and (owner_v as Node).is_in_group("pets") else null
	elif _ground_ally and bullet != null and bullet.has_meta("owner_unit"):
		# Unit.udarBullet: priorUnit = bul.owner, the shooter of another fraction.
		var shooter: Variant = bullet.get_meta("owner_unit")
		if shooter is Node2D and is_instance_valid(shooter) and shooter != self and (shooter as Node).is_in_group("enemies"):
			_prior = shooter
	_receive(dam, tip, bullet, false)


## Damage over time (Effect burn/acid/poison/pink and bleeding) is tt: no armor, no shock.
func _take_dot(amount: int, type: String) -> void:
	_receive(float(amount), type, null, true)


## Unit.damage after the bullet roll: resistance, armor wear, armor, critInvis, shock.
## An empty type is damage already scaled by Resistances.apply.
func _receive(amount: float, type: String, bullet: Node, tt: bool) -> void:
	if _dead or _downed or (_buried and _dig_left <= 0.0):
		return
	var dam := amount
	if type != "":
		dam *= _resist(type)
	if bullet != null and bool(bullet.get("from_player")):
		dam *= Progression.target_mult(self)
	if _brain != null and dam > 0.0:
		dam = _brain.on_damage(dam, type, bullet, tt)
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
			if _armor_qual > 0.0 and randf() < _armor_qual:
				armor2 += _armor
		elif type in ARMOR_MAGIC:
			armor2 = _skin
			if _armor_qual > 0.0 and randf() < _armor_qual:
				armor2 += _marmor
		if bullet != null and bullet.get("pier") != null:
			armor2 -= float(bullet.get("pier"))
		if armor2 > 0.0:
			dam -= armor2
	if bullet != null and bool(bullet.get("from_player")) and not _track_player:
		if _world_crit_invis > 0.0 and randf() < _world_crit_invis:
			dam *= 2.0
	var desintegr: Variant = bullet.get("desintegr") if bullet != null else null
	if desintegr != null and float(desintegr) > 0.0 and dam > 0.0 and type in ["DAM_LASER", "DAM_PLASMA"]:
		if hp <= dam * 10.0 and randf() < float(desintegr):
			dam *= 12.0
	var dealt := int(round(dam))
	if dealt <= 0:
		return
	var nshok := int(round((randf() * 0.8 + 0.2) * float(MAX_SHOK) * 4.0 * float(dealt) / maxf(1.0, float(max_hp))))
	nshok = mini(nshok, MAX_SHOK)
	if tt or nshok < 5:
		nshok = 0
	if nshok > _shok:
		_shok = nshok
	if nshok > 0:
		_windup_left = 0.0
	_die_tip = type
	_blood_fx(float(dealt), type, bullet)
	# Unit.damage: mat 10 (only UnitThunderHead sets it) flashes pole2 where the bullet hit.
	if _species_id == "thunderhead" and bullet is Node2D:
		UnitFx.emit(get_tree(), "pole2", (bullet as Node2D).global_position)
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
		UnitFx.emit(get_tree(), pid, (bullet as Node2D).global_position, {"dx": d.x, "dy": d.y, "kol": int(randf() * 5.0 + dam / 5.0)})
	else:
		UnitFx.emit(get_tree(), pid, _feet(self) - Vector2(0.0, size.y * 0.5), {"kol": int(dam / 3.0)})
	if blood != 1 or type == "DAM_BLEED" or _UnitMassa.massa(self) <= 0.2:
		return
	var ver := randf()
	if type == "DAM_CUT":
		ver *= ver
	if dam / 1000.0 <= ver:
		return
	var side := 1.0
	if bullet is Node2D:
		side = -1.0 if (bullet.get("direction") as Vector2).x < 0.0 else 1.0
	elif randf() < 0.5:
		side = -1.0
	var at := _feet(self) + Vector2(80.0 * side + (randf() - 0.5) * size.x * 0.5, -randf() * size.y * 0.5 - 40.0)
	UnitFx.emit(get_tree(), "bloodexpl%d" % randi_range(1, 3), at, {"mirr": 1 if side < 0.0 else 0})


func _apply_damage(amount: int, separate: bool = false) -> void:
	var calm := _is_calm()
	hp -= amount
	_float_hit(amount, false, separate)
	anim.modulate = Color(1.0, 0.5, 0.5)
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		if is_instance_valid(anim):
			anim.modulate = _tint
	)
	if _brain == null and not _class_anim:
		_play_anim("crouch")
	if calm:
		_wake_allies()
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
	var room := _room_rect()
	var pf := float(_player.get("facing")) if "facing" in _player else 1.0
	var pp := _player.global_position
	for i in range(1, 21):
		var to := Vector2.ZERO
		if i < 5:
			var s := -pf if randf() < 0.7 else pf
			to = Vector2(pp.x + s * (randf() * 300.0 + 200.0), pp.y)
		elif i < 10:
			var s2 := -pf if randf() < 0.5 else pf
			to = Vector2(pp.x + s2 * (randf() * 800.0 + 200.0), pp.y + randf() * 160.0 - 80.0)
		else:
			to = room.position + Vector2(randf() * room.size.x, randf() * room.size.y)
		to = Vector2(round(to.x / 40.0) * 40.0, ceil(to.y / 40.0) * 40.0 - 1.0)
		to.x = clampf(to.x, room.position.x + body_size.x, room.end.x - body_size.x)
		to.y = clampf(to.y, room.position.y + body_size.y + 40.0, room.end.y - 40.0)
		if _blocked_at(to):
			continue
		UnitFx.emit(get_tree(), "tele", global_position + Vector2(0.0, -body_size.y * 0.5), {"rx": body_size.x, "ry": body_size.y, "kol": 30})
		global_position = to
		velocity = Vector2.ZERO
		UnitFx.emit(get_tree(), "teleport", global_position + Vector2(0.0, -body_size.y * 0.5))
		_sense()
		if _track_player:
			ai_spok = 0
			ai_state = ST_SURPRISED
			_state_left = float(randi_range(20, 49)) / TPS
			facing = 1.0 if pp.x > global_position.x else -1.0
			_port_t = randi_range(150, 239)
		else:
			_port_t = randi_range(30, 119)
		_port_kol -= 1
		return


func _room_rect() -> Rect2:
	var size := Vector2(48 * 40, 25 * 40)
	var rx := int(get_meta("room_x", int(floor(global_position.x / size.x))))
	var ry := int(get_meta("room_y", int(floor(global_position.y / size.y))))
	return Rect2(Vector2(rx, ry) * size, size)


## Unit.collisionAll at a feet point: would the body overlap a wall there.
func _blocked_at(feet: Vector2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var box := RectangleShape2D.new()
	box.size = body_size - Vector2(2.0, 2.0)
	q.shape = box
	q.transform = Transform2D(0.0, feet + Vector2(0.0, -body_size.y * 0.5))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func _decide() -> void:
	var was := ai_state
	if ai_state == ST_DASH_PREP:
		ai_state = ST_DASH
		_state_left = DASH_TIME / TPS
		return
	if ai_state == ST_SURPRISED:
		if _track_player:
			ai_spok = MAX_SPOK + SIGHT_BONUS
			ai_state = ST_CHASE
		else:
			ai_state = ST_PATROL
	if ai_spok == 0:
		# Brain_Definition.stroll: units told to stay (un stay, aiTip stay) only stand.
		ai_state = ST_PATROL if _stroll and randf() < 0.5 else ST_IDLE
	elif ai_spok < MAX_SPOK:
		ai_state = ST_SEARCH
	else:
		if was != ST_CHASE and was != ST_HOLD:
			_wake_allies()
		ai_state = _pick_attack()
	if _is_calm():
		_state_left = randf_range(IDLE_MIN, IDLE_MAX) / TPS
	elif ai_state == ST_DASH_PREP:
		_state_left = DASH_PREP_TIME / TPS
	else:
		_state_left = randf_range(ALERT_MIN, ALERT_MAX) / TPS
	_sync_vision()
	_calm_cast()


func _sense() -> void:
	if _friendly or _buried or _downed or ai_state == ST_FLEE:
		return
	if _detect_delay > 0.0:
		return
	if _player == null or not is_instance_valid(_player):
		_track_player = false
		return
	# Unit.findCel: a seen priorUnit comes before the player.
	_on_prior = false
	var pr := _prior_target()
	if pr != null and _look(pr) > 0.5:
		_on_prior = true
		_track_player = true
		_aware = true
		_goal = pr.global_position
		if ai_spok < MAX_SPOK:
			ai_spok = MAX_SPOK + SIGHT_BONUS
		_sync_vision()
		return
	# Unit.findCel skips loc.gg.invulner, which controlOff sets.
	if bool(_player.get("control_off")):
		_lose()
		_sync_vision()
		return
	# Original rooms are separate locations; a room still waiting on its
	# scripted area must not see or hear the player past its edge.
	if not _aware and not _room_rect().has_point(_player.global_position) and _scene_pending():
		_lose()
		_sync_vision()
		return
	var heard := _listen(_player)
	var seen := _look(_player)
	if heard > 0.0:
		_add_obs(_player, heard, -1000.0)
	if seen > 0.0:
		_add_obs(_player, seen, _observ)
		if _obs(_player) >= MAX_OBS:
			_track_player = true
			_aware = true
			_memory_left = TARGET_MEMORY
			_goal = _player.global_position
			_on_seen()
			_sync_vision()
			return
	elif heard > 0.0:
		if _obs(_player) >= MAX_OBS:
			_track_player = false
			_goal = _player.global_position + Vector2(randf_range(-100.0, 100.0), randf_range(-100.0, 100.0))
		if heard > 1.0:
			ai_spok = MAX_SPOK - 1
			_sync_vision()
			return
	_lose()
	_sync_vision()


func _scene_pending() -> bool:
	if _scene_areas == null:
		_scene_areas = []
		var rect := _room_rect()
		for a in get_tree().get_nodes_in_group("land_area"):
			if not (a.get_meta("actions", []) as Array).is_empty() and rect.has_point((a as Node2D).global_position):
				_scene_areas.append(a)
	for a in _scene_areas:
		if is_instance_valid(a) and bool(a.get_meta("enabled", false)):
			return true
	return false


func _on_seen() -> void:
	if _v_konus > 0.0:
		ai_spok = MAX_SPOK + SIGHT_BONUS
		ai_state = ST_HOLD
		_state_left = randf_range(ALERT_MIN, ALERT_MAX) / TPS
		return
	if _is_calm():
		ai_state = ST_SURPRISED
		_state_left = float(randi_range(int(_surprise_min), int(_surprise_max))) / TPS
		return
	ai_spok = MAX_SPOK + SIGHT_BONUS


func _lose() -> void:
	# Six failed looks still follow the player's real position, then the guess drifts.
	if _memory_left > 0:
		_memory_left -= 1
		_track_player = true
		if _player != null and is_instance_valid(_player):
			_goal = _player.global_position
		return
	_track_player = false
	_unseen_looks += 1
	if _unseen_looks % DRIFT_INTERVAL == 0:
		_goal.x += randf_range(-SEARCH_DRIFT, SEARCH_DRIFT)
		_goal.y += randf_range(-SEARCH_DRIFT, SEARCH_DRIFT)
	if ai_spok > 0:
		ai_spok -= 1
	if ai_spok == 0:
		return
	if not _aware and ai_spok < GIVE_UP_SPOK:
		ai_spok = 0


func _sync_vision() -> void:
	_vision = _calm_vision if ai_spok == 0 else _alert_vision


func _become_alert(point: Vector2) -> void:
	_track_player = false
	_goal = point
	ai_spok = MAX_SPOK + SIGHT_BONUS
	ai_state = ST_CHASE
	_state_left = randf_range(ALERT_MIN, ALERT_MAX) / TPS
	_detect_delay = 0.0
	_vision = _alert_vision
	_overlook = true


func _wake_allies() -> void:
	if _wake_radius > 0.0:
		_budilo(_wake_radius)


## Unit.budilo: make a noise, and alarm awake units of the same fraction inside rad * their ear.
## Two robots hear each other at rad.
func _budilo(rad: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	set_meta("foe_noise", _noise_run * 1.2)
	var robot := _is_machine()
	for node in tree.get_nodes_in_group("enemies"):
		if node == self or not node.has_method("_alarm_from"):
			continue
		if int(node.get("fraction")) != fraction or bool(node.get("_dead")) or bool(node.get("_downed")) or bool(node.get_meta("unres", false)):
			continue
		var other := node as Node2D
		var d2 := other.global_position.distance_squared_to(global_position)
		var reach := rad
		if not (robot and bool(node.call("_is_machine"))):
			reach = rad * float(node.get("_ear"))
		if d2 < reach * reach:
			other.call("_alarm_from", global_position)


## Unit.alarma then Brain.alarm. Only a calm unit wakes; it starts shocked.
func _alarm_from(at: Vector2) -> void:
	if _dead or not _is_calm():
		return
	_become_alert(at + Vector2(randf_range(-125.0, 125.0), randf_range(-125.0, 125.0)))
	_shok = randi_range(_alarm_shock_min, _alarm_shock_max)
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
	var vel := _velocity_of(player)
	var vis := PLAYER_VIS_STILL
	if absf(vel.x) >= 2.0 * TPS or absf(vel.y) >= 2.0 * TPS:
		vis = PLAYER_VIS_MOVE
	vis *= float(player.get_meta("foe_vis_mult", 1.0))
	var detecting := float(player.get_meta("foe_detecting", DETECTING))
	# Unit.look: (visibility * stealthMult * loc.visMult + demask) * vision.
	var dist_vis := (vis * _world_stealth * _world_vis_mult + float(player.get_meta("foe_demask", 0.0))) * _vision
	# No cone: a target mostly below the eyes is harder to see, down to half range.
	if _v_konus == 0.0 and not _overlook and cy > 0.0 and cy * cy > cx * cx:
		dist_vis *= 0.5 + 0.5 * absf(cx / cy)
	# The original stops at 4x distVis inside its own room; the sight ray stops at a room width.
	if r2 > minf(dist_vis * dist_vis * 16.0, SIGHT_CAP * SIGHT_CAP):
		return 0.0
	# Calm raiders (overlook 0) see behind only inside detecting.
	if _v_konus == 0.0 and not _overlook and cx * facing < 0.0 and r2 > detecting * detecting:
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
	var noise := float(player.get_meta("foe_noise", 0.0)) * _ear * GameState.enemy_ear_mult()
	if noise <= 0.0:
		return 0.0
	var p_feet := _feet(player)
	var e_feet := _feet(self)
	var mouth := Vector2(p_feet.x, p_feet.y - _body_size(player).y * 0.75)
	var ear := Vector2(e_feet.x, e_feet.y - _body_size(self).y * 0.5)
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
		var ticks := delta * TPS
		var is_obs := float(player.get_meta("foe_is_obs", 0.0))
		var obs := float(player.get_meta("foe_obs", 0.0))
		if is_obs > 0.0:
			is_obs -= ticks
			if is_obs < 0.0:
				obs = maxf(0.0, obs - MINUS_OBS * (-is_obs))
				is_obs = 0.0
		elif obs > 0.0:
			obs = maxf(0.0, obs - MINUS_OBS * ticks)
		player.set_meta("foe_is_obs", is_obs)
		player.set_meta("foe_obs", obs)
		var demask := maxf(0.0, float(player.get_meta("foe_demask", 0.0)) - DEMASK_DECAY * ticks)
		var vel := _velocity_of(player)
		if absf(vel.x) > 10.0 * TPS or absf(vel.y) > 10.0 * TPS:
			demask = maxf(demask, FAST_DEMASK)
		player.set_meta("foe_demask", demask)
		_refresh_world(player)
		_world_danger = _gather_grenades(get_tree())
		var noise := maxf(0.0, float(player.get_meta("foe_noise", 0.0)) - NOISE_DECAY * ticks)
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
		room = _room_of(p2.global_position)
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
	var fog := get_tree().get_first_node_in_group("fog")
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
	var run := NOISE_RUN
	if Progression != null:
		run = maxf(0.0, 300.0 - 60.0 * float(Progression.skill_level_of("sneak")))
	run = Effects.stat("noiseRun", run)
	var vx := absf(vel.x)
	if vx > 12.0 * TPS:
		return run
	if vx > 7.0 * TPS:
		return run * 0.5
	if vx > 3.0 * TPS:
		return run * 0.25
	return 0.0


func _scan_shots(player: Node) -> void:
	var tree := get_tree()
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
	var demask := maxf(float(player.get_meta("foe_demask", 0.0)), SHOT_DEMASK)
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
	var obs := minf(float(player.get_meta("foe_obs", 0.0)) + nlook, MAX_OBS * 2.0)
	player.set_meta("foe_obs", obs)
	player.set_meta("foe_is_obs", OBS_GRACE)


func _obs(player: Node) -> float:
	return float(player.get_meta("foe_obs", 0.0))


func _eye_pos() -> Vector2:
	var size := _body_size(self)
	var feet := _feet(self)
	return Vector2(feet.x + size.x * 0.25 * facing, feet.y - size.y * 0.75)


func _look_point(body: Node2D) -> Vector2:
	var feet := _feet(body)
	return Vector2(feet.x, feet.y - _body_size(body).y * 0.6)


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


func _aim_angle() -> float:
	if _brain != null:
		return _brain.v_angle()
	if _aim_down:
		return PI * 0.5
	return V_ANGLE if facing >= 0.0 else PI


func _apply_species() -> void:
	if bool(get_meta("vortex_minion", false)) and str(_catalog_unit("vortex").get("brain", "")) == "":
		_configure_vortex()
		return
	var id := _read_species()
	if id == "":
		# Scene enemies with no species are raider gunners: they strafe while alert.
		_backpedal = fight_style != "melee" and fight_style != "turret"
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
		id = "bloat%d" % (randi() % 5)
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
	_observ = float(row.get("observ", 0.0))
	_weapon_skill = float(row.get("skill", 1.0))
	_levit_attack = float(row.get("levitatk", 1.0))
	_ai_dist = float(row.get("ai_dist", HOLD_RANGE))
	_trup = float(row.get("trup", 1.0)) > 0.0
	_loot_cont = str(row.get("cont", id))
	_noise_run = float(row.get("noise", UNIT_NOISE_RUN))
	_unit_porog = float(row.get("porog", STEP_UP))
	_porog = _unit_porog
	_raider_type = id == "raider" or _raider_kin(id)
	if _raider_type and _held_weapon == null:
		_held_weapon = _HeldWeapon.new()
		_held_weapon.name = "HeldWeapon"
		add_child(_held_weapon)
		_held_weapon.setup(self, id)
		_walker = _HeldWeapon.unit_flag(id, "walker")
	_anim_class = _anim_class_of(id)
	_class_anim = _anim_class != ""
	_levit_struggle = (_anim_class in ["pony", "hellhound", "zombie", "ant", "monstrik"] and not id.begins_with("ranger")) \
			or id.begins_with("alicorn")
	_levitaccel = float(_catalog_row(id).get("move", {}).get("levitaccel", 1.6))
	fraction = int(row.get("fraction", 2 if _raider_type else 1))
	if bool(row.get("stay", false)) or str(get_meta("ai_tip", "")) in ["stay", "quiet", "sniper"]:
		_stroll = false
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
		_can_dash = id.begins_with("zebra")
		_sniper = bool(row.get("sniper", false))
		_drop_arm = not (id.begins_with("encl") or id.begins_with("ranger")) and not has_meta("nodrop")
		_opens_doors = true
		_climbs_ladders = not _flying
		_wake_radius = WAKE_RADIUS
	elif id.begins_with("scorp") or id.begins_with("ant"):
		# UnitMonstrik / UnitAnt brains: default surprise, short alarm shock, alarm wakes 250 around.
		_surprise_min = BRAIN_SURPRISE_MIN
		_surprise_max = BRAIN_SURPRISE_MAX
		_alarm_shock_min = 3
		_alarm_shock_max = 8
		_alarm_radius = 250.0
		_wake_radius = 0.0
		_climbs_ladders = id.begins_with("ant")
	elif id.begins_with("hellhound"):
		_surprise_min = BRAIN_SURPRISE_MIN
		_surprise_max = BRAIN_SURPRISE_MAX
		_climbs_ladders = true


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
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
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
		_accel_tick = move_speed / TPS * ACCEL_RATIO
	var dmg := int(row.get("damage", melee_damage))
	melee_damage = dmg
	_bullet_damage = dmg
	_bullet_type = str(row.get("damage_type", _bullet_type))
	_bullet_speed = float(row.get("bullet_speed", _bullet_speed))
	fight_style = str(row.get("fight", fight_style))
	fixed_post = bool(row.get("fixed", fixed_post))
	_can_lift = bool(row.get("lift", true))
	_calm_vision = float(row.get("vision", _calm_vision))
	_alert_vision = float(row.get("alert", _alert_vision))
	_vision = _calm_vision
	_ear = float(row.get("ear", _ear))
	_v_konus = float(row.get("cone", 0.0))
	_aim_down = bool(row.get("aim_down", false))
	_gunner_hold = bool(row.get("hold", false))
	_hold_range = float(row.get("hold_range", _hold_range))
	_hold_chance = float(row.get("hold_chance", _hold_chance))
	_do_backoff = bool(row.get("backoff", false))
	_chase_shot = bool(row.get("chase_shot", fight_style == "gunner"))
	_swing_x = float(row.get("swing_x", _swing_x))
	_swing_above = float(row.get("swing_above", _swing_above))
	_swing_below = float(row.get("swing_below", _swing_below))
	_strike_cd = float(row.get("strike_cd", _strike_cd))
	_strike_windup = float(row.get("windup", _strike_windup))
	_strike_hold = float(row.get("strike_hold", _strike_hold))
	_contact_bite = bool(row.get("contact", false))
	_attack_reach = float(row.get("reach", _attack_reach))
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
	_gunner_hold = false
	_do_backoff = false
	_burst_len = 0
	_burst_left = 0


func _apply_bloat() -> void:
	var id := _species_id
	_flying = true
	_hover = 0.0
	_gunner_hold = false
	_do_backoff = false
	_loose_fly = false
	var reach := BLOAT_RANGE
	if id == "bloat0":
		reach = 600.0
	elif id == "bloat4" or id == "bloat6" or id == "bloat7":
		reach = 700.0
	_attack_reach = reach
	# Spitters keep the weapon armed above. They fly and shoot inside attRasst.
	# They do not use the raider hold. The others bite on contact.
	var spit := id in ["bloat1", "bloat2", "bloat5", "bloat8", "bloat9", "bloat10"]
	if spit and not _weapon.is_empty():
		fight_style = "gunner"
		_chase_shot = true
		_contact_bite = false
	else:
		fight_style = "melee"
		_contact_bite = true
		_chase_shot = false
		_strike_cd = BLOAT_TICKS / TPS
		_strike_windup = 0.0
		_strike_hold = 1.0


func _apply_emitter() -> void:
	fight_style = "melee"
	fixed_post = true
	move_speed = 0.0
	run_speed = 0.0
	_flying = false
	_gunner_hold = false
	_do_backoff = false
	_chase_shot = false
	_contact_bite = true
	_attack_reach = INF
	melee_damage = EBLOAT_DAMAGE
	_strike_cd = BLOAT_TICKS / TPS
	_strike_windup = 0.0
	_strike_hold = 1.0


func _apply_scorp(id: String) -> void:
	fight_style = "melee"
	_swing_x = SCORP_X
	_swing_above = SCORP_ABOVE
	_swing_below = SCORP_BELOW
	_strike_hold = SCORP_HOLD
	_strike_cd = PUNCH_TICKS / TPS
	_strike_windup = PUNCH_HIT / TPS
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
		_bullet_type = str(punch.get("damage_type", "DAM_BITE"))
	if _comb > 0:
		_body_damage = _comb
	# UnitMonstrik: not a jumper. closeHoldChance 0.7, then WeaponAttack while holding.
	_jump_reach = false
	_hop_gaps = false
	_ram_while_chase = false
	_melee_while_chase = false
	_backpedal = false
	_close_chance = SCORP_HOLD
	_band_min = 0.0
	_band_max = SCORP_X
	_band_up = SCORP_ABOVE
	_band_down = SCORP_BELOW
	_close_release = false
	_close_search = true
	_close_tmin = PUNCH_TICKS
	_close_tmax = PUNCH_TICKS
	_swing_chance = 1.0
	_leap_above = 40.0
	_reaim_every = 10
	_reaim_chance = 0.7
	_reaim_dist = 80.0


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


func _aim_probes() -> void:
	var side := facing if facing != 0.0 else -1.0
	floor_check.position.x = absf(floor_check.position.x) * side
	wall_check.target_position.x = absf(wall_check.target_position.x) * side
	muzzle.position = Vector2(side * maxf(body_size.x * 0.5, 16.0), -body_size.y * 0.6)


func _has_clip(clip: String) -> bool:
	return is_instance_valid(anim) and anim.sprite_frames != null and anim.sprite_frames.has_animation(clip)


func _present(moving: bool) -> void:
	if not is_instance_valid(anim):
		return
	if _climbing and _climb_locked:
		facing = _climb_face
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
	elif _crawling and _has_clip("polz"):
		if moving or not _has_clip("sit"):
			_play_anim("polz")
		else:
			_play_anim("sit")
	elif _flying:
		_play_anim("fly" if _has_clip("fly") else "idle")
	elif _jet:
		# UnitProtect.animate: fly while jump_n > 5 in the air, walk under 3 px a tick, else trot.
		if not is_on_floor():
			_play_anim("fly" if _jet_n > 5 else "jump")
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
				elif _anim_class == "encl" and _walker and ai_state in [ST_IDLE, ST_PATROL, ST_HOLD]:
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
				elif _walker and ai_state in [ST_IDLE, ST_PATROL, ST_HOLD]:
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
				if _crawling:
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


func _low_ceiling() -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return false
	var top := global_position + Vector2(0.0, -body_size.y * 0.55)
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0.0, -4.0), top, 1)
	var skip: Array[RID] = []
	skip.append(get_rid())
	query.exclude = skip
	return not space.intersect_ray(query).is_empty()


## The 30 Hz clock: whole AI ticks this frame, the shock countdown.
func _advance_ticks(delta: float) -> void:
	_sim += delta * TPS
	_frame_ticks = int(_sim)
	_sim -= float(_frame_ticks)
	_ai_tick += _frame_ticks
	if _shok > 0:
		_shok = maxi(0, _shok - _frame_ticks)
	if _ai_laz > 0:
		_ai_laz = maxi(0, _ai_laz - _frame_ticks)
	if _climbing:
		if _t_laz < 0:
			_t_laz = 0
		_t_laz += _frame_ticks
	else:
		if _t_laz > 0:
			_t_laz = 0
		_t_laz -= _frame_ticks
		_r_laz = 0


static func _room_of(at: Vector2) -> Vector2i:
	return Vector2i(int(floor(at.x / ROOM_W)), int(floor(at.y / ROOM_H)))


static func _room_near(room: Vector2i) -> bool:
	return absi(room.x - _world_room.x) <= ACTIVE_REACH and absi(room.y - _world_room.y) <= ACTIVE_REACH


## Only the player's Location runs in the original. Here the player's room and its
## neighbours run; a unit that ends up elsewhere sleeps until the player comes near.
func _room_still_active() -> bool:
	if (_friendly and not _ground_ally) or (_brain != null and _brain.always_active):
		return true
	_room_check -= _frame_ticks
	if _room_check > 0:
		return true
	_room_check = ROOM_CHECK_TICKS
	if _world_room.x == -99999 and _player_valid():
		_world_room = _room_of(_player.global_position)
	var here := _room_of(global_position)
	if _room_near(here):
		return true
	# Seamless rooms: a unit already after the player keeps going one room further.
	if not _is_calm() and absi(here.x - _world_room.x) <= CHASE_REACH and absi(here.y - _world_room.y) <= CHASE_REACH:
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
	_world_room = room
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
			_player = get_tree().get_first_node_in_group("player") as Node2D
			if _player == null:
				return
		var p := _player.global_position
		var room := Vector2i(int(floor(p.x / 1920.0)), int(floor(p.y / 1000.0)))
		if room != _room:
			_room = room
			on_room.call(room, get_tree())


## Weapon holder reload: no shots for reload ticks, then a full magazine.
func _tick_reload(delta: float) -> void:
	if _reload_left <= 0.0:
		return
	_reload_left -= delta
	if _reload_left <= 0.0:
		_reload_left = 0.0
		_mag = _mag_cap


## UnitRaider.watchForDanger: run from a grenade in view, react to a levitated mine.
func _watch_for_danger() -> void:
	if _friendly or _cannot_fight():
		return
	for k in _frame_ticks:
		var t := _ai_tick - k
		if _fear_grenade and not _world_danger.is_empty() and t % GRENADE_CHECK == 1 and randf() < GRENADE_CHECK_CHANCE:
			var nade: Variant = _grenade_in_view()
			if nade != null:
				_flee(float(nade.x) - global_position.x)
				return
		if t % MINE_CHECK == 1 and not _track_player:
			_watch_levitation()


func _grenade_in_view() -> Variant:
	var center := global_position + Vector2(0.0, -_body_size(self).y * 0.5)
	var eye := global_position + Vector2(0.0, -_body_size(self).y * 0.75)
	for g in _world_danger:
		var at: Vector2 = g
		if center.distance_squared_to(at) < 160000.0 and Sight.los_clear(eye, at, null):
			return at
	return null


func _flee(dx: float) -> void:
	ai_state = ST_FLEE
	ai_spok = MAX_SPOK + SIGHT_BONUS
	_state_left = float(randi_range(FLEE_TIME_MIN, FLEE_TIME_MAX)) / TPS
	if dx > FLEE_SLACK:
		_flee_dir = -1.0
	elif dx < -FLEE_SLACK:
		_flee_dir = 1.0
	if _flee_dir != 0.0:
		_goal = global_position + Vector2(_flee_dir * 1000.0, 0.0)


func _watch_levitation() -> void:
	if not _player_valid():
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
			_flee(dx)
		else:
			if fight_style == "gunner" and not _thrown:
				ai_state = ST_HOLD
			ai_spok = MAX_SPOK + SIGHT_BONUS
			_state_left = float(randi_range(FLEE_TIME_MIN, FLEE_TIME_MAX)) / TPS
	else:
		ai_spok = MINE_SUSPICION
		_sync_vision()


## Live grenades in the level (Location.grenades), gathered once per frame.
static func _gather_grenades(tree: SceneTree) -> Array:
	var out: Array = []
	for group in ["player_bullets", "enemy_bullets"]:
		for node in tree.get_nodes_in_group(group):
			if bool(node.get("explode_on_timeout")) and float(node.get("blast_radius")) > 0.0:
				out.append((node as Node2D).global_position)
	return out


## UnitRaider: throu = moving && celDY > 80 (every control tick, any aiState).
## Unit.setCel: celDY = celY - Y + scY with celY = target.Y - target.scY / 2.
## Patrol (aiSpok 0) aims at its own head, so celDY is 0 and it does not drop.
func _refresh_throu() -> void:
	var moving := not fixed_post and not _flying and move_speed > 0.0 and not levitated
	if not moving:
		_throu = false
		return
	var dy := 0.0
	if _track_player and _player_valid():
		var pf := _feet(_player)
		dy = pf.y - _body_size(_player).y * 0.5 - global_position.y + body_size.y
	elif not _is_calm():
		dy = _goal.y - global_position.y + body_size.y
	_throu = dy > DROP_THROUGH


## Unit.throu: collisionTile skips a shelf while this is set. Keep it on for a few
## ticks after the test so the body leaves the one-way lip.
func _apply_throu() -> void:
	_refresh_throu()
	var drop := _throu and is_on_floor() and not _flying and not levitated
	if drop:
		_throu_left = 6.0 / TPS
		if velocity.y < 40.0:
			velocity.y = 40.0
	elif _throu_left > 0.0:
		_throu_left -= get_physics_process_delta_time()
	set_collision_mask_value(PLATFORM_LAYER_BIT, _throu_left <= 0.0)


## WalkMotor porog: a ledge up to porog pixels is stepped onto instead of blocking.
func _step_up() -> bool:
	if _porog <= 0.0 or _flying:
		return false
	var dir := facing if facing != 0.0 else 1.0
	var up := Transform2D(0.0, global_position + Vector2(0.0, -_porog))
	if test_move(global_transform, Vector2(0.0, -_porog)):
		return false
	if test_move(up, Vector2(dir * 4.0, 0.0)):
		return false
	global_position.y -= _porog
	global_position.x += dir * 2.0
	return true


## Unit.opensDoors: walking into a closed, unlocked door opens it.
func _open_door_ahead() -> void:
	if not wall_check.is_colliding():
		return
	var door := wall_check.get_collider() as Node
	if door == null or not door.has_meta("lock"):
		return
	if float(door.get_meta("lock", 0.0)) > 0.0 or not bool(door.get_meta("usable", true)):
		return
	if int(door.get_meta("locktip", 1)) == 4:
		return
	if bool(door.get_meta("door_open", false)) or str(door.get_meta("door_id", "")) == "septum":
		return
	var host := get_tree().get_first_node_in_group("land_props")
	if host == null or not host.has_method("_apply_door"):
		return
	var doors: Variant = host.get("_doors")
	if doors is Array and (doors as Array).has(door):
		host.call("_apply_door", door, true)


## UnitRaider.mostLaz: grab when the tile at the feet (or 2 px below) is a stair, after the off-ladder wait.
func _climb_toward_target() -> void:
	if not _climbs_ladders or _climbing or _flying or not _player_valid():
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


func _tick_role(delta: float) -> void:
	_body_cd = maxf(0.0, _body_cd - delta)
	_attack_left = maxf(0.0, _attack_left - delta)
	_gutsy_cd = maxf(0.0, _gutsy_cd - delta)
	_necro_cd = maxf(0.0, _necro_cd - delta)
	if _cast_left > 0.0:
		_cast_left -= delta
		if _cast_left <= 0.0:
			_invis = false
	if _dig_left > 0.0:
		_dig_left -= delta
		visible = true
		if _dig_left <= 0.0:
			_buried = false
			set_collision_layer_value(3, true)
		return
	if _buried:
		if _player_valid() and global_position.distance_to(_player.global_position) < 480.0:
			_dig_left = 24.0 / TPS
			visible = true
		return
	if _prep_left > 0.0:
		_prep_left -= delta
		if _prep_left <= 0.0:
			_begin_super()
			_super_left = _super_need
	elif _super_left > 0.0:
		_run_super(delta)
		_super_left -= delta
		if _super_left <= 0.0:
			_end_super()
	elif _super != "" and ai_state == ST_CHASE:
		_rage += float(_frame_ticks)
		if _rage >= _zlo and _player_valid():
			_rage = 0.0
			_prep_left = _prep_need
			if _tele_kind == "ghoul":
				if _tele_unit == null and _track_player:
					_tele_unit = _player
				# UnitZombie.control calls findSuper for ss 1 and 2 only.
				if _tele_tr == 2:
					_find_super()
	if _cast != "" and not _is_calm():
		_cast_ready -= delta
		if _cast_ready <= 0.0:
			_do_cast()
	_tick_side(delta)
	_tick_gutsy()
	_tick_necro()
	_tick_vortex(delta)


func _gun_ready() -> bool:
	if fight_style == "melee" or _reload_left > 0.0:
		return false
	if _burst_len <= 0:
		return _attack_cd <= 0.0
	if _burst_left <= 0:
		_burst_left = maxi(1, int(round(float(_burst_len) * randf_range(0.8, 1.2))))
	var firing := _burst_left > int(round(float(_burst_len) * 0.25))
	if _frame_ticks > 0:
		_burst_left -= _frame_ticks
	return firing and _attack_cd <= 0.0


func _body_bite() -> void:
	if _body_damage <= 0 or _body_cd > 0.0 or not _player_valid():
		return
	if ai_state == ST_HOLD and not _show_attack:
		return
	if not _boxes_touch():
		return
	_body_cd = 10.0 / TPS
	if _player.has_method("take_hit") and not _player_dodges():
		_udar_fx("DAM_BITE")
		_player.take_hit(_body_damage, "DAM_BITE")


func _maybe_smash() -> void:
	if not _smash or not wall_check.is_colliding():
		return
	if ai_state != ST_CHASE and ai_state != ST_SEARCH:
		return
	if _player_valid() and absf(_player.global_position.y - global_position.y) > 80.0:
		return
	var body := wall_check.get_collider()
	if body is Node and (body as Node).has_method("take_hit"):
		var dmg := 5000 if hp <= int(round(float(max_hp) * 0.3)) else 1000
		(body as Node).take_hit(dmg, "DAM_BLUNT")


func _climb_step() -> bool:
	# WalkMotor.face() does not turn while isLaz. checkStairs sets storona to the rail.
	if not _climb_locked:
		_climb_locked = true
		_climb_face = facing
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
		_aim_probes()
		if not wall_check.is_colliding():
			_end_climb()
			velocity = Vector2(facing * move_speed, -160.0)
			return true
	else:
		if _stuck_on_rail():
			_end_climb()
			return false
		_hold_rail(rail)
	facing = _climb_face
	_aim_probes()
	_maybe_smash()
	var spd := move_speed if move_speed > 0.0 else SPEED
	if _species_id.begins_with("hellhound") and run_speed > 0.0:
		spd = run_speed * 0.6
	else:
		spd *= 0.6
	velocity.x = 0.0
	velocity.y = spd if _r_laz > 0 else -spd
	return true


## Unit.checkStairs: the tile at (X, Y+ny) must be empty of phis and have stair.
func _try_stairs(ny: float) -> Area2D:
	var at := global_position + Vector2(0.0, ny)
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
	floor_snap_length = 0.0
	set_collision_mask_value(PLATFORM_LAYER_BIT, false)
	_sync_climb_box()
	_snap_to_rail(rail, side)


func _end_climb() -> void:
	_climbing = false
	_climb_locked = false
	_on_rail = false
	_climb_stuck = 0
	floor_snap_length = _base_snap
	set_collision_mask_value(PLATFORM_LAYER_BIT, _throu_left <= 0.0)
	_sync_climb_box()


func _stuck_on_rail() -> bool:
	if absf(global_position.y - _climb_y) < 0.4:
		_climb_stuck += 1
	else:
		_climb_stuck = 0
	_climb_y = global_position.y
	return _climb_stuck > 20


## Unit.checkStairs: X = phX1 + scX/2 or phX2 - scX/2. run() skips X while isLaz, so this
## may sit inside a wall tile; the 28 px box keeps the Godot body inside the 40 px column.
func _snap_to_rail(rail: Area2D, side: String) -> void:
	var half := _climb_half_width()
	var center := rail.global_position.x
	var target := center - TILE_W * 0.5 + half
	if side != "left":
		target = center + TILE_W * 0.5 - half
	global_position.x = target


func _climb_half_width() -> float:
	return minf(body_size.x, CLIMB_BOX_W) * 0.5


## The body box is CLIMB_BOX_W wide while on a rail. Off it, it widens again only where
## the full box fits, stepping clear of a wall when it has to.
func _sync_climb_box() -> void:
	if _dead:
		_narrow = false
		return
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not shape_node.shape is RectangleShape2D:
		return
	var box := shape_node.shape as RectangleShape2D
	var want := minf(body_size.x, CLIMB_BOX_W) if _on_rail else body_size.x
	if is_equal_approx(box.size.x, want):
		return
	if want > box.size.x:
		var spare := (want - box.size.x) * 0.5
		var shift := NAN
		for dx in [0.0, spare, -spare]:
			if _box_fits(global_position + Vector2(dx, 0.0), Vector2(want, box.size.y)):
				shift = dx
				break
		if is_nan(shift):
			return
		global_position.x += shift
	var fresh := RectangleShape2D.new()
	fresh.size = Vector2(want, box.size.y)
	shape_node.shape = fresh
	_narrow = want < body_size.x


func _box_fits(at: Vector2, size: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var query := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size - Vector2(2.0, 2.0)
	query.shape = rect
	query.transform = Transform2D(0.0, at + Vector2(0.0, -size.y * 0.5))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return space.intersect_shape(query, 1).is_empty()


## The stair tile, not the 36 px grab above the rail top (standing on the lip).
func _ladder_tile_at(at: Vector2) -> Area2D:
	var space := get_world_2d().direct_space_state
	if space == null:
		return null
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 32
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for dx in [0.0, TILE_W * 0.35, -TILE_W * 0.35]:
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
			return maxf(TILE_W, ((child as CollisionShape2D).shape as RectangleShape2D).size.y - LADDER_GRAB_UP)
	return TILE_W


func _solid_at(at: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = at
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
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
	var on_floor := is_on_floor()
	if not _flying:
		_t_fall = 0 if on_floor else _t_fall + _frame_ticks
		var above := _track_player and _player_valid() and _player.global_position.y - global_position.y < -80.0
		if _t_fall > 6 or _swimming or above:
			_flying = true
			_t_landing = 0
			_hover = 0.0
		return
	if on_floor:
		_t_landing += _frame_ticks
		# UnitAlicorn aiState 4: a calm alicorn flies down and lands on touch.
		if _t_landing > 20 or (_species_id.begins_with("alicorn") and _is_calm()):
			_t_landing = 0
			_flying = false
			velocity.y = 0.0


func _fly_toward(point: Vector2, shoot: bool) -> bool:
	var to := point - global_position
	var spd := run_speed if run_speed > 0.0 and ai_spok >= MAX_SPOK else move_speed
	if _loose_fly or spd <= 0.0:
		spd = move_speed if move_speed > 0.0 else SPEED
	if to.length() > 28.0:
		velocity = to.limit_length(spd)
		if absf(to.x) > 4.0:
			facing = signf(to.x)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, spd)
	_aim_probes()
	if fight_style == "melee":
		if _frame_ticks > 0 and not _cannot_fight():
			_melee_swing()
			if _shok <= 0:
				_body_bite()
	elif shoot and _track_player and _player_valid() and _gun_ready():
		var in_reach := not _species_id.begins_with("bloat") or _target_distance() <= _attack_reach
		if in_reach and (_v_konus <= 0.0 or _look(_player) > 0.0):
			_shoot_at(_player.global_position)
	return velocity.length() > 8.0


## An F_PLAYER raider. Unit.findCel (Unit.as L4055-4062): with fraction F_PLAYER the
## player is never the target (L4058); only priorUnit, the last unit of another
## fraction that hit it, is. Otherwise Brain_Definition.stroll: patrol, or stand for ai="stay".
func _ally_act() -> bool:
	ai_spok = 0
	_track_player = false
	var foe := _prior_target()
	if foe != null and (not foe.is_in_group("enemies") or bool(foe.get("_dead")) or bool(foe.get("_friendly"))):
		_prior = null
		foe = null
	if foe != null and global_position.distance_to(foe.global_position) < 800.0 and _look(foe) > 0.0:
		ai_state = ST_HOLD
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * get_physics_process_delta_time())
		if absf(foe.global_position.x - global_position.x) > 2.0:
			facing = signf(foe.global_position.x - global_position.x)
		_heading = facing
		_aim_probes()
		if _gun_ready():
			_shoot_at(foe.global_position)
		return false
	if ai_state != ST_PATROL:
		ai_state = ST_IDLE
	if ai_state == ST_PATROL:
		return _patrol()
	velocity.x = 0.0
	return false


func _pet_act() -> bool:
	if not _player_valid():
		velocity = velocity.move_toward(Vector2.ZERO, move_speed)
		return false
	var foe := _nearest_foe()
	var dest := _follow_point()
	var shooting := false
	if foe != null:
		var at := foe.global_position
		var dist := global_position.distance_to(at)
		if dist > _pet_range:
			dest = at
		else:
			shooting = true
			facing = signf(at.x - global_position.x) if absf(at.x - global_position.x) > 2.0 else facing
			if _gun_ready():
				_shoot_at(at)
	var spd := run_speed if foe != null and run_speed > 0.0 else move_speed
	if spd <= 0.0:
		spd = SPEED
	var to := dest - global_position
	if to.length() > 36.0 and not shooting:
		velocity = to.limit_length(spd)
		if absf(to.x) > 4.0:
			facing = signf(to.x)
	elif to.length() > 36.0:
		velocity = to.limit_length(move_speed if move_speed > 0.0 else SPEED)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, spd)
	_aim_probes()
	return velocity.length() > 8.0


func _follow_point() -> Vector2:
	var face := 1.0
	if _player_valid() and "facing" in _player:
		face = float(_player.facing)
	return _player.global_position + Vector2(face * -120.0, -80.0)


func _nearest_foe() -> Node2D:
	var best: Node2D = null
	var best_d := 800.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not is_instance_valid(node) or not node is Node2D:
			continue
		if int(node.get("hp")) <= 0:
			continue
		var d := global_position.distance_to((node as Node2D).global_position)
		if d < best_d:
			best = node as Node2D
			best_d = d
	return best


func _calm_cast() -> void:
	if _cast != "invis" or not _is_calm() or _invis or _cast_ready > 0.0:
		return
	if randf() < 0.5:
		_do_cast()


func _do_cast() -> void:
	_cast_ready = _cast_gap * randf_range(0.8, 1.2)
	if _cast == "invis":
		_invis = true
		_cast_left = 300.0 / TPS
	elif _cast == "teleport" and _player_valid():
		var face := 1.0
		if "facing" in _player:
			face = float(_player.facing)
		var behind := randf() < 0.7
		var dist := randf_range(200.0, 500.0) if randf() < 0.5 else randf_range(200.0, 1000.0)
		var ny := 0.0 if dist <= 500.0 else randf_range(-80.0, 80.0)
		var side := -face if behind else face
		global_position = _player.global_position + Vector2(side * dist, ny)
	elif _cast == "telepathy" and _player_valid():
		_launch(_player.global_position, _weapon_row("alipsy"), false, false, false)


func _tick_side(delta: float) -> void:
	var grenades := _side_ammo > 0 and _side_id != ""
	if not grenades and not _ranger_side:
		return
	# SideWeaponAttack: the timer runs only while fighting. A due shot needs a target
	# in sight; without one only a blind weapon (ranger gas) fires.
	if not _is_attacking() or _cannot_fight():
		return
	_side_wait -= delta
	if _side_wait > 0.0:
		return
	_side_wait = float(randi_range(50, 200)) / TPS
	var seen := _track_player and _player_valid()
	if grenades:
		if seen and randf() < _side_chance:
			_launch(_player.global_position, _weapon_row(_side_id), _friendly, false, false)
			_side_ammo -= 1
		return
	if seen:
		var rocket := _weapon_row("robomlau")
		rocket["damage_expl"] = float(rocket.get("damage_expl", 150.0)) * 0.8
		_launch(_player.global_position, rocket, false, false, false)
	else:
		_launch(_goal, _weapon_row("robogas"), false, false, false)


func _tick_gutsy() -> void:
	if not _gutsy_fire or _is_calm() or not _player_valid():
		return
	var close := _target_distance() < 300.0
	if close or _gutsy_burst > 0:
		if _gutsy_burst <= 0:
			_gutsy_burst = maxi(1, int(round(100.0 * randf_range(0.8, 1.2))))
		var firing := _gutsy_burst > 25
		if _frame_ticks > 0:
			_gutsy_burst -= _frame_ticks
		if firing and _gutsy_cd <= 0.0:
			var fire := _weapon_row("robofire")
			fire["damage"] = float(fire.get("damage", 2.2)) * _gutsy_scale
			_launch(_player.global_position, fire, false, false, false)
			_gutsy_cd = 1.0 / TPS
		return
	if _frame_ticks <= 0 or _attack_cd > 0.0:
		return
	for _i in _frame_ticks:
		if randf() < 0.1:
			_shoot_at(_player.global_position)
			return


func _tick_necro() -> void:
	if not _necro_shot or _is_calm() or not _player_valid() or _necro_cd > 0.0:
		return
	if absf(_player.global_position.y - global_position.y) > 80.0:
		return
	if absf(_player.global_position.x - global_position.x) > 400.0:
		return
	if _frame_ticks <= 0:
		return
	for _i in _frame_ticks:
		if randf() < 0.1:
			_launch(_player.global_position, _weapon_row("zombinecro"), false, false, false)
			_necro_cd = 60.0 / TPS
			return


func _tick_vortex(delta: float) -> void:
	if _vortex_left <= 0 or _is_calm():
		return
	_vortex_wait -= delta
	if _vortex_wait > 0.0:
		return
	_spawn_vortex()
	_vortex_left -= 1
	_vortex_wait = 500.0 / TPS


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
	node.global_position = global_position + Vector2(randf_range(-24.0, 24.0), -body_size.y * 0.4)


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
	if _super == "jump" and _player_valid():
		var dest := _player.global_position - global_position
		var dist := dest.length()
		if dist > 1.0:
			velocity = dest / dist * _super_v
			var ticks := dist / maxf(_super_v / TPS, 1.0)
			_super_need = minf(20.0, ticks) / TPS
		_jump_free = true
		velocity.y = velocity.y
	elif _super == "spit" and _spit_id != "" and _player_valid():
		_launch(_player.global_position, _weapon_row(_spit_id), false, false, false)
	elif _super == "rad":
		_rad_power = 20.0
		_rad_left = _super_need
		_heal_zombies(1200.0, 30.0)
	elif _super == "quake":
		_quake_step = 0.0
	elif _super == "tele" and _tele != null:
		_super_tick = 0
		if _tele_unit != null and is_instance_valid(_tele_unit) and int(_tele_unit.get("levit")) != 1:
			_tele.grab(_tele_unit)


func _run_super(delta: float) -> void:
	if _super == "rad" and _player_valid():
		var dist := global_position.distance_to(_player.global_position)
		if dist < 1200.0:
			var koef := (1200.0 - dist) / 1200.0
			GameState.rad += _rad_power * koef * float(_frame_ticks)
		if _super_need > 0.0:
			_rad_power = maxf(1.0, _rad_power - (19.0 / _super_need) * delta)
	elif _super == "quake":
		_quake_step -= delta
		if _quake_step <= 0.0:
			_quake_step = 4.0 / TPS
			if _player_valid() and global_position.distance_to(_player.global_position) < 420.0:
				_player.global_position.y -= 12.0


func _end_super() -> void:
	_jump_free = false
	if _super == "jump":
		_super_need = 20.0 / TPS
	if _super == "rad":
		_rad_power = 1.0
	if _super == "tele" and _tele != null:
		_tele.release()
		_tele_unit = null


func _heal_zombies(radius: float, amount: float) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
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
	if _player_valid() and global_position.distance_to(_player.global_position) <= radius:
		if _player.has_method("take_hit"):
			_player.take_hit(damage, tip)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not node is Node2D or not is_instance_valid(node):
			continue
		if global_position.distance_to((node as Node2D).global_position) > radius:
			continue
		if (node as Node).has_method("take_hit"):
			(node as Node).take_hit(damage, tip)


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
		UnitFx.emit(get_tree(), "unlock", muzzle.global_position, {"rx": 20, "ry": 20})
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
	_pole_release()
	if _tele != null:
		_tele.release()
		_tele_unit = null
	if _brain != null and _brain.on_die():
		return
	if _brain != null:
		_brain.died()
	_last_rites = true
	if not _friendly and not _revives:
		_drop_loot()
		if _species_id.begins_with("bloat"):
			_bloat_split(global_position)
		# Unit.incStat: the PipBuck Enemies page kill count. UnitBloat skips tr 7-9 (king splits).
		if _species_id != "" and not _species_id in ["bloat7", "bloat8", "bloat9"]:
			Travel.set_trigger("frag_" + _species_id, int(Travel.triggers.get("frag_" + _species_id, 0)) + 1)
	if _brain != null:
		_brain.drop_loot()
	if _drop_id != "":
		_launch(_feet(self), _weapon_row(_drop_id), false, false, false)
		_drop_id = ""
	_last_rites = false
	if _pink_death:
		_hurt_radius(150.0, maxi(1, int(round(float(_comb) * 0.4))), "DAM_PINKCLOUD")
		_pink_death = false
	var host := get_tree().get_first_node_in_group("land_props")
	if host and host.has_method("run_actions"):
		host.run_actions(die_actions)
	if _friendly and _pet_revive:
		_downed = true
		hp = 0
		_revive_left = 30.0
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
		_revive_left = 300.0 / TPS
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
	_windup_left = 0.0
	_cut = 0.0
	_poison = 0.0
	_burn_left = 0.0
	_acid_left = 0.0
	_pink_left = 0.0
	remove_from_group("enemies")
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
		if int(get_meta("hero", 0)) > 0 and not _is_machine() and randf() < 0.75:
			_spawn_drop(host, "essence", 1, center)
		var tre := _drop_tre()
		if tre > 0.0 and points > 0 and randf() < tre * float(points) / 4000.0:
			_spawn_drop(host, "gem%d" % (randi() % 3 + 1), 1, center)
		if _raider_type and _drop_arm and not _weapon.is_empty():
			var wid := str(_weapon.get("id", ""))
			if wid != "" and not wid.begins_with("robo"):
				# LootGen.lootId(..., 0): Item kol 0 gives a weapon sost 0.05-0.2.
				_spawn_drop(host, wid, 1, muzzle.global_position, randf_range(0.05, 0.2))
	if _raider_type and _thrown and not _weapon.is_empty():
		for _i in DEATH_THROWS:
			var feet := _feet(self) + Vector2(randf_range(-DROP_SCATTER, DROP_SCATTER), 0.0)
			_launch(feet, _weapon, false, false, false)


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
const UNIT_LOOT := {
	"scorp": [[1, "compa", "chitin_comp"], [0.25, "compp", "gland"], [0.1, "food", "meat"]],
	"slime": [[0.75, "item", "acidslime"]],
	"pinkslime": [[0.75, "item", "pinkslime"]],
	"raider": [[0.25, "eda", ""], [0.25, "a", ""], [0.12, "e", ""]],
	"alicorn": [[1, "compp", "mdust"], [0.1, "pot", "potMP"], [0.3, "med", "potm1"], [0.2, "med", "potm2", -1, "or"]],
	"ranger": [[1, "item", "frag", -3], [0.5, "item", "scrap", -3], [1, "compa", "power_comp"], [0.25, "a", ""]],
	"encl": [[0.5, "item", "frag", -3], [0.3, "a", "batt"], [0.5, "a", "crystal", -1, "or"], [0.3, "compa", "power_comp"]],
	"hellhound1": [[1, "compw", "kogt", -1, "hero"]],
	"zombie": [[0.35, "compp", "ghoulblood"], [0.15, "compp", "radslime"], [0.5, "compa", "skin_comp"]],
	"zombie4": [[0.8, "compp", "ghoulblood"], [1, "compp", "radslime"]],
	"zombie5": [[1, "compp", "ghoulblood"], [0.3, "compp", "metal_comp"]],
	"zombie6": [[1, "compp", "ghoulblood"], [0.3, "compa", "battle_comp"], [0.8, "compp", "acidslime"]],
	"zombie7": [[0.6, "compp", "ghoulblood"], [0.2, "compp", "pinkslime"], [0.6, "compm", "darkfrag", -1, "hero"]],
	"zombie8": [[0.6, "compp", "ghoulblood"], [1, "compp", "pinkslime"], [0.8, "compm", "darkfrag", -1, "hero"]],
	"zombie9": [[0.6, "compp", "ghoulblood"], [1, "compp", "whorn"], [1, "compm", "darkfrag", -1, "hero"]],
	"bloodwing": [[0.2, "compp", "wingmembrane"], [0.16, "compp", "vampfang"], [0.25, "food", "meat"]],
	"bloodwing2": [[0.3, "compp", "wingmembrane"], [0.2, "compp", "vampfang"], [0.4, "compp", "pinkslime"]],
	"bloat0": [[0.2, "compp", "bloatwing"], [0.1, "compp", "bloateye"]],
	"bloat1": [[0.2, "compp", "bloatwing"], [0.1, "compp", "bloateye"], [0.2, "compp", "acidslime"]],
	"bloat2": [[0.2, "compp", "bloatwing"], [0.1, "compp", "bloateye"], [0.1, "compp", "gland"]],
	"bloat3": [[0.3, "compp", "bloatwing"], [0.2, "compp", "bloateye"], [0.1, "compp", "molefat"]],
	"bloat4": [[0.4, "compp", "bloatwing"], [0.3, "compp", "bloateye"]],
	"rat": [[0.35, "compp", "ratliver"], [0.25, "compp", "rattail"], [0.1, "food", "meat"]],
	"molerat": [[0.5, "compp", "ratliver"], [1, "compp", "molefat"], [0.25, "food", "meat"]],
	"fish1": [[0.5, "compp", "fishfat"]],
	"fish2": [[1, "compp", "fishfat"]],
	"ant1": [[0.15, "compa", "chitin_comp"], [0.1, "food", "meat"]],
	"ant2": [[0.3, "compa", "chitin_comp"], [0.1, "food", "meat"]],
	"ant3": [[0.2, "compa", "chitin_comp"], [1, "compp", "firegland"], [0.1, "food", "meat"]],
	"necros": [[0.5, "item", "dsoul"]],
	"ebloat": [[1, "compp", "essence"]],
	"turret": [[0.5, "item", "scrap"], [0.35, "compw", "frag"], [0.2, "a", "batt"], [0.2, "a", "energ", -1, "or"]],
	"turret1": [[0.5, "item", "scrap"], [0.5, "item", "scrap"], [0.85, "compw", "frag"], [0.52, "compa", "magus_comp"], [0.4, "a", "batt"], [0.8, "a", "energ", -1, "or"]],
	"robobrain": [[0.25, "item", "scrap"], [0.15, "compw", "frag"], [0.5, "compm", ""], [0.5, "a", "batt"], [0.4, "compa", "metal_comp"], [1, "compm", "impgen", -1, "hero"]],
	"protect": [[0.3, "item", "scrap"], [0.25, "compw", "frag"], [0.6, "compm", ""], [0.9, "a", "batt"], [0.4, "compa", "metal_comp"], [1, "compm", "uscan", -1, "hero"]],
	"gutsy": [[0.45, "item", "scrap"], [0.5, "compw", "frag"], [0.7, "compm", ""], [0.85, "compa", "battle_comp"], [0.4, "a", "fuel"], [0.75, "a", "energ", -1, "or"], [1, "compm", "tlaser", -1, "hero"]],
	"eqd": [[0.45, "item", "scrap"], [0.5, "compw", "frag"], [0.8, "compm", ""], [0.85, "compa", "magus_comp"], [1, "a", "energ"], [0.5, "item", "data"], [1, "compm", "pcrystal", -1, "hero"]],
	"sentinel": [[0.85, "item", "scrap"], [0.5, "compw", "frag"], [1, "compm", ""], [0.4, "a", "p5"], [1, "a", "crystal", -1, "or"], [0.85, "a", "rocket"], [0.5, "compw", ""], [1, "compm", "motiv"]],
	"vortex": [[0.2, "item", "scrap"]],
	"spritebot": [[0.2, "item", "scrap"]],
	"roller": [[0.2, "item", "scrap"]],
}


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
			count = randi_range(1, -count)
		last = gen._new(float(row[0]), str(row[1]), str(row[2]), count)
	return gen._drops


func _rise() -> void:
	_downed = false
	visible = true
	set_collision_layer_value(3, true)
	velocity = Vector2.ZERO
	if _friendly:
		hp = maxi(1, int(round(float(max_hp) * 0.5)))
		if _player_valid():
			global_position = _follow_point()
	else:
		hp = max_hp
	_play_anim("idle")


func _apply_role(id: String, row: Dictionary) -> void:
	_species_id = id
	_comb = int(row.get("comb", melee_damage))
	_krep = int(row.get("krep", 0))
	_flying = bool(row.get("fly", false))
	# UnitProtect is a UnitAIRobot walker; its jump() is a jet with jump_n ticks (jump_m 90, hero 500).
	_jet = id.begins_with("protect")
	if _jet:
		_flying = false
		_jet_max = 500 if int(get_meta("hero", 0)) == 1 else 90
		_jet_n = 100
	var pet_row := bool(row.get("pet", false)) or str(row.get("fraction", "")) == "player"
	_friendly = pet_row or bool(get_meta("player_side", false))
	_ground_ally = _friendly and not pet_row and (id == "raider" or _raider_kin(id)) and not _flying
	# UnitRaider flyer (Enclave, mercs): a walker that takes off and lands (isFly), not a hoverer.
	# UnitAlicorn has the same isFly / t_fall / t_landing rules.
	_flyer = _flying and (id.begins_with("encl") or id.begins_with("merc") or id.begins_with("alicorn"))
	if _flyer:
		_flying = false
	_cast = str(row.get("cast", ""))
	_revives = bool(row.get("revives", false))
	_drop_id = str(row.get("drop_weapon", ""))
	_burst_len = int(row.get("och", 0))
	_fire_down = id.begins_with("bossencl")
	_vortex_left = 8 if _fire_down else 0
	_encl_bonus = id.begins_with("encl")
	if _cast == "teleport":
		_cast_gap = (250.0 + 90.0) / TPS
	elif _cast != "":
		_cast_gap = (500.0 + 90.0) / TPS
	if _cast != "":
		_cast_ready = 90.0 / TPS
	if id == "rat":
		_hop_vy = 8.0 * TPS
	elif id == "molerat":
		_hop_vy = 14.0 * TPS
	if id.begins_with("hellhound"):
		_climb = true
		_can_crawl = true
		_smash = true
		_brake_ledge = true
		_air_frac = 1.0
		_wall_give = 0.5
		_turn_at_wall = false
		_backpedal = false
		_close_chance = 0.0
		_hop_gaps = true
		_jump_reach = true
	if id.begins_with("gutsy"):
		_gutsy_fire = true
		_chase_shot = false
		_gutsy_scale = 2.0 if id == "gutsy1" else 1.0
	if id.begins_with("ranger"):
		_ranger_side = true
		_shoot_climb = true
	var grenader := int(row.get("grenader", 0))
	if grenader > 0:
		_side_id = "mercgr"
		_side_ammo = grenader
		_side_chance = 0.5
		_side_wait = randf_range(50.0, 200.0) / TPS
	elif _ranger_side:
		_side_wait = randf_range(50.0, 200.0) / TPS
	if _ground_ally:
		fraction = 100
	elif _friendly:
		_pet_range = 400.0 if id == "owl" else 200.0
		_pet_revive = id == "phoenix"
		_hover = 80.0
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
		rolled = _roll_pool(row.get("pool", []))
		if rolled == "":
			rolled = str(row.get("weapon", ""))
	if rolled != "":
		_arm(rolled)
	if id == "bossencl3" and not _weapon.is_empty():
		_weapon["speed"] = 12.0
		_weapon["rapid"] = 30.0
		_weapon["damage_expl"] = float(_weapon.get("damage_expl", 250.0)) * 0.6
		_strike_cd = 30.0 / TPS
		_bullet_speed = 12.0 * TPS
		_bullet_damage = maxi(1, int(round(float(_weapon["damage_expl"]))))
	if id.begins_with("ant"):
		_climb = true
		_hop_gaps = false
		_jump_reach = false
		_jump_boost = 5.0
		_reaim_every = 10
		_reaim_chance = 0.7
		_reaim_dist = 80.0
		if id == "ant3":
			_body_damage = _comb if _comb > 0 else 7
			# Fire ants breathe only while holding. closeHoldChance is 0.07.
			_gunner_hold = false
			_close_chance = 0.07
			_band_min = 0.0
			_band_max = 120.0
			_band_up = 80.0
			_band_down = 80.0
			_close_tmin = 40.0
			_close_tmax = 90.0
			_close_search = true
			_close_release = false
			_shot_chance = 1.0
			_blind_chance = 0.0
			_need_sight = true
			_chase_shot = false
			_backpedal = false
			_ram_while_chase = true
			_ram_x = 100.0
			_ram_y = 120.0
			_bite_hop = HOP_POWER
		else:
			fight_style = "melee"
			_contact_bite = true
			_chase_shot = false
			melee_damage = _comb if _comb > 0 else melee_damage
			_bite_hop = HOP_POWER
	if id == "tarakan":
		fight_style = "melee"
		_contact_bite = true
		_chase_shot = false
		melee_damage = _comb if _comb > 0 else 4
		_hop_gaps = false
		_jump_reach = false
		_bite_hop = HOP_POWER
		_reaim_every = 10
		_reaim_chance = 0.7
		_reaim_dist = 80.0
	if id == "necros":
		_loose_fly = true
		_flying = true
		fight_style = "melee"
		_contact_bite = true
		_chase_shot = false
		melee_damage = _comb if _comb > 0 else 80
		_move_clip = "stay"
	if id == "rat" or id == "molerat":
		_bite_hop = HOP_POWER
		_hop_gaps = true
		_jump_reach = true
		_reaim_every = 10
		_reaim_chance = 0.7
		_reaim_dist = 80.0
	if not _raider_kin(id) and _reaim_chance == DURAK_REAIM:
		_reaim_chance = SMART_REAIM
	if _flying:
		_runs_alert = false
		_jump_reach = false
		_backpedal = false
	if fixed_post or fight_style == "turret":
		_runs_alert = false
		_jump_reach = false
		_hop_gaps = false
	if fight_style == "melee" and not _melee_while_chase and not id.begins_with("scorp"):
		_ram_while_chase = true
		if _ram_x <= 0.0 and not _contact_bite:
			_ram_x = _swing_x
			_ram_y = maxf(_swing_above, _swing_below)
	_apply_zombie(id, int(row.get("ss", 0)))
	_setup_tele(id, int(row.get("ss", 0)))
	if _flying and _sheet_clips.has("fly"):
		_move_clip = "fly"
	if _jet or (_flyer and _species_id.begins_with("alicorn") and _sheet_clips.has("walk")):
		_move_clip = "walk"


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
		_t_tele = -int(randf() * 100.0 + 50.0)
	if _t_tele >= _tele_throw_t + 10:
		_t_tele = -int(randf() * 100.0 + 50.0)
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
	if cel != null and randf() < 0.25:
		var lv := GameState.tele_enemy() if _tele_tr == 2 else int(GameState.tele_enemy() * 0.5)
		_tele.grab(cel, lv)
		return cel
	var box: Node2D = _tele.find_box(_opt_dist_tele)
	if box != null:
		_tele.grab(box)
	return box


func _alicorn_cel() -> Node2D:
	return _player if _track_player and _player_valid() else null


## Unit.setCel: celX = X + width / 4 * storona, celY = the target's middle.
func _cel_point() -> Vector2:
	if not _player_valid():
		return _goal
	var side := float(_player.get("facing")) if "facing" in _player else 1.0
	return _body_center(_player) + Vector2(_body_size(_player).x * 0.25 * side, 0.0)


## superSila2: the body is held at (superX, superY - halfHeight). 30 ticks before
## the end superX / superY become the ghoul's own feet. Leaving aiState 7 releases.
func _ghoul_tele() -> void:
	if _track_player and _player_valid():
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
	_chase_shot = false
	_melee_while_chase = false
	_ram_while_chase = true
	_close_chance = 0.0
	_backpedal = false
	_ram_x = 200.0
	_ram_y = 80.0
	_reaim_chance = SMART_REAIM
	_hop_gaps = true
	_jump_reach = true
	_contact_bite = true
	if _comb > 0:
		melee_damage = _comb
	if _sheet_clips.has("dig") and randf() < 0.75:
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
		if not entry.has("ch") or randf() < float(entry["ch"]):
			return wid
	return ""


func _arm(wid: String) -> void:
	var w := _weapon_row(wid)
	if w.is_empty():
		return
	var kind := str(w.get("kind", ""))
	var delivery := str(w.get("delivery", ""))
	var thrown := kind == "explosives" or delivery == "grenade"
	var rapid := maxf(float(w.get("rapid", 15.0)), 1.0)
	if kind == "melee" or delivery == "melee":
		fight_style = "melee"
		_thrown = false
		_chase_shot = false
		_blast = 0.0
		var wd := float(w.get("damage", _comb))
		if _krep == 0:
			melee_damage = maxi(1, int(round(wd)))
		else:
			melee_damage = maxi(1, int(round(wd * 0.5 + float(_comb))))
		_bullet_type = str(w.get("damage_type", _bullet_type))
		_strike_cd = rapid / TPS
		_swing_x = SWING_REACH
		var reach_y := rapid * 8.0
		_swing_above = reach_y
		_swing_below = reach_y
		_weapon = w
		_burst_len = 0
		_backpedal = false
		# UnitRaider.arm: a gripped melee weapon is a body ram. A levitated one swings.
		if _krep != 0:
			_contact_bite = true
			_chase_mul = CHARGE_SPEED
			_runs_seen = true
			_close_chance = 0.0
			_melee_while_chase = false
			_ram_while_chase = true
			_ram_x = 0.0
			_ram_y = 0.0
			if _comb > 0:
				melee_damage = maxi(1, int(round(float(wd) * 0.5 + float(_comb))))
		else:
			_contact_bite = false
			_chase_mul = 1.0
			_melee_while_chase = true
			_ram_while_chase = false
			_close_chance = 1.0
			_band_min = SWING_MIN
			_band_max = SWING_MAX
			_band_up = SWING_HEIGHT
			_band_down = SWING_HEIGHT
			_close_release = true
			_close_search = false
			_swing_chance = SWING_CHANCE
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
	fight_style = "gunner"
	_strike_cd = rapid / TPS
	var blast := float(w.get("radius", 0.0))
	var dam := direct
	if thrown or (expl > 0.0 and blast > 0.0):
		dam = expl if expl > 0.0 else direct
		_blast = blast
		_fuse = maxf(float(w.get("fuse", 75.0)) / TPS, 0.05)
	else:
		_blast = 0.0
	_bullet_damage = maxi(1, int(round(dam)))
	_bullet_type = str(w.get("damage_type", _bullet_type))
	_bullet_speed = maxf(float(w.get("speed", 12.0)) * TPS, 40.0)
	# Weapon holder: a magazine of mag rounds, rashod per shot, reload ticks to refill.
	_mag_cap = 0 if thrown else int(w.get("mag", 0))
	_mag = _mag_cap
	_rashod = maxi(1, int(w.get("ammo_per_shot", 1)))
	_reload_time = float(w.get("reload", 0.0)) / TPS
	_reload_left = 0.0
	_pellets = maxi(1, int(w.get("pellets", 1)))
	_deviation = float(w.get("spread", 0.0))
	_dop_effect = str(w.get("dop_effect", ""))
	_dop_damage = float(w.get("dop_damage", 0.0))
	_dop_chance = float(w.get("dop_chance", 1.0))
	if thrown:
		_burst_len = 0
		_shot_chance = THROW_CHANCE
		_blind_chance = 0.0
		_need_sight = true
	else:
		_shot_chance = SINGLE_SHOT
		_blind_chance = BLIND_SHOT
		_need_sight = false
		if _burst_len <= 0 and int(w.get("mag", 0)) > 10:
			_burst_len = int(round(float(w.get("mag", 0)) * 0.5))
	_chase_shot = true
	_backpedal = _krep != 0 and not _flying
	_melee_while_chase = false
	_ram_while_chase = false
	_close_chance = 0.0
	_chase_mul = 1.0


func _weapon_row(wid: String) -> Dictionary:
	_ensure_catalog()
	var found: Variant = _weapon_catalog.get(wid, {})
	if found is Dictionary and not (found as Dictionary).is_empty():
		return (found as Dictionary).duplicate(true)
	return {}


func _launch(target: Vector2, w: Dictionary, friendly: bool, use_main_cd: bool, aim_down: bool) -> void:
	if bullet_scene == null or (_cannot_fight() and not _last_rites):
		return
	var main := use_main_cd
	if main and _mag_cap > 0:
		if _reload_left > 0.0:
			return
		if _mag < _rashod:
			_reload_left = _reload_time
			return
		_mag -= _rashod
	if use_main_cd:
		_attack_cd = _strike_cd
	var start := _muzzle_clear()
	var shots := _pellets if main else maxi(1, int(w.get("pellets", 1)))
	var dev := _deviation if main else float(w.get("spread", 0.0))
	var mazil := _mazil if main else 0.0
	for _p in shots:
		_launch_one(start, target, w, friendly, aim_down, dev, mazil)


## Weapon.shoot from the barrel. A barrel inside a wall fires from the wall face instead.
func _muzzle_clear() -> Vector2:
	var at := _held_weapon.muzzle() if _held_weapon != null and _held_weapon.shown() else muzzle.global_position
	var from := global_position + Vector2(0.0, -_body_size(self).y * 0.5)
	var space := get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(from, at, 1)
	ray.exclude = [get_rid()]
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return at
	var dir := (at - from).normalized()
	return Vector2(hit["position"]) - dir * 2.0


func _launch_one(start: Vector2, target: Vector2, w: Dictionary, friendly: bool, aim_down: bool, dev: float, mazil: float) -> void:
	var bullet := bullet_scene.instantiate() as Area2D
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
		px_speed = maxf(float(w.get("speed", 12.0)) * TPS, 40.0)
		blast = float(w.get("radius", 0.0))
		var expl := float(w.get("damage_expl", 0.0))
		if thrown or (expl > 0.0 and blast > 0.0):
			dam = int(round(expl if expl > 0.0 else float(dam)))
		fuse = maxf(float(w.get("fuse", 75.0)) / TPS, 0.05)
		dop = str(w.get("dop_effect", ""))
		dop_d = float(w.get("dop_damage", 0.0))
		dop_c = float(w.get("dop_chance", 1.0))
	var aim := target - bullet.global_position
	var direction := aim.normalized() if aim.length_squared() > 1.0 else Vector2(facing, 0.0)
	if aim_down:
		direction = Vector2(0.2 * facing, 1.0).normalized()
	# Weapon.shoot: (rand - 0.5) * (deviation / skill + mazil) degrees.
	var spread := dev / (_weapon_skill + 0.01) + mazil
	if spread > 0.0:
		direction = direction.rotated(deg_to_rad((randf() - 0.5) * spread))
	if _blind_t > 0.0 and randf() < 0.6:
		direction = Vector2.from_angle(randf() * TAU)
	bullet.from_player = friendly
	if not friendly and fraction > 0:
		bullet.fraction = fraction
	bullet.speed = px_speed
	bullet.damage = maxi(1, dam)
	bullet.damage_type = tip
	bullet.block_damage = _Block.of(str(w.get("id", "")))
	bullet.dop_effect = dop
	bullet.dop_damage = dop_d
	bullet.dop_chance = dop_c
	if str(w.get("id", "")) == "bomb":
		bullet.global_position = global_position
		bullet.use_velocity = true
		bullet.velocity = Vector2(0.0, 40.0)
		bullet.direction = Vector2.DOWN
		bullet.fall_accel = GRAVITY
		bullet.lifetime = fuse
		bullet.blast_radius = blast
		bullet.explode_on_timeout = blast > 0.0
	elif thrown:
		bullet.use_velocity = true
		bullet.fall_accel = GRAVITY
		var arc := direction
		arc.y -= 0.65
		if arc.length_squared() < 0.01:
			arc = Vector2(facing, -0.6)
		bullet.velocity = arc.normalized() * px_speed
		bullet.direction = bullet.velocity.normalized()
		bullet.lifetime = fuse
		bullet.blast_radius = blast
		bullet.explode_on_timeout = blast > 0.0
	else:
		bullet.direction = direction
		if blast > 0.0:
			bullet.blast_radius = blast
	var host := get_tree().current_scene
	if host == null:
		bullet.queue_free()
		return
	bullet.weapon_id = str(w.get("id", ""))
	bullet.set_meta("owner_unit", self)
	host.add_child(bullet)


func _configure_vortex() -> void:
	_species_id = "vortex"
	_flying = true
	_friendly = false
	fight_style = "melee"
	_contact_bite = true
	_chase_shot = false
	melee_damage = 12
	_bullet_type = "DAM_PIERCE"
	max_hp = 15
	points = 30
	body_size = Vector2(30.0, 30.0)
	move_speed = 4.0 * TPS
	run_speed = 12.0 * TPS
	_attack_reach = 80.0
	_strike_cd = 0.4
	_sheet_native = false
	_can_lift = false


func _float_hit(amount: int, _player_hit: bool, separate: bool = false) -> void:
	if amount <= 0:
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("float_number"):
		hud.float_number(global_position, str(amount), "hit", self, separate)
