extends CharacterBody2D

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
const SPEED := 210.0
# walkSpeed * runSpeedMult. Trauma legs scale this through sprint_speed_mult.
const RUN_SPEED := 420.0
# littlepip accel 3.5 px/tick^2. !stay uses 0.1 * accel.
const ACCEL := 3150.0
const AIR_ACCEL := 315.0
# UnitPlayer.brake 2 px/tick^2. Sitting brakes at 0.4x, airborne at 0.1x.
const BRAKE := 1800.0
# Holding keyRun, control() accelerates only once t_run > 3.
const RUN_DELAY := 3.0 / 30.0
# Air jump side kick may not leave |dx| above 25 px/tick.
const DJUMP_CAP := 750.0
# Diagonal (stair) maxSpeed is walkSpeed * 0.75 and isRun has no effect there.
const STAIR_SCALE := 0.75
# Unit.porog while walking on the ground. porog_jump is 10 only for (isRun || keyBeUp) with jumpNumb 0.
const POROG := 20.0
const POROG_JUMP := 10.0
# Unit.run plays sndFall above 5 px/tick and makes noise above 9 and 16 px/tick.
const FALL_SOUND := 150.0
const FALL_NOISE_HALF := 270.0
const FALL_NOISE_FULL := 480.0
const NOISE_RUN := 200.0
# Bullet.otbros for hits that carry no weapon knock. 5 is the usual char_knock.
const KNOCK_DEFAULT := 5.0
# UnitPlayer.sitSpeed is walkSpeed * 0.5 while sitting on the ground.
const SIT_SCALE := 0.5
const CLIMB_SPEED := 157.5
# keySit on a ladder sets velocity.Y = lazSpeed * 1.5.
const CLIMB_DOWN_MULT := 1.5
const TILE_HALF := 20.0
const JUMP_VELOCITY := -360.0
const GRAVITY := 900.0
const LEVITATE_SPEED := 92.0
const MAX_FALL := 600.0
const JUMP_SUSTAIN := 8.0 / 30.0
const AIR_JUMP_HOLD := 10.0 / 30.0
const PLATFORM_LAYER_BIT := 7
const DROP_TIME := 0.28
# Pers.teleDist is 600*600. Perk telemaster raises the squared distance to 640000 (800px).
const TELE_RADIUS := 600.0
const TELE_RADIUS_MASTER := 800.0
# actTele snaps to the nearest object within 50px of the cursor (mindist 2500).
const TELE_SNAP := 50.0
const TELE_TICK := 1.0 / 30.0
# GameContainer.maxdelta. Box.run tests tiles at least this often so a carry cannot tunnel.
const CARRY_STEP := 9.0
# GameContainer.actionDist is 40000, a squared 200px. Walk cap is 3 px/tick.
const ACTION_REACH := 200.0
const ACTION_TICK := 1.0 / 30.0
const ACTION_CREEP := 90.0
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
const HOOF_DAMAGE := 10.0
const HOOF_DESTROY := 4.0
const KICK_DESTROY := 30.0
const HOOF_RAPID := 13.0 / 30.0
const HOOF_WINDUP := 8.0 / 30.0
const HOOF_NEAR := 20.0
const HOOF_FAR := 60.0
const KICK_FAR := 70.0
const HOOF_TYPE := "DAM_BLUNT"
# Pers.meleeR / meleeS / meleeRun. The grip may travel at most meleeR from the
# shoulder anchor. meleeRun is px per 30 Hz tick. WClub steps the blade every 10px.
const MELEE_RANGE := 100.0
const MELEE_SIDE := 40.0
const MELEE_RUN := 10.0
const MELEE_SAMPLE := 10.0
const MELEE_THRUST := 100.0
# UnitPon.footstepVol 0.2. Sound.stepVol scales walk and ladder steps. sndFall does not.
const FOOT_VOL := 0.2
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
const _Flags := preload("res://scripts/map/room_flags.gd")
const _Sats := preload("res://scripts/sats.gd")
const _Wheel := preload("res://scripts/weapon_wheel.gd")
const _QuickKeys := preload("res://scripts/quick_keys.gd")
## UnitPlayer dash 22 and dash_dy -2 px a tick, dash_maxt 30 ticks.
const DASH_SPEED := 22.0 * 30.0
const DASH_DY := -2.0 * 30.0
const DASH_MAXT := 30.0
const _LandRegistry := preload("res://scripts/map/land_registry.gd")

var _water := _Water.new()
var sats: Node

@export var bullet_scene: PackedScene

@onready var puppet: Node2D = $Puppet
@onready var muzzle: Marker2D = $Muzzle
@onready var hurtbox: Area2D = $Hurtbox
@onready var ladder_detector: Area2D = $LadderDetector
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _hurt_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var _ladder_shape: CollisionShape2D = $LadderDetector/CollisionShape2D

var facing: float = 1.0
var aim_dir: Vector2 = Vector2.RIGHT
var _fire_cd: float = 0.0
var _voice_serial: int = 0
var _spell_cd: float = 0.0
var _cast_glow: float = 0.0
var _spellbook: Dictionary = {}
var _spell_culd: Dictionary = {}
var _crystal_tried: bool = false
var _invuln: float = 0.0
## ggControl false (UnitPlayer.controlOff): no keys, invulner, the body still falls.
var control_off: bool = false
var _climbing: bool = false
var _levitating: bool = false
var _jumpp: float = 0.0
var _jump_count: int = 0
var _djump: bool = false
## dJump2: the air-jump boost ran this step.
var _djump2 := false
## t_levitfilter: levitFilter1 alpha t/20 and blur t/4 + 2.
var _t_levitfilter := -1.0
var _levit_aura: Node2D
## Obj.levit / teleHolder / fracLevit. A foe's Telekinesis sets them; levit is
## then the struggle counter. Unheld, levit is 1 while self-levitating.
var levit: int = 0
var tele_holder: Node = null
var frac_levit: int = 0
## Unit.damWall / t_throw: a telekinetic throw arms a wall hit for t_throw ticks.
var dam_wall: float = 0.0
var t_throw: int = 0
var _held_at := Vector2.INF
var _throw_acc := 0.0
var _air_kicked: bool = false
var _did_jump: bool = false
var _slow_left: float = 0.0
var _slow_tick: float = 0.0
var _slow_radius: float = 200.0
var _crystal_on: bool = false
var _crystal_grace: float = 0.0
var _shit_hp: float = 0.0
var _blood_left: float = 0.0
var _moon: Node2D
var _crystal_ring: Sprite2D
var _shit_ring: Sprite2D
var _inh_ring: Sprite2D
var _blood_auras: Array = []
var _heavy_id: int = 0
var _hide_id: int = 0
var _tele_obj: Node2D = null
var _tele_vel := Vector2.ZERO
var _tele_acc := 0.0
var _tk_was_down := false
## Pers.portTime / portDown are ticks, portMagic the magic bar, portMana Pers.manaHP.
const PORT_TIME := 25.0
const PORT_DOWN := 300.0
const PORT_MAGIC := 950.0
const PORT_MANA := 25.0
const _PORT_CEL := "res://assets/sprites/gui/port_cel_%d.png"
var _t_port := 0.0
var _port_cel: Sprite2D
## keyAttack during the charge clears keyTele and keyAttack until each key comes up again.
var _port_cut := false
var _port_shot_cut := false
var _drop_timer: float = 0.0
var _ladder_count: int = 0
var _ladder_lockout: bool = false
var _ladder_areas: Array[Area2D] = []
var _pose: String = "idle"
var _weapons: Array = []
var _weapon_i: int = -1
var _catalog: Dictionary = {}
var _mag_rounds: Dictionary = {}
var _reload_left: float = 0.0
var _reload_id: String = ""
# Leftover recharge wait per weapon, in seconds. ammo_recharg ticks at 30 Hz.
var _rech_left: Dictionary = {}
var _burst_left: int = 0
var _burst_wait: float = 0.0
var _prep: float = 0.0
var _semi_lock: bool = false
var _armed_id: String = ""
## UnitPlayer.magicWeapon fired by keyMagic: its own t_attack, t_prep and t_auto.
## Without a favourite it is the last magic weapon drawn.
var _magic_last_id: String = ""
## UnitPlayer.throwWeapon fired by keyGrenad: favourites cell 29, else the last explosive drawn.
var _throw_last_id: String = ""
var _throw_cd: float = 0.0
var _throw_armed := false
var _magic_cd: float = 0.0
var _magic_prep: float = 0.0
var _magic_semi: bool = false
var _said: Dictionary = {}
var _step_phase: int = 0
var _step_acc: float = 0.0
var _carried: Node2D
var _carried_id: String = ""
var _melee_acc: float = 0.0
var _melee_t: int = 0
var _melee_rapid: int = 0
var _melee_struck: Dictionary = {}
var _melee_prev: Array = []
var _melee_snd: bool = false
## Bullet.tilehit: one tile per blow. A swing (mtip 0) only hits the tile under the cursor.
var _melee_tile_hit: bool = false
var _melee_cel_tile := Vector2i.ZERO
var _wep_pos: Vector2 = Vector2.ZERO
var _wep_has: bool = false
var _wep_side: float = 1.0
var _wep_aim: Vector2 = Vector2.ZERO
var _wep_blum: float = 0.0
# Weapon presentation state (Weapon / WClub / UnitPlayer.changeWeapon), in 30 Hz ticks.
var _armed: Dictionary = {}
var _chw_left: float = 0.0
var _chw_stage: int = 0
var _chw_ready := false
var _reload_hold: float = 0.0
var _reload_filled := false
var _prep_snd: AudioStreamPlayer
var _prep_was := false
var _melee_pow: int = 0
var _melee_auto: int = 0
var _melee_combo: int = 0
var _melee_t_combo: int = 0
var _melee_power: float = 1.0
var _melee_quake := Vector2.ZERO
var _melee_vzz: Sprite2D
var _melee_vis = null
var _slot_down: Dictionary = {}
var _reload_prev: float = 0.0
# UnitPlayer.t_up and weapUp. Read by the puppet and the carried melee weapon.
var _up_for: float = 0.0
var weapon_raised: bool = false
var _hoof_cd: float = 0.0
var _hoof_work: float = 0.0
var _hoof_hit: float = 0.0
var _hoof_kick: bool = false
var _hoof_used: bool = false
var _run_down: bool = false
var _run_held_for: float = 0.0
var _run_for_kick: bool = false
# isSit latch, downp (in seconds), last tick's walk and maxSpeed for forces(), t_run.
var _sit: bool = false
var _down_for: float = 0.0
var _walk_dir: int = 0
var _max_speed: float = SPEED
var _t_run: float = 0.0
var _kdash_left: float = 0.0
## UnitPlayer dash_t (ticks).
var _dash_t: float = 0.0
var _pinok: float = 0.0
var _jump_cut: bool = false
# Sign of diagon.X (the way the stair rises), 0 off stairs.
var _diagon: int = 0
var _gait: String = "idle"
# Knock vector (px/tick, times otbros) of the bullet being applied right now.
var _hit_knock: Vector2 = Vector2.ZERO
var _use_node: Node = null
var _use_left: int = 0
var _use_max: int = 1
var _use_acc: float = 0.0
var _use_reach: float = 200.0
var _use_bar: Node2D = null
var _interact_queued := false
var _interact_frame := -1
## Location.sky (Land.ativateLoc): isFly, stay = false, no gravity. Set by sky_arena.gd.
var sky_mode := false: set = set_sky_mode
var _sky_acc := 0.0
var _sky_t := 0.0
## UnitPlayer.isFly outside sky rooms: pers.ableFly, toggled by a jump in the air.
var _is_fly := false
## UnitPlayer.rat (potion_rat): a 30x17 body, vis.rat instead of vis.osn.
var rat := false
var _rat_vis: AnimatedSprite2D = null

const _Resistances := preload("res://scripts/resistances.gd")
const _Barrier := preload("res://scripts/magic_barrier.gd")
const _Moon := preload("res://scripts/moonblade.gd")
const SHIT_ARMOR := 20
const TYPE_LABELS := {
	"DAM_PIERCE": "bullet",
	"DAM_LASER": "laser",
	"DAM_BURN": "fire",
	"DAM_PLASMA": "plasma",
	"DAM_EXPLOSION": "explosion",
}


func _ready() -> void:
	# A 45 degree stair must stay floor, never wall.
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	ladder_detector.area_entered.connect(_on_ladder_entered)
	ladder_detector.area_exited.connect(_on_ladder_exited)
	_load_catalog()
	_load_spellbook()
	var bags := get_node_or_null("/root/Inventory")
	if bags and bags.has_signal("changed") and not bags.changed.is_connected(_sync_owned):
		bags.changed.connect(_sync_owned)
	_sync_owned()
	# visualPlayer children: inh 3631, shit (visShit) and cryst 3687.
	_inh_ring = _FxClip.make("fx_inh", Vector2(-1.0, -32.5), 1.54, [-1])
	_inh_ring.z_index = -1
	add_child(_inh_ring)
	_shit_ring = _FxClip.make("fx_shit", Vector2(0, -40), 1.0, [20])
	_shit_ring.z_index = 2
	add_child(_shit_ring)
	_crystal_ring = _FxClip.make("fx_cryst", Vector2(0, -40), 1.0, [5, 15])
	_crystal_ring.z_index = 2
	add_child(_crystal_ring)
	# invulnerFilter1/2 on vis.osn: GlowFilter(0xFF5555,1,2,2,3,3), GlowFilter(0xFF0000,1,7,7,1,3).
	for glow in [[Color(1.0, 0.333, 0.333), 3.0, 0.99], [Color(1.0, 0.0, 0.0), 1.0, 2.96]]:
		var aura := (load("res://scripts/magic_aura.gd") as GDScript).new() as Node2D
		aura.name = "BloodAura%d" % _blood_auras.size()
		aura.set("host", puppet)
		aura.set("color", glow[0])
		aura.set("strength", glow[1])
		aura.set("sigma", glow[2])
		aura.set_meta("no_tele_glow", true)
		aura.set("alpha", 0.0)
		puppet.add_child(aura)
		_blood_auras.append(aura)
	_carried = Node2D.new()
	_carried.name = "CarriedWeapon"
	_carried.z_index = 3
	_carried.visible = false
	add_child(_carried)
	sats = _Sats.new()
	sats.name = "Sats"
	add_child(sats)
	var wheel := _Wheel.new()
	wheel.name = "WeaponWheel"
	add_child(wheel)
	var quick := _QuickKeys.new()
	quick.name = "QuickKeys"
	add_child(quick)


func _unhandled_input(event: InputEvent) -> void:
	if control_off:
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		_interact_queued = true


func _process(_delta: float) -> void:
	# Interact is read here only: at 30 physics ticks a physics read would see
	# the same press again a frame later and toggle a door back. Land props
	# reads tk_claim afterwards, so this still lands before that walk-up check.
	if GameState.paused or control_off or rat or GameState.ui_hold() or _WorkAnim.blocks_input(self):
		_interact_queued = false
		return
	_take_interact(_cursor_world())


func _physics_process(delta: float) -> void:
	if GameState.paused or _WorkAnim.blocks_input(self):
		return

	sats.step2(delta)
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_spell_cd = maxf(0.0, _spell_cd - delta)
	_cast_glow = maxf(0.0, _cast_glow - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_drop_timer = maxf(0.0, _drop_timer - delta)
	_tick_hoof(delta)
	if control_off or GameState.ui_hold():
		_control_off_step(delta)
		return
	_poll_run(delta)
	_tick_slow(delta)
	_tick_spell_state(delta)
	_tick_weapon_change(delta)
	if _chw_left > 0.0 or rat or Effects.attack_forever():
		pass
	elif Input.is_action_just_pressed("weapon_next"):
		_cycle_weapon(1)
	elif Input.is_action_just_pressed("weapon_prev"):
		_cycle_weapon(-1)
	else:
		_poll_quick_slots()

	var cursor := Effects.forced_aim(_cursor_world())
	# changeWeapon("not") on potion_shadow / potion_rat; atkPoss 0 keeps it put away.
	if not GameState.attack_allowed() and not _weapon().is_empty():
		holster()

	var move_x := Input.get_axis("move_left", "move_right")
	if GameState.controls_swapped():
		move_x = -move_x
	var move_y := Input.get_axis("aim_up", "aim_down")
	var key_left := move_x < -0.2
	var key_right := move_x > 0.2
	var on_ladder := _ladder_count > 0
	var jump_held := Input.is_action_pressed("jump")
	var jump_just := Input.is_action_just_pressed("jump")
	# pinok > 60 clears keyJump. The hold stays cut until the key comes up.
	if _jump_cut:
		if jump_held:
			jump_held = false
			jump_just = false
		else:
			_jump_cut = false
	var tk_held := Input.is_action_pressed("telekinesis")
	var down := Input.is_action_pressed("aim_down")
	var up := Input.is_action_pressed("aim_up")
	# A foe's Telekinesis.hold steers velocity. UnitPlayer.forces skips walking,
	# gravity and the 0.8 levit drag while teleHolder is set; jump only counts levit down.
	var tele_held := _tick_held(jump_just)
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
		_levitating = false
	if not rat and not sky_mode and _tick_lurk(delta, key_left, key_right, up, down, jump_just):
		move_x = 0.0
		move_y = 0.0
		key_left = false
		key_right = false
		jump_held = false
		jump_just = false
		down = false
		up = false
	var was_on_floor := is_on_floor()
	_tick_pinok(delta, was_on_floor)
	if _ladder_count == 0:
		_ladder_lockout = false
	var fly_ok := GameState.can_fly() and _Flags.allows("levit") and not rat
	if _is_fly and not fly_ok:
		_is_fly = false
	# keyJump in the air (or off a ladder) with pers.ableFly and loc.levitOn flips isFly.
	if jump_just and fly_ok and not sky_mode and not _water.is_plav and (_climbing or (not is_on_floor() and _jump_count >= 1)):
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
	var drop_off := down and jump_just and (_climbing or (is_on_floor() and _on_one_way()))
	if jump_just and not drop_off and (is_on_floor() or _climbing):
		GameState.spend_jump_stamina()
		if is_on_floor():
			Stash.jumped()
	if drop_off:
		_jumpp = 0.0
		_djump = false
		_air_kicked = false
		_did_jump = false
		_jump_count = 0
		_levitating = false
		if _climbing or on_ladder:
			_ladder_lockout = true
		_climbing = false
		floor_snap_length = 0.0
		_start_drop_through()
		jump_just = false
	elif _climbing and jump_just and not up:
		_ladder_lockout = true
		_climbing = false
		_levitating = false
		floor_snap_length = 0.0
		if absf(move_x) > 0.2:
			velocity.y = _jump_velocity()
			_jump_count = 1
			_did_jump = true
			_jumpp = JUMP_SUSTAIN
			_djump = false
		else:
			_jumpp = 0.0
			_did_jump = false
			_jump_count = 0
			velocity.y = maxf(velocity.y, 0.0)
		jump_just = false

	var ladder := _ladder_under_feet()
	var climb := on_ladder and not _ladder_lockout and not rat and not _is_fly and (absf(move_y) > 0.25 or _climbing)
	if jump_just and not up:
		climb = false
	if climb and not _climbing:
		# Grabbing on keyBeUp needs pinok < 30. Down on the ground grabs only
		# when checkStairs(2) finds the ladder below the feet.
		if _pinok >= 30.0:
			climb = false
		elif move_y > 0.25 and is_on_floor() and (ladder == null or _rail_bottom(ladder) <= global_position.y + 2.0):
			climb = false
	# checkStairs(-1) reads the tile at the feet. Once those feet reach the top
	# of the rail, that tile is not a ladder, so up lets go. The lip is that edge.
	if climb and ladder != null and move_y < -0.25 and _reaching_rail_top(ladder, delta, move_y):
		if _climbing:
			_stand_on_rail(ladder)
		climb = false
	# Feet on the floor at the bottom of the rail: left or right walks away.
	if climb and _climbing and is_on_floor() and absf(move_x) > 0.2 and absf(move_y) <= 0.25:
		climb = false
	if climb:
		if not _climbing and ladder != null:
			_snap_to_rail(ladder)
		_climbing = true
		_levitating = false
		_jumpp = 0.0
		_djump = false
		_air_kicked = false
		_set_sit(false)
		_walk_dir = 0
		_t_run = 0.0
		# Ladder tops are one-way lips. Snapping to them, or keeping them solid,
		# wedges the 50px body in the 40px slot beside the lip.
		floor_snap_length = 0.0
		set_collision_mask_value(PLATFORM_LAYER_BIT, false)
		if ladder != null:
			# storona = ladderSide, and vis.scaleX = storona.X. Left is -1.
			facing = _ladder_facing(ladder)
		var move_scale := GameState.move_speed_mult()
		# Unit.checkStairs pins X to the ladder tile's edge; left/right only matter for a jump off.
		velocity.x = 0.0
		if ladder != null and _climbing:
			_snap_to_rail(ladder)
		var climb_mult := CLIMB_DOWN_MULT if move_y > 0.0 else 1.0
		velocity.y = move_y * CLIMB_SPEED * climb_mult * move_scale
		_jump_count = 0
		_did_jump = false
	else:
		_climbing = false
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
	var fall_through := (down and not is_on_floor() and not _climbing) or _pinok > 70.0 or _kdash_left > 3.0 / 30.0
	if fall_through:
		set_collision_mask_value(PLATFORM_LAYER_BIT, false)
	elif _drop_timer <= 0.0 and not _climbing:
		set_collision_mask_value(PLATFORM_LAYER_BIT, true)

	_water.check(self, CROUCH_SIZE.y if _sit else BODY_SIZE.y)
	_water.tick(self, delta)
	if sky_mode or _is_fly:
		_sky_step(delta, key_left, key_right, up, down)
	elif _water.is_plav and not _climbing:
		_swim_step(delta, jump_held or up, down, key_left, key_right)
	elif not _climbing:
		_step_jump(delta, jump_held, jump_just, move_x, key_left, key_right)
		_water.wade(self, delta)
		if not _levitating and _water.lift(self, delta, CROUCH_SIZE.y if _sit else BODY_SIZE.y):
			floor_snap_length = 0.0
	if _drop_timer > 0.0 and _jumpp <= 0.0:
		floor_snap_length = 0.0

	_tick_use(delta)
	_update_telekinesis(tk_held and not rat, cursor, delta)
	_note_run_stamina()
	_step_up(delta, up, down)
	_auto_sit(delta, up)
	if tele_held:
		velocity = held_v
	var fall_vy := velocity.y
	var pre_v := velocity
	move_and_slide()
	_tick_throw_wall(delta, pre_v)
	_landed(was_on_floor, fall_vy)
	_tick_levit_glow(delta)
	_update_diagon()
	var pose := _pick_pose()
	# The punch label holds for t_work. Climb and hover keep their own clips.
	if _hoof_work > 0.0 and pose != "climb" and pose != "levitate":
		pose = "kick" if _hoof_kick else "punch"
	_pose = pose
	_apply_body_box(_sit)
	_footsteps(delta)
	_tick_weapon_raise(delta, up)
	if puppet.has_method("set_magic_activity"):
		_push_horn_glow()
	if puppet.has_method("update_pose") and not _WorkAnim.owns(self):
		puppet.update_pose(_pose, facing, aim_dir, delta)
	if rat:
		_pose_rat()
	if puppet.has_method("uses_lagged_aim") and puppet.uses_lagged_aim() and puppet.has_method("combat_aim_dir"):
		var lagged: Vector2 = puppet.combat_aim_dir()
		if lagged.length_squared() > 0.01:
			aim_dir = lagged
	_update_muzzle(cursor)
	var cursor_aim := aim_dir
	if _spell_cd <= 0.0:
		# keyDef casts currentSpell, then keySpell1-4 cast their cells.
		if Inventory != null and Input.is_action_just_pressed("cast_spell"):
			_cast_quick(str(Inventory.spell_id), cursor_aim)
		var quick := ""
		if MagicBinds != null and MagicBinds.has_method("poll"):
			quick = str(MagicBinds.poll())
		if quick != "":
			_cast_quick(quick, cursor_aim)
	_tick_weapon(delta)
	# currentWeapon.attack() runs only while t_work <= 0 (weapon change, punch).
	if _wants_shot(delta) and _fire_cd <= 0.0 and _magic_cd <= 0.0 and _reload_left <= 0.0 and _chw_left <= 0.0 and _hoof_work <= 0.0:
		_try_shoot()
	_tick_throw_key(delta)
	_tick_magic_key(delta)
	_push_gun_state()
	# Attack is handled first, then keyReload, same order as UnitPlayer.
	_poll_reload()
	var blink := 0.45 if _invuln > 0.0 and fmod(_invuln, 0.1) < 0.05 else puppet.modulate.a
	puppet.modulate.a = blink
	_tick_carried_weapon(delta, cursor)


## UnitPlayer.animate t_levitfilter and setFilters. Lifted by a foe (levit,
## fracLevit != fraction): its levitFilter2 in its colour. Own levitation or a
## double jump in progress (dJump): levitFilter1 in teleColor, fading in by 2
## a tick while levitating, 10 while the air jump pushes, out by 1 after.
func _tick_levit_glow(delta: float) -> void:
	var ticks := delta * 30.0
	var holder: Variant = get_meta("levit_by") if has_meta("levit_by") else null
	var lifted := _levitating or holder is Color
	if lifted and _t_levitfilter <= 20.0:
		_t_levitfilter += 2.0 * ticks
	if _djump2 and _t_levitfilter <= 20.0:
		_t_levitfilter += 10.0 * ticks
	if not lifted and not _djump2 and _t_levitfilter >= 0.0:
		_t_levitfilter -= ticks
	var t := minf(_t_levitfilter, 20.0)
	var show := t > 0.0 and (holder is Color or _levitating or _djump)
	if not show:
		if _levit_aura != null and is_instance_valid(_levit_aura):
			_levit_aura.set("alpha", 0.0)
		return
	if _levit_aura == null or not is_instance_valid(_levit_aura):
		_levit_aura = _Aura.attach(puppet)
		# The tail sits at z -1; the glow goes behind it.
		_levit_aura.z_index = -2
	if holder is Color:
		_levit_aura.set("color", holder)
		_levit_aura.set("alpha", 1.0)
		_levit_aura.set("strength", 1.0)
		_levit_aura.set("sigma", 2.96)
	else:
		_levit_aura.set("color", null)
		_levit_aura.set("alpha", t / 20.0)
		_levit_aura.set("strength", 2.0)
		# Flash blur b at quality 3 is a gaussian of sigma ~0.493 b; the kernel holds 2.96.
		_levit_aura.set("sigma", minf(0.493 * (t / 4.0 + 2.0), 2.96))


## True while a foe holds the player. UnitPlayer jump with levit > 1 only does levit--;
## Telekinesis.hold lets go once it reaches 1. A holder that died, left the tree or
## stopped ticking (its room went idle) lets go here.
func _tick_held(jump_just: bool) -> bool:
	if tele_holder != null:
		var gone := not is_instance_valid(tele_holder) or not tele_holder.is_inside_tree() or bool(tele_holder.get("_dead"))
		if gone or Engine.get_physics_frames() - int(get_meta("tele_frame", 0)) > 10:
			levit = 0
			tele_holder = null
			if has_meta("levit_by"):
				remove_meta("levit_by")
	if tele_holder == null:
		levit = 1 if _levitating else 0
		_held_at = Vector2.INF
		return false
	# Unit.setNull and teleport zero levit; the holder lets go on its next hold.
	if _held_at != Vector2.INF and global_position.distance_squared_to(_held_at) > 200.0 * 200.0:
		levit = 0
	_held_at = global_position
	if levit <= 0:
		return false
	if jump_just and levit > 1:
		levit -= 1
	return true


## Unit.damageWall during t_throw: a wall met faster than damWallSpeed (12 px a tick)
## deals |v| / damWallSpeed * damWall blunt damage and ends t_throw.
func _tick_throw_wall(delta: float, pre_v: Vector2) -> void:
	if t_throw <= 0:
		_throw_acc = 0.0
		return
	_throw_acc += delta * 30.0
	while _throw_acc >= 1.0 and t_throw > 0:
		_throw_acc -= 1.0
		t_throw -= 1
	if dam_wall <= 0.0:
		return
	var v := pre_v / 30.0
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var other := hit.get_collider() as Node
		if other == null or other.is_in_group("enemies"):
			continue
		var n := hit.get_normal()
		var into := -v.x * signf(n.x) if absf(n.x) > 0.7 else -v.y * signf(n.y)
		if into <= 12.0:
			continue
		t_throw = 0
		var dam := v.length() / 12.0 * dam_wall
		take_hit(int(round(dam)), "DAM_BLUNT")
		var half := (CROUCH_SIZE if _sit else BODY_SIZE) * 0.5
		UnitFx.emit(get_tree(), "bum", global_position + Vector2(-n.x * half.x, -half.y - n.y * half.y))
		SfxBank.play("hit_flesh")
		return


## UnitPlayer.controlOff: ctr.clearAll, dropTeleObj, isRun false, walk 0.
func set_control_off(off: bool) -> void:
	control_off = off
	if off:
		_interact_queued = false
		_run_down = false
		_walk_dir = 0
		_t_run = 0.0


## A tick with no keys held: gravity, water and the pose go on.
func _control_off_step(delta: float) -> void:
	_tick_slow(delta)
	_tick_spell_state(delta)
	_tick_weapon_change(delta)
	if _tele_obj != null and control_off:
		_drop_tele()
	var was_on_floor := is_on_floor()
	_tick_pinok(delta, was_on_floor)
	_water.check(self, CROUCH_SIZE.y if _sit else BODY_SIZE.y)
	_water.tick(self, delta)
	if _climbing:
		velocity = Vector2.ZERO
	elif sky_mode or _is_fly:
		_sky_step(delta, false, false, false, false)
	elif _water.is_plav:
		_swim_step(delta, false, false, false, false)
	else:
		_step_jump(delta, false, false, 0.0, false, false)
		_water.wade(self, delta)
	var fall_vy := velocity.y
	move_and_slide()
	_landed(was_on_floor, fall_vy)
	_djump2 = false
	_tick_levit_glow(delta)
	_pose = _pick_pose()
	_apply_body_box(_sit)
	_footsteps(delta)
	if puppet.has_method("update_pose") and not _WorkAnim.owns(self):
		puppet.update_pose(_pose, facing, aim_dir, delta)
	if rat:
		_pose_rat()


func _cursor_world() -> Vector2:
	if sats != null and sats.firing():
		return sats.cel_point()
	var cursor := get_tree().get_first_node_in_group("aim_cursor")
	if cursor and cursor.has_method("world_position"):
		return cursor.world_position()
	return get_global_mouse_position()


## pers.atkPoss (potion_shadow / potion_rat set it to 0). The rat never attacks.
func _attack_ok() -> bool:
	return not rat and GameState.attack_allowed()


## keyAttack or the vote's autoAttack.
func _shoot_held() -> bool:
	return Input.is_action_pressed("shoot") or Effects.auto_attack()


## UnitPlayer.changeWeapon("not"): the weapon is put away until the next equip.
func holster() -> void:
	if Inventory != null:
		Inventory.holster()
	_weapon_i = -1
	_publish_weapon()


## UnitPlayer.ratOn (potion_rat).
func rat_on() -> void:
	holster()
	_set_sit(false)
	_climbing = false
	_levitating = false
	_is_fly = false
	_drop_tele()
	_clear_use()
	rat = true
	_apply_body_box(false)
	_pose_rat()


## UnitPlayer.ratOff: the standing box must fit here, 15px right or 15px left.
## False keeps the rat (Effect then holds potion_rat a second longer).
func rat_off() -> bool:
	if not rat:
		return true
	var spot := global_position
	var fits := false
	for dx in [0.0, 15.0, -15.0]:
		if _stand_fits(spot + Vector2(dx, 0.0)):
			global_position = spot + Vector2(dx, 0.0)
			fits = true
			break
	if not fits:
		return false
	rat = false
	_apply_body_box(false)
	puppet.visible = true
	if _rat_vis != null:
		_rat_vis.visible = false
	UnitFx.emit(get_tree(), "black", global_position + Vector2(0, -39), {"kol": 30})
	return true


func _stand_fits(at: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var query := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE - Vector2(2.0, 2.0)
	query.shape = rect
	query.transform = Transform2D(0.0, at + Vector2(0.0, -BODY_SIZE.y * 0.5 - 1.0))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	for found in space.intersect_shape(query, 4):
		var node := found.collider as Node
		if node == null or node == self or _is_one_way(node):
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
		add_child(_rat_vis)
	puppet.visible = false
	_rat_vis.visible = true
	_rat_vis.flip_h = facing < 0.0
	if _rat_vis.sprite_frames == null:
		return
	var clip := "stay"
	if _water.is_plav:
		clip = "plav"
	elif not is_on_floor():
		clip = "jump"
	elif absf(velocity.x) > 30.0:
		clip = "run" if absf(velocity.x) > SPEED * 1.1 else "walk"
	if _rat_vis.animation != clip or not _rat_vis.is_playing():
		_rat_vis.play(clip)


func _update_muzzle(cursor: Vector2) -> void:
	var origin := global_position + Vector2(0, -36)
	if puppet.has_method("get_muzzle_global"):
		origin = puppet.get_muzzle_global()
	var to_cursor := cursor - origin
	aim_dir = to_cursor.normalized() if to_cursor.length_squared() > 1.0 else Vector2(facing, 0)
	muzzle.global_position = origin


func _start_drop_through() -> void:
	_drop_timer = DROP_TIME
	set_collision_mask_value(PLATFORM_LAYER_BIT, false)
	global_position.y += 4.0
	velocity.y = maxf(velocity.y, 80.0)


func _on_one_way() -> bool:
	# stayPhis == 2 only when a platform is under the body and no solid is.
	# A rest pose often has no slide contacts, so this probes the feet.
	var space := get_world_2d().direct_space_state
	if space == null:
		return false
	var platform_mask := 1 << (PLATFORM_LAYER_BIT - 1)
	var platform := false
	var solid := false
	for dx in [-20.0, 0.0, 20.0]:
		var from := global_position + Vector2(dx, -6.0)
		var to := global_position + Vector2(dx, 8.0)
		var down_ray := PhysicsRayQueryParameters2D.create(from, to, platform_mask)
		down_ray.exclude = [get_rid()]
		if not space.intersect_ray(down_ray).is_empty():
			platform = true
		var ground := PhysicsRayQueryParameters2D.create(from, to, 1)
		ground.exclude = [get_rid()]
		if not space.intersect_ray(ground).is_empty():
			solid = true
	return platform and not solid


func _load_catalog() -> void:
	_catalog.clear()
	if not FileAccess.file_exists("res://assets/data/weapons.json"):
		push_error("weapons.json missing")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/weapons.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("weapons.json did not parse")
		return
	for entry_v in (parsed as Dictionary).get("weapons", []):
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var id := str(entry.get("id", ""))
		if id != "":
			_catalog[id] = entry


func _sync_owned() -> void:
	var bags := get_node_or_null("/root/Inventory")
	if bags == null or not bags.has_method("owned_weapon_ids"):
		return
	var keep := ""
	if str(bags.get("weapon_id")) != "":
		keep = str(bags.weapon_id)
	var rows: Array = []
	for id_v in bags.owned_weapon_ids():
		var made: Dictionary = bags.weapon_def(str(id_v))
		if made.is_empty():
			continue
		rows.append(made)
	_weapons = rows
	_weapon_i = -1
	if keep != "":
		for i in rows.size():
			if str((rows[i] as Dictionary).get("id", "")) == keep:
				_weapon_i = i
				break
	_publish_weapon()


func _weapon() -> Dictionary:
	if _weapon_i < 0 or _weapon_i >= _weapons.size():
		return {}
	return _weapons[_weapon_i]


## Port: the step skips hidden weapons, spells and magic weapons (those are
## magic_attack / cast_spell, picked on the wheels).
func _cycle_weapon(step: int) -> void:
	if _weapons.is_empty() or not GameState.attack_allowed():
		return
	var index := -1
	var at := _weapon_i
	if at < 0:
		at = -1 if step > 0 else _weapons.size()
	for _i in _weapons.size():
		at = posmod(at + step, _weapons.size())
		var row: Dictionary = _weapons[at]
		var kind := str(row.get("kind", ""))
		if kind == "magic" or kind == "spell" or bool(row.get("spell", false)) or Stash.is_hidden(str(row.get("id", ""))):
			continue
		index = at
		break
	if index < 0 or index == _weapon_i:
		return
	var id := str((_weapons[index] as Dictionary).get("id", ""))
	var bags := get_node_or_null("/root/Inventory")
	if bags and bags.has_method("equip") and bags.equip(id):
		return
	_weapon_i = index
	_publish_weapon()


func _publish_weapon() -> void:
	var w := _weapon()
	var id := str(w.get("id", ""))
	if id != _armed_id:
		# Holstering cancels a reload that has not finished (setNull zeroes t_reload).
		# The rounds already in the magazine stay with that weapon.
		_reload_left = 0.0
		_reload_id = ""
		_armed_id = id
		_burst_left = 0
		_prep = 0.0
		_semi_lock = false
		if str(w.get("kind", "")) == "magic" and not bool(w.get("spell", false)):
			_magic_last_id = id
		if str(w.get("kind", "")) == "explosives":
			_throw_last_id = id
		_on_weapon_drawn(w)
		_begin_weapon_change()
	elif _chw_left <= 0.0:
		_armed = w
	if w.is_empty():
		GameState.set_weapon_name("")
		return
	var dtype := str(w.get("damage_type", ""))
	var label := str(w.get("name", w.get("id", "")))
	if TYPE_LABELS.has(dtype):
		label = "%s (%s)" % [label, TYPE_LABELS[dtype]]
	GameState.set_weapon_name(label)


func _begin_weapon_change() -> void:
	# UnitPlayer.changeWeapon: work "change", t_work 30. At 20 the old weapon is
	# put away, at 10 the new one is drawn. Loading a game swaps at once.
	if not _chw_ready or not is_inside_tree():
		_chw_left = 0.0
		_draw_armed(_weapon())
		return
	_chw_left = 30.0


func _tick_weapon_change(delta: float) -> void:
	_chw_ready = true
	if _chw_left <= 0.0:
		return
	var before := _chw_left
	_chw_left = maxf(0.0, _chw_left - delta * 30.0)
	if before > 20.0 and _chw_left <= 20.0:
		_draw_armed({})
	if before > 10.0 and _chw_left <= 10.0:
		_draw_armed(_weapon())
	if puppet.has_method("set_weapon_lowered"):
		puppet.set_weapon_lowered(_chw_left > 10.0)


func _draw_armed(w: Dictionary) -> void:
	_armed = w
	if puppet.has_method("set_weapon"):
		puppet.set_weapon(w)
	if "recoil_mult" in puppet:
		puppet.recoil_mult = int(Progression.pers("recoilMult", 1.0))
		puppet.drot_mult = 1.0 if str(w.get("kind", "")) == "magic" else Progression.pers("drotMult", 1.0)


func _poll_quick_slots() -> void:
	# UnitPlayer: keyWeapon1..12 call useFav(i), with keyRun held useFav(i + 12).
	var focus := get_viewport().gui_get_focus_owner()
	if focus is Control and (focus as Control).is_visible_in_tree():
		return
	for n in Favorites.HOTKEYS:
		var action := Favorites.action_of(n + 1)
		if not InputMap.has_action(action) or not Input.is_action_just_pressed(action):
			continue
		if _action_taken_by_spell(action):
			continue
		var cell := n + 1 + (Favorites.HOTKEYS if Input.is_action_pressed("sprint") else 0)
		Favorites.use_fav(cell)
		return


func _action_taken_by_spell(action: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and _key_taken_by_spell((event as InputEventKey).physical_keycode):
			return true
	return false


func _key_taken_by_spell(code: int) -> bool:
	return MagicBinds != null and MagicBinds.key_taken(code)


func _load_spellbook() -> void:
	_spellbook.clear()
	for entry_v in _weapons:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		if str(entry.get("kind", "")) == "spell":
			_spellbook[str(entry.get("id", ""))] = entry
	if not FileAccess.file_exists("res://assets/data/spells.json"):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/spells.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for entry_v in (parsed as Dictionary).get("spells", []):
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var id := str(entry.get("id", ""))
		if id == "" or _spellbook.has(id):
			continue
		_spellbook[id] = entry


func _cast_quick(id: String, dir: Vector2) -> void:
	var spell: Dictionary = _spellbook.get(id, {})
	if spell.is_empty() or not _Flags.allows("weapons"):
		return
	# Quick cells hold only spells the player carries (equipment.getSpell).
	if Inventory == null or Inventory.count(id) <= 0:
		return
	# Crystal shield is held. The key edge only starts the hold path, which pays once.
	if id == "sp_cryst" or str(spell.get("effect", "")) == "crystal":
		return
	if not _spell_ready(spell):
		_spell_cd = 0.25
		return
	var handled := _cast_spell(spell, dir)
	if handled <= 0:
		_spell_cd = 0.25
		return
	_pay_cast(spell)
	_play_spell_sound(spell)


func _notice(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notice"):
		hud.show_notice(text)


func _try_shoot() -> void:
	if bullet_scene == null:
		return
	var w := _weapon()
	if w.is_empty() or not _allowed(w):
		return
	var delivery := str(w.get("delivery", "projectile"))
	# changeWeapon hands spells to changeSpell. keyAttack never casts them.
	if delivery == "spell" or bool(w.get("spell", false)):
		return
	if not _pay(w):
		_burst_left = 0
		return
	var fired := false
	if delivery == "melee":
		fired = _melee(w)
	elif delivery == "mine":
		fired = _mine(w)
	elif delivery == "grenade":
		fired = _grenade(w)
	else:
		fired = _shoot_pellets(w)
	if not fired:
		_burst_left = 0
		return
	# Magazine drops only after a shot or swing actually starts.
	_commit_magazine(w)
	# Weapon.shoot: recoil, shell, and the vis "shoot" label. t_attack is rapid.
	if delivery != "melee" and puppet.has_method("weapon_fired"):
		puppet.weapon_fired(int(round(_shot_gap(w) * 30.0)))
	# magazineCapacity == 1 starts the reload in the same attack that fired.
	if int(w.get("mag", 0)) == 1 and not _self_charges(w):
		_begin_reload(w, false)
	_arm_cooldown(w)
	if sats.queued():
		sats.act()


func _throw_weapon() -> Dictionary:
	var id := ""
	if MagicBinds != null and MagicBinds.has_method("throw_weapon"):
		id = str(MagicBinds.throw_weapon())
	if id == "":
		id = _throw_last_id
	if id == "" or Inventory.count(id) <= 0:
		return {}
	for row in _weapons:
		if str((row as Dictionary).get("id", "")) == id:
			return row
	return {}


## UnitPlayer keyGrenad: throwWeapon.attack() without changing the weapon in hand,
## while keyAttack is up and that weapon is not mid-attack. A press waits until
## it can go; an explosive then throws once, a magic weapon repeats while held.
func _tick_throw_key(delta: float) -> void:
	_throw_cd = maxf(0.0, _throw_cd - delta)
	if not InputMap.has_action("grenade") or not Input.is_action_pressed("grenade"):
		_throw_armed = false
		return
	if Input.is_action_just_pressed("grenade"):
		_throw_armed = true
	if not _throw_armed or not _Flags.allows("weapons") or not _attack_ok() or Effects.attack_forever():
		return
	if Input.is_action_pressed("shoot") or _chw_left > 0.0 or _hoof_work > 0.0:
		return
	if _fire_cd > 0.0 or _magic_cd > 0.0 or _reload_left > 0.0 or _burst_left > 0:
		return
	var w := _throw_weapon()
	if w.is_empty():
		_throw_armed = false
		return
	if sats.queued():
		sats.clear_all()
	if str(w.get("kind", "")) == "explosives":
		_throw_armed = false
	if _throw_cd > 0.0:
		return
	if not _allowed(w) or not _pay(w):
		_throw_cd = maxf(_throw_cd, _fire_cd)
		_fire_cd = 0.0
		return
	var fired := false
	match str(w.get("delivery", "projectile")):
		"grenade":
			fired = _grenade(w)
		"mine":
			fired = _mine(w)
		_:
			fired = _shoot_pellets(w)
	if not fired:
		return
	_commit_magazine(w)
	_throw_cd = _shot_gap(w)
	if str(w.get("id", "")) == _armed_id:
		_fire_cd = _throw_cd


## favorites cell 30 holds a magic weapon or explosive. Empty, it is the last magic weapon drawn.
func _magic_weapon() -> Dictionary:
	var id := ""
	if MagicBinds != null and MagicBinds.has_method("magic_weapon"):
		id = str(MagicBinds.magic_weapon())
	if id == "":
		id = _magic_last_id
	if id == "":
		return {}
	for row in _weapons:
		if str((row as Dictionary).get("id", "")) == id:
			return row
	return {}


## UnitPlayer keyMagic: magicWeapon.attack() while keyAttack is up, outside the work
## animation, and only when the weapon in hand is not mid-attack (atkWeapon 0 or 3).
func _tick_magic_key(delta: float) -> void:
	_magic_cd = maxf(0.0, _magic_cd - delta)
	var held := InputMap.has_action("magic_attack") and Input.is_action_pressed("magic_attack") and _Flags.allows("weapons")
	held = held and _attack_ok() and not Effects.attack_forever()
	var w := _magic_weapon() if held else {}
	if w.is_empty():
		_magic_semi = false
		_magic_prep = maxf(0.0, _magic_prep - delta)
		return
	if Input.is_action_pressed("shoot") or _chw_left > 0.0 or _hoof_work > 0.0:
		return
	if _fire_cd > 0.0 or _reload_left > 0.0 or _burst_left > 0:
		return
	# Weapon.attack: a held key on a non-auto weapon only refreshes t_auto.
	if _magic_semi and not bool(w.get("auto", false)):
		return
	var prep_need := float(w.get("prep", 0)) / 30.0
	if prep_need > 0.0:
		if _magic_prep < prep_need + 10.0 / 30.0:
			_magic_prep += delta
		if _magic_prep < prep_need:
			return
	if _magic_cd > 0.0:
		return
	_magic_semi = true
	if not _allowed(w) or not _pay(w):
		_magic_cd = maxf(_magic_cd, _fire_cd)
		_fire_cd = 0.0
		return
	var fired := false
	match str(w.get("delivery", "projectile")):
		"grenade":
			fired = _grenade(w)
		"mine":
			fired = _mine(w)
		_:
			fired = _shoot_pellets(w)
	if not fired:
		return
	_commit_magazine(w)
	_magic_cd = _shot_gap(w)
	if str(w.get("id", "")) == _armed_id:
		_fire_cd = _magic_cd


func _spawn_shot(w: Dictionary, dir: Vector2, amount: float, from: Vector2 = Vector2.INF) -> void:
	var bullet := bullet_scene.instantiate() as Area2D
	bullet.global_position = muzzle.global_position if from == Vector2.INF else from
	bullet.direction = dir
	bullet.from_player = true
	bullet.damage = int(round(amount))
	bullet.damage_type = str(w.get("damage_type", "DAM_PIERCE"))
	bullet.block_damage = _Block.of(str(w.get("id", "")))
	bullet.hitscan = bool(w.get("hitscan", false))
	bullet.speed = float(w.get("speed", bullet.speed))
	bullet.blast_radius = float(w.get("radius", 0.0))
	bullet.style = str(w.get("style", "bullet"))
	if w.has("lifetime"):
		bullet.lifetime = float(w["lifetime"])
	# Firearm skill scaling is Progression's bullet hook. Spells are not guns.
	if str(w.get("kind", "")) == "spell":
		bullet.set_meta("prog_scaled", true)
	bullet.weapon_id = str(w.get("id", ""))
	# The caster already played the spell sound.
	bullet.voice_key = 0
	get_tree().current_scene.add_child(bullet)


func _dry_fire() -> void:
	# Weapon.attack on an empty magazine only calls initReload. No click plays.
	var w := _weapon()
	_fire_cd = _shot_gap(w) if not w.is_empty() else 0.22


func _tick_weapon(delta: float) -> void:
	# Condition's jam also starts a reload by writing _reload_left.
	if _reload_left > _reload_prev + 0.0001:
		_reload_filled = false
	_reload_prev = maxf(0.0, _reload_left - delta)
	if _reload_left > 0.0:
		_reload_left = maxf(0.0, _reload_left - delta)
		# reloadWeapon runs when t_reload reaches 10. Firing waits for 0.
		if not _reload_filled and _reload_left <= round(10.0 * Effects.stat("reloadMult", Progression.pers("reloadMult", 1.0))) / 30.0:
			_reload_filled = true
			_finish_reload()
		if _reload_left <= 0.0 and not _reload_filled:
			_finish_reload()
	var w := _weapon()
	if w.is_empty() or not _self_charges(w):
		return
	var mag := int(w.get("mag", 0))
	var id := str(w.get("id", ""))
	if mag <= 0 or id == "":
		return
	if not _mag_rounds.has(id):
		_mag_rounds[id] = mag
	# Weapon.step only counts t_rech while t_attack == 0 and the cell is not full.
	var ticks := int(w.get("recharg", 0))
	if ticks <= 0:
		return
	var step := float(ticks) / 30.0
	var left := float(_rech_left.get(id, step))
	if int(_mag_rounds[id]) >= mag:
		return
	if _fire_cd > 0.0 or _burst_left > 0 or _reload_left > 0.0:
		_rech_left[id] = left
		return
	left -= delta
	while left <= 0.0 and int(_mag_rounds[id]) < mag:
		_mag_rounds[id] = int(_mag_rounds[id]) + 1
		left += step
	_rech_left[id] = left


func _finish_reload() -> void:
	var w: Dictionary = _catalog.get(_reload_id, {})
	if w.is_empty():
		w = _weapon()
	_transfer_into_mag(w)


func _wants_shot(delta: float) -> bool:
	var w := _weapon()
	if w.is_empty() or not _Flags.allows("weapons") or not _attack_ok():
		return false
	if _burst_left > 0:
		_burst_wait = maxf(0.0, _burst_wait - delta)
		return _burst_wait <= 0.0
	if _port_shot_cut:
		_port_shot_cut = Input.is_action_pressed("shoot")
		if _port_shot_cut:
			return false
	# UnitPlayer: currentWeapon.attack(true) at que[0], once the weapon has turned onto it.
	if sats != null and sats.firing():
		var to_cel: Vector2 = sats.cel_point() - muzzle.global_position
		return to_cel.length_squared() < 1.0 or absf(aim_dir.angle_to(to_cel)) < 0.15
	var held := _shoot_held()
	if not held:
		_semi_lock = false
		_prep = maxf(0.0, _prep - delta)
		return false
	var prep_need := float(w.get("prep", 0)) / 30.0
	if prep_need > 0.0:
		# attack() adds 2 to t_prep while t_prep < prep + 10. actions() takes 1 back.
		if _prep < prep_need + 10.0 / 30.0:
			_prep += delta
		if _prep < prep_need:
			return false
	if bool(w.get("auto", false)):
		return true
	if _semi_lock:
		return false
	if prep_need > 0.0:
		return true
	return Input.is_action_just_pressed("shoot") or Effects.auto_attack()


func _shot_gap(w: Dictionary) -> float:
	# WClub sets rapidMult = 1 / meleeSpdMult. Head trauma lowers meleeSpdMult.
	var gap := maxf(float(w.get("rapid", 5)), 1.0) / 30.0
	if str(w.get("kind", "")) == "melee":
		gap /= _melee_spd()
	return gap


## Pers.meleeSpdMult: head trauma multiplies it, mmaster adds 0.15.
func _melee_spd() -> float:
	return maxf(GameState.melee_speed_mult() + Progression.pers("meleeSpdMult", 0.0), 0.05)


func _arm_cooldown(w: Dictionary) -> void:
	var rapid := _shot_gap(w)
	var burst := int(w.get("burst", 0))
	var auto := bool(w.get("auto", false))
	if _burst_left > 0:
		_burst_left -= 1
		if _burst_left > 0:
			_burst_wait = rapid
			_fire_cd = 0.0
		else:
			_fire_cd = rapid * 2.0
			if not auto:
				_semi_lock = true
		return
	if burst > 1:
		_burst_left = burst - 1
		_burst_wait = rapid
		_fire_cd = 0.0
		return
	_fire_cd = rapid * (2.0 if burst == 1 else 1.0)
	if not auto:
		_semi_lock = true


func _allowed(w: Dictionary) -> bool:
	# Spell.cast has no character level gate. Magic weapons (WMagic) keep perslvl.
	var need := 0 if bool(w.get("spell", false)) else int(w.get("pers_lvl", 0))
	var lvl := int(Progression.level) if Progression else 1
	if need > lvl:
		_notice(OriginalLines.info("persLevel"))
		_fire_cd = 0.35
		return false
	if str(w.get("kind", "")) != "explosives" and _razn(w) > 2:
		_notice(OriginalLines.info("weaponSkillLevel"))
		_fire_cd = 0.35
		return false
	return true


func _razn(w: Dictionary) -> int:
	if str(w.get("skill_id", "")) == "":
		return 0
	return int(w.get("lvl", 0)) - _skill_level(w)


func _skill_level(w: Dictionary) -> int:
	var sid := str(w.get("skill_id", ""))
	if sid == "" or Progression == null:
		return 100
	return int(Progression.skill_level_of(sid))


func _skill_mult(w: Dictionary) -> float:
	var sid := str(w.get("skill_id", ""))
	if sid == "" or Progression == null:
		return 1.0
	return 1.0 + 0.05 * float(Progression.rank(sid))


func _skill_conf(w: Dictionary) -> float:
	var razn := _razn(w)
	var explosives := str(w.get("kind", "")) == "explosives"
	if razn <= 0:
		return 1.0
	if razn == 1:
		return 0.75 if explosives else 0.8
	return 0.5 if explosives else 0.6


func _skill_plus(w: Dictionary) -> float:
	if str(w.get("kind", "")) == "magic":
		return 1.0
	var razn := _razn(w)
	if razn < 0:
		return 1.0 - float(razn) * 0.1
	return 1.0


func _amount(w: Dictionary, expl: bool) -> float:
	var base := float(w.get("damage_expl" if expl else "damage", 0.0))
	var kind := str(w.get("kind", ""))
	# resultDamage: (dam0 + damAdd) * damMult. Both come from the weapon's perk.
	if Progression and kind != "magic":
		base = (base + Progression.weapon_perk(w, "Det", 0.0)) * Progression.weapon_perk(w, "Dam", 1.0)
	var sk := _skill_mult(w)
	var amount := base
	if kind == "explosives":
		amount = base * (1.0 + (sk - 1.0) * 0.5) * _skill_conf(w)
	elif kind == "magic":
		amount = base * sk
	else:
		# resultDamage: (1 - breaking * 0.3), WClub (1 - breaking * 0.6).
		amount = base * sk * _skill_plus(w) * (1.0 - _breaking(w) * (0.6 if kind == "melee" else 0.3))
	if Progression:
		amount *= 1.0 + float(Progression.skill_level_of("attack")) * 0.05
		if kind == "melee":
			amount *= Progression.pers("meleeDamMult", 1.0)
		var chance := Progression.get_crit_chance() + Progression.weapon_perk(w, "Critch", 0.0)
		if chance > 0.0 and randf() < chance:
			amount *= Progression.get_crit_damage_multiplier()
	amount *= GameState.damage_dealt_mult(kind)
	if kind == "magic" or bool(w.get("spell", false)):
		amount *= GameState.spell_damage_mult()
		if Progression:
			amount *= Progression.pers("spellsDamMult", 1.0)
	amount *= _worn_dam_mult(w)
	return amount


## Pers.armorParameters: each worn piece (suit, then amulet) multiplies one
## damage channel. Weapon.setPers applies gunsDamMult for skill 2, 3, or 4
## (smallguns, repair, energy). WClub applies meleeDamMult. WMagic applies
## spellsDamMult. magicMult also scales throwForce in Progression.throw_force.
func _worn_dam_mult(w: Dictionary) -> float:
	if Inventory == null or Condition == null:
		return 1.0
	var kind := str(w.get("kind", ""))
	var sid := str(w.get("skill_id", ""))
	var key := ""
	if kind == "melee":
		key = "melee"
	elif kind == "magic":
		key = "magic"
	elif sid == "smallguns" or sid == "repair" or sid == "energy":
		key = "guns"
	if key == "":
		return 1.0
	var mult := 1.0
	for worn_id in Inventory.worn_ids():
		var row: Dictionary = Condition.armor_row(worn_id)
		mult *= float(row.get(key, 1.0))
	return mult


func _pay(w: Dictionary) -> bool:
	var kind := str(w.get("kind", ""))
	if kind == "magic" or bool(w.get("spell", false)):
		if not GameState.spells_allowed():
			_notice(OriginalLines.info("noSpells"))
			SfxBank.play("nomagic")
			_fire_cd = 0.25
			return false
		# WMagic: magic and mana times allDManaMult and warlockDManaMult. A bar at
		# 99% may fire anything. Both pools fail with noMana.
		var cost := _spell_costs(w, true)
		if GameState.spell_block(cost.x, cost.y, true) != "":
			_notice(OriginalLines.info("noMana"))
			SfxBank.play("nomagic")
			_fire_cd = 0.25
			return false
		GameState.pay_spell(cost.x, cost.y)
		return true
	if kind == "melee" or (kind == "internal" and str(w.get("ammo", "")) == ""):
		if not _uses_mag(w):
			return true
	if kind == "explosives":
		var toss := maxi(1, int(w.get("ammo_per_shot", 1)))
		if GameState.try_spend_ammo(toss):
			return true
		_dry_fire()
		return false
	return _pay_gun(w)


func _pay_gun(w: Dictionary) -> bool:
	var per := maxi(1, int(w.get("ammo_per_shot", 1)))
	var mag := int(w.get("mag", 0))
	var id := str(w.get("id", ""))
	if not _uses_mag(w):
		return true
	if _self_charges(w) and not _mag_rounds.has(id):
		_mag_rounds[id] = mag
	if not _mag_rounds.has(id):
		_mag_rounds[id] = 0
	if int(_mag_rounds[id]) >= per:
		return true
	# A recharge cell does not manual-reload. An empty inventory mag reloads instead of firing.
	if _self_charges(w):
		_dry_fire()
		return false
	_begin_reload(w, true)
	return false


## Weapon.status: 5 broken, 4 no ammo, 2 empty magazine, 6 no mana, 1 attacking, 3 reloading, 0 ready.
func weapon_status() -> int:
	var w := _weapon()
	if w.is_empty():
		return 0
	var id := str(w.get("id", ""))
	if Condition != null and id != "" and float(Condition.weapon_max(id)) > 0.0 and float(Condition.weapon_hp(id)) <= 0.0:
		return 5
	var per := maxi(1, int(w.get("ammo_per_shot", 1)))
	if _inventory_ammo(w) and int(w.get("mag", 0)) > 0 and int(_mag_rounds.get(id, 0)) < per:
		return 4 if _ammo_reserve(str(w.get("ammo", ""))) < per else 2
	if str(w.get("kind", "")) == "magic":
		var cost := _spell_costs(w, true)
		if GameState.spell_block(cost.x, cost.y, true) != "":
			return 6
	if _fire_cd > 0.0 or _burst_left > 0:
		return 1
	if _reload_left > 0.0:
		return 3
	return 0


func _breaking(w: Dictionary) -> float:
	# Weapon.setBreaking: 0 above half condition, rising to 1 at zero.
	var id := str(w.get("id", ""))
	if Condition == null or id == "":
		return 0.0
	var top := float(Condition.weapon_max(id))
	if top <= 0.0:
		return 0.0
	var hp := Condition.weapon_hp(id)
	if hp >= top / 2.0:
		return 0.0
	return (top - hp) / top * 2.0 - 1.0


func _spread_angle(w: Dictionary, index: int, pellets: int) -> float:
	var dev := float(w.get("spread", 0.0))
	var sk := _skill_mult(w)
	var wobble_deg := dev / (sk + 0.01)
	if str(w.get("kind", "")) != "explosives":
		# Weapon.shoot: deviation * (1 + breaking * 2).
		wobble_deg = dev * (1.0 + _breaking(w) * 2.0) / _skill_conf(w) / (sk + 0.01)
	# allPrecMult scales Weapon.resultPrec. This slice has no bullet precision,
	# so the same factor widens the deviation. mazilAdd is added in degrees.
	wobble_deg = wobble_deg / maxf(GameState.aim_prec_mult(), 0.05) + GameState.aim_mazil()
	if Progression:
		wobble_deg *= Progression.weapon_perk(w, "Dev", 1.0)
	var wobble := (randf() - 0.5) * wobble_deg * PI / 180.0
	var fan := (float(index) - (pellets - 1) * 0.5) * dev * PI / 360.0
	return wobble + fan


func _shoot_pellets(w: Dictionary) -> bool:
	var pellets := maxi(1, int(w.get("pellets", 1)))
	var origin := muzzle.global_position
	if str(w.get("kind", "")) == "magic" and puppet.has_method("spell_origin"):
		origin = puppet.spell_origin()
	var voice := _next_voice()
	var fired := false
	for i in pellets:
		var dir := aim_dir.rotated(_spread_angle(w, i, pellets))
		if _spawn_catalog(w, dir, origin, false, i, voice):
			fired = true
	return fired


func _grenade(w: Dictionary) -> bool:
	var origin := muzzle.global_position
	var cursor := _cursor_world()
	var rx := cursor.x - origin.x
	var ry := cursor.y - origin.y
	var sk := _skill_mult(w) * _skill_conf(w)
	var speed_tick := float(w.get("speed", 10.0))
	var dist := sqrt(rx * rx + ry * ry)
	var vel := minf(speed_tick * sk, dist / 10.0 * sk - ry / 10.0 * sk)
	vel = maxf(vel, 1.0)
	var ang := aim_dir.angle() + (-rx / (vel + 0.0001) / 100.0) + _spread_angle(w, 0, 1)
	var dir := Vector2.from_angle(ang)
	var bullet := _make_bullet(w, dir, origin, true)
	bullet.velocity = dir * vel * 30.0
	bullet.use_velocity = true
	bullet.fall_accel = 900.0
	# PhisBullet blows at liv == 3 of detTime.
	bullet.lifetime = maxf(float(w.get("det_time", w.get("fuse", 75))) - 3.0, 1.0) / 30.0
	bullet.explode_on_timeout = true
	bullet.phis = true
	bullet.bumc = bool(w.get("bumc", false))
	bullet.lip = int(w.get("throw_tip", 0)) == 2
	bullet.sensor = Progression.pers("grenader", 0.0) > 0.0 and not Input.is_action_pressed("sprint")
	var host := get_tree().current_scene
	if host == null:
		return false
	host.add_child(bullet)
	return true


func _mine(w: Dictionary) -> bool:
	var bullet := _make_bullet(w, Vector2.DOWN, global_position, true)
	# WThrow: sapper multiplies a player mine's damage.
	var sapper := Progression.pers("sapper", 1.0)
	if sapper > 1.0:
		bullet.damage = int(round(float(bullet.damage) * sapper))
	bullet.speed = 0.0
	bullet.velocity = Vector2.ZERO
	bullet.use_velocity = true
	bullet.lifetime = maxf(float(w.get("fuse", 75)), 1.0) / 30.0
	bullet.explode_on_timeout = true
	if int(w.get("radio", 0)) > 0:
		# WThrow char_radio (x37): sens 0 and no fuse. It waits for detonator().
		bullet.explode_on_timeout = false
		bullet.lifetime = 1.0e6
		bullet.set_meta("radio", str(w.get("id", "")))
		bullet.add_to_group("radio_mines")
	var host := get_tree().current_scene
	if host == null:
		return false
	host.add_child(bullet)
	return true


## WThrow.detonator: every radio mine of this id in play runs Mine.activate,
## then explodes after explTime (det_time) ticks.
func _detonator(w: Dictionary) -> bool:
	if int(w.get("radio", 0)) <= 0:
		return false
	var id := str(w.get("id", ""))
	var delay := maxf(float(w.get("det_time", 15)), 1.0) / 30.0
	for mine in get_tree().get_nodes_in_group("radio_mines"):
		if not is_instance_valid(mine) or str(mine.get_meta("radio", "")) != id:
			continue
		mine.remove_from_group("radio_mines")
		mine.set("explode_on_timeout", true)
		get_tree().create_timer(delay, false).timeout.connect(Callable(mine, "_on_timeout"))
	return true


func _next_voice() -> int:
	_voice_serial += 1
	return _voice_serial


func _spawn_catalog(w: Dictionary, dir: Vector2, origin: Vector2, expl: bool, pellet: int = 0, voice: int = -1) -> bool:
	var bullet := _make_bullet(w, dir, origin, expl or float(w.get("radius", 0.0)) > 0.0)
	bullet.pellet_index = pellet
	bullet.voice_key = voice
	var flame := int(w.get("flame", 0))
	var grav := float(w.get("grav", 0.0))
	var exact := bool(w.get("volna", false)) or grav > 0.0
	var px := float(w.get("speed", 100.0)) * 30.0
	if Progression:
		px *= Progression.weapon_perk(w, "Speed", 1.0)
	if not exact:
		px *= randf() * 0.4 + 0.8
	bullet.speed = px
	bullet.velocity = dir * px
	if flame > 0 or grav > 0.0:
		bullet.use_velocity = true
		bullet.fall_accel = grav * 900.0
		if flame == 1:
			bullet.fall_accel += -720.0
			bullet.lifetime = 200.0 / 7.0 / 30.0
		elif flame == 2:
			bullet.fall_accel += -180.0
			bullet.lifetime = 120.0 / 7.0 / 30.0
	else:
		bullet.lifetime = 100.0 / 30.0
	var host := get_tree().current_scene
	if host == null:
		return false
	host.add_child(bullet)
	return true


func _make_bullet(w: Dictionary, dir: Vector2, origin: Vector2, expl: bool) -> Area2D:
	var bullet := bullet_scene.instantiate() as Area2D
	bullet.global_position = origin
	bullet.direction = dir
	bullet.from_player = true
	bullet.damage = maxi(0, int(round(_amount(w, expl))))
	bullet.damage_type = str(w.get("damage_type", "DAM_PIERCE"))
	bullet.block_damage = _Block.of(str(w.get("id", "")))
	bullet.hitscan = false
	bullet.weapon_id = str(w.get("id", ""))
	bullet.blast_radius = float(w.get("radius", 0.0)) if expl or float(w.get("radius", 0.0)) > 0.0 else 0.0
	bullet.blast_radius *= Progression.pers("explRadMult", 1.0)
	bullet.explode_on_timeout = bullet.blast_radius > 0.0
	bullet.style = _style_of(w)
	bullet.range_px = float(w.get("range", 0.0)) * _prec_mult(w, dir)
	bullet.anti_px = float(w.get("antiprec", 0.0))
	bullet.miss_chance = maxf(0.0, 1.0 - _skill_conf(w))
	bullet.set_meta("prog_scaled", true)
	bullet.pier = float(w.get("pier", 0.0)) + Progression.weapon_perk(w, "Pier", 0.0)
	bullet.knock_mult = Progression.weapon_perk(w, "Knock", 1.0)
	if str(w.get("damage_type", "")) in ["DAM_LASER", "DAM_PLASMA"]:
		bullet.desintegr = Progression.pers("desintegr", 0.0)
	bullet.dop_effect = str(w.get("dop_effect", ""))
	bullet.dop_damage = float(w.get("dop_damage", 0.0))
	bullet.dop_chance = float(w.get("dop_chance", 1.0))
	var stun := Progression.weapon_perk(w, "Stun", 0.0)
	if stun > 0.0:
		# Weapon.setPers: <perk>Stun replaces the dop effect with a sure stun.
		bullet.dop_effect = "stun"
		bullet.dop_damage = stun
		bullet.dop_chance = 1.0
	if bullet.dop_effect != "":
		bullet.set_meta("dop_effect", bullet.dop_effect)
	return bullet


## Weapon.resultPrec: weapon precMult (allPrecMult, <perk>Prec) times the owner's
## precMult (allPrecMult and UnitPlayer's stance penalties from rungun / composure).
func _prec_mult(w: Dictionary, dir: Vector2) -> float:
	var all := Progression.pers("allPrecMult", 1.0)
	var stance := all
	# A running Sats queue skips the stance terms.
	if sats != null and sats.queued():
		return all * Progression.weapon_perk(w, "Prec", 1.0) * stance
	var stay := is_on_floor()
	var run_pen := Progression.pers("runPenalty", 0.5)
	if run_pen > 0.0 and (absf(velocity.x) > 300.0 or absf(velocity.y) > 300.0):
		stance *= 1.0 - run_pen
	if not stay:
		stance *= 1.0 - Progression.pers("jumpPenalty", 0.3)
	elif absf(velocity.x) < 30.0:
		stance *= 1.0 + Progression.pers("stayBonus", 0.3)
	if dir.x != 0.0 and signf(dir.x) != signf(facing):
		stance *= 1.0 - Progression.pers("backPenalty", 0.4)
	return all * Progression.weapon_perk(w, "Prec", 1.0) * stance


func _style_of(w: Dictionary) -> String:
	if int(w.get("flame", 0)) > 0:
		return "flame"
	var dtype := str(w.get("damage_type", ""))
	if float(w.get("radius", 0.0)) > 0.0 and dtype == "DAM_BURN":
		return "fireball"
	if int(w.get("pellets", 1)) > 1:
		return "pellet"
	match dtype:
		"DAM_LASER":
			return "laser"
		"DAM_PLASMA":
			return "plasma"
		"DAM_BURN":
			return "flame"
		_:
			return "bullet"


func _self_charges(w: Dictionary) -> bool:
	return int(w.get("recharg", 0)) > 0 or str(w.get("ammo", "")) == "recharg"


func _inventory_ammo(w: Dictionary) -> bool:
	var ammo := str(w.get("ammo", ""))
	return ammo != "" and ammo != "not" and not _self_charges(w)


func _uses_mag(w: Dictionary) -> bool:
	if int(w.get("mag", 0)) <= 0:
		return false
	var ammo := str(w.get("ammo", ""))
	return _inventory_ammo(w) or _self_charges(w) or ammo == "not"


func _on_weapon_drawn(w: Dictionary) -> void:
	if w.is_empty():
		return
	var id := str(w.get("id", ""))
	var cap := int(w.get("mag", 0))
	if _self_charges(w):
		# Recharge cells are born full. They do not take rounds from the bag.
		if cap > 0 and id != "" and not _mag_rounds.has(id):
			_mag_rounds[id] = cap
		return
	# Inventory-fed magazines start at 0 and keep their rounds across switches.
	# The first trigger pull on an empty one starts initReload.


func _poll_reload() -> void:
	# UnitPlayer: keyReload counts t_reload while held. Released before 10 ticks
	# it calls initReload. Held to 30 ticks it calls unloadWeapon.
	if not InputMap.has_action("reload") or Effects.attack_forever():
		return
	if Input.is_action_pressed("reload"):
		# A radio weapon spends the press on detonator() (ctr.keyReload = false).
		if _reload_hold <= 0.0 and _detonator(_weapon()):
			_reload_hold = 31.0
		var before := _reload_hold
		_reload_hold += get_physics_process_delta_time() * 30.0
		if before < 30.0 and _reload_hold >= 30.0:
			_unload_weapon(_weapon())
		return
	var tapped := _reload_hold > 0.0 and _reload_hold < 10.0
	_reload_hold = 0.0
	if not tapped or _chw_left > 0.0:
		return
	var w := _weapon()
	if w.is_empty() or _self_charges(w) or int(w.get("mag", 0)) <= 0:
		return
	_begin_reload(w, false)


func _unload_weapon(w: Dictionary) -> void:
	# Weapon.unloadWeapon: the magazine goes back to the bag with sndReload.
	if w.is_empty() or not _inventory_ammo(w) or Inventory == null:
		return
	var id := str(w.get("id", ""))
	var have := int(_mag_rounds.get(id, 0))
	if have <= 0:
		return
	Inventory.add(str(w.get("ammo", "")), have)
	_mag_rounds[id] = 0
	_notice(OriginalLines.info("unloadWeapon", OriginalLines.name_of(id)))
	_play_if_present(str(_WeaponVis.fx(id).get("snd_reload", "")))


func _begin_reload(w: Dictionary, from_trigger: bool) -> bool:
	if _self_charges(w):
		return false
	var cap := int(w.get("mag", 0))
	var id := str(w.get("id", ""))
	if cap <= 0 or id == "":
		return false
	var have := int(_mag_rounds.get(id, 0))
	if have >= cap:
		return false
	if _reload_left > 0.0 and _reload_id == id:
		return true
	var per := maxi(1, int(w.get("ammo_per_shot", 1)))
	var ammo := str(w.get("ammo", ""))
	if _inventory_ammo(w) and _ammo_reserve(ammo) < per:
		if from_trigger:
			_dry_fire()
		_notice(OriginalLines.info("noAmmo", OriginalLines.name_of(ammo)))
		return false
	# ammo_reload is frames at 30 Hz. The magazine fills when that wait ends.
	var dur := maxf(float(w.get("reload", 0.0)), 0.0) * Effects.stat("reloadMult", Progression.pers("reloadMult", 1.0)) / 30.0
	_reload_id = id
	if dur <= 0.0:
		_transfer_into_mag(w)
		return true
	_reload_left = dur
	_fire_cd = maxf(_fire_cd, dur)
	_present_reload(w)
	return true


func _push_gun_state() -> void:
	var w := _weapon()
	var held := _shoot_held() and _chw_left <= 0.0 and _hoof_work <= 0.0 and not w.is_empty()
	_tick_prep_sound(w, held)
	if puppet.has_method("weapon_prep"):
		puppet.weapon_prep(_prep * 30.0, _reload_left > 0.0)
	if puppet.has_method("set_weapon_hidden"):
		var thrown := str(w.get("kind", "")) == "explosives" and (_fire_cd > 0.0 or GameState.ammo < 1)
		puppet.set_weapon_hidden(thrown)


func _tick_prep_sound(w: Dictionary, attacking: bool) -> void:
	# Weapon.actions sndPrep: start at t_prep * 30 ms on press, jump back to
	# snd_t1 + 200 while held past snd_t2 - 300, and to snd_t2 + 100 on release.
	var fx := _WeaponVis.fx(str(w.get("id", "")))
	var snd := str(fx.get("snd_prep", ""))
	var was := _prep_was
	_prep_was = attacking
	if snd == "":
		if _prep_snd != null and _prep_snd.playing:
			_prep_snd.stop()
		return
	if _prep_snd == null:
		_prep_snd = AudioStreamPlayer.new()
		_prep_snd.name = "PrepSound"
		add_child(_prep_snd)
	var path := "res://assets/sfx/%s.wav" % snd
	if not ResourceLoader.exists(path):
		path = "res://assets/sfx/%s.mp3" % snd
	if not ResourceLoader.exists(path):
		return
	if _prep_snd.stream == null or _prep_snd.stream.resource_path != path:
		_prep_snd.stream = load(path) as AudioStream
	var t1 := float(fx.get("snd_t1", 0))
	var t2 := float(fx.get("snd_t2", 0))
	var length := _prep_snd.stream.get_length() * 1000.0 if _prep_snd.stream else 0.0
	var pos := _prep_snd.get_playback_position() * 1000.0 if _prep_snd.playing else length
	if not was and attacking:
		_prep_snd.play(_prep * 30.0 * 30.0 / 1000.0)
	elif t1 > 0.0 and attacking and pos > t2 - 300.0:
		_prep_snd.play((t1 + 200.0) / 1000.0)
	elif t2 > 0.0 and was and not attacking and _prep > 0.0 and _prep_snd.playing and pos < t2 - 400.0:
		_prep_snd.play((t2 + 100.0) / 1000.0)


func _present_reload(w: Dictionary) -> void:
	# Weapon.initReload: gotoAndPlay("reload") on an animated vis, then sndReload.
	_reload_filled = false
	if puppet != null and puppet.has_method("play_reload"):
		puppet.call("play_reload", w)
	_play_if_present(str(_WeaponVis.fx(str(w.get("id", ""))).get("snd_reload", "")))


func _transfer_into_mag(w: Dictionary) -> void:
	if w.is_empty() or _self_charges(w):
		return
	var cap := int(w.get("mag", 0))
	var id := str(w.get("id", ""))
	if cap <= 0 or id == "":
		return
	var have := int(_mag_rounds.get(id, 0))
	var room := cap - have
	if room <= 0:
		return
	var ammo := str(w.get("ammo", ""))
	if ammo == "" or ammo == "not":
		_mag_rounds[id] = cap
		return
	if not _inventory_ammo(w):
		return
	var reserve := _ammo_reserve(ammo)
	var take := mini(room, reserve)
	if take <= 0:
		return
	if Inventory and Inventory.spend(ammo, take):
		_mag_rounds[id] = have + take


func _commit_magazine(w: Dictionary) -> void:
	if not _uses_mag(w):
		return
	var per := maxi(1, int(w.get("ammo_per_shot", 1)))
	var id := str(w.get("id", ""))
	var have := int(_mag_rounds.get(id, 0))
	if have < per:
		return
	# recyc: energy cells sometimes are not spent.
	var recyc := Progression.pers("recyc", 0.0)
	if recyc > 0.0 and str(w.get("ammo", "")) in ["batt", "energ", "crystal"] and randf() < recyc:
		return
	_mag_rounds[id] = have - per


func _ammo_reserve(ammo: String) -> int:
	if ammo == "" or Inventory == null:
		return 0
	return Inventory.count(ammo)


func _tick_hoof(delta: float) -> void:
	_hoof_cd = maxf(0.0, _hoof_cd - delta)
	_hoof_work = maxf(0.0, _hoof_work - delta)
	if _hoof_hit > 0.0:
		_hoof_hit = maxf(0.0, _hoof_hit - delta)
		if _hoof_hit <= 0.0:
			_land_hoof()
	if not InputMap.has_action("melee") or not Input.is_action_pressed("melee") or not _Flags.allows("weapons"):
		_hoof_used = false
		return
	# keyPunch as a rat drinks the antidote: remEffect("potion_rat").
	if rat:
		if not _hoof_used:
			_hoof_used = true
			Effects.remove(self, "potion_rat")
		return
	# keyPunch as the alicorn is alicornPort.
	if ScriptsEngine.alicorn:
		if not _hoof_used:
			_hoof_used = true
			_alicorn_port(_cursor_world())
		return
	# keyPunch stays down until the swing starts or the key comes up. One swing per press.
	if _hoof_used or not _hoof_ready() or Effects.attack_forever() or not GameState.attack_allowed():
		return
	_hoof_used = true
	_hoof_kick = _kick_modifier()
	if _hoof_kick:
		_run_for_kick = true
	_hoof_cd = HOOF_RAPID
	_hoof_work = HOOF_RAPID
	_hoof_hit = HOOF_WINDUP


func _hoof_ready() -> bool:
	# UnitPlayer punches only while stay, not sitting, and not holding left or right.
	if _hoof_cd > 0.0:
		return false
	if not is_on_floor() or _climbing or _levitating:
		return false
	if _sitting_on_ground() or _ceiling_blocks_stand():
		return false
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
		return false
	return true


func _kick_modifier() -> bool:
	# WKick.kick = keyRun. "sprint" is Shift and L3, so Shift+F and L3+RB kick.
	return InputMap.has_action("sprint") and Input.is_action_pressed("sprint")


func _land_hoof() -> void:
	var kick := _hoof_kick
	var sign_x := -facing if kick else facing
	if sign_x == 0.0:
		sign_x = 1.0
	var far := KICK_FAR if kick else HOOF_FAR
	var top := -50.0
	var bottom := -30.0 if kick else -10.0
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(far - HOOF_NEAR, bottom - top)
	var mid := global_position + Vector2(sign_x * (HOOF_NEAR + far) * 0.5, (top + bottom) * 0.5)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = rect
	query.transform = Transform2D(0.0, mid)
	# World (destructibles), enemies and traps. The hoof does not shoot the equipped gun.
	query.collision_mask = 1 | 4
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	# powerkick: punchDamMult +0.5 and kickDestroy 80.
	var unit_damage := HOOF_DAMAGE * (2.0 if kick else 1.0) * Progression.pers("punchDamMult", 1.0)
	var block_damage := Progression.pers("kickDestroy", KICK_DESTROY) if kick else HOOF_DESTROY
	var seen: Dictionary = {}
	for found in space.intersect_shape(query, 16):
		var node := found.collider as Node
		if node == null or node == self:
			continue
		var id := node.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		if node.is_in_group("enemies") and node.has_method("take_hit"):
			_Resistances.apply(node, unit_damage * Progression.target_mult(node), HOOF_TYPE)
			SfxBank.play("hit")
		elif node.is_in_group("trap_units"):
			_Resistances.apply(node, unit_damage, HOOF_TYPE)
		elif node.is_in_group("destructibles"):
			_Resistances.apply(node, block_damage, HOOF_TYPE)


func _melee(w: Dictionary) -> bool:
	# WClub.weaponAttack starts t_attack at rapid_act. The swing lands in _melee_tick.
	if _melee_t > 0:
		if _melee_t > 10:
			_melee_combo = 0
		return false
	var fx := _WeaponVis.fx(str(w.get("id", "")))
	# resultRapid: rapid / skillConf * rapidMult (1 / meleeSpdMult). Saws skip rapidMult.
	var rapid := maxf(float(w.get("rapid", 5)), 1.0) / maxf(_skill_conf(w), 0.05)
	if _mtip_of(w) != 2:
		rapid /= _melee_spd()
	_melee_rapid = maxi(int(rapid), 1)
	_melee_t = _melee_rapid
	_melee_auto = 3
	_melee_power = 1.0
	_melee_struck.clear()
	_melee_prev.clear()
	_melee_snd = false
	_melee_tile_hit = false
	# combinat: every 4th blow inside rapid + 20 ticks hits twice as hard.
	# Weapons that are neither auto nor chargeable get it by default.
	var combinat := bool(fx.get("combo", false)) or (not bool(w.get("auto", false)) and not bool(fx.get("pow", false)))
	if combinat:
		_melee_t_combo = _melee_rapid + 20
		_melee_combo += 1
		if _melee_combo >= 4:
			_melee_power = 2.0
			_melee_combo = 0
	if _mtip_of(w) == 2:
		var knock := float(fx.get("knock", 0))
		_melee_quake = Vector2(randf() * knock, randf() * knock)
	return true


func _mtip_of(w: Dictionary) -> int:
	var id := str(w.get("id", ""))
	if MELEE_MTIP.has(id):
		return int(MELEE_MTIP[id])
	return int(MELEE_MTIP.get(id.split("^")[0], 0))


func _tick_carried_weapon(delta: float, cursor: Vector2) -> void:
	# The drawn weapon, which lags the selection while a change is under way.
	var w := _armed
	if str(w.get("kind", "")) != "melee":
		_carried.visible = false
		_carried_id = ""
		_melee_t = 0
		_wep_has = false
		return
	_show_carried(w)
	if not _wep_has:
		_melee_tick(w, cursor, false)
	_melee_acc += delta
	var guard := 0
	while _melee_acc >= TELE_TICK and guard < 3:
		_melee_acc -= TELE_TICK
		_melee_tick(w, cursor, true)
		guard += 1
	_dress_carried()


func _show_carried(w: Dictionary) -> void:
	var id := str(w.get("id", ""))
	if id != _carried_id:
		_carried_id = id
		_wep_has = false
		_melee_prev.clear()
		_melee_combo = 0
		_melee_pow = 0
		for child in _carried.get_children():
			child.free()
		_build_carried(w)
	_carried.visible = true


func _build_carried(w: Dictionary) -> void:
	# Grip at the origin, blade along +X, same space the swing already uses.
	var sprite := Sprite2D.new()
	sprite.name = "Vis"
	_melee_vis = _WeaponVis.clip(str(w.get("id", "")))
	if _melee_vis == null:
		return
	_melee_vis.goto_stop(1)
	_melee_vis.show(sprite)
	_carried.add_child(sprite)
	_WeaponVis.make_glow(sprite)
	# visVzz, the swing trail. vis_lasm weapons have none.
	_melee_vzz = null
	if not bool(_WeaponVis.fx(str(w.get("id", ""))).get("lasm", false)):
		var trail := _WeaponVis.fx_clip("visVzz")
		if trail != null:
			_melee_vzz = Sprite2D.new()
			_melee_vzz.name = "Vzz"
			trail.show(_melee_vzz)
			_melee_vzz.visible = false
			_melee_vzz.set_meta("clip", trail)
			_carried.add_child(_melee_vzz)


func _dress_carried() -> void:
	var sprite := _carried.get_node_or_null("Vis") as Sprite2D
	if sprite == null or _melee_vis == null:
		return
	_melee_vis.show(sprite)
	_WeaponVis.sync_glow(sprite, sprite.get_node_or_null("Glow") as Sprite2D, _WeaponVis.tele_color(), true)


func _melee_tick(w: Dictionary, cursor: Vector2, advance: bool) -> void:
	var mtip := _mtip_of(w)
	if _melee_t == _melee_rapid:
		_melee_cel_tile = Vector2i(floori(cursor.x / 40.0), floori(cursor.y / 40.0))
	var length := maxf(float(w.get("length", 50.0)), 1.0)
	var min_l := float(w.get("min_length", length))
	if min_l <= 0.0:
		min_l = length
	var height := CROUCH_SIZE.y if _sit else BODY_SIZE.y
	var weapon_y := global_position.y - height * 0.40
	if weapon_raised and _raised_clear(weapon_y - 40.0):
		weapon_y -= 40.0
	# UnitPlayer.setWeaponPos: during a change (t_work > 10) the weapon sits at half height.
	if _chw_left > 10.0:
		weapon_y = global_position.y - height * 0.5
	var side := facing if facing != 0.0 else 1.0
	var chest := Vector2(global_position.x, global_position.y - height * 0.75)
	var ds := 40.0 * side
	var cel := cursor
	if mtip == 0:
		cel = Vector2(cursor.x - length * 0.8 * side, cursor.y + length * 0.3)
		cel = _solid_stop(chest, cel)
		_wep_side = 1.0 if cursor.x > global_position.x - 100.0 * side else -1.0
	else:
		if mtip == 2 or _melee_t <= 0:
			_wep_aim = _solid_stop(chest, cursor)
		cel = _wep_aim
		if mtip == 2:
			var back := cel - Vector2(global_position.x + ds, weapon_y)
			var reach := length - (length - min_l) * 0.5
			cel -= back.limit_length(reach)
		_wep_side = 1.0 if cel.x > global_position.x else -1.0
	var del := (cel - Vector2(global_position.x + ds, weapon_y)).limit_length(MELEE_RANGE)
	ds = MELEE_SIDE * side
	var target := Vector2(global_position.x + ds + del.x, weapon_y + del.y)
	# setWeaponPos isLaz: the base point is the body centre; the pull toward the cursor stays.
	if _climbing:
		target.x = global_position.x + del.x
	if not _wep_has:
		_wep_pos = target
		_wep_has = true
	var step := (target - _wep_pos) * 0.5
	# norma(del, max(levitRun, 1 / massa)), massa = phis_massa / 50. No phis_massa, no cap.
	var massa := float(_WeaponVis.fx(str(w.get("id", ""))).get("massa", 0.0)) / 50.0
	if massa > 0.0:
		step = step.limit_length(maxf(MELEE_RUN, 1.0 / massa))
	if advance:
		_wep_blum = (step.x * _wep_side + step.y) * 0.5
		_wep_pos += step
	var is_pow := false
	if advance:
		is_pow = _melee_power_tick(w)
	var rot := _carried_rot(mtip, cel, height, is_pow)
	var thrust := Vector2.ZERO
	if mtip == 1 and _melee_t > 0:
		var anim := -0.25 if is_pow else _swing_anim(float(_melee_t), float(maxi(_melee_rapid, 1)))
		thrust = Vector2(cos(rot), sin(rot)) * anim * MELEE_THRUST
	if advance:
		# animate(): quake decays by a random 0.5..0.8 each tick, snapping to 0 under 1.
		_melee_quake *= randf_range(0.5, 0.8)
		if absf(_melee_quake.x) < 1.0:
			_melee_quake.x = 0.0
		if absf(_melee_quake.y) < 1.0:
			_melee_quake.y = 0.0
		_wep_pos = _keep_out_of_walls(_wep_pos, rot, length, chest)
	_carried.global_position = _wep_pos + thrust + _melee_quake
	# blumR is in degrees, added to the rotation in degrees.
	_carried.global_rotation = rot + deg_to_rad(_wep_blum)
	_carried.scale = Vector2(1.0, _wep_side)
	if advance:
		if not is_pow:
			_strike_melee(w, mtip, rot, thrust, length, min_l)
			if _melee_t > 0:
				_melee_t -= 1
		_melee_frames(w, mtip, length, is_pow)


func _melee_power_tick(w: Dictionary) -> bool:
	# Weapon.attack / WClub.actions: holding a chargeable weapon past the windup
	# freezes the swing at -0.25 and builds powerMult = 1 + pow / (rapid * 2.15).
	var rapid := float(maxi(_melee_rapid, 1))
	var held := _shoot_held() and _chw_left <= 0.0 and _hoof_work <= 0.0
	if held and not bool(w.get("auto", false)) and _melee_auto > 0:
		_melee_auto = 3
		_melee_pow += 1
	if _melee_auto > 0:
		_melee_auto -= 1
	else:
		_melee_pow = 0
	if _melee_t_combo > 0:
		_melee_t_combo -= 1
	else:
		_melee_combo = 0
	var chargeable := bool(_WeaponVis.fx(str(w.get("id", ""))).get("pow", false))
	if chargeable and _melee_t > 0 and float(_melee_t) < rapid * 5.0 / 6.0 and _melee_pow > 2 and float(_melee_pow) < rapid * 2.15:
		var charge := float(_melee_pow) / (rapid * 2.15)
		_melee_power = 1.0 + charge
		_melee_quake.y = charge * 30.0 * ((randf() - 0.5) if _mtip_of(w) == 1 else 1.0)
		return true
	return false


func _melee_frames(w: Dictionary, mtip: int, length: float, is_pow: bool) -> void:
	var rapid := float(maxi(_melee_rapid, 1))
	var t := float(_melee_t)
	var active := _melee_t > 0 and t >= rapid * 0.5 and t < rapid * 5.0 / 6.0
	# vis_lasm clips: frame 1 idle, 2 swinging, 3 inside the hit window.
	if _melee_vis != null and bool(_WeaponVis.fx(str(w.get("id", ""))).get("lasm", false)):
		_melee_vis.goto_stop(3 if active else (2 if _melee_t > 0 else 1))
	if _melee_vzz == null:
		return
	_melee_vzz.visible = mtip == 0 and active and not is_pow
	if not _melee_vzz.visible:
		return
	var trail = _melee_vzz.get_meta("clip")
	var strong := _melee_power > 1.5
	trail.goto_stop(2 if strong else 1)
	trail.show(_melee_vzz)
	_melee_vzz.modulate.a = 1.0 if strong else minf(10.0 / rapid, 1.0)
	_melee_vzz.scale = Vector2(length / 100.0, length / 100.0)


func _carried_rot(mtip: int, cel: Vector2, height: float, is_pow := false) -> float:
	var side := _wep_side if _wep_side != 0.0 else 1.0
	if mtip == 0:
		if _melee_t <= 0:
			return -PI * 0.5 - (PI / 6.0) * side
		var anim := -0.25 if is_pow else _swing_anim(float(_melee_t), float(maxi(_melee_rapid, 1)))
		return -PI * 0.5 + (-(PI / 6.0) + anim * PI) * side
	var chest := Vector2(global_position.x, global_position.y - height * 0.5)
	return (cel - chest).angle()


func _swing_anim(t: float, rapid: float) -> float:
	# WClub t_attack curve. Windup, then the fast half, then recover.
	if rapid <= 0.0:
		return 0.0
	if t >= rapid * 5.0 / 6.0:
		return -(rapid - t) / rapid * 1.5
	if t >= rapid * 0.5:
		return -0.25 + ((rapid - t) / rapid - (1.0 / 6.0)) * 3.75
	return t * 2.0 / rapid


func _strike_melee(w: Dictionary, mtip: int, rot: float, thrust: Vector2, length: float, min_l: float) -> void:
	if _melee_t <= 0:
		_melee_prev.clear()
		return
	var rapid := float(maxi(_melee_rapid, 1))
	var t := float(_melee_t)
	var dir := Vector2(cos(rot), sin(rot))
	var origin := _wep_pos + thrust
	if mtip == 2:
		if _melee_t == 1:
			_sweep_melee(origin + dir * min_l, origin + dir * length, w)
		return
	var points: Array[Vector2] = []
	if mtip == 1:
		points.append(origin + dir * length)
	else:
		var count := int(round(maxf(length - min_l, 0.0) / MELEE_SAMPLE))
		for i in count + 1:
			points.append(origin + dir * (min_l + float(i) * MELEE_SAMPLE))
	var active := t >= rapid * 0.5 and t < rapid * (5.0 / 6.0)
	if active and not _melee_snd:
		_melee_snd = true
		# WClub plays sndShoot at a random gain from 0.5 to 1.
		_play_if_present(str(w.get("sound", "")), randf_range(0.5, 1.0))
	if _melee_prev.size() != points.size():
		_melee_prev = points.duplicate()
		return
	if active:
		for i in points.size():
			_sweep_melee(_melee_prev[i] as Vector2, points[i], w)
	_melee_prev = points.duplicate()


func _sweep_melee(a: Vector2, b: Vector2, w: Dictionary) -> void:
	var dist := a.distance_to(b)
	var steps := maxi(int(ceil(dist / 9.0)), 1)
	for i in steps + 1:
		_touch_melee(a.lerp(b, float(i) / float(steps)), w, (b - a).normalized())


func _touch_melee(at: Vector2, w: Dictionary, motion := Vector2.ZERO) -> void:
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, at)
	# World, enemies, and shelves. Only enemies and destructibles take the hit.
	query.collision_mask = 1 | 4 | 64
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	_crack_crate(at, w, motion)
	for found in space.intersect_shape(query, 8):
		var node := found.collider as Node
		if node == null or node == self:
			continue
		var id := node.get_instance_id()
		if _melee_struck.has(id):
			continue
		if node.has_method("hit_tile"):
			_melee_tile(node, at, w, motion)
			continue
		var enemy := node.is_in_group("enemies") and node.has_method("take_hit")
		var block := node.is_in_group("destructibles")
		var trap := node.is_in_group("trap_units") and node.has_method("take_hit")
		if not enemy and not block and not trap:
			continue
		_melee_struck[id] = true
		# b.damage = curDam * powerMult (charged swing or the 4th combo blow).
		var dealt := _amount(w, false) * _melee_power
		var struck := float(_Block.of(str(w.get("id", "")))) if block else dealt
		var kind := str(w.get("damage_type", "DAM_BLUNT"))
		if enemy:
			_melee_impact(_ImpactFx.unit_material(node, kind), at, w, dealt)
			struck *= Progression.target_mult(node)
		_Resistances.apply(node, struck, kind)
		# WClub: knockx = storona.X, knocky = -0.2, otbros = otbros * otbrosMult * powerMult.
		if enemy and node.has_method("otbros"):
			node.otbros(Vector2(_wep_side, -0.2), float(_WeaponVis.fx(str(w.get("id", ""))).get("knock", 0)) * Progression.weapon_perk(w, "Knock", 1.0) * _melee_power)
		if node.has_method("apply_on_hit"):
			var stun := Progression.weapon_perk(w, "Stun", 0.0)
			if stun > 0.0:
				_roll_on_hit(node, "stun", stun, 1.0, int(round(dealt)))
			else:
				_roll_on_hit(node, str(w.get("dop_effect", "")), float(w.get("dop_damage", 0.0)), float(w.get("dop_chance", 1.0)), int(round(dealt)))
		_melee_crash(w, motion)


## Bullet.run on a solid tile: popadalo, sound, crash, then Location.hitTile with char_destroy.
func _melee_tile(wall: Node, at: Vector2, w: Dictionary, motion: Vector2) -> void:
	if _melee_tile_hit:
		return
	var rect: Rect2 = wall.call("decal_rect")
	if rect.has_area():
		at = at.clamp(rect.position, rect.end - Vector2(0.01, 0.01))
	if _mtip_of(w) == 0 and Vector2i(floori(at.x / 40.0), floori(at.y / 40.0)) != _melee_cel_tile:
		return
	_melee_tile_hit = true
	var id := str(w.get("id", ""))
	_melee_impact(_ImpactFx.surface_of(wall), at, w, _amount(w, false) * _melee_power)
	_melee_crash(w, motion)
	wall.call("hit_tile", at, _Block.of(id), str(w.get("damage_type", "DAM_BLUNT")), int(_WeaponVis.fx(id).get("tipdec", 0)))


## Bullet.run with crack (weapons.xml: only mont): the box under the cursor
## (loc.celObj) takes Box.udarBullet(b, 1) = damage(destroy) where the blade
## passes. Only a locked container (bulPlayer) takes it.
func _crack_crate(at: Vector2, w: Dictionary, motion: Vector2) -> void:
	var id := str(w.get("id", ""))
	if id.get_slice("^", 0) != "mont":
		return
	var cursor := _cursor_world()
	for props in get_tree().get_nodes_in_group("land_props"):
		var crates: Variant = props.get("_loot")
		if not (crates is Array) or not props.has_method("break_crate"):
			continue
		for crate in crates:
			if not is_instance_valid(crate) or _melee_struck.has(crate.get_instance_id()):
				continue
			var rect: Rect2 = props.call("_crate_rect", crate)
			if not rect.has_point(cursor) or not rect.has_point(at):
				continue
			_melee_struck[crate.get_instance_id()] = true
			if props.break_crate(crate, float(_Block.of(id))):
				var mat := int(str(_LandRegistry.obj(str(crate.get_meta("id", ""))).get("mat", "3")))
				_melee_impact(mat, at, w, _amount(w, false) * _melee_power)
				_melee_crash(w, motion)
			return


func _melee_impact(mat: int, at: Vector2, w: Dictionary, dealt: float) -> void:
	var id := str(w.get("id", ""))
	var fx := _WeaponVis.fx(id)
	var tip := int(fx.get("tipdec", 0))
	_ImpactFx.popadalo(get_tree(), at, mat, tip, dealt, str(fx.get("flare", "")))
	_ImpactFx.sound(mat, str(w.get("damage_type", "DAM_BLUNT")), id, tip)


func _melee_crash(w: Dictionary, motion: Vector2) -> void:
	# WClub.crash: 1 wear per blow plus the ammo's increasedWear, then the kickback shake.
	var id := str(w.get("id", ""))
	if Condition and Condition.has_method("_wear_weapon"):
		Condition.call("_wear_weapon", id, 1.0 + float(Condition.call("_extra_wear", id)))
	var knock := float(_WeaponVis.fx(id).get("knock", 0)) * Progression.weapon_perk(w, "Knock", 1.0)
	if knock > 5.0 and motion != Vector2.ZERO and CamShake != null:
		CamShake.quake(knock * motion.x, knock * motion.y)
	if _mtip_of(w) == 2 or motion == Vector2.ZERO:
		_melee_quake = Vector2(randf(), randf()) * knock * 2.0
	else:
		_melee_quake = -motion * knock


func _solid_stop(from: Vector2, to: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	if space == null:
		return to
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return to
	return hit.position


## The carried weapon's grip stays on the near side of walls, and a blade that
## would reach into one backs off along its own axis.
func _keep_out_of_walls(grip: Vector2, rot: float, length: float, chest: Vector2) -> Vector2:
	var p := _solid_stop(chest, grip)
	if p != grip:
		p += (chest - p).normalized() * 2.0
	var dir := Vector2(cos(rot), sin(rot))
	var tip := p + dir * length
	var hit := _solid_stop(p, tip)
	if hit != tip:
		var back := p - dir * (hit.distance_to(tip) + 2.0)
		if _solid_stop(chest, back) == back:
			p = back
	return p


func _raised_clear(at_y: float) -> bool:
	return _solid_stop(Vector2(global_position.x, at_y + 40.0), Vector2(global_position.x, at_y)) == Vector2(global_position.x, at_y)


func _play_if_present(name: String, volume: float = 1.0) -> void:
	if name == "":
		return
	var wav := "res://assets/sfx/%s.wav" % name
	var mp3 := "res://assets/sfx/%s.mp3" % name
	if ResourceLoader.exists(wav) or ResourceLoader.exists(mp3):
		SfxBank.play(name, volume)


func _spell_blast(w: Dictionary) -> void:
	var rad := float(w.get("radius", 500.0))
	var power := 1.0
	if Progression:
		power = 1.0 + 0.1 * float(Progression.rank("tele"))
	var dam := float(w.get("damage", 20.0)) * power
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		var body := enemy as Node2D
		var away := body.global_position - global_position
		var dist := away.length()
		if dist > rad or dist < 1.0:
			continue
		var sila := dam * (1.0 - dist / rad) * (randf() * 0.4 + 0.8)
		sila = minf(sila, dam)
		if "velocity" in body:
			body.velocity = away.normalized() * sila * 30.0
		# Spell.cast_blast: stun += random * telePower * dam, in ticks.
		if body.has_method("apply_stun"):
			body.apply_stun(int(randf() * power * float(w.get("damage", 20.0))))
	UnitFx.emit(get_tree(), "blast", global_position)


func _spell_dash(w: Dictionary) -> void:
	# Spell.cast_kdash does nothing under @levitoff.
	if not _Flags.allows("levit"):
		return
	var tele := 1.0
	if Progression:
		tele = 1.0 + 0.1 * float(Progression.rank("tele"))
	var spd := float(w.get("damage", 20.0)) * (1.0 + (tele - 1.0) * 0.5)
	# Spell.cast_kdash aims from the top of the box and pushes by at most spd.
	# kdash_t (prod) holds off gravity and braking, then velocity *= 0.3.
	var height := CROUCH_SIZE.y if _sit else BODY_SIZE.y
	var v := _cursor_world() - (global_position - Vector2(0.0, height))
	var rasst := v.length()
	if rasst < 0.001:
		v = Vector2(facing, 0.0)
	var prod := 15
	if spd > rasst / 15.0:
		prod = int(round(rasst / maxf(spd, 0.001))) + 1
	prod = maxi(prod, 7)
	_climbing = false
	_levitating = false
	velocity += v.limit_length(spd) * 30.0
	_kdash_left = float(prod) / 30.0


func _poll_run(delta: float) -> void:
	# UnitPlayer isRun = keyRun: runs only while held, on the pad too.
	# A press that was part of a kick chord does not run.
	var held := InputMap.has_action("sprint") and Input.is_action_pressed("sprint")
	if held:
		if not _run_down:
			_run_held_for = 0.0
			# Melee already down: this press is the strong kick, not a run.
			_run_for_kick = Input.is_action_pressed("melee")
		_run_held_for += delta
		_run_down = true
	elif _run_down:
		_run_down = false
		_run_held_for = 0.0
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
	if _climbing or _levitating or not is_on_floor():
		return false
	if _sitting_on_ground() or _diagon != 0:
		return false
	return true


func _note_run_stamina() -> void:
	# UnitPlayer drains stamRun * dstam only while moving on the ground.
	GameState.set_running(_ground_sprint() and absf(velocity.x) > 1.0)


func _footsteps(delta: float) -> void:
	# UnitPon.sndStep. t_walk advances one tick at 30 Hz and only those frames
	# play. Stopping does not zero the phase, so a floor flicker cannot retrigger.
	var tip := _step_tip()
	if tip == 0:
		_step_acc = 0.0
		return
	_step_acc += delta
	var guard := 0
	while _step_acc >= TELE_TICK and guard < 3:
		_step_acc -= TELE_TICK
		_emit_step(tip, _step_phase)
		_step_phase += 1
		guard += 1


func _step_tip() -> int:
	if _climbing:
		return 3 if absf(velocity.y) > 8.0 else 0
	if not is_on_floor() or _levitating or _sit:
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
	var volume := FOOT_VOL * step_vol
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
		volume = FOOT_VOL * 2.0 * step_vol
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
	SfxBank.play("lazstep%d" % leg if tip == 3 else _step_clip(leg), volume)


## UnitPon.sndStep / sndFall: metalstep on a metal floor (stayMat), else footstep;
## the 'a' take half the time (isrnd).
func _step_clip(leg: int) -> String:
	var base := "footstep"
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < -0.7:
			if _ImpactFx.surface_of(c.get_collider()) == _ImpactFx.METAL:
				base = "metalstep"
			break
	return "%s%d%s" % [base, leg, "a" if randf() < 0.5 else ""]


func _sitting_on_ground() -> bool:
	if _climbing or _levitating or not is_on_floor():
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
	var on_floor := is_on_floor()
	if down:
		if on_floor and not _sit and not _levitating and _diagon == 0 and _kdash_left <= 0.0:
			var downp := int(_down_for * 30.0 + 0.001)
			var one_way := _on_one_way()
			if (not one_way and downp == 1) or (one_way and downp == 5):
				_set_sit(true)
		_down_for = minf(_down_for + delta, 6.0 / 30.0)
	else:
		_down_for = 0.0
	if _sit and up and not down:
		_try_unsit()
		if not _sit:
			_up_for = 10.0 / 30.0
	if _sit and not on_floor:
		_try_unsit()
	# A low ceiling never lets the standing box in. Keep it down there.
	if not _sit and on_floor and _ceiling_blocks_stand():
		_set_sit(true)


func _ceiling_blocks_stand() -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	var band_h := BODY_SIZE.y - CROUCH_SIZE.y - 2.0
	rect.size = Vector2(BODY_SIZE.x - 4.0, band_h)
	query.shape = rect
	var center_y := -(CROUCH_SIZE.y + 1.0 + band_h * 0.5)
	query.transform = Transform2D(0.0, global_position + Vector2(0.0, center_y))
	# Layer 1 solids only. Floor crates are one-way shelves on layer 64.
	# Walking beside or onto them is not a low ceiling. A 40px hatch is.
	query.collision_mask = 1
	query.exclude = [get_rid()]
	for found in space.intersect_shape(query, 4):
		var node := found.collider as Node
		if node == null or node == self or _is_one_way(node):
			continue
		if node is CollisionObject2D and ((node as CollisionObject2D).collision_layer & 1) == 0:
			continue
		return true
	return false


func _pick_pose() -> String:
	if _climbing:
		_gait = ""
		return "climb"
	if _water.is_plav:
		_gait = ""
		return "swim"
	if _levitating:
		_gait = ""
		return "levitate"
	if not is_on_floor() or _kdash_left > 0.0:
		_gait = ""
		# aJump > 0 keeps vis.osn "jump" for the whole flight. Walking off a ledge plays pinok.
		return "jump" if _did_jump else "fall"
	if _lurked or _lurk_work == "lurk":
		_gait = ""
		return "lurk%d" % clampi(_lurk_tip, 1, 3)
	if _lurk_work == "unlurk":
		_gait = ""
		return "unlurk%d" % clampi(_lurk_tip, 1, 3)
	if _sit:
		_gait = ""
		return "crouch"
	_gait = _pick_gait()
	return _gait


func _pick_gait() -> String:
	# animatePlayerMovement on the ground, from velocity and maxSpeed, not the stick.
	var vx := velocity.x
	if _diagon == 0:
		if (absf(vx) <= 30.0 and _walk_dir != 0) or (absf(vx) <= 120.0 and _walk_dir == 0):
			return "idle"
	elif absf(vx) < 1.0:
		return "stairs_up_still" if float(_diagon) * facing > 0.0 else "stairs_down_still"
	if _diagon != 0:
		return "stairs_up" if float(_diagon) * facing > 0.0 else "stairs_down"
	if _max_speed < 150.0:
		return "walk"
	var walk_speed := SPEED * GameState.move_speed_mult()
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
	if _climbing or not is_on_floor():
		return
	var n := get_floor_normal()
	if absf(n.x) > 0.2:
		_diagon = -1 if n.x > 0.0 else 1


func _apply_body_box(crouch: bool) -> void:
	var size := RAT_SIZE if rat else (CROUCH_SIZE if crouch else BODY_SIZE)
	var full := size
	if _climbing:
		size.x = minf(size.x, CLIMB_BOX_W)
	var box := _body_shape.shape as RectangleShape2D
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
			global_position.x += dx
	box.size = size
	_body_shape.position = Vector2(0, -size.y * 0.5)
	var hurt := _hurt_shape.shape as RectangleShape2D
	if hurt:
		hurt.size = full + Vector2(4, 4)
		_hurt_shape.position = Vector2(0, -full.y * 0.5)
	var ladder := _ladder_shape.shape as RectangleShape2D
	if ladder:
		ladder.size = Vector2(40, size.y)
		_ladder_shape.position = Vector2(0, -size.y * 0.5)


## X shift that lets a box of size stand here without touching a wall, or NAN.
func _widen_offset(size: Vector2) -> float:
	var box := _body_shape.shape as RectangleShape2D
	var spare := (size.x - (box.size.x if box != null else size.x)) * 0.5
	for dx in [0.0, spare, -spare]:
		if _box_fits(global_position + Vector2(dx, 0.0), size):
			return dx
	return NAN


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
	for found in space.intersect_shape(query, 4):
		var node := found.collider as Node
		if node == null or node == self or _is_one_way(node):
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
	_jumpp = _Water.JUMP_RECHARGE
	_jump_count = 1
	_t_run = 0.0
	floor_snap_length = 0.0
	set_collision_mask_value(PLATFORM_LAYER_BIT, false)
	_max_speed = _Water.PLAV_SPEED
	_walk_dir = _water.swim(self, delta, up, down, key_left, key_right, GameState.move_speed_mult())


func set_sky_mode(on: bool) -> void:
	sky_mode = on
	if on and is_node_ready():
		_climbing = false
		_levitating = false
		_set_sit(false)
		floor_snap_length = 0.0


## Unit.forces and UnitPlayer.control with isFly in a sky room: maxSpeed is
## walkSpeed * 3 * 1.3 and accel1 is 0.5 * accel; keyBeUp / keySit add levidy
## (accel * 0.25, alicorn 0.5). The alicorn holding keyRun with mana over 20
## takes full accel up to runSpeed * alicornFlyMult * 2 and pays
## alicornRunMana a tick. Over maxSpeed the velocity is cut by 0.7 a tick, and
## an axis under brake (2 px/tick) stops. Nothing else slows the flight.
## Steps whole 30 Hz ticks: the brake snap is larger than one tick of accel1.
func _sky_step(delta: float, key_left: bool, key_right: bool, up: bool, down: bool) -> void:
	var max_speed := SPEED * GameState.move_speed_mult() * 1.3
	var accel := ACCEL * 0.5
	var alicorn := ScriptsEngine != null and ScriptsEngine.alicorn
	var levidy := ACCEL * (0.5 if alicorn else 0.25)
	if alicorn and Input.is_action_pressed("sprint") and GameState.magic > 20.0:
		accel = ACCEL
		max_speed = RUN_SPEED * GameState.move_speed_mult() * Progression.pers("alicornFlyMult", 1.0) * 2.0
		if key_left or key_right or up:
			GameState.channel(Progression.pers("alicornRunMana", 5.0), false)
	var walk := 0
	if key_left and not key_right:
		walk = -1
	elif key_right and not key_left:
		walk = 1
	var tick := 1.0 / 30.0
	var damp := 0.96 if Input.is_action_pressed("sprint") else 0.9
	_sky_acc += delta
	while _sky_acc >= tick:
		_sky_acc -= tick
		var v := velocity * tick
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
		velocity = v / tick
	_walk_dir = walk
	_max_speed = max_speed
	_t_run = 0.0
	_jump_count = 1
	floor_snap_length = 0.0


## UnitPlayer jerk to the side: keyDash toward storona. The port triggers it by
## sprint pressed twice (PadGestures) instead of a direction double tap with
## keyRun held. Only standing, not sitting, dash_t spent, stam > 200, no
## overload, not the rat.
func _dash_step(delta: float, _key_left: bool, _key_right: bool, on_floor: bool) -> bool:
	_dash_t = maxf(0.0, _dash_t - delta * 30.0)
	if not (InputMap.has_action("dash") and Input.is_action_just_pressed("dash")):
		return false
	var dir := 1 if facing >= 0.0 else -1
	if not on_floor or _sit or _dash_t > 0.0 or GameState.stam <= 200.0 or Inventory.overload_max_speed() < 100.0 or rat:
		return false
	if dir > 0:
		velocity.x = maxf(velocity.x, DASH_SPEED)
	else:
		velocity.x = minf(velocity.x, -DASH_SPEED)
	velocity.y += DASH_DY
	_dash_t = DASH_MAXT
	_jump_count = 2
	_djump = false
	_jumpp = 0.0
	floor_snap_length = 0.0
	GameState.spend_dash_stamina()
	return true


func _step_jump(delta: float, jump_held: bool, jump_just: bool, move_x: float, key_left: bool, key_right: bool) -> void:
	# kdash_t keeps stay false, skips gravity and braking until its last tick.
	_djump2 = false
	var dashing := _kdash_left > 0.0
	var on_floor := is_on_floor() and not dashing
	if _dash_step(delta, key_left, key_right, on_floor):
		on_floor = false
		jump_held = false
		jump_just = false
	# trauma_mana stage 4 clears isDJ.
	# Location.levitOn (@levitoff) takes the double jump and self-levitation.
	var levit_on := _Flags.allows("levit")
	var has_dj := _owns_perk("levitation") and GameState.spells_allowed() and levit_on
	var has_hover := _owns_perk("selflevit") and levit_on
	if on_floor and not jump_held:
		_jumpp = JUMP_SUSTAIN
		_djump = false
		_air_kicked = false
		_jump_count = 0
		_did_jump = false
	elif not on_floor and not jump_held and has_dj and _jump_count <= 1:
		_jumpp = AIR_JUMP_HOLD
		_djump = true
		_air_kicked = false
	elif not jump_held and _jump_count == 0:
		_jump_count = 1

	if jump_just:
		_jump_count += 1

	if not on_floor and jump_held:
		_jumpp = maxf(0.0, _jumpp - delta)
	if not on_floor and not jump_held and not (has_dj and _jump_count <= 1):
		_jumpp = 0.0

	var hover_after := 2 if has_dj else 1
	if jump_held and has_hover and GameState.hover_allowed() and not on_floor and _jumpp <= 0.0 and _jump_count > hover_after:
		_levitating = true
	elif not jump_held or on_floor:
		_levitating = false

	var kicked := false
	if _levitating and jump_held and not on_floor:
		floor_snap_length = 0.0
		var lift := Input.get_axis("aim_up", "aim_down")
		velocity.y = move_toward(velocity.y, lift * LEVITATE_SPEED, 900.0 * delta)
	elif jump_held and _jumpp > 0.0 and not (_djump and (on_floor or not has_dj)):
		floor_snap_length = 0.0 if not on_floor else 1.0
		if _djump and has_dj and not on_floor:
			_djump2 = true
			velocity.y = _air_jump_velocity()
			if not _air_kicked:
				_air_kicked = true
				_jump_count = 3
				kicked = true
				# UnitPlayer.jump: Emitter.emit('quake') on the air jump's first push.
				UnitFx.emit(get_tree(), "quake", global_position)
			_did_jump = true
		else:
			velocity.y = _jump_velocity()
			_did_jump = true
	elif dashing:
		floor_snap_length = 0.0
	elif not on_floor:
		floor_snap_length = 1.0
		velocity.y += GRAVITY * delta * (0.1 if _dash_t > DASH_MAXT - 11.0 else 1.0)
		velocity.y = minf(velocity.y, MAX_FALL)
	else:
		floor_snap_length = 1.0

	if _levitating:
		velocity.x = move_x * SPEED * GameState.move_speed_mult() * 0.75
		_walk_dir = 0
		_max_speed = SPEED
		_t_run = 0.0
	else:
		if not dashing:
			_forces_x(delta, on_floor)
		_control_x(delta, key_left, key_right, on_floor)
	if kicked:
		# One tick of djumpdy * 0.5 sideways. The result is capped at 25 px/tick.
		var kick := absf(_air_jump_velocity()) * 0.5
		if key_left:
			velocity.x -= kick
		if key_right:
			velocity.x += kick
		velocity.x = clampf(velocity.x, -DJUMP_CAP, DJUMP_CAP)
	if dashing:
		_kdash_left -= delta
		if _kdash_left <= 0.0:
			_kdash_left = 0.0
			velocity *= 0.3


func _forces_x(delta: float, on_floor: bool) -> void:
	# Unit.forces runs before control(), with last tick's walk and maxSpeed.
	# Walking above maxSpeed bleeds brake1 per tick. No walk brakes to zero.
	var brake := BRAKE * (0.4 if _sit else 1.0)
	if not on_floor:
		brake = BRAKE * 0.1
	var step := brake * delta
	if _walk_dir < 0:
		if velocity.x < -_max_speed:
			velocity.x = minf(velocity.x + step, -_max_speed)
	elif _walk_dir > 0:
		if velocity.x > _max_speed:
			velocity.x = maxf(velocity.x - step, _max_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, step)


func _control_x(delta: float, key_left: bool, key_right: bool, on_floor: bool) -> void:
	# UnitPlayer.control [speed] and [acceleration]. trauma_legs allSpeedMult is on every gait.
	var walk_speed := SPEED * GameState.move_speed_mult()
	var accel := ACCEL
	var max_speed := walk_speed
	# stay && keyAction: accel * 0.4 and maxSpeed 3. Run, sit and stairs are assigned after and replace it.
	if on_floor and _use_node != null and max_speed > ACTION_CREEP:
		accel = ACCEL * 0.4
		max_speed = ACTION_CREEP
	if on_floor and _run_wants():
		max_speed = RUN_SPEED * GameState.move_speed_mult() * GameState.sprint_speed_mult()
	if on_floor and _sit:
		max_speed = walk_speed * SIT_SCALE
	if _diagon != 0:
		max_speed = walk_speed * STAIR_SCALE
	# Heavy weapons (massa = phis_massa / 50) slow running. bigsize sets bigGunsSlow to 0.
	var massa := float(_weapon().get("phis_massa", 0.0)) / 50.0
	var big_slow := Progression.pers("bigGunsSlow", 1.0)
	if max_speed > walk_speed and massa >= 0.1 and big_slow > 0.0:
		max_speed *= 1.0 - massa * big_slow
	if not on_floor:
		accel = AIR_ACCEL
	var walk := 0
	if key_left and not key_right:
		walk = -1
	elif key_right and not key_left:
		walk = 1
	if walk != 0:
		if velocity.x * walk < max_speed and (not _run_wants() or _t_run > RUN_DELAY):
			velocity.x += walk * accel * delta
			if velocity.x * walk > max_speed:
				velocity.x = walk * max_speed
		_t_run += delta
	else:
		_t_run = 0.0
	_walk_dir = walk
	_max_speed = max_speed


func _owns_perk(id: String) -> bool:
	return Progression.perk_rank(id) > 0


func _jump_velocity() -> float:
	# jumpdy 12, trauma_legs adds -2 at stage 3.
	return JUMP_VELOCITY * GameState.jump_velocity_mult()


func _air_jump_velocity() -> float:
	# djumpdy v0=6 vd=1 per Telekinesis level, in px/tick, times 30.
	return -30.0 * Progression.djump_dy()


func _tick_slow(delta: float) -> void:
	if _slow_left <= 0.0:
		if _inh_ring:
			_inh_ring.visible = false
		return
	_slow_left = maxf(0.0, _slow_left - delta)
	if _slow_left <= 0.0 and _inh_ring:
		_inh_ring.visible = false
	_slow_tick -= delta
	if _slow_tick > 0.0:
		return
	_slow_tick = 1.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) > _slow_radius:
			continue
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(40.0 / 30.0)


func _start_slow(entry: Dictionary) -> void:
	var power := 1.0 + 0.1 * float(Progression.rank("magic"))
	_slow_radius = float(entry.get("radius", 200)) * power
	_slow_left = 60.0
	_slow_tick = 0.0
	if _inh_ring:
		_inh_ring.call("play_from", 1)


func _spell_cooldown(entry: Dictionary) -> float:
	# t_culd = round(culd * 30 * spellDown) ticks. spellDown drops 0.1 per Magic level.
	return roundf(_spell_culd_base(entry) * 30.0 * Progression.spell_down()) / 30.0


func _take_interact(cursor: Vector2) -> void:
	var pressed := _interact_queued or Input.is_action_just_pressed("interact")
	if not pressed:
		return
	_interact_queued = false
	var frame := Engine.get_process_frames()
	if _interact_frame == frame:
		return
	_interact_frame = frame
	if _tele_obj != null and is_instance_valid(_tele_obj):
		set_meta("tk_claim", true)
		_throw_tele()
		return
	if _use_node != null:
		return
	_try_tele_use(cursor)


func _update_telekinesis(held: bool, cursor: Vector2, delta: float) -> void:
	# actTele: each keyTele press toggles. It drops what is held, or grabs
	# when the magic bar has at least 200. Telekinesis.hold then steers the body
	# toward the cursor until a drop rule fires.
	var pressed := held and not _tk_was_down
	_tk_was_down = held
	_tick_port(held, cursor, delta)
	if _tele_obj != null and not is_instance_valid(_tele_obj):
		_tele_obj = null
	# Telekinesis.hold: another caster's grab replaced teleHolder; drop the reference only.
	if _tele_obj != null and _tele_obj.get_meta("tele_holder", self) != self:
		_tele_obj = null
		_tele_vel = Vector2.ZERO
		_tele_acc = 0.0
	if pressed:
		if _tele_obj != null:
			_drop_tele()
		else:
			_try_grab(cursor)
	if _tele_obj != null and not _tele_keeps():
		_drop_tele()
	_tick_magic_channel()
	if _tele_obj == null:
		return
	_steer_tele(cursor, delta)


## spell_port (Pers.portPoss): keyTele held for portTime ticks counts t_port; letting go
## then runs actPort. The GUI portCel shows past 15 ticks.
func _tick_port(held: bool, cursor: Vector2, delta: float) -> void:
	var can := Progression.pers("portPoss", 0.0) > 0.0 and GameState.spells_allowed() and not (ScriptsEngine != null and ScriptsEngine.alicorn)
	if _port_cut:
		_port_cut = held
		held = false
	elif held and Input.is_action_just_pressed("shoot"):
		_port_cut = true
		_port_shot_cut = true
		_t_port = 0.0
		held = false
	if held and not Input.is_action_pressed("interact") and not Travel.can_travel_here():
		if can and not _spell_culd.has("port"):
			_t_port += delta * 30.0
	else:
		if _t_port >= PORT_TIME and can and _Flags.allows("port"):
			_act_port(cursor)
		_t_port = 0.0
	_show_port_cel(cursor)


func _port_feet(cursor: Vector2) -> Vector2:
	return Vector2(roundf(cursor.x / 40.0) * 40.0, roundf(cursor.y / 40.0 + 1.0) * 40.0 - 1.0)


## checkPort: magic over portMana, a tile the player can see, and room to stand there.
func _check_port(cursor: Vector2) -> bool:
	if GameState.magic < PORT_MANA * GameState.mana_cost_mult():
		return false
	if sky_mode:
		return true
	var feet := _port_feet(cursor)
	# t.visibility >= 0.8: lit now or remembered, no line of sight needed.
	var fog := get_tree().get_first_node_in_group("fog")
	if fog != null and fog.get("_state") != null:
		if float(fog.call("tile_seen", cursor)) < 0.8:
			return false
	else:
		var eye := global_position + Vector2(0.0, -BODY_SIZE.y * 0.75)
		if not Sight.los_clear(eye, Vector2(roundf(cursor.x / 40.0) * 40.0, roundf(cursor.y / 40.0) * 40.0)):
			return false
	var space := get_world_2d().direct_space_state
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE - Vector2(2.0, 2.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = rect
	query.transform = Transform2D(0.0, feet - Vector2(0.0, BODY_SIZE.y * 0.5))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	for found in space.intersect_shape(query, 4):
		var node := found.collider as Node
		if node != null and node != self and not _is_one_way(node):
			return false
	return true


## actPort: Unit.teleport(eff 1), then manaSpell(portMagic, portMana) and t_culd = spellDown * portDown.
func _act_port(cursor: Vector2) -> void:
	var mult := GameState.mana_cost_mult()
	if GameState.magic < PORT_MANA * mult and GameState.magic < float(GameState.MAX_MAGIC) * 0.99:
		_notice(OriginalLines.info("overMana"))
		return
	if not _check_port(cursor):
		return
	UnitFx.emit(get_tree(), "tele", global_position - Vector2(0.0, BODY_SIZE.y * 0.5), {"rx": BODY_SIZE.x, "ry": BODY_SIZE.y, "kol": 30})
	# Unit.teleport: setPos keeps dx / dy; only levit is cleared.
	global_position = _port_feet(cursor)
	_levitating = false
	UnitFx.emit(get_tree(), "teleport", global_position - Vector2(0.0, BODY_SIZE.y * 0.5))
	SfxBank.play("teleport")
	_fog_relight()
	GameState.pay_spell(PORT_MAGIC * mult, PORT_MANA * mult)
	if _tele_obj != null:
		_drop_tele()
	# loc.electroDam: blinking into a live room shocks and sets the player alight.
	var land := _Flags.active_land()
	var actors := land.get_node_or_null("Actors") if land != null else null
	var electro := float(actors.call("room_electro", _Flags.cell_of(global_position))) if actors != null and actors.has_method("room_electro") else 0.0
	if electro > 0.0:
		GameState.apply_damage_f(electro, "DAM_ELECTRIC", true)
		SfxBank.play("electro")
		Effects.add(self, "burning", 40)
		UnitFx.emit(get_tree(), "iskr", global_position + Vector2(0, -39), {"kol": 40})
	_spell_culd["port"] = Progression.spell_down() * PORT_DOWN / 30.0


## alicornPort: no cooldown and no manaHP, alicornPortMana off the magic bar.
func _alicorn_port(cursor: Vector2) -> void:
	var cost := Progression.pers("alicornPortMana", 500.0)
	if GameState.magic < cost and GameState.magic < float(GameState.MAX_MAGIC) * 0.99:
		_notice(OriginalLines.info("overMana"))
		return
	if not _check_port(cursor):
		return
	UnitFx.emit(get_tree(), "tele", global_position - Vector2(0.0, BODY_SIZE.y * 0.5), {"rx": BODY_SIZE.x, "ry": BODY_SIZE.y, "kol": 30})
	global_position = _port_feet(cursor)
	_levitating = false
	UnitFx.emit(get_tree(), "teleport", global_position - Vector2(0.0, BODY_SIZE.y * 0.5))
	SfxBank.play("teleport")
	_fog_relight()
	if _tele_obj != null:
		_drop_tele()
	GameState.pay_spell(cost, 0.0)


func _fog_relight() -> void:
	var fog := get_tree().get_first_node_in_group("fog")
	if fog != null:
		fog.call("relight_after_jump")


func _show_port_cel(cursor: Vector2) -> void:
	if _t_port <= 15.0:
		if _port_cel != null:
			_port_cel.visible = false
		return
	if _port_cel == null:
		_port_cel = Sprite2D.new()
		_port_cel.top_level = true
		_port_cel.z_index = 50
		_port_cel.centered = true
		add_child(_port_cel)
	var frame := 3
	if _check_port(cursor):
		frame = 1 if _t_port < PORT_TIME else 2
	_port_cel.texture = load(_PORT_CEL % frame) as Texture2D
	_port_cel.global_position = Vector2(roundf(cursor.x / 40.0) * 40.0, roundf(cursor.y / 40.0) * 40.0)
	_port_cel.visible = true


func _try_grab(cursor: Vector2) -> void:
	_heavy_id = 0
	_hide_id = 0
	if GameState.magic < 200.0 or not _Flags.allows("tele"):
		return
	var pick := _pick_aimed(cursor, ["levitatable", "enemies", "ground_loot", "pickups"], _tele_radius(), TELE_SNAP, false)
	if pick == null:
		return
	if _tele_needs_los() and not _los_to(pick):
		_show_hidden(pick)
		return
	if not _levit_poss(pick):
		return
	if _tele_massa(pick) > _max_tele_massa():
		_show_too_heavy(pick)
		return
	_grab_tele(pick)
	if pick.is_in_group("enemies"):
		pick.set_meta("levit_r", _levit_r(pick))


## UnitPlayer drop rules: past teleDist * 1.2, magic bar at 0, a unit held past
## levit_max * unitLevitMult breaks free (levitPoss off until levit_r decays).
func _tele_keeps() -> bool:
	var reach := _tele_radius()
	if global_position.distance_squared_to(_body_center(_tele_obj)) > reach * reach * 1.2:
		return false
	if GameState.magic <= 0.0:
		return false
	if _tele_obj.is_in_group("enemies"):
		if bool(_tele_obj.get("_dead")):
			return _tele_obj.is_in_group("levitatable")
		var r := float(_tele_obj.get_meta("levit_r", 0.0)) + get_physics_process_delta_time() * 30.0
		_tele_obj.set_meta("levit_r", r)
		var cap := float(_UnitMassa.row(_tele_obj).get("levit_max", 0))
		if cap > 0.0 and r > cap * Progression.unit_levit_mult():
			_tele_obj.set_meta("levit_broke", true)
			return false
	return true


## Unit.levit_r: counts up while lifted, down (from at most 60) while free.
## levitPoss comes back once it is down to 1.
func _levit_r(body: Node) -> float:
	var r := minf(float(body.get_meta("levit_r", 0.0)), 60.0)
	var since := float(Time.get_ticks_msec() - int(body.get_meta("levit_r_at", 0))) * 0.03
	return maxf(0.0, r - since)


func _levit_poss(body: Node) -> bool:
	if not body.is_in_group("enemies"):
		return true
	var data := _UnitMassa.row(body)
	if not data.is_empty() and not bool(data.get("levit", true)):
		return false
	if bool(body.get_meta("levit_broke", false)):
		if _levit_r(body) > 1.0:
			return false
		body.set_meta("levit_broke", false)
	return true


## Obj.massa: units from units.xml, crates from objs.xml, loot 0.1.
func _tele_massa(body: Node) -> float:
	if body.is_in_group("enemies"):
		return _UnitMassa.massa(body)
	return _carried_massa(body)


## Pers.maxTeleMassa (Telekinesis level table) times the trauma_mana stage mult.
func _max_tele_massa() -> float:
	return Progression.max_tele_mass() * GameState.tele_mass_mult()


## UnitPlayer.actions mana block: a held object costs sqrt(massa) * teleMult per
## tick above telePorog, self-levitation levitDMana plus levitDManaUp while rising.
func _tick_magic_channel() -> void:
	var holding := _tele_obj != null
	if not holding and not _levitating:
		return
	var drain := 0.0
	if holding:
		var m := _tele_massa(_tele_obj)
		if m > Progression.tele_porog():
			drain += sqrt(m) * Progression.tele_mult()
	if _levitating:
		drain += Progression.levit_dmana()
		if Input.is_action_pressed("aim_up"):
			drain += Progression.levit_dmana_up()
	GameState.channel(drain, _levitating)


## throwTele (keyAction while holding): throwDmagic * massa off the magic bar,
## 5% of that off manaHP, then the object gets throwForce away from the player.
## A short bar scales the force down. Without spells the hold just drops.
func _throw_tele() -> void:
	var body := _tele_obj
	if not GameState.spells_allowed():
		_drop_tele()
		return
	var force := Progression.throw_force()
	var dm := 0.0
	if force > 0.0:
		dm = _tele_massa(body) * Progression.throw_dmagic() * GameState.mana_cost_mult()
	var have := maxf(GameState.magic, 0.0)
	if dm <= have:
		GameState.drain_magic(dm)
		GameState.damage_mana(dm * 0.05)
	else:
		force *= have / dm
		GameState.damage_mana(have * 0.05)
		GameState.drain_magic(GameState.magic)
	# Settings.VANILLA_THROW trims the carry speed to teleAccel * 4 first.
	var vel := _tele_vel.limit_length(Progression.tele_accel() * 4.0)
	var away := _body_center(body) - (global_position + Vector2(0.0, -(CROUCH_SIZE.y if _sit else BODY_SIZE.y) * 0.5 - 10.0))
	_tele_vel = vel + away.limit_length(force)
	if "t_throw" in body:
		body.t_throw = 2
	_drop_tele(false)
	if force > 0.0:
		SfxBank.play("dash")


func _push_horn_glow() -> void:
	var w := _weapon()
	var kind := str(w.get("kind", ""))
	var spell_weapon := kind == "magic" or bool(w.get("spell", false)) or str(w.get("delivery", "")) == "spell"
	var weapon_held := false
	if not w.is_empty() and kind != "internal" and not spell_weapon:
		if kind == "melee":
			weapon_held = true
		elif puppet.has_method("weapon_visible"):
			weapon_held = bool(puppet.weapon_visible())
	var tele := _tele_obj != null and is_instance_valid(_tele_obj)
	var heavy := tele and _carried_massa(_tele_obj) >= 1.0
	var spell := _cast_glow > 0.0 or _crystal_on or _shit_hp > 0.0 or _blood_left > 0.0 or _slow_left > 0.0
	if _moon != null and is_instance_valid(_moon):
		spell = true
	puppet.set_magic_activity(weapon_held, tele, spell, heavy)


func _carried_massa(body: Node) -> float:
	# Loot.massa is 0.10. A crate at or above 1 is the heavy horn glow.
	if "massa" in body:
		return float(body.massa)
	if body.has_meta("massa"):
		return float(body.get_meta("massa"))
	if body.is_in_group("ground_loot") or body.is_in_group("pickups"):
		return 0.1
	return 1.0


func _grab_tele(body: Node2D) -> void:
	_release_strays(body)
	_detach_from_player(body)
	_tele_obj = body
	_tele_vel = Vector2.ZERO
	_tele_acc = 0.0
	_mark_tele(body, true)
	_Aura.attach(body)
	# Telekinesis.grab: setChildIndex(vis, numChildren - 1).
	var layer := body.get_parent()
	if layer != null:
		layer.move_child(body, layer.get_child_count() - 1)


func _detach_from_player(body: Node2D) -> void:
	var walk: Node = body.get_parent()
	var under := false
	while walk:
		if walk == self:
			under = true
			break
		walk = walk.get_parent()
	if not under:
		return
	var host := get_tree().current_scene
	if host == null or host == body:
		return
	var at := body.global_position
	body.reparent(host)
	body.global_position = at


func _drop_tele(trim: bool = true) -> void:
	var body := _tele_obj
	# Telekinesis.release trims to teleAccel * 4 (Settings.VANILLA_THROW).
	var leftover := (_tele_vel.limit_length(Progression.tele_accel() * 4.0) if trim else _tele_vel) * 30.0
	_tele_obj = null
	if body != null and is_instance_valid(body) and body.is_in_group("enemies"):
		body.set_meta("levit_r_at", Time.get_ticks_msec())
	_tele_vel = Vector2.ZERO
	_tele_acc = 0.0
	if body == null or not is_instance_valid(body):
		return
	_Aura.clear(body)
	body.set_meta("tele_driven", false)
	if body.has_meta("tele_holder") and body.get_meta("tele_holder") == self:
		body.remove_meta("tele_holder")
	if body.has_method("set_levitated"):
		body.set_levitated(false)
		if "velocity" in body:
			body.velocity = leftover
	elif body.has_method("release_vel"):
		body.release_vel(leftover)
	elif body.has_method("release"):
		body.release()
	elif "held" in body:
		body.held = false
	if body is CanvasItem and not body.has_method("set_levitated"):
		(body as CanvasItem).modulate = Color.WHITE


func _mark_tele(body: Node2D, on: bool) -> void:
	body.set_meta("tele_driven", on)
	if not on:
		return
	body.set_meta("tele_holder", self)
	if body.has_method("set_levitated"):
		body.set_levitated(true, _body_center(body), 0.0)
	elif body.has_method("hold_at"):
		body.hold_at(_body_center(body), 0.0, 0.0)
	elif "held" in body:
		body.held = true
	if body is CanvasItem and not body.has_method("set_levitated"):
		(body as CanvasItem).modulate = _Aura.tele_tint()


func _release_strays(keep: Node) -> void:
	var seen := {}
	for group_name in ["levitatable", "enemies", "ground_loot", "pickups"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node == keep or seen.has(node) or not is_instance_valid(node):
				continue
			seen[node] = true
			if node.get("held") == true and node.has_method("release"):
				node.release()
			elif node.get("levitated") == true and node.has_method("set_levitated"):
				node.set_meta("tele_driven", false)
				node.set_levitated(false)


func _steer_tele(cursor: Vector2, delta: float) -> void:
	# Telekinesis.hold steers the object's centre toward the cursor (celX, celY).
	# teleSpeed is 8 + 1.5 per skill level, in pixels per 30 Hz tick.
	# Approach is min(speed, the stop-in-time speed, 35% of the gap).
	# Velocity then changes by at most teleAccel. Release keeps that velocity.
	_tele_acc += delta
	var guard := 0
	var speed := Progression.tele_speed()
	var accel := Progression.tele_accel()
	while _tele_acc >= TELE_TICK and guard < 4 and is_instance_valid(_tele_obj):
		_tele_acc -= TELE_TICK
		guard += 1
		var to := cursor - _body_center(_tele_obj)
		var dist := to.length()
		var steer := -_tele_vel
		if dist > 0.0:
			var disc := sqrt(2.0 * accel * dist + accel * accel * 0.25) - accel * 0.5
			var approach := minf(speed, minf(maxf(disc, 0.0), dist * 0.35))
			steer = -_tele_vel + to / dist * approach
		if steer.length() > accel:
			steer = steer.normalized() * accel
		_tele_vel += steer
		_tele_vel = _carry_move(_tele_obj, _tele_vel)
	# A carried drop inside Loot.osnRad is granted this frame. The hold ends first.
	if is_instance_valid(_tele_obj) and _tele_obj.is_in_group("ground_loot") and _tele_obj.has_method("try_autopick"):
		_tele_obj.try_autopick()


func _tele_level() -> int:
	if Progression:
		return Progression.skill_level_of("tele")
	return 0


func _tele_radius() -> float:
	if _owns_perk("telemaster"):
		return TELE_RADIUS_MASTER
	return TELE_RADIUS


func _tele_needs_los() -> bool:
	# UnitPlayer checks perk telemaster, not a Telekinesis skill cutoff.
	# skills.xml id "tele" never clears line of sight on its own. @portoff needs it too.
	return not _owns_perk("telemaster") or not _Flags.allows("port")


func _tele_eye() -> Vector2:
	# isLine starts at feet.y - height * 0.75.
	var height := CROUCH_SIZE.y if _sitting_on_ground() else BODY_SIZE.y
	return global_position + Vector2(0.0, -height * 0.75)


func _los_to(body: Node2D) -> bool:
	# Location.isLine from the eye (75% of body height) to the object's centre.
	# Full-height solids and closed doors block. The target itself does not.
	# Perk telemaster skips the test.
	if not _tele_needs_los():
		return true
	var dest := _body_center(body)
	return _line_clear(_tele_eye(), dest, body, _aim_rect(body).grow(8.0))


func tele_blocks_use(node: Node) -> bool:
	if not _tele_needs_los():
		return false
	if not node is Node2D:
		return false
	if _los_to(node as Node2D):
		return false
	_notice(OriginalLines.info("noVisible"))
	return true


func _try_tele_use(cursor: Vector2) -> void:
	set_meta("tk_claim", false)
	# actAction: the object under the cursor (onCursor), within actionDist (200px).
	# Levitatable covers a box you can already grab, even if it is not tagged tk_use.
	var target := _pick_aimed(cursor, ["tk_use", "levitatable", "pickups", "ground_loot"], ACTION_REACH, 0.0, true)
	if target == null:
		return
	set_meta("tk_claim", true)
	if tele_blocks_use(target):
		return
	for props in get_tree().get_nodes_in_group("land_props"):
		if props.has_method("use_prop") and bool(props.use_prop(target)):
			return
	if target.has_method("collect"):
		target.collect()
	elif target.has_method("pickup"):
		target.pickup()


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
	_use_acc = 0.0
	_use_reach = reach
	_ensure_use_bar()
	_sync_use_bar()


func _tick_use(delta: float) -> void:
	if _use_node == null:
		return
	if not Input.is_action_pressed("interact") or _use_blocked():
		_clear_use()
		return
	_use_acc += delta
	var guard := 0
	while _use_acc >= ACTION_TICK and guard < 30 and _use_node != null:
		_use_acc -= ACTION_TICK
		guard += 1
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
	if bool(_use_node.get_meta("dead", false)) or bool(_use_node.get_meta("spent", false)):
		return true
	if _use_node.has_meta("usable") and not bool(_use_node.get_meta("usable")):
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
	_use_acc = 0.0
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


func _pick_aimed(cursor: Vector2, groups: Array, radius: float, snap: float, for_use: bool) -> Node2D:
	var best: Node2D = null
	var best_gap := 0.0
	var best_inside := false
	var seen := {}
	var reach2 := radius * radius
	# Body centres sit within 600 px of the origin (wide areas and doors); skip far
	# nodes before the real checks.
	var coarse2 := (radius + 600.0) * (radius + 600.0)
	for group_name in groups:
		for node in _RoomActivity.near(get_tree(), group_name):
			if not node is Node2D or node == self or seen.has(node) or not is_instance_valid(node):
				continue
			seen[node] = true
			var body := node as Node2D
			if global_position.distance_squared_to(body.global_position) > coarse2:
				continue
			if not _aimed_ok(body, for_use):
				continue
			if global_position.distance_squared_to(_body_center(body)) > reach2:
				continue
			var gap := _cursor_gap(body, cursor)
			var inside := gap <= 0.0
			if not inside and (snap <= 0.0 or gap > snap):
				continue
			if best != null:
				if best_inside and not inside:
					continue
				if inside == best_inside and gap >= best_gap:
					continue
			best = body
			best_gap = gap
			best_inside = inside
	return best


func _aimed_ok(body: Node2D, for_use: bool) -> bool:
	if for_use:
		if body.is_in_group("enemies"):
			return false
		if bool(body.get_meta("spent", false)):
			return false
		if body.has_meta("usable") and not bool(body.get_meta("usable")):
			return false
		return true
	if body.is_in_group("enemies") and body.get("_can_lift") == false:
		return false
	if body.has_meta("levit_poss") and not bool(body.get_meta("levit_poss")):
		return false
	return true


func _show_hidden(target: Node) -> void:
	var id := target.get_instance_id()
	if id == _hide_id:
		return
	_hide_id = id
	_notice(OriginalLines.info("noVisible"))


func _cursor_gap(body: Node2D, cursor: Vector2) -> float:
	var rect := _aim_rect(body)
	if rect.has_point(cursor):
		return 0.0
	var dx := 0.0
	if cursor.x < rect.position.x:
		dx = rect.position.x - cursor.x
	elif cursor.x > rect.end.x:
		dx = cursor.x - rect.end.x
	var dy := 0.0
	if cursor.y < rect.position.y:
		dy = rect.position.y - cursor.y
	elif cursor.y > rect.end.y:
		dy = cursor.y - rect.end.y
	return Vector2(dx, dy).length()


func _body_center(body: Node2D) -> Vector2:
	var shaped := _shape_rect(body)
	if shaped.size != Vector2.ZERO:
		return shaped.get_center()
	return _aim_rect(body).get_center()


func _aim_rect(body: Node2D) -> Rect2:
	var rect := _shape_rect(body)
	var visual := body.get_node_or_null("Visual") as Sprite2D
	if visual and visual.visible and visual.texture:
		var art := _sprite_rect(visual)
		if rect.size == Vector2.ZERO:
			return art
		return rect.merge(art)
	if rect.size != Vector2.ZERO:
		return rect
	var size := Vector2.ZERO
	if body.has_meta("size"):
		size = body.get_meta("size")
	elif body.has_meta("box"):
		size = body.get_meta("box")
	elif body.has_meta("door_w"):
		size = Vector2(float(body.get_meta("door_w")), float(body.get_meta("door_h", 40.0)))
	if size.x < 1.0 or size.y < 1.0:
		size = Vector2(32, 32)
		return Rect2(body.global_position - size * 0.5, size)
	return Rect2(body.global_position, size)


func _shape_rect(body: Node2D) -> Rect2:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is RectangleShape2D):
		return Rect2()
	var box := shape_node.shape as RectangleShape2D
	if box.size.x < 1.0 or box.size.y < 1.0:
		return Rect2()
	var center := shape_node.global_position
	return Rect2(center - box.size * 0.5, box.size)


func _sprite_rect(sprite: Sprite2D) -> Rect2:
	var tex := sprite.texture.get_size()
	var scaled := Vector2(tex.x * absf(sprite.global_scale.x), tex.y * absf(sprite.global_scale.y))
	var origin := sprite.global_position + sprite.offset * sprite.global_scale.abs()
	if sprite.centered:
		origin -= scaled * 0.5
	return Rect2(origin, scaled)


func _carry_move(body: Node2D, vel: Vector2) -> Vector2:
	# Box.run steps by at most maxdelta and stops on collision == 1.
	# Levitating objects ignore one-way platforms. They pass through other props.
	if not is_instance_valid(body):
		return vel
	if not body is PhysicsBody2D:
		body.global_position += vel
		return vel
	var phys := body as PhysicsBody2D
	var saved := phys.collision_mask
	phys.collision_mask = 1
	vel = _push_axis(phys, vel, Vector2(vel.x, 0.0))
	if is_instance_valid(phys):
		vel = _push_axis(phys, vel, Vector2(0.0, vel.y))
	if is_instance_valid(phys):
		phys.collision_mask = saved
	return vel


func _push_axis(body: PhysicsBody2D, vel: Vector2, axis: Vector2) -> Vector2:
	var left := axis
	var ignored: Array[CollisionObject2D] = []
	var guard := 0
	while left.length() > 0.01 and guard < 8 and is_instance_valid(body):
		guard += 1
		var slice := left
		if slice.length() > CARRY_STEP:
			slice = slice.limit_length(CARRY_STEP)
		var hit := body.move_and_collide(slice, true, 0.08, false)
		if hit == null:
			body.global_position += slice
			left -= slice
			continue
		var other := hit.get_collider() as Node
		var normal := hit.get_normal()
		var blocked := other != null and _carry_wall(other) and _opposes(normal, slice)
		if not blocked:
			var block := other as CollisionObject2D
			if block != null and block not in ignored:
				body.add_collision_exception_with(block)
				ignored.append(block)
				continue
			body.global_position += slice
			left -= slice
			continue
		var travel := hit.get_travel()
		if travel.length() > 0.01:
			body.global_position += travel
		vel = _bounce_carry(vel, normal, body)
		left = Vector2.ZERO
	for other in ignored:
		if is_instance_valid(body) and is_instance_valid(other):
			body.remove_collision_exception_with(other)
	return vel


func _opposes(normal: Vector2, motion: Vector2) -> bool:
	return normal.dot(motion) < -0.01


func _bounce_carry(vel: Vector2, normal: Vector2, body: Node) -> Vector2:
	# Box.run: a slow hit stops. Faster than 10 px/tick rebounds at 0.2.
	# A floor hit also kills a small horizontal speed. A ceiling hit clears Y.
	if absf(normal.x) > absf(normal.y):
		if absf(vel.x) > 10.0:
			vel.x = -vel.x * 0.2
		else:
			vel.x = 0.0
		if normal.x * vel.x < 0.0:
			vel.x = 0.0
		return vel
	if normal.y < 0.0:
		var mass := 0.1 if body.is_in_group("ground_loot") or body.is_in_group("pickups") else 1.0
		if body.has_meta("massa"):
			mass = float(body.get_meta("massa"))
		if vel.y < 5.0 or mass > 1.0:
			vel.y = 0.0
		else:
			vel.y *= -0.2
		if absf(vel.x) < 5.0:
			vel.x = 0.0
		else:
			vel.x *= 0.92
		return vel
	vel.y = 0.0
	return vel


func _carry_wall(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group("player") or node.is_in_group("levitatable") or node.is_in_group("ground_loot") or node.is_in_group("pickups") or node.is_in_group("enemies"):
		return false
	if _is_closed_door(node):
		return true
	if _is_one_way(node):
		return false
	if node.is_in_group("tk_use"):
		return false
	var parent := node.get_parent()
	var pname := str(parent.name) if parent else ""
	if pname in ["Solids", "Slopes"]:
		return true
	if pname in ["Platforms", "Ladders"]:
		return false
	return bool(node.get_meta("blocks_sight", false))


func _sight_wall(node: Node) -> bool:
	if _is_closed_door(node):
		return true
	if not _carry_wall(node):
		return false
	return _full_height(node)


func _full_height(node: Node) -> bool:
	var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and shape.shape is RectangleShape2D:
		return (shape.shape as RectangleShape2D).size.y >= 39.0
	if node.get_node_or_null("CollisionPolygon2D") != null:
		return true
	return true


func _is_closed_door(node: Node) -> bool:
	if not node.has_meta("door_id") and not node.has_meta("door_open"):
		return false
	if bool(node.get_meta("dead", false)) or bool(node.get_meta("door_open", false)):
		return false
	if node is CollisionObject2D and (node as CollisionObject2D).collision_layer == 0:
		return false
	var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and shape.disabled:
		return false
	return true


func _is_one_way(node: Node) -> bool:
	var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return shape != null and shape.one_way_collision


func _line_clear(from: Vector2, to: Vector2, target: Node, rect: Rect2) -> bool:
	var delta := to - from
	var dist := delta.length()
	if dist <= 1.0:
		return true
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var steps := int(dist / CARRY_STEP) + 1
	for i in range(1, steps + 1):
		var point := from.lerp(to, float(i) / float(steps))
		if rect.has_point(point):
			return true
		if _point_wall(space, point, target):
			return false
	return true


func _point_wall(space: PhysicsDirectSpaceState2D, point: Vector2, target: Node) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	for hit in space.intersect_point(query, 8):
		var collider: Object = hit.collider
		if collider == target or not collider is Node:
			continue
		if _sight_wall(collider as Node):
			return true
	return false


## HUD liftability: the object's massa against _levitation_skill.
func _levitate_difficulty(body: Node) -> float:
	return _tele_massa(body)


func _levitation_skill() -> float:
	return _max_tele_massa()


func _show_too_heavy(target: Node) -> void:
	var id := target.get_instance_id()
	if id == _heavy_id:
		return
	_heavy_id = id
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notice"):
		hud.show_notice(OriginalLines.gui("heavy"))


func _spell_power() -> float:
	# skills.xml magic: spellPower v0=1 vd=0.1
	var rank := 0.0
	if Progression:
		rank = float(Progression.rank("magic"))
	return 1.0 + 0.1 * rank


## x is the magic bar cost (items.xml magic), y the Pers.manaHP cost (mana),
## both times allDManaMult. warlock adds warlockDManaMult, which Spell.cast
## leaves out of its check but applies to the payment.
func _spell_costs(entry: Dictionary, warlock: bool) -> Vector2:
	var mult := GameState.mana_cost_mult()
	if warlock:
		mult *= Progression.warlock_mult()
	return Vector2(float(entry.get("magic", 0.0)), float(entry.get("mana", 0.0))) * mult


## Spell.cast gates before the effect runs: spellsPoss, t_culd, magic, manaHP.
func _spell_ready(entry: Dictionary) -> bool:
	if rat or Effects.attack_forever():
		return false
	# Spell.cast: the alicorn casts only sp_mshit.
	if ScriptsEngine.alicorn and str(entry.get("id", "")) != "sp_mshit":
		return false
	if not GameState.spells_allowed() or (str(entry.get("id", "")) in _ATK_SPELLS and not GameState.attack_allowed()):
		_notice(OriginalLines.info("noSpells"))
		SfxBank.play("nomagic")
		return false
	var left := float(_spell_culd.get(str(entry.get("id", "")), 0.0))
	if left > 0.0:
		if _spell_culd_base(entry) * 30.0 >= 100.0:
			_notice(OriginalLines.info("spellCuld", str(ceili(left))))
		SfxBank.play("nomagic")
		return false
	var cost := _spell_costs(entry, false)
	var why := GameState.spell_block(minf(cost.x, 999.0), cost.y)
	if why != "":
		_notice(OriginalLines.info(why))
		SfxBank.play("nomagic")
		return false
	return true


## Spell.cast est == 1: manaSpell(magic, mana) drops the telekinesis hold, then
## t_culd = culd * spellDown.
func _pay_cast(entry: Dictionary) -> void:
	var cost := _spell_costs(entry, true)
	GameState.pay_spell(cost.x, cost.y)
	if _tele_obj != null:
		_drop_tele()
	_cast_glow = 0.45
	var culd := _spell_cooldown(entry)
	if culd > 0.0:
		_spell_culd[str(entry.get("id", ""))] = culd


func _spell_culd_base(entry: Dictionary) -> float:
	return float(entry.get("cooldown", entry.get("culd", 0.0)))


func _play_spell_sound(entry: Dictionary) -> void:
	var snd := str(entry.get("sound", ""))
	if snd != "":
		SfxBank.play(snd)


func _cast_spell(entry: Dictionary, _dir: Vector2) -> int:
	var id := str(entry.get("id", ""))
	var effect := str(entry.get("effect", ""))
	if id == "sp_cryst" or effect == "crystal":
		return 2
	if effect == "slow" or id == "sp_slow":
		_start_slow(entry)
		return 1
	if effect == "blast" or id == "sp_blast":
		_spell_blast(entry)
		return 1
	if effect == "dash" or id == "sp_kdash":
		_spell_dash(entry)
		return 1
	if effect == "barrier" or id == "sp_mwall":
		return 1 if _cast_mwall(entry) else 0
	if effect == "ghost_wall" or id == "sp_gwall":
		return 1 if _cast_gwall(entry) else 0
	if effect == "shield" or id == "sp_mshit":
		_cast_mshit(entry)
		return 1
	if effect == "moonblade" or id == "sp_moon":
		_cast_moon(entry)
		return 1
	if effect == "blood_shield" or id == "sp_invulner":
		return 1 if _cast_blood(entry) else 0
	return -1


func _magic_origin() -> Vector2:
	if puppet.has_method("spell_origin"):
		return puppet.spell_origin()
	return global_position + Vector2(0.0, -32.0)


func _spell_target(entry: Dictionary) -> Variant:
	var origin := _magic_origin()
	var target := _cursor_world()
	var id := str(entry.get("id", ""))
	var needs_los := int(entry.get("line", 0)) == 1 or id in ["sp_mwall", "sp_gwall"]
	if needs_los and Sight != null and not Sight.los_clear(origin, target):
		_notice(OriginalLines.info("noVisible"))
		return null
	var dist := float(entry.get("dist", 0.0))
	if dist <= 0.0 and id in ["sp_mwall", "sp_gwall"]:
		dist = 300.0
	if dist > 0.0:
		var delta := target - origin
		var length := delta.length()
		if length > dist:
			target = origin + delta / length * dist
	return target


func _cast_mwall(entry: Dictionary) -> bool:
	var point: Variant = _spell_target(entry)
	if point == null:
		return false
	var host := get_tree().current_scene
	if host == null:
		return false
	var hp := float(entry.get("spell_hp", 200.0)) * _spell_power()
	var wall = _Barrier.new()
	host.add_child(wall)
	wall.global_position = point
	wall.setup_mwall(hp)
	return true


func _cast_gwall(entry: Dictionary) -> bool:
	var point: Variant = _spell_target(entry)
	if point == null:
		return false
	var host := get_tree().current_scene
	if host == null:
		return false
	var power := _spell_power()
	var hp := float(round(float(entry.get("spell_hp", 100.0)) * power))
	var seconds := float(round(float(entry.get("damage", 10.0)) * power))
	var placed := 0
	var aim: Vector2 = point
	for offset in [Vector2(0, -40), Vector2.ZERO, Vector2(0, 40)]:
		var center := _tile_center(aim + offset)
		UnitFx.emit(get_tree(), "gwall", center)
		if not _tile_open(center):
			continue
		var tile = _Barrier.new()
		host.add_child(tile)
		tile.global_position = center
		tile.setup_gtile(hp, seconds)
		placed += 1
	if placed <= 0:
		_notice(Locale.t("spell_no_room"))
		return false
	return true


func _tile_center(world: Vector2) -> Vector2:
	return Vector2(floor(world.x / 40.0) * 40.0 + 20.0, floor(world.y / 40.0) * 40.0 + 20.0)


func _tile_open(center: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 36)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, center)
	params.collision_mask = 1 | 4 | 32 | 64
	params.collide_with_areas = true
	params.collide_with_bodies = true
	for result in space.intersect_shape(params, 8):
		var collider: Object = result.collider
		if collider is Node and (collider as Node).is_in_group("ladders"):
			return false
		if collider is CollisionObject2D and ((collider as CollisionObject2D).collision_layer & (1 | 4 | 64)) != 0:
			return false
	return true


func _cast_mshit(entry: Dictionary) -> void:
	# shithp = hp * spellPower, then UnitPlayer steps it down by 0.05 per tick.
	_shit_hp = float(entry.get("spell_hp", 150.0)) * _spell_power()
	if ScriptsEngine.alicorn:
		_shit_hp = Progression.pers("alicornShitHP", 2000.0)


func _cast_moon(entry: Dictionary) -> void:
	var power := _spell_power()
	# UnitPet moonblade: level = pers.level - 1, hp 70 and dam 15, each times
	# (1 + 0.1 * level) and spellPower.
	var grow := 1.0 + 0.1 * float(maxi(0, int(Progression.level) - 1))
	var pet_hp := 70.0 * grow * power
	var pet_dam := 15.0 * grow * power
	if _moon != null and is_instance_valid(_moon) and _moon.has_method("heal_full"):
		_moon.heal_full()
		return
	var host := get_tree().current_scene
	if host == null:
		return
	var moon = _Moon.new()
	host.add_child(moon)
	moon.global_position = global_position + Vector2(0.0, -80.0)
	moon.setup(self, pet_hp, pet_dam)
	_moon = moon


func _cast_blood(entry: Dictionary) -> bool:
	# cast_invulner fails when bloodHP <= dam * 3. dam is 50, so the gate is 150.
	# The spend is bloodDamage(dam, BLEED): dam * 3 * random(), so 0–150 off bloodHP.
	var dam := float(entry.get("damage", 50.0))
	if not GameState.try_blood_shield(dam):
		# cast_invulner fails quietly when blood is too low.
		return false
	_blood_left = 4.0
	return true


func _tick_spell_state(delta: float) -> void:
	# Spell.step: every carried spell counts its own t_culd down.
	for id in _spell_culd.keys():
		var left := float(_spell_culd[id]) - delta
		if left <= 0.0:
			_spell_culd.erase(id)
		else:
			_spell_culd[id] = left
	_tick_crystal(delta)
	if _shit_hp > 0.0:
		_shit_hp = maxf(0.0, _shit_hp - 0.05 * 30.0 * delta)
	if _blood_left > 0.0:
		_blood_left = maxf(0.0, _blood_left - delta)
	if _shit_ring:
		if _shit_hp > 0.0 and not _shit_ring.visible:
			_shit_ring.call("play_from", 1)
		elif _shit_hp <= 0.0:
			_shit_ring.visible = false
	for aura in _blood_auras:
		aura.set("alpha", 1.0 if _blood_left > 0.0 else 0.0)
	for clip in [_inh_ring, _shit_ring, _crystal_ring]:
		if clip:
			clip.scale.x = absf(clip.scale.x) * (-1.0 if facing < 0.0 else 1.0)
	if _inh_ring:
		_inh_ring.position.x = -1.0 if facing >= 0.0 else 1.0


func _tick_crystal(delta: float) -> void:
	var held := _crystal_held()
	var was_on := _crystal_on
	if not held:
		_crystal_tried = false
	if held and not _crystal_on and _crystal_grace <= 0.0:
		var spell := _crystal_spell()
		if _crystal_tried:
			pass
		elif not _spell_ready(spell):
			_crystal_tried = true
		else:
			_pay_cast(spell)
			_crystal_on = true
			_crystal_grace = 5.0 / 30.0
			SfxBank.play("crystal")
	elif held:
		_crystal_grace = 5.0 / 30.0
	if _crystal_grace > 0.0:
		if _crystal_ring and roundi(_crystal_grace * 30.0) == 4 and int(_crystal_ring.call("frame")) < 10:
			_crystal_ring.call("play_from", 10)
		_crystal_grace = maxf(0.0, _crystal_grace - delta)
		_crystal_on = _crystal_grace > 0.0
	else:
		_crystal_on = false
	if _crystal_ring:
		if _crystal_on and not was_on:
			_crystal_ring.call("play_from", 1)
		elif not _crystal_on:
			_crystal_ring.visible = false
	GameState.magic_locked = _crystal_on


func _crystal_held() -> bool:
	if Inventory == null or Inventory.count("sp_cryst") <= 0:
		return false
	if MagicBinds != null and MagicBinds.is_held("sp_cryst"):
		return true
	return str(Inventory.spell_id) == "sp_cryst" and Input.is_action_pressed("cast_spell")


func _crystal_spell() -> Dictionary:
	var spell: Dictionary = _spellbook.get("sp_cryst", {})
	if spell.is_empty() and Inventory != null:
		spell = Inventory.weapon_def("sp_cryst")
	if spell.is_empty():
		return {"id": "sp_cryst", "magic": 50, "mana": 5}
	return spell


func _shielded_amount(amount: int, tip: String) -> int:
	var bypass := tip in ["DAM_BLEED", "DAM_POISON", "DAM_INTERNAL"]
	if _crystal_on and not bypass:
		# dam *= 5 / spellPower comes off the magic bar, a tenth of it off manaHP, and regen restarts.
		var drain := float(amount) * 5.0 / _spell_power()
		GameState.pay_spell(drain, drain * 0.1)
		if GameState.magic <= 0.0:
			_crystal_on = false
			_crystal_grace = 0.0
			GameState.magic_locked = false
		return 0
	if _blood_left > 0.0 and not bypass:
		if _shit_hp > 0.0:
			_shit_hp = maxf(0.0, _shit_hp - float(amount))
		return 0
	if _shit_hp > 0.0 and not bypass:
		_shit_hp = maxf(0.0, _shit_hp - float(amount))
		return maxi(0, amount - SHIT_ARMOR)
	return amount


func _roll_on_hit(node: Node, effect: String, dop: float, chance: float, dealt: int) -> void:
	if effect == "" or chance <= 0.0:
		return
	if chance < 1.0 and randf() >= chance:
		return
	if node.has_method("apply_on_hit"):
		node.apply_on_hit(effect, dop, dealt)


## bullet.gd _roll_status: the weapon's dop effect on the player.
func apply_on_hit(effect: String, dop: float, dealt: int) -> void:
	Effects.player_hit(effect, dop, float(dealt))


func take_hit(amount: int = 15, type: String = "") -> void:
	if type != "":
		set_meta("_hit_tip", type)
		_Resistances.apply(self, float(amount), type)
		remove_meta("_hit_tip")
		return
	var tip := str(get_meta("_hit_tip", ""))
	amount = _shielded_amount(amount, tip)
	if amount <= 0:
		return
	if _invuln > 0.0 or control_off:
		return
	_invuln = GameState.hit_invuln_time()
	# UnitPlayer.damage: pinok grows with dam / maxhp, except for bleed, poison,
	# internal and pink cloud. Only a heavy pile-up breaks a climb or a hover.
	if not tip in ["DAM_BLEED", "DAM_POISON", "DAM_INTERNAL", "DAM_PINKCLOUD"]:
		var max_hp := maxi(1, int(GameState._max_health()))
		_pinok = minf(100.0, _pinok + float(amount) / float(max_hp) * 200.0)
		var knock := _hit_knock if _hit_knock != Vector2.ZERO else _contact_knock()
		_otbros(knock)
	if _pinok > 60.0:
		if _levitating:
			_levitating = false
			_jump_cut = true
		if _tele_obj != null:
			_drop_tele()
	if _pinok > 30.0 and _climbing:
		_climbing = false
	GameState.apply_damage(amount, tip)
	_float_hit(amount, true)
	_blood_fx(float(amount), tip)


## Unit.damage blood for the player: none in alicorn form.
func _blood_fx(dam: float, tip: String) -> void:
	if ScriptsEngine.alicorn or not tip in ["DAM_PIERCE", "DAM_CUT", "DAM_BLUNT", "DAM_BLEED", "DAM_BITE"]:
		return
	var shape := get_node_or_null("CollisionShape2D") as Node2D
	var mid := shape.global_position if shape != null else global_position
	if _hit_knock != Vector2.ZERO:
		var d := _hit_knock.normalized() * 5.0
		UnitFx.emit(get_tree(), "blood", mid, {"dx": d.x, "dy": d.y, "kol": int(randf() * 5.0 + dam / 5.0)})
	else:
		UnitFx.emit(get_tree(), "blood", mid, {"kol": int(dam / 3.0)})


func _otbros(knock: Vector2) -> void:
	# Unit.otbros: sila = rnd(0.8..1.2) * knocked / massa, at most 3. littlepip is massa 1, knocked 1.
	if knock == Vector2.ZERO:
		return
	var sila := minf((randf() * 0.4 + 0.8) * Effects.stat("knocked", 1.0), 3.0)
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


func _contact_knock() -> Vector2:
	# Melee and touch hits arrive without a bullet. Their blow flies from the
	# nearest enemy toward the player.
	var best: Node2D = null
	var best_d := 160.0
	for node in get_tree().get_nodes_in_group("enemies"):
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


func _tick_pinok(delta: float, on_floor: bool) -> void:
	# actions(): pinok drops 1 per tick standing or on a ladder, 3 in the air.
	if _pinok <= 0.0:
		return
	var rate := 30.0 if on_floor or _climbing else 90.0
	_pinok = maxf(0.0, _pinok - rate * delta)


func _tick_weapon_raise(delta: float, up: bool) -> void:
	# weapUp: stay and keyBeUp for more than 10 ticks of t_up.
	weapon_raised = false
	if is_on_floor() and up and not _climbing and not _levitating:
		_up_for += delta
		weapon_raised = _up_for > 10.0 / 30.0
	elif not up:
		_up_for = 0.0


func _landed(was_on_floor: bool, fall_vy: float) -> void:
	# Unit.run on touchdown: sndFall above 5 px/tick, makeNoise(noiseRun) above 16, half above 9.
	if was_on_floor or not is_on_floor() or _climbing:
		return
	if fall_vy > FALL_SOUND:
		# sndFall plays at footstepVol without Sound.stepVol.
		SfxBank.play(_step_clip(randi_range(1, 4)), FOOT_VOL)
		SfxBank.play(_step_clip(randi_range(1, 4)), FOOT_VOL)
	var noise := 0.0
	var run_noise := Effects.stat("noiseRun", NOISE_RUN)
	if fall_vy > FALL_NOISE_FULL:
		noise = run_noise
	elif fall_vy > FALL_NOISE_HALF:
		noise = run_noise * 0.5
	if noise > 0.0:
		set_meta("foe_noise", maxf(float(get_meta("foe_noise", 0.0)), noise))


func _step_up(delta: float, up: bool, down: bool) -> void:
	# Unit.run lifts onto a tile or platform whose top is within porog of the
	# feet. porog is 20 only while walking and 0 under keySit. In the air
	# porog_jump is 10 for (isRun || keyBeUp) before any jump, else 0.
	if _walk_dir == 0 or down or _climbing or _levitating:
		return
	var dx := velocity.x * delta
	if absf(dx) < 0.01:
		return
	var lift := 0.0
	if is_on_floor():
		lift = POROG
	elif (_run_wants() or up) and _jump_count == 0:
		lift = POROG_JUMP
	if lift <= 0.0:
		return
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var box := _body_shape.shape as RectangleShape2D
	var half := box.size.x * 0.5 if box != null else BODY_SIZE.x * 0.5
	var probe_x := global_position.x + signf(dx) * half + dx
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(probe_x, global_position.y - lift - 0.5), Vector2(probe_x, global_position.y - 0.5), collision_mask)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	# Stairs are slopes and Godot already walks them.
	if (hit.normal as Vector2).y > -0.9:
		return
	var rise := global_position.y - (hit.position as Vector2).y
	if rise <= 0.5 or rise > lift + 0.5:
		return
	# One pixel of air under the raised box so the step's own top is not a hit.
	if test_move(global_transform, Vector2(0.0, -rise - 1.0)):
		return
	if test_move(global_transform.translated(Vector2(0.0, -rise - 1.0)), Vector2(dx, 0.0)):
		return
	# Land over the step, not on its corner, which would stop the slide like a wall.
	global_position += Vector2(dx, -rise - 0.5)


## Unit.run (isUp && stay && !isSit): the tile at the head row ahead is open and
## the one under it a full block, so the pony climbs onto it crouched. unsit()
## follows in the same run and stands again when the gap is tall enough.
func _auto_sit(delta: float, up: bool) -> void:
	if not up or _sit or rat or _walk_dir == 0 or _climbing or _levitating or not is_on_floor():
		return
	var dir := signf(velocity.x) if absf(velocity.x) > 0.01 else float(_walk_dir)
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var box := _body_shape.shape as RectangleShape2D
	var half := box.size.x * 0.5 if box != null else BODY_SIZE.x * 0.5
	const TILE := 40.0
	var probe_x := global_position.x + dir * (half + 1.0) + velocity.x * delta
	var row := floori((global_position.y - BODY_SIZE.y) / TILE)
	var top := float(row + 1) * TILE
	var rise := global_position.y - top
	if rise <= POROG + 0.5 or rise > TILE + 0.5:
		return
	var point := PhysicsPointQueryParameters2D.new()
	point.position = Vector2(probe_x, top - TILE * 0.5)
	point.collision_mask = collision_mask
	point.exclude = [get_rid()]
	if not space.intersect_point(point, 1).is_empty():
		return
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(probe_x, top - 2.0), Vector2(probe_x, top + TILE - 1.0), collision_mask)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty() or absf((hit.position as Vector2).y - top) > 1.0 or (hit.normal as Vector2).y > -0.9:
		return
	_set_sit(true)
	var lifted := global_transform.translated(Vector2(0.0, -rise - 0.5))
	# Far enough in that _ceiling_blocks_stand's narrower band reaches under the lip.
	if test_move(lifted, Vector2(dir * (half + 6.0), 0.0)):
		_set_sit(false)
		return
	global_position += Vector2(dir * 6.0, -rise - 0.5)
	velocity.y = 0.0
	_try_unsit()


var _lurked := false
var _lurk_tip := 0
var _lurk_box: Node2D = null
var _lurk_raised: Node2D = null
var _lurk_box_at := Vector2.ZERO
var _lurk_x := 0.0
var _lurk_work := ""
var _lurk_t := 0.0
var _lurk_up_t := 0


## UnitPlayer lurk: a short tap of up while standing hides in a box (Box.lurk
## 1 niche, 2 beside its edge, 3 behind) or between two hiding-spot tiles.
## Returns true while the hide or its exit owns the movement keys.
func _tick_lurk(delta: float, key_left: bool, key_right: bool, up: bool, down: bool, jump_just: bool) -> bool:
	var ticks := delta * 30.0
	if _lurk_work != "":
		_lurk_t -= ticks
		if _lurk_work == "lurk":
			velocity.x = 0.0
			global_position.x = move_toward(global_position.x, _lurk_x, 4.0 * ticks)
			if _lurk_t <= 10.0:
				_lurk_layer(true)
		else:
			velocity.x = 0.0
			if _lurk_t <= 5.0:
				_lurk_layer(false)
		if _lurk_t <= 0.0:
			_lurk_work = ""
		return true
	if _lurked:
		var box_moved := _lurk_box != null and (not is_instance_valid(_lurk_box) or _lurk_box.global_position.distance_to(_lurk_box_at) > 2.0)
		if not is_on_floor() or absf(global_position.x - _lurk_x) > 10.0 or box_moved:
			_lurk_lose()
			return false
		if up or down or jump_just:
			_unlurk()
			return true
		if (key_left or key_right) and (_lurk_tip == 1 or _lurk_tip == 3):
			facing = -1.0 if key_left else 1.0
		velocity.x = 0.0
		return true
	var stay := is_on_floor() and not _climbing and not _levitating
	if stay and up:
		_lurk_up_t += 1
	else:
		if _lurk_up_t > 0 and _lurk_up_t <= 7 and not key_left and not key_right:
			_try_lurk()
		if not up:
			_lurk_up_t = 0
	return false


func _try_lurk() -> void:
	_lurk_tip = 0
	if not is_on_floor() or _sit or absf(velocity.x) >= 150.0 or _lurk_work != "":
		return
	var feet := global_position
	_lurk_box = null
	var best_rect := Rect2()
	for node in _lurk_candidates():
		var id := str(node.get_meta("id", ""))
		var tip: int = _LandRegistry.int_of(_LandRegistry.obj(id).get("lurk"), 0) if id != "" else 0
		if tip <= _lurk_tip:
			continue
		var rect := _lurk_rect(node)
		if feet.x > rect.position.x and feet.x < rect.end.x and feet.y - 10.0 > rect.position.y and feet.y - 10.0 < rect.end.y:
			_lurk_tip = tip
			_lurk_box = node
			best_rect = rect
	if _lurk_box != null:
		_lurk_box_at = _lurk_box.global_position
		if _lurk_tip == 2:
			if feet.x > best_rect.get_center().x:
				facing = 1.0
				_lurk_x = best_rect.end.x - 10.0
			else:
				facing = -1.0
				_lurk_x = best_rect.position.x + 10.0
		else:
			_lurk_x = best_rect.get_center().x
	elif _Flags.hiding_at(feet + Vector2(-20.0, -10.0)) and _Flags.hiding_at(feet + Vector2(20.0, -10.0)):
		_lurk_tip = 1
		_lurk_x = roundf(feet.x / 40.0) * 40.0
	else:
		var quick := get_node_or_null("QuickKeys")
		if quick != null and quick.has_method("armor_ability"):
			quick.call("armor_ability")
		return
	velocity.x = 0.0
	_lurk_t = 20.0
	_lurk_work = "lurk"
	_lurked = true
	set_meta("foe_detecting", 0.0)
	set_meta("foe_vis_mult", 0.5)


## Unit.observation: the share of pers.sneakLurk taken off a looker's view (sitting is a fifth).
func lurk_cut() -> float:
	if _lurked:
		return 1.0
	if _sit:
		return 0.2
	return 0.0


## Unit.udarBullet dexter + dexterPlus (sitDexterPlus 0.3, lurkDexterPlus 2). 0 is always hit.
func dexter_now() -> float:
	var dex := Progression.player_dexter() if Progression != null else 1.0
	if dex <= 0.0:
		return 0.0
	if _lurked:
		return dex + 2.0
	if _sit:
		return dex + 0.3
	return dex


## Unit.udarUnit: a body or club hit misses on rnd < dodge (1 + dodgePlus while dashing).
func can_be_hit() -> bool:
	return _invuln <= 0.0 and not control_off and Time.get_ticks_msec() >= _dodge_until


## udarUnit sets neujaz before the roll, so a dodged contact is not rolled again at once.
func dodge_roll() -> bool:
	if Time.get_ticks_msec() < _dodge_until:
		return true
	if _invuln > 0.0:
		return false
	var dodge := Progression.player_dodge_plus() if Progression != null else 0.0
	if _kdash_left > 0.0:
		dodge += 1.0
	if dodge > 0.0 and randf() < dodge:
		_dodge_until = Time.get_ticks_msec() + int(GameState.hit_invuln_time() * 1000.0)
		return true
	return false


var _dodge_until := 0


func _lurk_candidates() -> Array:
	var out: Array = []
	for group in ["floor_box", "levitatable", "tk_use"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node2D and node.has_meta("id") and not out.has(node):
				out.append(node)
	for props in get_tree().get_nodes_in_group("land_props"):
		for node in props.get_children():
			if node is Node2D and node.has_meta("id") and not out.has(node):
				out.append(node)
	return out


func _lurk_rect(node: Node2D) -> Rect2:
	if node.has_meta("feet") and node.has_meta("size"):
		var size: Vector2 = node.get_meta("size")
		var at: Vector2 = node.get_meta("feet")
		if not node is PhysicsBody2D:
			return Rect2(at - Vector2(size.x * 0.5, size.y), size)
	return _aim_rect(node)


func _unlurk() -> void:
	if _lurked and is_on_floor():
		_lurk_t = 10.0
		_lurk_work = "unlurk"
	else:
		_lurk_layer(false)
	_lurk_end()


func _lurk_lose() -> void:
	_lurk_layer(false)
	_lurk_end()


func _lurk_end() -> void:
	_lurked = false
	_lurk_box = null
	remove_meta("foe_detecting")
	remove_meta("foe_vis_mult")


## chSloy(0) for lurk 1 puts the pony under the objects (a hiding-spot niche also
## under the wall patches). For 2 and 3 it stays on the unit layer and the box goes
## to the top of it.
func _lurk_layer(hidden: bool) -> void:
	var box := _lurk_box if is_instance_valid(_lurk_box) else null
	if puppet != null and puppet.has_method("set_flat_layers"):
		puppet.set_flat_layers(hidden)
	if not hidden:
		z_index = 0
		if is_instance_valid(_lurk_raised) and _lurk_raised.has_meta("lurk_z"):
			_lurk_raised.z_index = int(_lurk_raised.get_meta("lurk_z"))
			_lurk_raised.remove_meta("lurk_z")
		_lurk_raised = null
		return
	if _lurk_tip != 1:
		z_index = 0
		if box != null and not box.has_meta("lurk_z"):
			box.set_meta("lurk_z", box.z_index)
			box.z_index = maxi(box.z_index, 4)
			_lurk_raised = box
	else:
		z_index = -4 if box != null else -9


func puppet_state() -> Dictionary:
	return {
		"a_jump": _did_jump,
		"sit": _sit,
		"walk": _walk_dir,
		"weapon_raised": weapon_raised,
	}


func _exit_tree() -> void:
	if GameState:
		GameState.magic_locked = false
		GameState.set_running(false)


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
		var score := absf(area.global_position.x - global_position.x)
		if global_position.y < _rail_top(area) - 1.0:
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
	var box := _body_shape.shape as RectangleShape2D
	var half := (RAT_SIZE if rat else BODY_SIZE).x * 0.5
	if box != null and box.size.x > CLIMB_BOX_W:
		box.size.x = CLIMB_BOX_W
	var center := area.global_position.x
	var target := center - TILE_HALF + half
	if _ladder_facing(area) > 0.0:
		target = center + TILE_HALF - half
	var dx := target - global_position.x
	if absf(dx) < 0.01 or test_move(global_transform, Vector2(dx, 0.0)):
		return
	global_position.x = target


func _ladder_facing(area: Area2D) -> float:
	var side := str(area.get_meta("ladder_side", "right"))
	return -1.0 if side == "left" else 1.0


func _reaching_rail_top(area: Area2D, delta: float, move_y: float) -> bool:
	var top := _rail_top(area)
	if global_position.y <= top + 1.0:
		return true
	var climb_vy := move_y * CLIMB_SPEED * GameState.move_speed_mult()
	return global_position.y + climb_vy * delta <= top


func _stand_on_rail(area: Area2D) -> void:
	# isLaz clears here. Drop onto the one-way lip instead of hanging in the grab zone.
	var top := _rail_top(area)
	global_position.y = top - 2.0
	velocity.y = 80.0
	_climbing = false
	floor_snap_length = 8.0
	set_collision_mask_value(PLATFORM_LAYER_BIT, true)


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		take_hit(12)


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_bullets"):
		var tip := "DAM_PIERCE"
		if "damage_type" in area:
			tip = str(area.damage_type)
		_hit_knock = _bullet_knock(area)
		take_hit(10, tip)
		_hit_knock = Vector2.ZERO
		area.queue_free()
	elif area.is_in_group("pickups"):
		if area.has_method("collect"):
			area.collect()


func _float_hit(amount: int, player_hit: bool) -> void:
	if amount <= 0:
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("float_number"):
		hud.float_number(global_position, str(amount), "player" if player_hit else "hit", self)
