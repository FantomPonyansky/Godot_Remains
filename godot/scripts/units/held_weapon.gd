extends Node2D

## A pony or griffon foe's current weapon as its own sprite (Weapon.vis), not sheet art.
## Weapon point: UnitPon.setWeaponPos, then UnitRaider.setWeaponPos (the wPos table per anim
## row and frame, for weapon tip 1, 2 and 4 unless enclweap). krep 0 is a unicorn: the weapon
## floats (eased toward the point, teleColor glow). krep > 0 holds it in the teeth or hooves at
## the point. Griffons (UnitMerc) hold it in visualGrifArm<tr>, drawn above the weapon.
## Guns aim (Weapon.actions / animate). Melee is WClub: a gripped one keeps the table angle,
## a levitated one floats 40 px ahead, raised, and swings on an attack.

const _WeaponVis := preload("res://scripts/weapon_vis.gd")
const DATA := "res://assets/data/unit_wpos.json"
const ARM_DIR := "res://assets/sprites/units/grif_arm/"
const TPS := 30.0
const TIP := {"melee": 1, "lightGun": 2, "heavyGun": 3, "explosives": 4}

static var _data: Dictionary = {}
static var _arms: Dictionary = {}

var _host: Node2D
var _table: Array = []
var _enclweap := false
var _griffon := false
var _tele := Color(0, 0, 0, 0)
var _wid := ""
var _tip := 2
var _mtip := 0
var _clip: _WeaponVis.Clip
var _sprite: Sprite2D
var _glow: Sprite2D
var _arm: Sprite2D
var _arm_emit := Vector2.ZERO
var _eased := false
var _rot := 0.0
var _r := 0.0
var _acc := 0.0
var _last_cd := 0.0
var _t_attack := 0
var _rapid := 15


static func table_key(id: String, sex: String) -> String:
	if id.begins_with("zebra"):
		return "zebra"
	if id.begins_with("ranger"):
		return "ranger"
	if id.begins_with("encl"):
		return "encl"
	if id.begins_with("merc"):
		return "griffon"
	return "raider_w" if sex == "w" else "raider_m"


static func _load() -> void:
	if not _data.is_empty() or not FileAccess.file_exists(DATA):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if parsed is Dictionary:
		_data = parsed
	var arms: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARM_DIR + "arm.json")) if FileAccess.file_exists(ARM_DIR + "arm.json") else null
	if arms is Dictionary:
		_arms = arms


static func unit_flag(id: String, key: String) -> bool:
	_load()
	return bool(((_data.get("units", {}) as Dictionary).get(id, {}) as Dictionary).get(key, false))


func setup(host: Node2D, id: String) -> void:
	_load()
	_host = host
	# Posed every frame in _process, relative to the (interpolated) host.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var unit: Dictionary = (_data.get("units", {}) as Dictionary).get(id, {})
	_table = (_data.get("wpos", {}) as Dictionary).get(table_key(id, str(unit.get("sex", "m"))), [])
	_enclweap = bool(unit.get("enclweap", false))
	_griffon = id.begins_with("merc")
	var tele := str(unit.get("telecolor", ""))
	if tele != "":
		_tele = Color("#" + tele)
	_sprite = Sprite2D.new()
	_sprite.z_index = 1
	add_child(_sprite)
	_glow = _WeaponVis.make_glow(_sprite)
	if _griffon:
		_make_arm(clampi(int(host.get_meta("tr", 1)), 1, 5))
	visible = false


func _make_arm(tr: int) -> void:
	var rec: Dictionary = _arms.get(str(tr), _arms.get("1", {}))
	var path := ARM_DIR + "%d.png" % (tr if _arms.has(str(tr)) else 1)
	if rec.is_empty() or not ResourceLoader.exists(path):
		return
	_arm = Sprite2D.new()
	_arm.texture = load(path)
	_arm.centered = false
	var anchor: Array = rec.get("anchor", [0, 0])
	_arm.offset = -Vector2(float(anchor[0]), float(anchor[1]))
	var emit: Array = rec.get("emit", [0, 0])
	_arm_emit = Vector2(float(emit[0]), float(emit[1]))
	_arm.z_index = 2
	add_child(_arm)


## Weapon.shoot origin: the clip's emit point, in world space.
func muzzle() -> Vector2:
	return _sprite.to_global(_WeaponVis.emit(_wid))


func shown() -> bool:
	return visible and _clip != null


func _process(delta: float) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	# A sleeping host (room_bounds: far rooms) keeps its last pose.
	if _wid != "" and not _host.is_physics_processing():
		return
	var w: Dictionary = _host.get("_weapon")
	var wid := str(w.get("id", ""))
	if bool(_host.get("_dead")) or wid == "" or not _WeaponVis.has_art(wid):
		visible = false
		return
	if wid != _wid:
		_wid = wid
		_clip = _WeaponVis.clip(wid)
		var fx := _WeaponVis.fx(wid)
		_tip = int(TIP.get(str(fx.get("tip", "")), 2))
		_mtip = int(fx.get("mtip", 0))
		_eased = false
		_t_attack = 0
	if _clip == null:
		visible = false
		return
	visible = true
	var krep := int(_host.get("_krep"))
	var s := -1.0 if float(_host.get("facing")) < 0.0 else 1.0
	var cel := _target(s) - _host.global_position
	var point := _weapon_point(krep, s, cel)
	var cd := float(_host.get("_attack_cd"))
	if cd > _last_cd + 0.001:
		_fired(cd)
	_last_cd = cd
	_acc += delta * TPS
	var ticks := int(_acc)
	_acc -= ticks
	if _tip == 1:
		_melee(ticks, krep, s, point, cel)
	else:
		_gun(ticks, krep, s, point, cel, delta)
	_clip.show(_sprite)
	_WeaponVis.sync_glow(_sprite, _glow, _tele, krep == 0 and _tele.a > 0.0)


func _gun(ticks: int, krep: int, s: float, point: Vector2, cel: Vector2, delta: float) -> void:
	for _i in ticks:
		if krep > 0 or not _eased:
			_sprite.position = point
			_eased = true
		else:
			_sprite.position += (point - _sprite.position) / 5.0
		_clip.advance()
	var aim := cel - _sprite.position
	var want := atan2(aim.y, absf(aim.x) * s) if krep > 0 else atan2(aim.y, aim.x)
	_rot = lerp_angle(_rot, want, clampf(delta * TPS * 0.35, 0.0, 1.0))
	_sprite.scale = Vector2.ONE
	if krep > 0:
		_sprite.scale.x = s
		_sprite.rotation = _rot + PI * 0.5 * (1.0 - s)
	elif cel.x < _sprite.position.x:
		_sprite.scale.x = -1.0
		_sprite.rotation = _rot + PI
	else:
		_sprite.rotation = _rot
	if _arm != null:
		_arm.position = point
		_arm.scale = Vector2(s, 1.0)
		_arm.rotation = _rot + PI * 0.5 * (1.0 - s)
		_sprite.position = _arm.position + _arm.transform.basis_xform(_arm_emit)


func _melee(ticks: int, krep: int, s: float, point: Vector2, cel: Vector2) -> void:
	_sprite.scale = Vector2(1.0, s)
	if krep > 0 or _griffon:
		_sprite.position = point
		_sprite.rotation = deg_to_rad(90.0 * s - 90.0 + _r * s)
		for _i in ticks:
			_t_attack = maxi(0, _t_attack - 1)
		if _arm != null:
			_arm.position = point
			_arm.scale = Vector2(s, 1.0)
			var rot := -PI * 0.5 - PI / 6.0 * s if _mtip == 0 else atan2(cel.y, absf(cel.x) * s)
			_arm.rotation = rot + PI * 0.5 * (1.0 - s)
			_sprite.position = _arm.position + _arm.transform.basis_xform(_arm_emit)
		return
	var size: Vector2 = _host.get("body_size")
	var rot := -PI * 0.5 - PI / 6.0 * s
	for _i in ticks:
		var goal := Vector2(40.0 * s, point.y)
		if not _eased:
			_sprite.position = goal
			_eased = true
		_sprite.position += (goal - _sprite.position) / 2.0
		_t_attack = maxi(0, _t_attack - 1)
	if _t_attack > 0:
		var r := float(_rapid)
		var t := float(_t_attack)
		var anim := t * 2.0 / r
		if t >= r * 5.0 / 6.0:
			anim = -(r - t) / r * 1.5
		elif t >= r * 0.5:
			anim = -0.25 + ((r - t) / r - 1.0 / 6.0) * 3.75
		if _mtip == 0:
			rot = -PI * 0.5 + (-PI / 6.0 + anim * PI) * s
		else:
			rot = atan2(cel.y + size.y * 0.5, cel.x)
	elif _mtip != 0:
		rot = atan2(cel.y + size.y * 0.5, cel.x)
	_sprite.rotation = rot


func _fired(cd: float) -> void:
	if _tip == 1:
		_rapid = maxi(1, int(round(cd * TPS)))
		_t_attack = _rapid
	elif _clip.label("shoot") > 0:
		_clip.goto_play("shoot")


func _target(s: float) -> Vector2:
	var player: Variant = _host.get("_player")
	if bool(_host.get("_track_player")) and player is Node2D and is_instance_valid(player):
		return _host.call("_body_center", player)
	var size: Vector2 = _host.get("body_size")
	return _host.global_position + Vector2(s * 200.0, -size.y * 0.6)


func _weapon_point(krep: int, s: float, cel: Vector2) -> Vector2:
	var size: Vector2 = _host.get("body_size")
	var at := Vector2(0.0, -size.y * 0.5)
	_r = 0.0
	if krep == 0:
		var ahead := (s > 0.0 and cel.x > size.x * 0.5) or (s < 0.0 and cel.x < -size.x * 0.5)
		at.x = size.x * s if ahead and not bool(_host.get("_climbing")) else 0.0
		at.y = -size.y * (0.4 if _tip == 1 else 0.7)
	if not _griffon and (_enclweap or not _tip in [1, 2, 4]):
		return at
	var anim := _host.get("anim") as AnimatedSprite2D
	if anim == null or _table.is_empty():
		return at
	var clips: Dictionary = _host.get("_sheet_clips")
	var spec: Variant = clips.get(str(anim.animation), {})
	var row := int((spec as Dictionary).get("y", 0)) if spec is Dictionary else 0
	if row < 0 or row >= _table.size():
		return at
	var frames: Array = _table[row]
	if frames.is_empty():
		return at
	var p: Array = frames[clampi(anim.frame, 0, frames.size() - 1)]
	_r = float(p[2])
	var cell := Vector2(_host.get("_sheet_cell"))
	var off: Vector2 = _host.get("_sheet_offset")
	return Vector2((float(p[0]) + off.x - cell.x * 0.5) * s, float(p[1]) + off.y - cell.y * 0.5)
