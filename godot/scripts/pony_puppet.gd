extends Node2D

## Side-view pony from the body clips in pfe.swf.
## Frames play at 30 fps. Feet sit on this node's origin. scale.x flips the pony.
## The art node draws the body at BODY_DRAW. stay frame 1 is 65 opaque pixels
## from hoof to ear, so 1.2 puts that span at 78px. The flip stays on this node.
## A levitated gun uses the vis clip and UnitPlayer's hold, and points at the cursor.
## Each strip is the body timeline with every limb held on its unlabeled frame.
## Idle holds stay frame 1, then free1/2/3 the way UnitPlayer rolls them.
## Crouch plays stay "down" into frame 2. Standing plays "up". Moving crouch is polz.
## Wings are separate. They show only while pers.ableFly is set.
## One PipBuck tracks the near foreleg after the stable grant. Mane, tail, and
## eyes are overlays recolored the way Appear.as recolors those symbols.
## The horn is morda.horn (setColor fur) and tracks the head. Its magic child
## is hardlight in the magic color. Only the eye's gray iris takes the eye color.

const FPS := 30.0
const WALK_SPEED := 210.0
const CLIMB_STILL := 8.0
# levit body (body_levit_484 frame scripts): the hover loops 17-49 (frame50
# goes to 17), a fall enters at 51 and frame65 goes to 17, release plays 67
# and frame75 stops. 76-80 are empty.
const HOVER_FROM := 17
const HOVER_LOOP_END := 50
const HOVER_TO := 66
const HOVER_ENTRY := 51
const HOVER_ENTRY_END := 65
const HOVER_STOP := 75
# stay/1 opaque rows 4..68 are 65px. 65 * 1.2 = 78, inside a two-tile gap.
const BODY_DRAW := 1.2
const _GAITS: Array[String] = ["walk", "trot", "trot_up", "trot_down", "run"]

# Flash registration point inside each clip's shared canvas, in pixels.
const _ANCHOR := {
	"stay": Vector2(43.5, 63.6),
	"walk": Vector2(21.35, 60.75),
	"trot": Vector2(24.95, 62.05),
	"trot_up": Vector2(25.95, 66.8),
	"trot_down": Vector2(23.95, 61.0),
	"run": Vector2(30.3, 59.45),
	"climb": Vector2(18.95, 62.1),
	"jump": Vector2(28.55, 68.4),
	"levit": Vector2(29.05, 65.55),
	"polz": Vector2(36.65, 37.95),
	"punch": Vector2(15.95, 64.15),
	"kick": Vector2(51.25, 60.5),
	"pinok": Vector2(26.3, 64.8),
	"free1": Vector2(15.95, 63.25),
	"free2": Vector2(15.95, 62.45),
	"free3": Vector2(17.25, 61.55),
	"roll": Vector2(32.05, 59.05),
	"plav": Vector2(27.75, 65.55),
	"die": Vector2(26.5, 69.6),
	"dieali": Vector2(18.8, 69.6),
	"res": Vector2(26.5, 60.5),
	"lurk1": Vector2(15.95, 66.25),
	"lurk2": Vector2(15.95, 69.3),
	"lurk3": Vector2(25.25, 69.15),
}
# The lurk clips' colour transform on the hair layers, per frame. The body frames
# already carry theirs.
const _LURK_DIM := {
	"lurk1": [1.0, 0.93, 0.86, 0.79, 0.71, 0.64, 0.57, 0.5, 0.43, 0.36,
			0.42, 0.49, 0.55, 0.62, 0.68, 0.74, 0.81, 0.87, 0.94, 1.0],
	"lurk2": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
			0.9, 0.8, 0.7, 0.6, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
	"lurk3": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
			0.9, 0.8, 0.7, 0.6, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
}

const Look := preload("res://scripts/pony_look.gd")
const _EyeShader := preload("res://assets/shaders/eye_iris.gdshader")
const _MagicShader := preload("res://assets/shaders/horn_magic.gdshader")
const _Aura := preload("res://scripts/magic_aura.gd")
# h0/h1 inside the mane clip, in pixels. Forelock is head * this.
# Tail h0/h1 sit at (51, 59) twips. Horn and magic share morda (2, -221) twips.
const _MANE_AT := Vector2(15.45, 54.1)
const _FORE_AT := Vector2(28.6, -56.4)
const _TAIL_AT := Vector2(2.55, 2.95)
const _MAGIC_AT := Vector2(24.25, 6.05)
const _MORDA_AT := Vector2(24.15, 17.1)
## morda.konec (sprite 273): magicX/magicY, where spells and magic shots start.
const _KONEC_IN := Vector2(-54.4, -75.15)
const _EYE_IN := Vector2(4.6, 1.35)
const _PARTS: PackedStringArray = ["h0", "h1", "fore0", "fore1", "tail0", "tail1", "eye", "pip", "magic", "horn", "helm"]

var _clock: float = 0.0
var _clip: String = ""
# Player state for this frame, the air animState (jump / pinok / levit) and the last jump/pinok frame.
var _ps: Dictionary = {}
var _air: String = ""
var _hover_entry := false
var _air_shown: int = 1

## A saved slot's look for the Load preview; empty uses the live appearance.
var look_override: Dictionary = {}
var _art: Node2D
var _flat := false
var _flat_saved: Array = []
var _sprite: Sprite2D
var _frames: Dictionary = {}
## Menu previews set this before entering the tree: body frames come from
## clips/<clip>/hd (HD_ZOOM times the pixels) where exported.
var hd := false
const HD_ZOOM := 3.0
var _hd_frames: Dictionary = {}
var _hd_parts: Dictionary = {}
const _WeaponVis := preload("res://scripts/weapon_vis.gd")
const _WeaponFx := preload("res://scripts/weapon_fx.gd")

var _gun: Node2D
var _gun_sprite: Sprite2D
var _muzzle: Marker2D
var _spell: Marker2D
var _shoulder: Marker2D
var _weapon: Dictionary = {}
var _gun_angle: float = 0.0
var _hold_ready := false
# Weapon.vis playhead, teleFilter copy, and the Weapon.actions timers in 30 Hz ticks.
var _gun_clip = null
var _gun_glow: Sprite2D
var _gun_pos := Vector2.ZERO
var _gun_fx: Dictionary = {}
var _gun_acc := 0.0
var _gun_fresh := false
## Weapon.setPers recoilMult (an int, so hardness's 0.2 is 0) and drotMult (bigsize 2, not for magic).
var recoil_mult := 1
var drot_mult := 1.0
var _t_ret := 0
var _rot_up := 0.0
var _t_shoot := 0
var _t_attack := 0
var _t_prep := 0.0
var _t_reload := false
var _weapon_lowered := false
var _weapon_hidden := false
## vis.osn.rotation while swimming, in degrees.
var swim_tilt := 0.0
var _armor_id: String = ""
var _armor_frames: Dictionary = {}
static var _armor_cache: Dictionary = {}
static var _armor_tex: Dictionary = {}
## Frame sequences by folder, shared by every puppet for the whole session: the
## body alone is ~1,900 separate files, far too slow to reread per puppet on a
## slow drive. Worker threads fill it (warm_up, _warm_suit); _lock guards these
## three caches.
static var _seq_cache: Dictionary = {}
static var _lock := Mutex.new()
static var _warm_started := false
static var _suits_warming: Dictionary = {}
static var _tasks: Array[int] = []
static var _on_quit: Array[Callable] = []
static var _warm_task := -1
var _armor_sprite: Sprite2D
var _armor_anchor: Dictionary = {}
## Body layers above pip2 (clips/<clip>/upper), drawn over the far-leg PipBuck when facing left.
var _upper_frames: Dictionary = {}
var _upper_anchor: Dictionary = {}
var _upper_sprite: Sprite2D
var _pose: String = "idle"
var _wings: Node2D
var _wing_near: Polygon2D
var _wing_far: Polygon2D
var _missing_attack: Dictionary = {}
var _anchor: Dictionary = {}
var _tracks: Dictionary = {}
var _parts: Dictionary = {}
var _part_anchor: Dictionary = {}
var _mane: Sprite2D
var _mane2: Sprite2D
var _fore: Sprite2D
var _fore2: Sprite2D
var _tail_s: Sprite2D
var _tail2: Sprite2D
var _eye: Sprite2D
var _pip: Sprite2D
var _magic: Sprite2D
var _horn: Sprite2D
var _konec_ok := false
## morda stops on the armour label: helm frame and whether the hair stays.
var _helm: Sprite2D
var _helm_labels: Dictionary = {}
var _magic_color := Color(0.137, 1.0, 0.137)
var _horn_alpha := 0.0
var _want_weapon := false
var _want_tele := false
var _want_tele_heavy := false
var _want_spell := false
var _style_hair := 1
var _style_eye := 1
var _vis_hair1 := false
var _magic_preview := false
var _shown_clip := "stay"
var _shown_frame := 1
var _idle_clip := "stay"
var _free_n := 0
var _body_play := ""
var _body_frame := 1.0
var _idle_left := 0.0
var _rng := RandomNumberGenerator.new()


## Menu pony (visBodyStay instances): an HD puppet in a CanvasGroup carrying the
## instance's GlowFilter (00FF99, strength 2.9; blur 4 on dialNew, 3 elsewhere).
## z 1 keeps the tail (z -1) above the dialog panel it stands on.
static func preview(holder_pos: Vector2, holder_scale: float, blur: float) -> Array:
	var group := CanvasGroup.new()
	group.position = holder_pos
	group.scale = Vector2(holder_scale, holder_scale)
	group.z_index = 1
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/group_glow.gdshader")
	mat.set_shader_parameter("blur", blur)
	group.material = mat
	var puppet: Node2D = load("res://scripts/pony_puppet.gd").new()
	puppet.hd = true
	group.add_child(puppet)
	return [group, puppet]


func _ready() -> void:
	add_to_group("pony_puppet")
	_rng.randomize()
	_build()
	if hd:
		_flatten_z()
	apply_appearance()
	# The player's puppet starts in whatever suit is worn. Menu and PipBuck
	# previews (no body parent) start bare.
	var worn := ""
	if get_parent() is CharacterBody2D:
		var inv := get_node_or_null("/root/Inventory")
		if inv != null and inv.has_method("body_armor_id"):
			worn = str(inv.call("body_armor_id", str(inv.get("worn"))))
	set_armor(worn)


func armor_id() -> String:
	return _armor_id


func set_armor(id: String = "") -> void:
	# Obj.setArmor. An empty id is the unlabeled limb frame. changeArmor
	# stores the suit id (pip, kombu, metal, ali, and the rest) and the
	# limb stops on that label. An overlay on disk is
	# clips/<clip>/<id>/<frame>.png: the limbs on that label without the
	# fur-class parts, drawn untinted above the fur-tinted body. A missing
	# range draws nothing and the id is still stored.
	# lwing/rwing show while pers.ableFly is set: ali armor (armors.json
	# ableFly), the alicorn effect, or potion_fly. Dropping ali hides them
	# when neither of the other two remains.
	_armor_id = id
	_warm_suit(id)
	_armor_frames.clear()
	_armor_anchor.clear()
	if _sprite != null:
		_show(_shown_clip, _shown_frame)
	_place_wings(_pose)


func get_muzzle_global() -> Vector2:
	if _is_magic():
		return spell_origin() if _spell != null else global_position
	if _gun != null and _gun.visible and _muzzle != null:
		return _muzzle.global_position
	if _shoulder != null:
		return _shoulder.global_position
	return global_position


func set_weapon(weapon: Dictionary) -> void:
	_weapon = weapon
	_hold_ready = false
	if _gun == null:
		return
	var kind := str(weapon.get("kind", ""))
	_gun_clip = null
	_t_ret = 0
	_rot_up = 0.0
	_t_shoot = 0
	_t_attack = 0
	_t_prep = 0.0
	_t_reload = false
	_weapon_hidden = false
	if weapon.is_empty() or _is_magic() or kind == "internal" or kind == "melee":
		_gun.visible = false
		return
	var id := str(weapon.get("id", ""))
	_gun_clip = _WeaponVis.clip(id)
	if _gun_sprite == null or _gun_clip == null:
		_gun.visible = false
		return
	# WeaponFactory: totalFrames > 1 makes the weapon animated. setNull shows frame 1.
	_gun_clip.goto_stop(1)
	_gun_clip.show(_gun_sprite)
	_gun_fx = _WeaponVis.fx(id)
	_gun.visible = true
	_muzzle.position = _WeaponVis.emit(id)
	_gun_angle = 0.0


func _is_magic() -> bool:
	return str(_weapon.get("kind", "")) == "magic" or bool(_weapon.get("spell", false))


func spell_origin() -> Vector2:
	if _spell == null:
		return get_muzzle_global()
	var at := _spell.global_position
	# UnitPlayer.setWeaponPos: a konec inside a wall drops to the body.
	if _point_solid(at):
		var body := get_parent() as Node2D
		if body != null:
			at.y = body.global_position.y - (35.0 if bool(body.get("_sit")) else 75.0)
	return at


func uses_lagged_aim() -> bool:
	return _gun != null and _gun.visible


func combat_aim_dir() -> Vector2:
	if not uses_lagged_aim():
		return Vector2.ZERO
	# Weapon.shoot: b.rot = rot - rotUp * storona.X / 50.
	var side := 1.0 if _gun.scale.x > 0.0 else -1.0
	if _is_throwable():
		return Vector2.from_angle((_aim_world() - _gun.global_position).angle())
	return Vector2.from_angle(_gun_angle - _rot_up * side / 50.0)


## Weapon.shoot for the held gun: t_ret, rotUp, gilza, and gotoAndPlay("shoot")
## when t_shoot <= 1. attack_ticks is t_attack (rapid), for drot2.
func weapon_fired(attack_ticks: int = 0) -> void:
	if _gun == null or not _gun.visible:
		return
	var recoil := float(_gun_fx.get("recoil", 0))
	_t_ret = int(round(recoil * recoil_mult))
	if recoil > 3.0 and _t_ret < 3:
		_t_ret = 3
	_rot_up += recoil * 0.5 * recoil_mult
	_t_attack = maxi(_t_attack, attack_ticks)
	if bool(_gun_fx.get("shell", false)):
		_WeaponFx.shell(get_tree(), _gun.global_position, _gun.scale.x)
	if _gun_clip != null and _gun_clip.total > 1 and _t_shoot <= 1 and _gun_clip.label("shoot") > 0:
		_gun_clip.goto_play("shoot")
		_t_shoot = 3
		_gun_fresh = true
		_gun_clip.show(_gun_sprite)


## Weapon.initReload: gotoAndPlay("reload") on an animated vis.
func play_reload(_w: Dictionary = {}) -> void:
	_t_reload = true
	if _gun_clip == null or not _gun.visible or _gun_clip.label("reload") <= 0:
		return
	_gun_clip.goto_play("reload")
	_gun_fresh = true
	_gun_clip.show(_gun_sprite)


## t_prep in ticks, the weapon's prep, and whether t_reload is still running.
func weapon_prep(t_prep: float, reloading: bool) -> void:
	_t_prep = t_prep
	_t_reload = reloading


## UnitPlayer.setWeaponPos: while work == "change" and t_work > changeWeaponTime3
## the weapon sits at the body centre.
func set_weapon_lowered(on: bool) -> void:
	_weapon_lowered = on


## WThrow.animate: alpha 0 while t_attack > 0 or no charge is left.
func set_weapon_hidden(on: bool) -> void:
	_weapon_hidden = on


## UnitPlayer.controlOff hides currentWeapon.vis, controlOn shows it.
func set_weapon_shown(on: bool) -> void:
	if _gun != null:
		_gun.modulate.a = 1.0 if on else 0.0


func _is_throwable() -> bool:
	return str(_weapon.get("kind", "")) == "explosives"


func set_magic_preview(on: bool) -> void:
	_magic_preview = on
	if on:
		_horn_alpha = 1.0
	if _shown_clip != "":
		_place_rig(_shown_clip, _shown_frame)


func weapon_visible() -> bool:
	return _gun != null and _gun.visible


## teleColor, the colour UnitPlayer.teleFilter glows with.
func magic_color() -> Color:
	return _magic_color


func set_magic_activity(weapon_held: bool, telekinesis: bool, spell_active: bool, tele_heavy: bool = false) -> void:
	# aMagic targets from UnitPlayer: held weapon 50, light telekinesis 50,
	# heavy telekinesis (massa >= 1) 100, self-levitation 100. Spell cast is
	# the same half glow. aMC steps 5 per 30 Hz tick in _step_glow.
	_want_weapon = weapon_held
	_want_tele = telekinesis
	_want_spell = spell_active
	_want_tele_heavy = tele_heavy


func apply_appearance() -> void:
	var look := look_override if not look_override.is_empty() else Look.state()
	_style_hair = clampi(int(look.hair_style), 1, Look.MAX_HAIR)
	_style_eye = clampi(int(look.eye_style), 1, Look.MAX_EYE)
	_vis_hair1 = bool(look.vis_hair1)
	var fur := Look.tint(look.fur)
	var hair := Look.tint(look.hair)
	var hair1 := Look.tint(look.hair1)
	var eye := Look.tint(look.eye)
	var magic := Look.tint(look.magic)
	if _sprite != null:
		_sprite.modulate = fur
	if _upper_sprite != null:
		_upper_sprite.modulate = fur
	for part in [_mane, _fore, _tail_s]:
		if part != null:
			part.modulate = hair
	for part in [_mane2, _fore2, _tail2]:
		if part != null:
			part.modulate = hair1
	if _horn != null:
		_horn.modulate = fur
	_magic_color = magic
	_paint_eye(eye)
	_paint_magic()
	if _shown_clip != "":
		_place_rig(_shown_clip, _shown_frame)


func update_pose(state: String, facing: float, aim_dir: Vector2, delta: float) -> void:
	if _sprite == null:
		return
	# player.gd blinks by writing modulate.a after this, and expects it reset to 1.
	modulate.a = 1.0
	scale.x = facing if facing != 0.0 else 1.0
	# The player hands over its own state (aJump, isSit, walk, weapUp).
	# Previews without a player body fall back to the pose name alone.
	var body := get_parent()
	_ps = body.puppet_state() if body != null and body.has_method("puppet_state") else {}
	var motion := _body_velocity()
	var clip := "stay"
	var frame := 1
	var airborne := state in ["jump", "fall", "levitate"]
	swim_tilt = 0.0
	var landed_from := ""
	if not airborne:
		landed_from = _air
		_air = ""
	match state:
		"walk":
			_clear_fidget()
			clip = "walk"
			frame = _cycle(clip, delta)
		"run":
			_clear_fidget()
			clip = "trot"
			frame = _cycle(clip, delta)
		"sprint":
			_clear_fidget()
			clip = "run" if _len("run") > 0 else "trot"
			frame = _cycle(clip, delta)
		"stairs_up", "stairs_down":
			_clear_fidget()
			clip = "trot_up" if state == "stairs_up" else "trot_down"
			frame = _cycle(clip, delta)
		"stairs_up_still", "stairs_down_still":
			# Standing still on a diagonal holds trot_up / trot_down frame 1.
			_clear_fidget()
			clip = "trot_up" if state == "stairs_up_still" else "trot_down"
			frame = 1
			_clip = clip
			_clock = 0.0
		"jump", "fall", "levitate":
			_clear_fidget()
			var air := _air_pick(state, motion, delta)
			clip = air[0]
			frame = air[1]
		"crouch":
			_free_n = 0
			var vx := motion.x
			var walk := int(_ps.get("walk", 0))
			var still := (absf(vx) <= 30.0 and walk != 0) or (absf(vx) <= 120.0 and walk == 0)
			# Roll is the crouch sprint. The player does not sprint while sitting,
			# so this plays only if something else pushes speed past walk * 1.6.
			if absf(vx) > WALK_SPEED * 1.6 and _len("roll") > 0:
				_body_play = ""
				clip = "roll"
				frame = _cycle(clip, delta)
			elif not still and _len("polz") > 0:
				_body_play = ""
				clip = "polz"
				frame = _cycle(clip, delta)
			else:
				clip = "stay"
				frame = _crouch_still(delta, landed_from)
				_clip = clip
		"climb":
			_clear_fidget()
			clip = "climb"
			frame = _climb_frame(motion.y, delta)
		"swim":
			# isPlav: osn stops on "plav", whose nested clip loops on its own;
			# vis.osn.rotation = velocity.Y * 1.5 (degrees, px/tick).
			_clear_fidget()
			clip = "plav"
			frame = _cycle(clip, delta)
			swim_tilt = motion.y / 30.0 * 1.5
		_ when state.begins_with("hold:"):
			# anim(dey, true): osn on dey, body stopped on its last frame.
			_clear_fidget()
			clip = state.substr(5)
			frame = maxi(_len(clip), 1)
			_clip = clip
		"lurk1", "lurk2", "lurk3", "unlurk1", "unlurk2", "unlurk3":
			# lurk(): osn goes to "lurkN" and stops on label "un"; unlurk plays from "un".
			_clear_fidget()
			clip = state.trim_prefix("un")
			var un := int((_tracks.get(clip, {}) as Dictionary).get("labels", {}).get("un", _len(clip)))
			if _len(clip) <= 0:
				_note_missing_clip(clip)
				clip = "stay"
				frame = 1
				_clip = clip
			elif state.begins_with("un"):
				frame = _play_span(clip, state, un, _len(clip), delta)
			else:
				frame = _play_span(clip, state, 1, un, delta)
		"punch", "kick", "die", "dieali", "res":
			_clear_fidget()
			if _len(state) > 0:
				clip = state
				frame = _play_once(clip, delta)
			else:
				_note_missing_clip(state)
				clip = "stay"
				frame = 1
				_clip = clip
		_:
			frame = _idle_frame(delta, landed_from)
			clip = _idle_clip
			_clip = clip
	_step_glow(delta, state)
	_art.rotation_degrees = swim_tilt
	_show(clip, frame)
	_dim_hair(_LURK_DIM.get(clip, []), frame)
	_place_markers(state, clip)
	# Melee is carried in world space by the player. A shoulder parent would
	# orbit the blade. The swing and its reach stay on the player.
	if str(_weapon.get("kind", "")) == "melee":
		if _gun != null:
			_gun.visible = false
	elif _gun != null and _gun.visible:
		_place_gun(state, delta)
	_pose = state
	_place_wings(state)


func _clear_fidget() -> void:
	_free_n = 0
	_body_play = ""


func _crouch_still(delta: float, landed_from: String) -> int:
	# stay labels: "down" 3-11 and "downjump" 21-26 both end on sit frame 2.
	# Landing crouched out of a jump plays downjump. Stopping a crawl snaps
	# to frame 2 and does not replay "down".
	if landed_from == "jump":
		_body_play = "downjump"
		_body_frame = 21.0
	elif landed_from != "" or (not _body_play in ["down", "downjump", "sit"] and _pose != "crouch"):
		_body_play = "down"
		_body_frame = 3.0
	if _body_play == "down":
		return _play_range(3, 11, "sit", 2, delta)
	if _body_play == "downjump":
		return _play_range(21, 26, "sit", 2, delta)
	_body_play = "sit"
	var edge := _edge_frame(true)
	return edge if edge > 0 else 2


## UnitPlayer.getStayFrame: on a ledge the stay clip holds a lean frame by how
## much of the body hangs past the floor (Unit shX1 left, shX2 right).
## Standing: 27-37 front / 38-48 back past 0.30; crouching: 49-59 / 60-70.
func _edge_frame(sit: bool) -> int:
	var hang := _overhang()
	if hang.x < 0.0:
		return 0
	var front := hang.y if scale.x >= 0.0 else hang.x
	var back := hang.x if scale.x >= 0.0 else hang.y
	if sit:
		if front > 0.0:
			return 49 + int(round(front * 10.0))
		if back > 0.0:
			return 60 + int(round(back * 10.0))
	else:
		if front > 0.30:
			return 27 + int(round((front - 0.30) * 13.0))
		if back > 0.30:
			return 38 + int(round((back - 0.30) * 13.0))
	return 0


## (shX1, shX2) from short rays under the body; (-1, -1) with no floor found.
func _overhang() -> Vector2:
	var body := get_parent() as CollisionObject2D
	if body == null or not body.is_inside_tree() or not body.is_in_group("player"):
		return Vector2(-1, -1)
	var space := body.get_world_2d().direct_space_state
	var box := _body_box()
	var w := maxf(box.x, 1.0)
	var shape_node := body.get_node_or_null("CollisionShape2D") as Node2D
	var mid := shape_node.global_position if shape_node != null else body.global_position
	var left := mid.x - w * 0.5
	var y := mid.y + box.y * 0.5 if shape_node != null else mid.y
	var first := -1.0
	var last := -1.0
	var steps := 20
	for k in steps + 1:
		var x := left + w * float(k) / float(steps)
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, y - 4.0), Vector2(x, y + 6.0), body.collision_mask)
		q.exclude = [body.get_rid()]
		if not space.intersect_ray(q).is_empty():
			if first < 0.0:
				first = x
			last = x
	if first < 0.0:
		return Vector2(-1, -1)
	return Vector2((first - left) / w, (left + w - last) / w)


func _play_range(from: int, to: int, then: String, hold: int, delta: float) -> int:
	var frame := int(_body_frame)
	_body_frame += delta * FPS
	if frame > to:
		_body_play = then
		return hold
	return clampi(frame, from, to)


func _idle_frame(delta: float, landed_from: String) -> int:
	# stay label "up" 12-20 stands from a sit. Landing from jump or levit
	# plays body label "jump" 71-76. Both end on stay frame 1.
	if landed_from == "jump" or landed_from == "levit":
		_body_play = "land"
		_body_frame = 71.0
	elif _pose == "crouch" or _body_play in ["down", "downjump", "sit"]:
		if _body_play != "up":
			_body_play = "up"
			_body_frame = 12.0
	if _body_play == "up" or _body_play == "land":
		_free_n = 0
		_idle_clip = "stay"
		if _body_play == "up":
			return _play_range(12, 20, "", 1, delta)
		return _play_range(71, 76, "", 1, delta)
	var edge := _edge_frame(false)
	if edge > 0:
		_free_n = 0
		_body_play = ""
		_idle_clip = "stay"
		return edge
	if _free_n > 0:
		_idle_clip = "free%d" % _free_n
		var shown := mini(int(_body_frame), 49)
		_body_frame += delta * FPS
		if shown >= 49:
			_free_n = 0
		return shown
	_body_play = ""
	_idle_clip = "stay"
	_idle_left += delta * FPS
	var ticks := mini(int(_idle_left), 45)
	_idle_left -= float(ticks)
	for _i in ticks:
		if _rng.randf() < 0.01:
			var pick := _rng.randi_range(1, 3)
			if _len("free%d" % pick) <= 0:
				continue
			_free_n = pick
			_body_frame = 1.0
			_idle_clip = "free%d" % _free_n
			return 1
	return 1


func _play_once(clip: String, delta: float) -> int:
	var count := _len(clip)
	if count <= 0:
		return 1
	if _clip != clip:
		_clock = 0.0
		_clip = clip
	else:
		_clock = minf(_clock + delta * FPS, float(count - 1))
	return int(_clock) + 1


func _dim_hair(table: Array, frame: int) -> void:
	var k: float = float(table[clampi(frame, 1, table.size()) - 1]) if not table.is_empty() else 1.0
	var tone := Color(k, k, k)
	for part in [_tail_s, _tail2, _mane, _mane2, _fore, _fore2, _eye, _horn, _helm]:
		if part != null:
			(part as CanvasItem).self_modulate = tone


## Frames first..last once, then held on last. key restarts the clock when it changes.
func _play_span(clip: String, key: String, first: int, last: int, delta: float) -> int:
	if _clip != key:
		_clock = 0.0
		_clip = key
	else:
		_clock = minf(_clock + delta * FPS, float(maxi(last - first, 0)))
	return clampi(first + int(_clock), 1, maxi(_len(clip), 1))


func _cycle(clip: String, delta: float) -> int:
	var count := _len(clip)
	if count <= 0:
		_clip = clip
		return 1
	var keep: bool = _clip in _GAITS and clip in _GAITS and _len(_clip) == count
	if _clip != clip and not keep:
		_clock = 0.0
	else:
		_clock = fposmod(_clock + delta * FPS, float(count))
	_clip = clip
	return int(_clock) + 1


func _air_pick(state: String, motion: Vector2, delta: float) -> Array:
	# animatePlayerMovement in the air. aJump > 0 holds "jump" for the whole
	# flight. A fall that did not start from a jump is "pinok".
	var a_jump: bool = _ps.get("a_jump", state == "jump") == true
	var levit := state == "levitate"
	if _air != "jump" and _air != "levit":
		_air = "jump" if a_jump else "pinok"
	if levit and _air != "levit":
		# Hover takes over only from body frames 14-18 after a jump (levit from 1),
		# or 10-22 otherwise (levit from 51).
		if a_jump and _air_shown >= 14 and _air_shown <= 18:
			_air = "levit"
			_clock = 0.0
			_hover_entry = false
		elif not a_jump and _air_shown >= 10 and _air_shown <= 22:
			_air = "levit"
			_clock = float(HOVER_ENTRY - 1)
			_hover_entry = true
		if _air == "levit":
			_clip = "levit"
			return ["levit", int(_clock) + 1]
	if _air == "levit":
		_clip = "levit"
		_clock += delta * FPS
		var f := int(_clock) + 1
		if levit:
			# body_levit frame50 / frame65: gotoAndPlay(17). Hover loops 17-49;
			# the fall entry 51-64 runs once. Past 66 (let go, held again) is 17.
			if f >= (HOVER_ENTRY_END if _hover_entry else HOVER_LOOP_END):
				_clock = float(HOVER_FROM - 1)
				_hover_entry = false
		else:
			# Letting go: gotoAndPlay(67) below 66; frame75 stop() holds until landing.
			if f < HOVER_TO:
				_clock = float(HOVER_TO)
			_clock = minf(_clock, float(HOVER_STOP - 1))
		return ["levit", int(_clock) + 1]
	var vy := motion.y / FPS
	var vx := motion.x / FPS
	var frame := 1
	if _air == "jump":
		frame = clampi(int(round(16.0 + vy)), 1, 32)
	elif vy > 2.0 and vx > -6.0 and vx < 6.0:
		frame = clampi(int(round(31.0 + vy)), 33, 42)
	else:
		frame = clampi(int(round(16.0 + vx * scale.x)), 1, 32)
	_air_shown = frame
	var clip := _air
	if clip == "pinok" and _len("pinok") <= 0:
		clip = "jump"
		frame = clampi(frame, 1, 32)
	_clip = clip
	return [clip, frame]


func _climb_frame(vy: float, delta: float) -> int:
	if absf(vy) < CLIMB_STILL:
		_clip = "climb"
		_clock = 1.0
		return 1
	if _clip != "climb":
		_clip = "climb"
		_clock = 1.0
	# Up (negative y) steps 2→13. Down steps the other way. Same as animate().
	var dir := 1.0 if vy < 0.0 else -1.0
	_clock += dir * delta * FPS
	_clock = fposmod(_clock - 1.0, 12.0) + 1.0
	return int(_clock) + 1


func _note_missing_clip(clip_name: String) -> void:
	if _missing_attack.has(clip_name):
		return
	_missing_attack[clip_name] = true
	push_warning("pony clip '%s' is missing under clips/; holding stay" % clip_name)


func _show(clip: String, frame: int) -> void:
	var frames: Array = _frames.get(clip, [])
	if frames.is_empty():
		return
	var idx := clampi(frame, 1, frames.size()) - 1
	var hd_frames: Array = _hd_frames.get(clip, [])
	var zoom := HD_ZOOM if idx < hd_frames.size() else 1.0
	var tex: Texture2D = hd_frames[idx] if zoom > 1.0 else frames[idx]
	if _sprite.texture != tex:
		_sprite.texture = tex
	_sprite.scale = Vector2.ONE / zoom
	_sprite.offset = -_anchor_of(clip) * zoom
	# Worn armour: the limb sub-clips on their armour label with the fur
	# parts left out, same canvas as the body frame, drawn untinted on top.
	var worn: Array = _worn_frames(clip)
	if _armor_sprite != null:
		_armor_sprite.visible = not worn.is_empty()
		if not worn.is_empty():
			var atex := _worn_tex(str(worn[clampi(frame, 1, worn.size()) - 1]))
			if _armor_sprite.texture != atex:
				_armor_sprite.texture = atex
			_armor_sprite.offset = -_armor_anchor.get(clip, _anchor_of(clip))
	_shown_clip = clip
	_shown_frame = frame
	_place_rig(clip, frame)


func _place_markers(state: String, clip: String) -> void:
	var shoulder := Vector2(10, -28)
	var spell := Vector2(28, -42)
	if state == "crouch":
		shoulder = Vector2(8, -18)
		spell = Vector2(26, -30)
	elif clip == "climb":
		shoulder = Vector2(6, -18)
		spell = Vector2(6, -50)
	elif clip == "trot_up":
		shoulder = Vector2(10, -34)
		spell = Vector2(26, -50)
	_shoulder.position = shoulder
	if not _konec_ok:
		_spell.position = spell


## vis.osn.body.totalFrames for a clip, 0 if it was not exported.
func clip_len(clip: String) -> int:
	return _len(clip)


func _len(clip: String) -> int:
	var frames: Variant = _frames.get(clip)
	if frames == null:
		return 0
	return (frames as Array).size()


func _body_velocity() -> Vector2:
	var body := get_parent() as CharacterBody2D
	if body == null:
		return Vector2.ZERO
	return body.velocity


func _build() -> void:
	_load_clips()
	_art = Node2D.new()
	_art.name = "Art"
	_art.scale = Vector2(BODY_DRAW, BODY_DRAW)
	add_child(_art)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_art.add_child(_sprite)
	_upper_sprite = Sprite2D.new()
	_upper_sprite.name = "Upper"
	_upper_sprite.centered = false
	_upper_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_upper_sprite.visible = false
	_art.add_child(_upper_sprite)
	_armor_sprite = Sprite2D.new()
	_armor_sprite.name = "Armor"
	_armor_sprite.centered = false
	_armor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_armor_sprite.visible = false
	_art.add_child(_armor_sprite)
	_shoulder = Marker2D.new()
	_shoulder.position = Vector2(10, -28)
	_art.add_child(_shoulder)
	_spell = Marker2D.new()
	_spell.position = Vector2(28, -42)
	_art.add_child(_spell)
	_gun = Node2D.new()
	_gun.name = "Weapon"
	_gun.set_meta("no_tele_glow", true)
	_gun.z_index = 3
	_gun.top_level = true
	add_child(_gun)
	_gun_sprite = Sprite2D.new()
	_gun_sprite.name = "Vis"
	_gun.add_child(_gun_sprite)
	_gun_glow = _WeaponVis.make_glow(_gun_sprite)
	_build_wings()
	_build_rig()
	_muzzle = Marker2D.new()
	_muzzle.position = Vector2(28, 0)
	_gun.add_child(_muzzle)
	_show("stay", 1)
	_place_markers("idle", "stay")
	set_weapon(_weapon)


func _load_clips() -> void:
	for clip_name in _ANCHOR.keys():
		var folder := "res://assets/sprites/pony/clips/%s" % clip_name
		_frames[clip_name] = _load_sequence(folder)
		if hd:
			_hd_frames[clip_name] = _load_sequence(folder + "/hd")
		var anchor: Variant = _read_json(folder + "/anchor.json")
		if anchor is Array and (anchor as Array).size() >= 2:
			_anchor[clip_name] = Vector2(float(anchor[0]), float(anchor[1]))
		else:
			_anchor[clip_name] = _ANCHOR[clip_name]
		var tracks: Variant = _read_json(folder + "/tracks.json")
		if tracks is Dictionary:
			_tracks[clip_name] = tracks
		var upper := _load_sequence(folder + "/upper")
		var upper_anchor: Variant = _read_json(folder + "/upper/anchor.json")
		if not upper.is_empty() and upper_anchor is Array and (upper_anchor as Array).size() >= 2:
			_upper_frames[clip_name] = upper
			_upper_anchor[clip_name] = Vector2(float(upper_anchor[0]), float(upper_anchor[1]))
	for part in _PARTS:
		var part_folder := "res://assets/sprites/pony/parts/%s" % part
		_parts[part] = _load_sequence(part_folder)
		if hd:
			_hd_parts[part] = _load_sequence(part_folder + "/hd")
		_part_anchor[part] = _load_part_anchors(part_folder + "/anchors.json")
	var helm_labels: Variant = _read_json("res://assets/sprites/pony/parts/helm/labels.json")
	if helm_labels is Dictionary:
		_helm_labels = helm_labels


## clip_name's frame paths on the worn suit, listed once per suit for every
## puppet. A frame's texture loads when it is first drawn (_worn_tex).
func _worn_frames(clip_name: String) -> Array:
	if _armor_id == "":
		return []
	if _armor_frames.has(clip_name):
		return _armor_frames[clip_name]
	var entry: Array = _suit_entry(_armor_id, clip_name)
	_armor_frames[clip_name] = entry[0]
	if entry[1] is Vector2:
		_armor_anchor[clip_name] = entry[1]
	return entry[0]


static func _suit_entry(armor: String, clip_name: String) -> Array:
	var key := "%s/%s" % [armor, clip_name]
	_lock.lock()
	var cached: Variant = _armor_cache.get(key)
	_lock.unlock()
	if cached is Array:
		return cached
	var folder := "res://assets/sprites/pony/clips/%s/%s" % [clip_name, armor]
	var paths: Array = []
	var i := 1
	while ResourceLoader.exists("%s/%d.png" % [folder, i]):
		paths.append("%s/%d.png" % [folder, i])
		i += 1
	# A suit wider than the body frame carries its own origin.
	var anchor: Variant = null
	var parsed: Variant = _read_json(folder + "/anchor.json") if not paths.is_empty() else null
	if parsed is Array and (parsed as Array).size() >= 2:
		anchor = Vector2(float(parsed[0]), float(parsed[1]))
	var entry := [paths, anchor]
	_lock.lock()
	_armor_cache[key] = entry
	_lock.unlock()
	return entry


static func _worn_tex(path: String) -> Texture2D:
	_lock.lock()
	var tex: Texture2D = _armor_tex.get(path)
	_lock.unlock()
	if tex == null:
		tex = load(path) as Texture2D
		_lock.lock()
		_armor_tex[path] = tex
		_lock.unlock()
	return tex


## Loads every body clip and part sequence (normal and HD) on a worker thread,
## then runs `after` on the same worker (warm_up.gd's groups: one loader at a
## time). `on_quit` runs at shutdown once the task is done.
static func warm_up(after := Callable(), on_quit := Callable()) -> void:
	if _warm_started:
		return
	_warm_started = true
	if on_quit.is_valid():
		_on_quit.append(on_quit)
	_start_task(_warm_body.bind(after))
	_warm_task = _tasks[-1]


## True once warm_up's task has finished, or when it never started.
static func warm_done() -> bool:
	return _warm_task < 0 or WorkerThreadPool.is_task_completed(_warm_task)


static func _start_task(job: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and not tree.root.tree_exiting.is_connected(_drop_on_quit):
		tree.root.tree_exiting.connect(_drop_on_quit)
	_tasks.append(WorkerThreadPool.add_task(job))


## Textures still held in static vars at shutdown are freed after the renderer
## and crash the exit, so the caches let go while the tree is still up.
static func _drop_on_quit() -> void:
	for id in _tasks:
		WorkerThreadPool.wait_for_task_completion(id)
	_tasks.clear()
	_warm_task = -1
	_lock.lock()
	_seq_cache.clear()
	_armor_tex.clear()
	_armor_cache.clear()
	_lock.unlock()
	for job in _on_quit:
		job.call()
	_on_quit.clear()


static func _warm_body(after: Callable) -> void:
	for clip_name in _ANCHOR.keys():
		var folder := "res://assets/sprites/pony/clips/%s" % clip_name
		for sub in ["", "/upper", "/hd"]:
			_load_sequence(folder + sub)
	for part in _PARTS:
		_load_sequence("res://assets/sprites/pony/parts/%s" % part)
		_load_sequence("res://assets/sprites/pony/parts/%s/hd" % part)
	if after.is_valid():
		after.call()

## Loads a suit's frames for every clip off the main thread, so the first
## time each frame is drawn does not stall the animation.
static func _warm_suit(armor: String) -> void:
	if armor == "":
		return
	_lock.lock()
	var started: bool = _suits_warming.has(armor)
	_suits_warming[armor] = true
	_lock.unlock()
	if not started:
		_start_task(_warm_suit_frames.bind(armor))


static func _warm_suit_frames(armor: String) -> void:
	for clip_name in _ANCHOR.keys():
		for path in _suit_entry(armor, clip_name)[0]:
			_worn_tex(str(path))


static func _load_sequence(folder: String) -> Array[Texture2D]:
	_lock.lock()
	var cached: Variant = _seq_cache.get(folder)
	_lock.unlock()
	if cached != null:
		return cached
	var frames: Array[Texture2D] = []
	var i := 1
	while true:
		var path := "%s/%d.png" % [folder, i]
		if not ResourceLoader.exists(path):
			break
		var tex := load(path) as Texture2D
		if tex == null:
			break
		frames.append(tex)
		i += 1
	_lock.lock()
	_seq_cache[folder] = frames
	_lock.unlock()
	return frames


func _anchor_of(clip: String) -> Vector2:
	if _anchor.has(clip):
		return _anchor[clip] as Vector2
	return _ANCHOR.get(clip, Vector2.ZERO) as Vector2


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _load_part_anchors(path: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var parsed: Variant = _read_json(path)
	if parsed is Array:
		for item in parsed:
			if item is Array and (item as Array).size() >= 2:
				out.append(Vector2(float(item[0]), float(item[1])))
	return out


func _build_rig() -> void:
	# Tail sits behind the coat. Mane and forelock sit on top of it.
	# The PipBuck is the front-most leg device (pip1).
	_tail_s = _make_part("Tail", -1)
	_tail2 = _make_part("TailHighlight", -1)
	_mane = _make_part("Mane", 1)
	_mane2 = _make_part("ManeHighlight", 1)
	_fore = _make_part("Forelock", 2)
	_fore2 = _make_part("ForelockHighlight", 2)
	_eye = _make_part("Eye", 3)
	var eye_mat := ShaderMaterial.new()
	eye_mat.shader = _EyeShader
	_eye.material = eye_mat
	_horn = _make_part("Horn", 4)
	_magic = _make_part("Magic", 5)
	var magic_mat := ShaderMaterial.new()
	magic_mat.shader = _MagicShader
	_magic.material = magic_mat
	_helm = _make_part("Helm", 5)
	_pip = _make_part("PipBuck", 6)
	# Facing left it drops to z 0 between the body and the upper layers.
	_art.move_child(_pip, _sprite.get_index() + 1)


## A CanvasGroup only captures children on its own z, so the preview turns the
## art layers' z order into tree order. The preview always faces right.
func _flatten_z() -> void:
	var layers: Array = _art.get_children().filter(func(n: Node) -> bool: return n is CanvasItem)
	var order := range(layers.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var za: int = (layers[a] as CanvasItem).z_index
		var zb: int = (layers[b] as CanvasItem).z_index
		return za < zb or (za == zb and a < b))
	for i in order.size():
		var item: CanvasItem = layers[order[i]]
		_art.move_child(item, i)
		item.z_index = 0


## Lurk: the parts keep their order but share the body's z, so a box raised over
## the pony also covers the eye, horn and PipBuck. Off restores z and order.
func set_flat_layers(on: bool) -> void:
	if on == _flat:
		return
	_flat = on
	if on:
		_flat_saved.clear()
		for item in _art.get_children():
			if item is CanvasItem:
				_flat_saved.append([item, (item as CanvasItem).z_index, item.get_index()])
		_flatten_z()
		return
	for row_v in _flat_saved:
		var row: Array = row_v
		var item := row[0] as CanvasItem
		if is_instance_valid(item):
			item.z_index = int(row[1])
	for row_v in _flat_saved:
		var row: Array = row_v
		if is_instance_valid(row[0]):
			_art.move_child(row[0], mini(int(row[2]), _art.get_child_count() - 1))
	_flat_saved.clear()


func _make_part(part_name: String, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = part_name
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = z
	sprite.visible = false
	_art.add_child(sprite)
	return sprite


func _place_rig(clip: String, frame: int) -> void:
	if _mane == null:
		return
	var hair := _style_hair
	_place_matrix(_mane, "h0", hair, _track(clip, frame, "mane"), _MANE_AT)
	_place_matrix(_fore, "fore0", hair, _track(clip, frame, "head"), _FORE_AT)
	_place_matrix(_tail_s, "tail0", hair, _track(clip, frame, "tail"), _TAIL_AT)
	if _vis_hair1:
		_place_matrix(_mane2, "h1", hair, _track(clip, frame, "mane"), _MANE_AT)
		_place_matrix(_fore2, "fore1", hair, _track(clip, frame, "head"), _FORE_AT)
		_place_matrix(_tail2, "tail1", hair, _track(clip, frame, "tail"), _TAIL_AT)
	else:
		_mane2.visible = false
		_fore2.visible = false
		_tail2.visible = false
	var helm: Dictionary = _helm_labels.get(_armor_id, {})
	if not helm.is_empty() and not bool(helm.get("hair", true)):
		_fore.visible = false
		_fore2.visible = false
	_place_eye(clip, frame)
	_place_horn(clip, frame)
	_place_magic(clip, frame)
	_place_helm(clip, frame, helm)
	var leg_key := "fr" if scale.x >= 0.0 else "fl"
	_place_pip(_track(clip, frame, leg_key))
	_place_upper(clip, frame, leg_key == "fl" and _pip.visible)


func _place_matrix(sprite: Sprite2D, part: String, index: int, matrix: Array, extra: Vector2) -> void:
	if matrix.size() < 6 or not _set_part(sprite, part, index):
		sprite.visible = false
		return
	sprite.transform = _mat(matrix) * Transform2D(0.0, extra)
	sprite.visible = true


func _place_eye(clip: String, frame: int) -> void:
	var head := _track(clip, frame, "head")
	if head.size() < 6 or not _set_part(_eye, "eye", _style_eye):
		_eye.visible = false
		return
	_eye.transform = _mat(head) * Transform2D(0.0, _MORDA_AT) * _eye_basis() * Transform2D(0.0, _EYE_IN)
	_eye.visible = true


func _place_horn(clip: String, frame: int) -> void:
	var head := _track(clip, frame, "head")
	_konec_ok = head.size() >= 6 and _spell != null
	if _konec_ok:
		_spell.position = _mat(head) * Transform2D(0.0, _MORDA_AT) * _KONEC_IN
	if _horn == null or head.size() < 6 or not _set_part(_horn, "horn", 1):
		if _horn != null:
			_horn.visible = false
		return
	# morda.horn sits on the head instance, same chain as the magic oval.
	_horn.transform = _mat(head) * Transform2D(0.0, _MAGIC_AT)
	_horn.visible = true


func _place_helm(clip: String, frame: int, helm: Dictionary) -> void:
	if _helm == null:
		return
	var head := _track(clip, frame, "head")
	if helm.is_empty() or head.size() < 6 or not _set_part(_helm, "helm", int(helm.get("frame", 0))):
		_helm.visible = false
		return
	_helm.transform = _mat(head) * Transform2D(0.0, _MORDA_AT)
	_helm.visible = true


func _place_magic(clip: String, frame: int) -> void:
	var head := _track(clip, frame, "head")
	var alpha := 1.0 if _magic_preview else _horn_alpha
	if _magic == null or head.size() < 6 or alpha <= 0.01 or not _set_part(_magic, "magic", 1):
		if _magic != null:
			_magic.visible = false
		return
	_magic.transform = _mat(head) * Transform2D(0.0, _MAGIC_AT)
	_magic.modulate = Color(1.0, 1.0, 1.0, alpha)
	_magic.visible = true


func _step_glow(delta: float, state: String) -> void:
	# aMC moves 5 points toward aMagic each 30 Hz tick. 5/100 per tick is 1.5/s.
	var target := _glow_target(state)
	var step := 1.5 * delta
	if _horn_alpha < target:
		_horn_alpha = minf(target, _horn_alpha + step)
	elif _horn_alpha > target:
		_horn_alpha = maxf(target, _horn_alpha - step)


func _glow_target(state: String) -> float:
	if _magic_preview:
		return 1.0
	var target := 0.0
	if _want_weapon:
		target = 0.5
	if _want_tele:
		target = 1.0 if _want_tele_heavy else maxf(target, 0.5)
	if _want_spell:
		target = maxf(target, 0.5)
	# levit == 1 forces aMagic to 100.
	if state == "levitate":
		target = 1.0
	return target


func _paint_eye(eye: Color) -> void:
	if _eye == null:
		return
	_eye.modulate = Color.WHITE
	var mat := _eye.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("iris_mul", Vector3(eye.r, eye.g, eye.b))


func _paint_magic() -> void:
	if _magic == null:
		return
	var mat := _magic.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("magic_mul", Vector3(_magic_color.r, _magic_color.g, _magic_color.b))


func _place_pip(leg: Array) -> void:
	if leg.size() < 6 or not _set_part(_pip, "pip", 1):
		_pip.visible = false
		return
	var bags := get_node_or_null("/root/Inventory")
	if bags == null or not bool(bags.get("leg_pip")):
		_pip.visible = false
		return
	_pip.visible = true
	_pip.position = Vector2(float(leg[4]), float(leg[5]))
	_pip.rotation = atan2(float(leg[1]), float(leg[0]))
	_pip.scale = Vector2.ONE
	var hd_pip: Array = _hd_parts.get("pip", [])
	if not hd_pip.is_empty():
		_pip.texture = hd_pip[0]
		_pip.offset *= HD_ZOOM
		_pip.scale = Vector2.ONE / HD_ZOOM


func _place_upper(clip: String, frame: int, behind: bool) -> void:
	var frames: Array = _upper_frames.get(clip, [])
	behind = behind and not frames.is_empty()
	_upper_sprite.visible = behind
	if not hd and not _flat:
		_pip.z_index = 0 if behind else 6
	if not behind:
		return
	var tex: Texture2D = frames[clampi(frame, 1, frames.size()) - 1]
	if _upper_sprite.texture != tex:
		_upper_sprite.texture = tex
	_upper_sprite.offset = -(_upper_anchor[clip] as Vector2)


func _set_part(sprite: Sprite2D, part: String, index: int) -> bool:
	var frames: Array = _parts.get(part, [])
	if frames.is_empty() or sprite == null:
		return false
	var idx := clampi(index, 1, frames.size()) - 1
	sprite.texture = frames[idx]
	var anchors: Array = _part_anchor.get(part, [])
	var anchor := Vector2.ZERO
	if idx < anchors.size() and anchors[idx] is Vector2:
		anchor = anchors[idx]
	elif not anchors.is_empty() and anchors[0] is Vector2:
		anchor = anchors[0]
	sprite.offset = -anchor
	return true


func _track(clip: String, frame: int, key: String) -> Array:
	var data: Variant = _tracks.get(clip, {})
	if not (data is Dictionary):
		return []
	var frames: Variant = (data as Dictionary).get("frames", [])
	if not (frames is Array) or (frames as Array).is_empty():
		return []
	var idx := clampi(frame, 1, (frames as Array).size()) - 1
	var row: Variant = (frames as Array)[idx]
	if row is Dictionary:
		var value: Variant = (row as Dictionary).get(key, [])
		if value is Array:
			return value
	return []


func _mat(m: Array) -> Transform2D:
	return Transform2D(
		Vector2(float(m[0]), float(m[1])),
		Vector2(float(m[2]), float(m[3])),
		Vector2(float(m[4]), float(m[5]))
	)


func _eye_basis() -> Transform2D:
	# morda places eye 220, then the shape clip sits inside that.
	return Transform2D(
		Vector2(0.9839477539, -0.0731658936),
		Vector2(0.0859069824, 0.9957275391),
		Vector2(-34.35, -18.3)
	)


func _able_fly() -> bool:
	# pers.ableFly. ali is the only suit with ableFly. The alicorn effect
	# and potion_fly set the same flag from effs.xml.
	if _armor_id == "ali":
		return true
	return _effect_on("alicorn") or _effect_on("potion_fly")


func _effect_on(id: String) -> bool:
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("effect_active"):
		return bool(state.effect_active(id))
	return false


func _build_wings() -> void:
	# The wing symbols are not in the body strips. UnitPlayer toggles
	# lwing/rwing from pers.ableFly. These stand in for that pair.
	_wings = Node2D.new()
	_wings.name = "Wings"
	_wings.z_index = -1
	_wings.visible = false
	_art.add_child(_wings)
	_wing_near = Polygon2D.new()
	_wing_near.color = Color(0.86, 0.9, 0.95, 0.92)
	_wings.add_child(_wing_near)
	_wing_far = Polygon2D.new()
	_wing_far.color = Color(0.55, 0.66, 0.78, 0.88)
	_wings.add_child(_wing_far)


func _place_wings(state: String) -> void:
	if _wings == null:
		return
	var fly := _able_fly()
	_wings.visible = fly
	if not fly:
		return
	# ali armor and the alicorn effect hold the wings on frame 11.
	# potion_fly holds frame 1 on the ground and plays while airborne.
	var spread := _armor_id == "ali" or _effect_on("alicorn")
	if not spread and state in ["jump", "fall", "levitate"]:
		spread = true
	var y := -40.0
	if state == "crouch":
		y = -28.0
	elif state == "climb":
		y = -30.0
	_wings.position = Vector2(-4, y)
	if spread:
		_wing_near.polygon = PackedVector2Array([
			Vector2(8, -2), Vector2(-8, -28), Vector2(-40, -18),
			Vector2(-28, -2), Vector2(-6, 8), Vector2(8, 6)
		])
		_wing_far.polygon = PackedVector2Array([
			Vector2(4, -12), Vector2(-12, -34), Vector2(-32, -26),
			Vector2(-20, -10), Vector2(2, -4)
		])
	else:
		_wing_near.polygon = PackedVector2Array([
			Vector2(6, 0), Vector2(-18, -8), Vector2(-20, 4), Vector2(-6, 8), Vector2(6, 4)
		])
		_wing_far.polygon = PackedVector2Array([
			Vector2(4, -6), Vector2(-12, -12), Vector2(-14, -2), Vector2(2, 0)
		])


func _place_gun(state: String, delta: float) -> void:
	# UnitPlayer.setWeaponPos with weaponKrep false. The old shoulder marker
	# was art (10, -28) times BODY_DRAW 1.2: 12px out and 33.6px up.
	# littlepip sX is 50. Outward aim sits a full body-width off the hooves.
	# Guns use 0.70 of the box height. The 0.20 chase is Weapon.actions.
	var feet := global_position
	var box := _body_box()
	var facing := scale.x if scale.x != 0.0 else 1.0
	var cel := _aim_world()
	var off_x := 0.0
	if state != "climb":
		var past := (facing > 0.0 and cel.x > feet.x + box.x * 0.5) or (facing < 0.0 and cel.x < feet.x - box.x * 0.5)
		if past:
			off_x = box.x * facing
	var hold := Vector2(feet.x + off_x, feet.y - box.y * 0.70)
	if off_x != 0.0 and (_point_solid(hold) or _point_solid(hold + Vector2(15.0 * facing, 0.0))):
		hold.x = feet.x
	# weapUp comes from the player (stay + keyBeUp past 10 ticks).
	if _ps.get("weapon_raised", false) == true and not _point_solid(Vector2(hold.x, hold.y - 40.0)):
		hold.y -= 40.0
	if _weapon_lowered:
		hold = Vector2(feet.x, feet.y - box.y * 0.50)
	# Weapon.setNull on teleports; the lag never exceeds ~80 px otherwise.
	if not _hold_ready or not is_inside_tree() or _gun_pos.distance_squared_to(hold) > 200.0 * 200.0:
		_gun_pos = hold
		_hold_ready = true
	else:
		var gain := 1.0 - pow(0.8, delta * 30.0)
		_gun_pos = _gun_pos.lerp(hold, gain)
	var aim := (cel - _gun_pos).angle()
	# drot2 replaces drot while t_prep > 0 or t_attack > 0. Degrees per tick.
	var drot := float(_weapon.get("drot", 0.0))
	var drot2 := float(_gun_fx.get("drot2", 0.0))
	if drot2 > 0.0 and (_t_prep > 0.0 or _t_attack > 0):
		drot = drot2
	if drot <= 0.0:
		_gun_angle = aim
	else:
		_gun_angle = rotate_toward(_gun_angle, aim, deg_to_rad(drot) * drot_mult * 30.0 * delta)
	_tick_gun(delta)
	# Weapon.animate: vis.x = X - t_ret * scaleX * 2. When the cursor is left of
	# the weapon, scaleX = -1 and rotation = rot + 180 + rotUp, else rot - rotUp.
	# WThrow.animate holds rotation 0 and scaleX 1.
	var flip := 1.0
	if _is_throwable():
		_gun.global_rotation = 0.0
	elif _gun_pos.x > cel.x:
		flip = -1.0
		_gun.global_rotation = _gun_angle + PI + deg_to_rad(_rot_up)
	else:
		_gun.global_rotation = _gun_angle - deg_to_rad(_rot_up)
	_gun.scale = Vector2(flip, 1.0)
	_gun.global_position = _gun_pos - Vector2(float(_t_ret) * flip * 2.0, 0.0)
	_gun_sprite.visible = not (_is_throwable() and _weapon_hidden)
	_WeaponVis.sync_glow(_gun_sprite, _gun_glow, _WeaponVis.tele_color(), true)


func _tick_gun(delta: float) -> void:
	_gun_acc += delta
	var guard := 0
	while _gun_acc >= 1.0 / 30.0 and guard < 3:
		_gun_acc -= 1.0 / 30.0
		guard += 1
		# The Flash playhead advances before the frame's logic. A shoot or
		# reload started this frame is drawn first, then plays on.
		if _gun_clip != null:
			if _gun_fresh:
				_gun_fresh = false
			else:
				_gun_clip.advance()
		if _t_ret > 0:
			_t_ret -= 1
		if _t_attack > 0:
			_t_attack -= 1
		if _rot_up > 5.0:
			_rot_up *= 0.9
		elif _rot_up > 0.5:
			_rot_up -= 0.5
		else:
			_rot_up = 0.0
		if _t_shoot > 0:
			_t_shoot -= 1
		_animate_prep()
	if _gun_clip != null:
		_gun_clip.show(_gun_sprite)


func _animate_prep() -> void:
	# Weapon.animate for spin-up weapons (minigun, bfg): t_prep picks the frame.
	var prep := int(_weapon.get("prep", 0))
	if _gun_clip == null or prep <= 0 or _t_shoot > 0:
		return
	var t := int(_t_prep)
	if t < prep and t > 1:
		_gun_clip.goto_stop(t)
	if t >= prep and _gun_clip.label("ready") > 0:
		_gun_clip.goto_stop("ready")
	if t <= 1 and not _t_reload:
		_gun_clip.goto_stop(1)


func _aim_world() -> Vector2:
	var cursor := get_tree().get_first_node_in_group("aim_cursor")
	if cursor and cursor.has_method("world_position"):
		return cursor.world_position()
	return get_global_mouse_position()


func _body_box() -> Vector2:
	var body := get_parent() as CharacterBody2D
	if body == null:
		return Vector2(50, 78)
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		return (shape_node.shape as RectangleShape2D).size
	return Vector2(50, 78)


func _point_solid(at: Vector2) -> bool:
	var body := get_parent() as CollisionObject2D
	if body == null:
		return false
	var space := body.get_world_2d().direct_space_state
	if space == null:
		return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = at
	query.collision_mask = 1
	query.collide_with_areas = false
	query.exclude = [body.get_rid()]
	return not space.intersect_point(query, 1).is_empty()
