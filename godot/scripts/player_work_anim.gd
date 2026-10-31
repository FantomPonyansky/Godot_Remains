extends Node
## UnitPlayer works that drive the body while control is off:
## "die" (die clip for 205 ticks: 170-120 colour offset, the dieFilter glow and
## die_spark, 120-70 fade out), alicorn "dieali" (200-140 red offset and redray,
## 140 bloodblast and bale_e), "res" (resurrect clip for t_work ticks) and
## anim(dey, true), which holds the clip's last frame (animOff) until anim("").
## setNull / resurect clear the colour transform, glow and alpha.

const SHADER := preload("res://assets/shaders/desintegr.gdshader")
const TPS := 30.0
const NODE_NAME := "WorkAnim"
const DIE_GLOW := Color(0.8, 0.0, 1.0)
const HALF_HEIGHT := 39.0

var work := ""
var t_work := 0
var hold := false
var _clip := ""
var _player: Node2D
var _mat: ShaderMaterial
var _saved := {}
var _acc := 0.0
var _alpha := 1.0
var _rig_tinted: Node2D
var _die_aura: Node2D


static func of(player: Node) -> Node:
	return player.get_node_or_null(NODE_NAME) if player != null else null


## UnitPlayer.anim(dey, ok) and the die / resurect works. ticks < 0 is the clip length.
static func play(player: Node2D, dey: String, ticks: int, hold_last := false) -> void:
	if player == null or not is_instance_valid(player):
		return
	var fx := of(player)
	if fx == null:
		fx = new()
		fx.name = NODE_NAME
		fx.set("_player", player)
		player.add_child(fx)
	fx.call("_begin", dey, ticks, hold_last)


## anim(""): animOff off, the player animates itself again.
static func stop(player: Node) -> void:
	var fx := of(player)
	if fx != null:
		fx.call("_finish")


## player.gd leaves the body to this node while a work plays.
static func owns(player: Node) -> bool:
	var fx := of(player)
	return fx != null and str(fx.get("work")) != ""


## UnitPlayer.control returns early during work "res".
static func blocks_input(player: Node) -> bool:
	var fx := of(player)
	return fx != null and str(fx.get("work")) == "res"


func _begin(dey: String, ticks: int, hold_last: bool) -> void:
	_restore()
	work = dey
	hold = hold_last
	t_work = ticks
	_clip = dey
	if dey == "die" and not hold_last and ScriptsEngine.alicorn:
		_clip = "dieali"
	var puppet := _puppet()
	if ticks < 0:
		t_work = int(puppet.clip_len(_clip)) if puppet != null and puppet.has_method("clip_len") else 0
	_acc = 0.0
	_pose()


func _physics_process(delta: float) -> void:
	if GameState.paused or work == "":
		return
	_acc += delta * TPS
	var n := mini(int(_acc), 4)
	_acc -= float(int(_acc))
	for _i in n:
		_tick()
		if work == "":
			return


func _tick() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if hold:
		_pose()
		return
	if t_work > 0:
		t_work -= 1
	if t_work <= 0:
		if work == "die":
			hold = true
			_pose()
		else:
			_finish()
		return
	if work == "die":
		if _clip == "dieali":
			_die_ali()
		else:
			_die()
	_pose()


func _die() -> void:
	if t_work < 170 and t_work > 120:
		var k := float(170 - t_work)
		_tint(Vector3(k * 2.0, 0.0, k * 3.0) / 255.0, 1.0 - float(t_work - 120) / 50.0)
		var facing := float(_player.get("facing")) if "facing" in _player else 1.0
		var at := _player.global_position + Vector2(randf() * 120.0 - 60.0 + 20.0 * facing, 0.0)
		UnitFx.emit(get_tree(), "die_spark", at)
	elif t_work < 120 and t_work > 70:
		_alpha = float(t_work - 70) / 50.0


func _die_ali() -> void:
	var mid := _player.global_position - Vector2(0.0, HALF_HEIGHT)
	if t_work < 200 and t_work > 140:
		var k := float(200 - t_work)
		_tint(Vector3(k * 4.0, 0.0, k) / 255.0, -1.0)
		UnitFx.emit(get_tree(), "redray", mid)
	if t_work == 140:
		UnitFx.emit(get_tree(), "bloodblast", mid)
		SfxBank.play("bale_e")
		_alpha = 0.0


## vis.osn.transform.colorTransform offsets; glow < 0 keeps the dieFilter alpha.
func _tint(add: Vector3, glow: float) -> void:
	var puppet := _puppet()
	var rig: Node2D = puppet.call("rig") if puppet != null and puppet.has_method("rig") else null
	if rig != null:
		# The rig's CanvasGroups and colour-transform materials must keep their own shaders.
		rig.call("set_ct_offset", Color(add.x, add.y, add.z, 0.0))
		_rig_tinted = rig
		if glow >= 0.0:
			if _die_aura == null or not is_instance_valid(_die_aura):
				_die_aura = (load("res://scripts/magic_aura.gd") as GDScript).new() as Node2D
				_die_aura.name = "DieAura"
				_die_aura.set("host", puppet)
				_die_aura.set("color", DIE_GLOW)
				_die_aura.set("strength", 2.0)
				_die_aura.set_meta("no_tele_glow", true)
				puppet.add_child(_die_aura)
			_die_aura.set("alpha", glow)
		return
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		_mat.set_shader_parameter("mul_col", Vector3.ONE)
		_mat.set_shader_parameter("dissolve", 0.0)
		_mat.set_shader_parameter("glow", Vector4(DIE_GLOW.r, DIE_GLOW.g, DIE_GLOW.b, 0.0))
		if puppet != null:
			_apply(puppet)
	_mat.set_shader_parameter("add_col", add)
	if glow >= 0.0:
		_mat.set_shader_parameter("glow", Vector4(DIE_GLOW.r, DIE_GLOW.g, DIE_GLOW.b, glow))


func _apply(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem and not child is Control and child.name != "Weapon":
			_saved[child] = (child as CanvasItem).material
			(child as CanvasItem).material = _mat
			_apply(child)


func _restore() -> void:
	for item in _saved.keys():
		if is_instance_valid(item):
			(item as CanvasItem).material = _saved[item]
	_saved.clear()
	_mat = null
	if _rig_tinted != null and is_instance_valid(_rig_tinted):
		_rig_tinted.call("set_ct_offset", Color(0.0, 0.0, 0.0, 0.0))
	_rig_tinted = null
	if _die_aura != null and is_instance_valid(_die_aura):
		_die_aura.queue_free()
	_die_aura = null
	_alpha = 1.0
	var puppet := _puppet()
	if puppet != null:
		puppet.modulate.a = 1.0


func _finish() -> void:
	_restore()
	work = ""
	hold = false
	t_work = 0
	queue_free()


func _pose() -> void:
	var puppet := _puppet()
	if puppet == null or not puppet.has_method("update_pose"):
		return
	var facing := float(_player.get("facing")) if "facing" in _player else 1.0
	var aim: Vector2 = _player.get("aim_dir") if "aim_dir" in _player else Vector2.RIGHT
	puppet.update_pose(("hold:" + _clip) if hold else _clip, facing, aim, 1.0 / TPS)
	puppet.modulate.a = _alpha


func _puppet() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		return null
	return _player.get_node_or_null("Puppet") as Node2D
