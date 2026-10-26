extends Node2D

## The land backdrop (LandAct.fon, World.vfon): drawn under the whole land and
## kept over the visible area; back holes show it through the same shader.

const SHADER := preload("res://assets/shaders/land_fon.gdshader")
const DIR := "res://assets/sprites/fon/"
const ROOM_PX := Vector2(1920.0, 1000.0)
const BASE_DARK := 0xAA
const _Flags := preload("res://scripts/map/room_flags.gd")

var hole_mat: ShaderMaterial
var _mat: ShaderMaterial
var _tex: Texture2D
var _view := Rect2()
var _screen := Vector2.ZERO


static func attach(land: Node2D, fon_name: String) -> Node2D:
	var node: Node2D = load("res://scripts/map/land_fon.gd").new()
	node.name = "LandFon"
	node.z_index = -40
	node._setup(fon_name)
	land.add_child(node)
	return node


func _setup(fon_name: String) -> void:
	var path := DIR + (fon_name if fon_name != "" else "fonDefault") + ".png"
	if not ResourceLoader.exists(path):
		path = DIR + "fonDefault.png"
	_tex = load(path)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("fon", _tex)
	_mat.set_shader_parameter("room_px", ROOM_PX)
	material = _mat
	hole_mat = _mat.duplicate()
	hole_mat.set_shader_parameter("mask", true)


## rooms: land room dicts; envs: RoomFlags rows by cell; mults: room colour by cell;
## land_back: the land's backwall option.
func set_cells(rooms: Array, envs: Dictionary, mults: Dictionary, land_back: String) -> void:
	var size := Vector2i(1, 1)
	for room_v in rooms:
		var r: Dictionary = room_v
		size = Vector2i(maxi(size.x, int(r.x) + 1), maxi(size.y, int(r.y) + 1))
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBAF)
	img.fill(Color(1, 1, 1, 1))
	var ordered := rooms.filter(func(r: Dictionary) -> bool: return int(r.get("z", 0)) != 0)
	ordered.append_array(rooms.filter(func(r: Dictionary) -> bool: return int(r.get("z", 0)) == 0))
	for room_v in ordered:
		var r: Dictionary = room_v
		var cell := Vector2i(int(r.x), int(r.y))
		var o: Dictionary = r.get("options", {})
		var env: Dictionary = envs.get(cell, {})
		var back := str(o.get("backwall", land_back))
		var dark := 0.0
		if back != "sky" and not o.has("transpfon"):
			dark = clampf(float(BASE_DARK + int(env.get("dark", 0))) / 255.0, 0.0, 1.0)
		var mult: Color = mults.get(cell, Color(1, 1, 1))
		var want: Color = _Flags.COLORS.get(str(o.get("colorfon", "")), Color(1, 1, 1))
		img.set_pixelv(cell, Color(_undo(want.r, mult.r), _undo(want.g, mult.g), _undo(want.b, mult.b), dark))
	var cells := ImageTexture.create_from_image(img)
	for m in [_mat, hole_mat]:
		m.set_shader_parameter("cells", cells)
		m.set_shader_parameter("grid", Vector2(size))
		m.set_shader_parameter("origin", (get_parent() as Node2D).global_position)


static func _undo(want: float, mult: float) -> float:
	return want / mult if mult > 0.01 else 1.0


func _process(_delta: float) -> void:
	var vp := get_viewport()
	var screen := vp.get_visible_rect().size
	if screen != _screen and _tex != null:
		_screen = screen
		var t := Vector2(_tex.get_size())
		var s := maxf(screen.x / t.x, screen.y / t.y)
		var crop := screen / (t * s)
		_mat.set_shader_parameter("crop", crop)
		hole_mat.set_shader_parameter("crop", crop)
	var inv := vp.get_canvas_transform().affine_inverse()
	for m in [_mat, hole_mat]:
		m.set_shader_parameter("view_origin", inv.origin)
		m.set_shader_parameter("view_x", inv.x * screen.x)
		m.set_shader_parameter("view_y", inv.y * screen.y)
	var view := (get_global_transform().affine_inverse() * inv) * Rect2(Vector2.ZERO, screen)
	if view != _view:
		_view = view
		queue_redraw()


func _draw() -> void:
	draw_rect(_view.grow(2.0), Color.WHITE)
