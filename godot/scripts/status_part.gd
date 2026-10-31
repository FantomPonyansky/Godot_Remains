extends Sprite2D
## parts.xml blind / stun on the player (Effect.secEffect, Unit.actions), at 30 ticks/s.

const TPS := 30.0
const SHEETS := "res://assets/sprites/sheets/traps/"
const PARTS := {
	"blind": {"sheet": "fx_blind", "minliv": 40, "rliv": 20, "rsc": 0.5, "multiply": true},
	"stun": {"sheet": "fx_stun", "minliv": 20, "rliv": 10, "rsc": 0.6, "minv": 5.0, "rv": 5.0, "rr": 20.0, "rot": true, "brake": 0.91},
}

static var _manifest: Dictionary = {}

var _liv := 20
var _vel := Vector2.ZERO
var _spin := 0.0
var _brake := 1.0
var _acc := 0.0


static func emit(tree: SceneTree, id: String, at: Vector2) -> Node:
	var spec: Dictionary = PARTS.get(id, {})
	var scene := tree.current_scene if tree != null else null
	if spec.is_empty() or scene == null:
		return null
	var rec := _rec(str(spec.sheet))
	var path := SHEETS + str(rec.get("sheet", ""))
	if rec.is_empty() or not ResourceLoader.exists(path):
		return null
	var part: Sprite2D = load("res://scripts/status_part.gd").new()
	part.texture = load(path)
	part.centered = false
	var anchor: Array = rec.get("anchor", [0, 0])
	part.offset = -Vector2(float(anchor[0]), float(anchor[1]))
	part.z_index = 7
	part.global_position = at
	part._setup(spec)
	scene.add_child(part)
	return part


static func _rec(sheet: String) -> Dictionary:
	if _manifest.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHEETS + "manifest.json"))
		if parsed is Dictionary:
			_manifest = parsed
	var rec: Variant = _manifest.get(sheet)
	return rec if rec is Dictionary else {}


func _setup(spec: Dictionary) -> void:
	_liv = int(spec.minliv) + randi() % maxi(1, int(spec.rliv))
	var rsc := float(spec.get("rsc", 0.0))
	if rsc != 0.0:
		scale = Vector2.ONE * (1.0 - rsc + randf() * rsc)
	if bool(spec.get("multiply", false)):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://assets/shaders/alpha_mul.gdshader")
		material = mat
	var v := float(spec.get("minv", 0.0)) + randf() * float(spec.get("rv", 0.0))
	_vel = Vector2.from_angle(randf() * TAU) * v
	_spin = (randf() * 2.0 - 1.0) * float(spec.get("rr", 0.0))
	if bool(spec.get("rot", false)):
		rotation_degrees = randf() * 360.0
	_brake = float(spec.get("brake", 1.0))


func _process(delta: float) -> void:
	_acc += delta * TPS
	while _acc >= 1.0:
		_acc -= 1.0
		position += _vel
		_vel *= _brake
		rotation_degrees += _spin
		_liv -= 1
		modulate.a = float(_liv) / 10.0 if _liv < 9 else 1.0
		if _liv <= 0:
			queue_free()
			return
