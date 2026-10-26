extends RefCounted

## Background structures from backs.xml / BackObj.as.
## Sprites are back_<id>_[t|l|e] frames in texture1.swf (Grafon numbBack).
## They are drawn on the dim back-wall layer and have no collision.

const DATA := "res://assets/data/backs.json"
const HOLE_SHADER := preload("res://assets/shaders/back_hole.gdshader")
const TILE := 40.0
const COLS := 48

## tBackWall averages about 145. The original concrete wall in the reference
## shot sits near 65, which is 0.45 of that texture. Floor lips stay undimmed.
const DIM := 0.45

static var _kinds: Dictionary = {}
static var _tex: Dictionary = {}


static func drop_cache() -> void:
	_tex.clear()
static var _mul: CanvasItemMaterial
static var _add: CanvasItemMaterial


static func layers(parent: Node, backdrop: Color) -> Dictionary:
	var dim := Node2D.new()
	dim.name = "BackDim"
	dim.modulate = Color(DIM, DIM, DIM, 1.0)
	dim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(dim)
	var holes := Node2D.new()
	holes.name = "BackHoles"
	holes.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = HOLE_SHADER
	mat.set_shader_parameter("fill", backdrop)
	holes.set_meta("hole_mat", mat)
	parent.add_child(holes)
	return {"dim": dim, "holes": holes}


static func paint(drawn: Dictionary, room: Dictionary, origin: Vector2, lights: int) -> void:
	var kinds := _catalog()
	if kinds.is_empty():
		return
	var light_on := lights
	var options: Dictionary = room.get("options", {})
	if lights == 0 and options.has("lon"):
		light_on = int(options.lon)
	var buckets := {}
	for obj_v in room.get("objs", []):
		var obj: Dictionary = obj_v
		if str(obj.get("tag", "")) != "back":
			continue
		var oid := str(obj.get("id", ""))
		if not kinds.has(oid):
			continue
		var spec: Dictionary = kinds[oid]
		var sloy := int(spec.get("s", 0))
		if not buckets.has(sloy):
			buckets[sloy] = []
		(buckets[sloy] as Array).append(obj)
	var order: Array = buckets.keys()
	order.sort()
	for sloy in order:
		for obj_v in buckets[sloy]:
			_place(drawn, kinds, obj_v, origin, bool(room.get("mirror", false)), light_on)


static func _place(drawn: Dictionary, kinds: Dictionary, obj: Dictionary, origin: Vector2, mirrored: bool, light_on: int) -> void:
	var spec: Dictionary = kinds[str(obj.get("id", ""))]
	var attrs: Dictionary = obj.get("attrs", {})
	var px := float(obj.get("x", 0)) * TILE
	var py := float(obj.get("y", 0)) * TILE
	var scale_x := float(attrs.get("w", 1.0))
	var scale_y := float(attrs.get("h", 1.0))
	if scale_x == 0.0:
		scale_x = 1.0
	if scale_y == 0.0:
		scale_y = 1.0
	var wid := float(spec.get("x2", 1.0)) * TILE
	if attrs.has("w"):
		wid = float(attrs.w) * TILE
	var flip := false
	var mirr := str(spec.get("mirr", ""))
	if mirrored:
		if mirr == "2" and randf() < 0.5:
			px = COLS * TILE - px
			flip = true
		elif mirr == "1":
			px = COLS * TILE - px
			flip = true
		else:
			px = COLS * TILE - px - wid
	elif mirr == "2" and randf() < 0.5:
		px += wid
		flip = true
	if flip:
		scale_x = -absf(scale_x)
	var alpha := float(spec.get("alpha", 1.0))
	if attrs.has("a"):
		alpha = float(attrs.a)
	var at := origin + Vector2(px, py)
	var scale := Vector2(scale_x, scale_y)
	var main: Array = spec.get("t", [])
	var glow: Array = spec.get("l", [])
	var erase: Array = spec.get("e", [])
	var frame := _frame(spec, attrs, main if not main.is_empty() else glow, light_on)
	var blend := str(spec.get("blend", ""))
	if not glow.is_empty():
		_sprite(drawn.dim, glow, frame, at, scale, alpha, -6, "add")
	if not main.is_empty():
		_sprite(drawn.dim, main, frame, at, scale, alpha, -6, blend)
	if not erase.is_empty():
		_sprite(drawn.holes, erase, frame, at, scale, 1.0, -7, "hole")


static func _frame(spec: Dictionary, attrs: Dictionary, frames: Array, light_on: int) -> int:
	var count := frames.size()
	if count < 1:
		return 1
	var frame := 1
	if int(spec.get("fr", 0)) > 0:
		frame = int(spec.fr)
	elif light_on > 0 and int(spec.get("lon", 0)) > 0:
		frame = int(spec.lon)
	elif light_on < 0 and int(spec.get("loff", 0)) > 0:
		frame = int(spec.loff)
	else:
		frame = randi() % count + 1
	if attrs.has("fr"):
		frame = int(attrs.fr)
	if attrs.has("lon"):
		var placed := float(attrs.lon)
		if placed > 1.0 and int(spec.get("lon", 0)) > 0:
			frame = int(spec.lon)
		elif placed < 1.0 and int(spec.get("loff", 0)) > 0:
			frame = int(spec.loff)
	return clampi(frame, 1, count)


static func _sprite(parent: Node, frames: Array, frame: int, at: Vector2, scale: Vector2, alpha: float, z: int, blend: String) -> void:
	if frames.is_empty():
		return
	var pic: Dictionary = frames[clampi(frame, 1, frames.size()) - 1]
	var texture := _texture(str(pic.get("path", "")))
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = at
	sprite.offset = Vector2(float(pic.get("ox", 0.0)), float(pic.get("oy", 0.0)))
	sprite.scale = scale
	sprite.z_index = z
	sprite.modulate = Color(1, 1, 1, alpha)
	if blend == "multiply":
		sprite.material = _multiply()
	elif blend == "add":
		sprite.material = _glow()
	elif blend == "hole":
		sprite.material = parent.get_meta("hole_mat")
	parent.add_child(sprite)


static func _multiply() -> CanvasItemMaterial:
	if _mul == null:
		_mul = CanvasItemMaterial.new()
		_mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	return _mul


static func _glow() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add


static func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex.has(path):
		var cached = _tex[path]
		return cached if cached is Texture2D else null
	var texture: Texture2D = load(path)
	_tex[path] = texture
	return texture


static func _catalog() -> Dictionary:
	if not _kinds.is_empty():
		return _kinds
	if not FileAccess.file_exists(DATA):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_kinds = (parsed as Dictionary).get("kinds", {})
	return _kinds
