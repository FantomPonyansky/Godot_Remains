extends Node2D

## Side-view pony on OTHER's player rig (`assets/rigs/player`, driven through
## `scripts/rig/player_rig_port.gd`). Each pose holds a frame of a Flash
## `body_<clip>` timeline; clip lengths and labels are `assets/data/pony_clips.json`.
## Frames play at 30 fps. Feet sit on this node's origin. scale.x flips the pony.
## The art node holds the rig and the markers at BODY_DRAW; the rig itself is
## Flash size (1 / BODY_DRAW under it).
## A levitated gun uses the vis clip and UnitPlayer's hold, and points at the cursor.
## Idle holds stay frame 1, then free1/2/3 the way UnitPlayer rolls them.
## Crouch plays stay "down" into frame 2. Standing plays "up". Moving crouch is polz.
## Wings show only while pers.ableFly is set. The PipBuck shows after the stable grant.

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
const BODY_DRAW := 1.2
const _GAITS: Array[String] = ["walk", "trot", "trot_up", "trot_down", "run"]
const CLIPS := "res://assets/data/pony_clips.json"

const Look := preload("res://scripts/pony_look.gd")
const _WeaponVis := preload("res://scripts/weapon_vis.gd")
const _WeaponFx := preload("res://scripts/weapon_fx.gd")
const _PLAYER_RIG := "res://assets/rigs/player/player_rig.tscn"
const _PLAYER_ART := "res://assets/rigs/player/art/"
const _PlayerRigPort := preload("res://scripts/rig/player_rig_port.gd")
## The rig's fuller tail, mane and helmets need more room than the old frame clips (user, 2026-10-31).
const PREVIEW_FIT := 0.8

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
var _rig: Node2D
## body_<clip> frame counts and labels, shared by every puppet.
static var _clips: Dictionary = {}

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
## The rig scene and art, loaded once on a worker (warm_up) and held for the session.
static var _held: Array[Resource] = []
static var _lock := Mutex.new()
static var _warm_started := false
static var _tasks: Array[int] = []
static var _on_quit: Array[Callable] = []
static var _warm_task := -1
var _pose: String = "idle"
var _missing_attack: Dictionary = {}
var _magic_color := Color(0.137, 1.0, 0.137)
var _horn_alpha := 0.0
var _want_weapon := false
var _want_tele := false
var _want_tele_heavy := false
var _want_spell := false
var _magic_preview := false
var _shown_clip := "stay"
var _shown_frame := 1
var _idle_clip := "stay"
var _free_n := 0
var _body_play := ""
var _body_frame := 1.0
var _idle_left := 0.0
var _rng := RandomNumberGenerator.new()


## Menu pony (visBodyStay instances): the puppet in a CanvasGroup carrying the
## instance's GlowFilter (00FF99, strength 2.9; blur 4 on dialNew, 3 elsewhere).
## z 1 keeps the tail above the dialog panel it stands on. The rig's own
## CanvasGroups do not draw inside the glow group, so the rig renders in a
## SubViewport and the group holds its texture.
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
	var feet := Vector2(90, 130)
	var view := SubViewport.new()
	view.transparent_bg = true
	view.disable_3d = true
	view.size = Vector2i((Vector2(180, 160) * holder_scale).ceil())
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var zoom := Node2D.new()
	zoom.position = feet * holder_scale
	zoom.scale = Vector2.ONE * holder_scale * PREVIEW_FIT
	zoom.add_child(puppet)
	view.add_child(zoom)
	group.add_child(view)
	var shown := Sprite2D.new()
	shown.centered = false
	shown.texture = view.get_texture()
	shown.scale = Vector2.ONE / holder_scale
	shown.position = -feet
	group.add_child(shown)
	return [group, puppet]


func _ready() -> void:
	add_to_group("pony_puppet")
	_rng.randomize()
	_build()
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


## Obj.setArmor: every armour symbol of the rig stops on the suit label (pip,
## kombu, metal, ali, ...); an empty id is the unlabeled frame. The mane hides
## under the suits with AllData hide='1'. lwing/rwing show while pers.ableFly
## is set: ali armor, the alicorn effect, or potion_fly.
func set_armor(id: String = "") -> void:
	_armor_id = id
	if _rig != null:
		_rig.set_armor(id)
		_show(_shown_clip, _shown_frame)

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
		_show(_shown_clip, _shown_frame)


## The player rig.
func rig() -> Node2D:
	return _rig


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
	_magic_color = Look.tint(look.magic)
	if _rig == null:
		return
	for pair in [["trFur", look.fur], ["trHair", look.hair], ["trHair1", look.hair1],
			["trEye", look.eye], ["trMagic", look.magic]]:
		var rgb: Array = pair[1]
		_rig.set_channel_color(pair[0], Color8(int(rgb[0]), int(rgb[1]), int(rgb[2])))
	_rig.set_hair(clampi(int(look.hair_style), 1, Look.MAX_HAIR) - 1)
	_rig.set_eye_style(clampi(int(look.eye_style), 1, Look.MAX_EYE) - 1)
	_rig.set_hair1_visible(bool(look.vis_hair1))
	if _shown_clip != "":
		_show(_shown_clip, _shown_frame)


func update_pose(state: String, facing: float, aim_dir: Vector2, delta: float) -> void:
	if _rig == null:
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
			var un := _label(clip, "un", _len(clip))
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
	_place_markers(state, clip)
	# Melee is carried in world space by the player. A shoulder parent would
	# orbit the blade. The swing and its reach stay on the player.
	if str(_weapon.get("kind", "")) == "melee":
		if _gun != null:
			_gun.visible = false
	elif _gun != null and _gun.visible:
		_place_gun(state, delta)
	_pose = state


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


## The rig holds frame `frame` of the Flash body_<clip> timeline (climb is body_laz).
func _show(clip: String, frame: int) -> void:
	if _rig == null or _len(clip) == 0:
		return
	var source := "body_laz" if clip == "climb" else "body_" + clip
	if not _rig.hold_source_frame(source, frame):
		_rig.hold_source_frame("body_stay", 1)
	_shown_clip = clip
	_shown_frame = frame
	var bags := get_node_or_null("/root/Inventory")
	_rig.pip_shown = bags != null and bool(bags.get("leg_pip"))
	_rig.set_facing_right(scale.x >= 0.0)
	_rig.set_magic_intensity(1.0 if _magic_preview else _horn_alpha)
	var fly := _able_fly()
	_rig.set_wings_visible(fly)
	_rig.set_wing_alicorn(fly and (_armor_id == "ali" or _effect_on("alicorn")))
	# morda.konec: magicX/magicY, where spells and magic shots start.
	_spell.position = _rig.get_spell_origin()


func _place_markers(state: String, clip: String) -> void:
	var shoulder := Vector2(10, -28)
	if state == "crouch":
		shoulder = Vector2(8, -18)
	elif clip == "climb":
		shoulder = Vector2(6, -18)
	elif clip == "trot_up":
		shoulder = Vector2(10, -34)
	_shoulder.position = shoulder


## vis.osn.body.totalFrames for a clip, 0 if it is not in pony_clips.json.
func clip_len(clip: String) -> int:
	return _len(clip)


func _len(clip: String) -> int:
	return int((_clip_data(clip)).get("frames", 0))


## A label's frame in body_<clip> (lurk "un"), or `fallback`.
func _label(clip: String, label: String, fallback: int) -> int:
	return int((_clip_data(clip).get("labels", {}) as Dictionary).get(label, fallback))


static func _clip_data(clip: String) -> Dictionary:
	if _clips.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CLIPS))
		_clips = parsed if parsed is Dictionary else {"stay": {"frames": 1}}
	return _clips.get(clip, {})

func _body_velocity() -> Vector2:
	var body := get_parent() as CharacterBody2D
	if body == null:
		return Vector2.ZERO
	return body.velocity


func _build() -> void:
	_art = Node2D.new()
	_art.name = "Art"
	_art.scale = Vector2(BODY_DRAW, BODY_DRAW)
	add_child(_art)
	_rig = load(_PLAYER_RIG).instantiate()
	_rig.set_script(_PlayerRigPort)
	_rig.scale = Vector2.ONE / BODY_DRAW
	_art.add_child(_rig)
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
	_muzzle = Marker2D.new()
	_muzzle.position = Vector2(28, 0)
	_gun.add_child(_muzzle)
	_show("stay", 1)
	_place_markers("idle", "stay")
	set_weapon(_weapon)


## Loads the rig scene and its art on a worker thread, then runs `after` on the
## same worker (warm_up.gd's groups: one loader at a time). `on_quit` runs at
## shutdown once the task is done.
static func warm_up(after := Callable(), on_quit := Callable()) -> void:
	if _warm_started:
		return
	_warm_started = true
	if on_quit.is_valid():
		_on_quit.append(on_quit)
	_start_task(_warm_rig.bind(after))
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
	_held.clear()
	_lock.unlock()
	for job in _on_quit:
		job.call()
	_on_quit.clear()


static func _warm_rig(after: Callable) -> void:
	var loaded: Array[Resource] = [ResourceLoader.load(_PLAYER_RIG)]
	for entry in ResourceLoader.list_directory(_PLAYER_ART):
		if entry.get_extension() == "png":
			loaded.append(ResourceLoader.load(_PLAYER_ART + entry))
	_lock.lock()
	_held.append_array(loaded)
	_lock.unlock()
	if after.is_valid():
		after.call()

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
