extends Node

## World.showScene / unshowScene / endgame and Grafon.specEffect.
## A scene is a visualScene clip (thunder1..3, endgame, gameover; frames in
## assets/sprites/scenes) played at 30 fps from frame n over black on the
## 1280x800 stage, holding its last frame. catPause: while it shows the land
## and the player stop (Land.step skips loc.step) but scripts keep stepping;
## the world and the GUI are hidden. specEffect is the ColorMatrix (1-6) or
## blur (> 100) over the world layer, under the GUI.

const FONT := "res://theme/hud_sans.tres"
const SHADER := "res://assets/shaders/story_matrix.gdshader"
const SCENES := "res://assets/sprites/scenes/"
const STAGE := Vector2(1280, 800)
const FPS := 30.0
## Grafon.specEffect matrices: rows r, g, b of [r g b a offset(0-255)].
const MATRICES := {
	1: [[2.0, -0.9, -0.1, 0.0, 0.0], [-0.4, 1.5, -0.1, 0.0, 0.0], [-0.4, -0.9, 2.0, 0.0, 0.0]],
	2: [[-0.574, 1.43, 0.144, 0.0, 0.0], [0.426, 0.43, 0.144, 0.0, 0.0], [0.426, 1.43, -0.856, 0.0, 0.0]],
	3: [[0.0, 1.0, 0.0, 0.0, 0.0], [1.0, 0.0, 0.0, 0.0, 0.0], [0.0, 0.0, -0.2, 100.0, 0.0]],
	4: [[0.0, -0.5, -0.5, 0.0, 255.0], [-0.5, 0.0, -0.5, 0.0, 255.0], [-0.5, -0.5, 0.0, 0.0, 255.0]],
	5: [[3.4, 6.7, 0.9, 0.0, -635.0], [3.4, 6.75, 0.9, 0.0, -635.0], [3.4, 6.7, 0.9, 0.0, -635.0]],
	6: [[0.33, 0.33, 0.33, 0.0, 0.0], [0.33, 0.33, 0.33, 0.0, 0.0], [0.33, 0.33, 0.33, 0.0, 0.0]],
}

var scene_id := ""
var effect := 0.0

var _scene_layer: CanvasLayer
var _scene: ColorRect
var _scene_label: Label
var _fx_layer: CanvasLayer
var _fx: ColorRect
var _hud_hidden: Array[CanvasItem] = []
var _stage: Control
var _image: TextureRect
var _frames: Array = []
var _frame := 0
var _tick_acc := 0.0
var _manifest: Dictionary = {}
var _frozen: Dictionary = {}


func _ready() -> void:
	_scene_layer = CanvasLayer.new()
	_scene_layer.layer = 4
	add_child(_scene_layer)
	_scene = ColorRect.new()
	_scene.color = Color.BLACK
	_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.visible = false
	_scene_layer.add_child(_scene)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = STAGE
	_scene.add_child(_stage)
	_image = TextureRect.new()
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_image)
	var path := SCENES + "scenes.json"
	if FileAccess.file_exists(path):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if v is Dictionary:
			_manifest = v
	_scene_label = Label.new()
	_scene_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scene_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scene_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scene_label.add_theme_color_override("font_color", Color("00ff99"))
	_scene_label.add_theme_font_size_override("font_size", 22)
	if ResourceLoader.exists(FONT):
		_scene_label.add_theme_font_override("font", load(FONT))
	_scene.add_child(_scene_label)
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 0
	add_child(_fx_layer)
	_fx = ColorRect.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.visible = false
	if ResourceLoader.exists(SHADER):
		var mat := ShaderMaterial.new()
		mat.shader = load(SHADER)
		_fx.material = mat
	_fx_layer.add_child(_fx)


func reset() -> void:
	hide_scene()
	spec_effect(0)


## World.showScene: catPause, the visual and the GUI off, the scene on, its
## clip playing from frame n (1-based; 0 is the start).
func show_scene(id: String, n: int = 0) -> void:
	if scene_id != id:
		_frames.clear()
		var entry: Dictionary = _manifest.get(id, {})
		for f in entry.get("frames", []):
			_frames.append(f)
			if f is Array:
				ResourceLoader.load_threaded_request(SCENES + id + "/" + str(f[0]))
	scene_id = id
	_scene_label.text = ""
	_scene.visible = true
	_frame = maxi(0, n - 1)
	_tick_acc = 0.0
	_show_frame()
	_gui(false)
	_freeze(true)


func scene_text(text: String) -> void:
	_scene_label.text = text


func hide_scene() -> void:
	if scene_id == "" and not _scene.visible:
		return
	scene_id = ""
	_frames.clear()
	_image.texture = null
	_scene.visible = false
	_scene_label.text = ""
	_gui(true)
	_freeze(false)


func cat_pause() -> bool:
	return _scene.visible


func _process(delta: float) -> void:
	if not _scene.visible:
		return
	var view := get_viewport().get_visible_rect().size
	var k := minf(view.x / STAGE.x, view.y / STAGE.y)
	_stage.scale = Vector2(k, k)
	_stage.position = (view - STAGE * k) * 0.5
	if GameState.paused or _frames.is_empty():
		return
	_tick_acc += delta * FPS
	var ticks := mini(int(_tick_acc), 5)
	_tick_acc -= float(ticks)
	if ticks > 0 and _frame < _frames.size() - 1:
		_frame = mini(_frame + ticks, _frames.size() - 1)
		_show_frame()


func _show_frame() -> void:
	if _frame >= _frames.size() or not _frames[_frame] is Array:
		_image.texture = null
		return
	var f: Array = _frames[_frame]
	var path: String = SCENES + scene_id + "/" + str(f[0])
	var tex: Texture2D = null
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		tex = ResourceLoader.load_threaded_get(path) as Texture2D
	if tex == null:
		tex = load(path) as Texture2D
	_image.texture = tex
	_image.position = Vector2(float(f[1]), float(f[2]))
	_image.size = tex.get_size() if tex != null else Vector2.ZERO


## catPause: the shown land and the player stop; scripts and the GUI run.
func _freeze(on: bool) -> void:
	if not is_inside_tree():
		return
	if not on:
		for node in _frozen:
			if is_instance_valid(node):
				(node as Node).process_mode = _frozen[node]
		_frozen.clear()
		return
	for node in [get_tree().get_first_node_in_group("active_land"), get_tree().get_first_node_in_group("player")]:
		if node != null and not _frozen.has(node):
			_frozen[node] = (node as Node).process_mode
			(node as Node).process_mode = Node.PROCESS_MODE_DISABLED


## Grafon.specEffect(n).
func spec_effect(n: float) -> void:
	effect = n
	var mat := _fx.material as ShaderMaterial
	if n == 0.0 or mat == null:
		_fx.visible = false
		return
	var k := int(n)
	if MATRICES.has(k) and float(k) == n:
		var rows: Array = MATRICES[k]
		for i in 3:
			var r: Array = rows[i]
			mat.set_shader_parameter("row%d" % i, Vector4(r[0], r[1], r[2], r[3]))
			mat.set_shader_parameter("off%d" % i, float(r[4]) / 255.0)
		mat.set_shader_parameter("blur", 0.0)
		_fx.visible = true
	elif n > 100.0:
		mat.set_shader_parameter("row0", Vector4(1, 0, 0, 0))
		mat.set_shader_parameter("row1", Vector4(0, 1, 0, 0))
		mat.set_shader_parameter("row2", Vector4(0, 0, 1, 0))
		for i in 3:
			mat.set_shader_parameter("off%d" % i, 0.0)
		mat.set_shader_parameter("blur", log(n - 100.0) / log(2.0))
		_fx.visible = true
	else:
		push_warning("StoryScreen: unknown special effect %s" % n)


func _gui(on: bool) -> void:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	if not on:
		_hud_hidden.clear()
		var root := hud.get_node_or_null("Root") as CanvasItem if hud != null else null
		if root != null and root.visible:
			root.visible = false
			_hud_hidden.append(root)
		return
	for item in _hud_hidden:
		if is_instance_valid(item):
			item.visible = true
	_hud_hidden.clear()
