extends Area2D

## CheckPoint.as. vischeckpoint is the door (osn, pfe.swf sprite 2992), the
## lock plate (3002, frame = the digit in checkpoint1..5) and the teleport
## glow (fiol, 3005). Walking in opens it (Area.over → areaActivate); the use
## key opens it or, once open, takes the return teleport (30 frames).
## Frames were exported at zoom 2; *_AT are each sprite's top-left in
## vischeckpoint space, whose origin is the object's bottom centre.

const Registry := preload("res://scripts/map/land_registry.gd")
const ART := "res://assets/sprites/props/checkpoint/"
## Pers.manaCPres.
const CP_MANA := 50.0
const OSN_FRAMES := 45
const REOPEN := 26
const FIOL_FRAMES := 25
const OSN_AT := Vector2(-65.5, -120.0)
const LOCK_AT := Vector2(-17.6, -89.9)
const FIOL_AT := Vector2(-37.45, -189.45)
## objs.xml size 2, wid 3.
const SIZE := Vector2(80, 120)

var id := "checkpoint"
var code := ""
var land_id := ""
var active := 0
var tele_on := false
var used := false
var main := false
var hide_cp := false
var rnd := false
var un_xp := 100
var _locked := false
var _osn: Sprite2D
var _lock: Sprite2D
var _fiol: Sprite2D
var _osn_frame := 1
var _osn_stop := 1
var _fiol_frame := 1
var _fiol_stop := 1
var _acc := 0.0
var _start_active := false

static var _tex: Dictionary = {}


static func drop_cache() -> void:
	_tex.clear()


## row: a LandSpawn checkpoint row. ctx: the land plan ctx (rnd, xp, stage).
func setup(row: Dictionary, ctx: Dictionary, owner_land: String) -> void:
	id = str(row.get("id", "checkpoint"))
	land_id = owner_land
	var attrs: Dictionary = row.get("attrs", {})
	var feet: Array = row.get("feet", [0, 0])
	position = Vector2(float(feet[0]), float(feet[1]))
	name = "cp_%s_%d_%d" % [id, int(position.x), int(position.y)]
	code = str(attrs.get("code", ""))
	main = attrs.has("main")
	tele_on = attrs.has("tele")
	hide_cp = attrs.has("hide")
	rnd = bool(ctx.get("rnd", false))
	un_xp = int(ctx.get("xp", 100))
	var dif := GameState.difficulty()
	if dif <= 1 or (rnd and dif == 2 and randf() < 0.33):
		tele_on = true
	_start_active = str(attrs.get("active", "")) == "1"
	if _start_active and int(ctx.get("stage", 0)) == 0:
		tele_on = true
	_locked = id.length() > 10
	var room: Array = row.get("room", [0, 0])
	set_meta("room_x", int(room[0]))
	set_meta("room_y", int(room[1]))
	set_meta("uid", str(row.get("uid", "")))


func _ready() -> void:
	add_to_group("checkpoints")
	add_to_group("land_objects")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	box.size = SIZE
	shape.shape = box
	shape.position = Vector2(0, -SIZE.y * 0.5)
	add_child(shape)
	_osn = _sprite(OSN_AT, -3)
	_fiol = _sprite(FIOL_AT, -2)
	_lock = _sprite(LOCK_AT, -2)
	_show_osn(1)
	_show_fiol(1)
	if _locked:
		_lock.texture = _frame("lock", clampi(int(id.substr(10, 1)), 1, 5))
	_lock.visible = _locked
	set_meta("id", "" if hide_cp else "checkpoint")
	_set_use("activate", false)
	if main:
		monitoring = false
		active = 2
		tele_on = true
		_show_osn(OSN_FRAMES)
		_show_fiol(FIOL_FRAMES)
		_set_use("returnm", true)
	else:
		body_entered.connect(_on_body_entered)
	if hide_cp:
		visible = false
		set_meta("usable", false)
	else:
		add_to_group("tk_use")
	var props := get_parent()
	if not main and props != null and props.has_method("flag"):
		used = bool(props.call("flag", "cpused|" + name, false))
		# CheckPoint.save act: an opened one comes back reopened; Travel activates the current one again.
		if int(props.call("flag", "cpact|" + name, 0)) > 0:
			active = 1
			_show_osn(REOPEN)
	Travel.checkpoint_built(self, land_id, code, rnd)
	if _start_active:
		call_deferred("activate", true)


func _process(delta: float) -> void:
	_acc += delta * 30.0
	var ticks := mini(int(_acc), 5)
	_acc -= float(ticks)
	for _i in ticks:
		if _osn_frame < _osn_stop:
			_osn_frame += 1
			_osn.texture = _frame("osn", _osn_frame)
		if _fiol_frame < _fiol_stop:
			_fiol_frame += 1
			_fiol.texture = _frame("fiol", _fiol_frame)
			_fiol.visible = true
	if main:
		var mission := Travel.mission_id
		set_meta("usable", mission != "" and Travel.lands.has(mission) and str(Registry.land(mission).get("tip", "")) != "base")
		return
	if _locked and float(get_meta("lock", 0.0)) <= 0.0 and int(get_meta("mine", 0)) <= 0:
		_locked = false
		_lock.visible = false
	if active == 2 and Travel.current_cp() != self:
		deactivate()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and active == 0:
		activate()


## CheckPoint.activate. first: placed open (Location.createCheck), no mana or xp.
## restored: a saved act 2 coming back open, without the save and info text.
func activate(first: bool = false, restored: bool = false) -> void:
	if float(get_meta("lock", 0.0)) > 0.0 or int(get_meta("mine", 0)) > 0:
		return
	if active == 2:
		return
	if active == 0 and not first:
		GameState.restore_mana(CP_MANA)
		Progression.add_xp(un_xp * 3)
	active = 2
	var glow := Travel.m_return() and tele_on and not used
	if first:
		_show_osn(OSN_FRAMES)
		if glow:
			_show_fiol(FIOL_FRAMES)
	else:
		_osn_stop = OSN_FRAMES
		if glow:
			_show_fiol(1)
			_fiol_stop = FIOL_FRAMES
	if used:
		_show_fiol(1)
	if glow:
		_set_use("returnb", true)
	else:
		_set_use("", false)
		set_meta("usable", false)
	var props := get_parent()
	if not main and props != null and props.has_method("set_flag"):
		props.call("set_flag", "cpact|" + name, 2)
	if not restored:
		Travel.checkpoint_activated(self, land_id, code)


## Another checkpoint became current.
func deactivate() -> void:
	if main:
		return
	set_meta("usable", not hide_cp)
	active = 1
	_show_osn(REOPEN)
	_show_fiol(1)
	_set_use("activate", false)


## CheckPoint.teleport.
func teleport() -> void:
	if main:
		if Travel.mission_id != "rbl":
			Travel.goto_land(Travel.mission_id)
		return
	Travel.goto_land(Travel.base_id)
	if Inventory.hard_inv() and rnd:
		used = true
		_set_use("", false)
		set_meta("usable", false)
		_show_fiol(1)
		var props := get_parent()
		if props != null and props.has_method("set_flag"):
			props.call("set_flag", "cpused|" + name, true)


## The use key, after any lock or mine is passed. from_timer: the 30-frame
## hold of the teleport has finished.
func use_object(from_timer: bool) -> void:
	var action := str(get_meta("user_action", ""))
	if action == "returnb" or action == "returnm":
		if from_timer:
			teleport()
			return
		var player := get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("begin_use_timer"):
			player.begin_use_timer(self)
		return
	if action == "activate":
		activate()


## Interact.t_action is 30 for the teleport and 0 for opening.
func _set_use(action: String, hold: bool) -> void:
	set_meta("user_action", action)
	set_meta("hold_use", hold)
	set_meta("act_time", 30 if hold else 0)
	if action != "" and not hide_cp:
		set_meta("usable", true)


func _show_osn(frame: int) -> void:
	_osn_frame = frame
	_osn_stop = frame
	_osn.texture = _frame("osn", frame)


func _show_fiol(frame: int) -> void:
	_fiol_frame = frame
	_fiol_stop = frame
	_fiol.texture = _frame("fiol", frame)
	_fiol.visible = frame > 1


func _sprite(at: Vector2, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.position = at
	sprite.scale = Vector2(0.5, 0.5)
	sprite.z_index = z
	add_child(sprite)
	return sprite


func _frame(part: String, frame: int) -> Texture2D:
	var key := "%s/%d" % [part, frame]
	if not _tex.has(key):
		var path := "%s%s/%d.png" % [ART, part, frame]
		_tex[key] = load(path) if ResourceLoader.exists(path) else null
	return _tex[key]
