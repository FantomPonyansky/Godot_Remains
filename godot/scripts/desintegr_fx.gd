extends Node
## Desintegr: an exotic death (burn, melt, astro, freeze) or an overkilled
## bloody body. burnTime1 ticks of colour transform with a growing glow, then
## burnTime2 ticks of pixel dissolve that throws burnPart; then the unit goes.

const SHADER := preload("res://assets/shaders/desintegr.gdshader")
const BLOOD_PATH := "res://assets/data/unit_blood.json"
const TPS := 30.0
const TIME1 := 10
const TIME2 := 30
## burnTip: per-tick ColorTransform (mul, add / 255), part, glow colour, sound.
const TIPS := {
	1: [Vector3(1, 1, 1), Vector3(255, 100, 0), "burn", Color8(0xFF, 0xAA, 0x00), "desintegr_f"],
	2: [Vector3(1, 1, 1), Vector3(0, 255, 100), "plakap", Color8(0x00, 0xFF, 0x00), "liquid_f"],
	3: [Vector3(1, 1, 1), Vector3(155, 155, 255), "burn", Color8(0x44, 0x44, 0xFF), "desintegr_f"],
	4: [Vector3(1, 1, 1), Vector3(100, 100, 255), "krupa", Color8(0x00, 0x00, 0xFF), "freezing_f"],
	5: [Vector3(1, 0.85, 0.85), Vector3.ZERO, "blood", Color8(0xFF, 0x00, 0x00), ""],
	6: [Vector3(0.9, 1, 0.85), Vector3.ZERO, "gblood", Color8(0x66, 0xCC, 0x33), ""],
	7: [Vector3(1, 0.85, 0.88), Vector3.ZERO, "pblood", Color8(0xFF, 0x66, 0xFF), ""],
}

static var _blood: Variant = null

var _unit: Node2D
var _tip := 0
var _size := Vector2(40, 40)
var _massa := 1.0
var _n := 0
var _acc := 0.0
var _mat: ShaderMaterial


## Unit.damage on hp <= 0: the sposob the killing hit gives.
static func sposob(damage_type: String, hp: int, max_hp: int, trup: bool) -> int:
	var s := 0
	if damage_type == "DAM_BURN" and (hp <= -max_hp * 3 or not trup):
		s = 1
	if damage_type == "DAM_LASER" and (hp <= -max_hp * 3 or not trup or randf() < 0.5):
		s = 1
	if damage_type in ["DAM_PLASMA", "DAM_ACID"]:
		s = 2
	if damage_type in ["DAM_ASTRO", "DAM_HARMONY"]:
		s = 3
	if damage_type == "DAM_COLD":
		s = 4
	return s


## units.xml <param blood>: 0 none, 1 red, 2 green, 3 pink.
static func blood_of(unit_id: String) -> int:
	if _blood == null:
		_blood = JSON.parse_string(FileAccess.get_file_as_string(BLOOD_PATH)) if FileAccess.file_exists(BLOOD_PATH) else {}
	return int((_blood as Dictionary).get(unit_id, 0)) if _blood is Dictionary else 0


static func start(unit: Node2D, tip: int, size: Vector2, massa: float) -> void:
	if unit == null or not TIPS.has(tip) or unit.has_node("Desintegr"):
		return
	var fx := new()
	fx.name = "Desintegr"
	fx._unit = unit
	fx._tip = tip
	fx._size = size
	fx._massa = massa
	unit.add_child(fx)


func _ready() -> void:
	var row: Array = TIPS[_tip]
	if str(row[4]) != "":
		SfxBank.play(str(row[4]))
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("seed", randf() * 1000.0)
	_apply(_unit)
	_n = 1


func _apply(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem and not child is Control:
			(child as CanvasItem).material = _mat
		_apply(child)


func _physics_process(delta: float) -> void:
	_acc += delta * TPS
	while _acc >= 1.0:
		_acc -= 1.0
		_step()


func _step() -> void:
	if _unit == null or not is_instance_valid(_unit):
		return
	var row: Array = TIPS[_tip]
	if _n <= TIME1:
		var k := float(_n)
		var mul: Vector3 = row[0]
		var add: Vector3 = row[1]
		_mat.set_shader_parameter("mul_col", Vector3(pow(mul.x, k), pow(mul.y, k), pow(mul.z, k)))
		_mat.set_shader_parameter("add_col", add * k / float(TIME1) / 255.0)
		var glow: Color = row[3]
		_mat.set_shader_parameter("glow", Vector4(glow.r, glow.g, glow.b, k / float(TIME1)))
	elif _n <= TIME1 + TIME2:
		_mat.set_shader_parameter("dissolve", float(_n - TIME1) / float(TIME2))
		if _massa >= 0.25 or randf() < _massa * 4.0:
			UnitFx.emit(get_tree(), str(row[2]), _unit.global_position - Vector2(0, _size.y * 0.5),
				{"rx": _size.x * 0.75, "ry": _size.y * 0.5})
	else:
		_unit.queue_free()
		return
	_n += 1
