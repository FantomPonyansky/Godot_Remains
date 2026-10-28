extends RefCounted

## Session warm-up, started by the main menu. Art and sound every save uses load
## on a worker and stay referenced, so the first shot, hit, loot drop or PipBuck
## page finds them in the resource cache instead of reading a file mid-game.
## Land art (unit sheets, tiles, backs, objects) is left to the land build.
## Each project shader and built-in blend mode is drawn once behind the menu so
## its pipeline is compiled before play.

const _PonyPuppet := preload("res://scripts/pony_puppet.gd")
const DIRS: PackedStringArray = [
	"res://assets/sfx/",
	"res://assets/sprites/weapons/",
	"res://assets/sprites/projectiles/",
	"res://assets/sprites/fx/",
	"res://assets/sprites/decals/",
	"res://assets/sprites/debris/",
	"res://assets/fx_blits/",
	"res://assets/sprites/loot/",
	"res://assets/sprites/ui/",
	"res://assets/sprites/gui/",
	"res://assets/sprites/sats/",
	"res://assets/ui/effects/",
	"res://assets/ui/imp/",
	"res://assets/ui/pip/",
	"res://assets/ui/trol/",
	"res://assets/ui/lmb/",
]
const EXTS: PackedStringArray = ["png", "webp", "wav", "mp3", "ogg"]
const SHADERS := "res://assets/shaders/"
## Frames the shader probes stay drawn.
const PROBE_FRAMES := 3

static var _held: Array[Resource] = []
static var _lock := Mutex.new()


## Runs after the pony frames on the pony warm-up's worker; pony_puppet waits for
## that task at shutdown and then calls _release.
static func start(host: Node) -> void:
	_PonyPuppet.warm_up(_load_all, _release)
	_compile_shaders(host)


static func done() -> bool:
	return _PonyPuppet.warm_done()


static func _load_all() -> void:
	for dir in DIRS:
		_load_dir(dir)


static func _load_dir(dir: String) -> void:
	for entry in ResourceLoader.list_directory(dir):
		if entry.ends_with("/"):
			_load_dir(dir + entry)
		elif EXTS.has(entry.get_extension().to_lower()):
			var res := ResourceLoader.load(dir + entry)
			if res != null:
				_lock.lock()
				_held.append(res)
				_lock.unlock()


## Resources still held in statics at shutdown are freed after the servers.
static func _release() -> void:
	_lock.lock()
	_held.clear()
	_lock.unlock()


static func _compile_shaders(host: Node) -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	var root := Node2D.new()
	root.name = "ShaderProbes"
	var materials: Array[Material] = []
	for entry in ResourceLoader.list_directory(SHADERS):
		if entry.get_extension() == "gdshader":
			var mat := ShaderMaterial.new()
			mat.shader = load(SHADERS + entry) as Shader
			materials.append(mat)
	for mode in [CanvasItemMaterial.BLEND_MODE_ADD, CanvasItemMaterial.BLEND_MODE_SUB,
			CanvasItemMaterial.BLEND_MODE_MUL, CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA]:
		var cim := CanvasItemMaterial.new()
		cim.blend_mode = mode
		materials.append(cim)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	materials.append(unshaded)
	for mat in materials:
		var probe := Sprite2D.new()
		probe.texture = tex
		probe.centered = false
		probe.material = mat
		root.add_child(probe)
	# The menu pony's glow runs in a CanvasGroup, a separate pipeline.
	var group := CanvasGroup.new()
	var glow := ShaderMaterial.new()
	glow.shader = load(SHADERS + "group_glow.gdshader") as Shader
	group.material = glow
	var inner := Sprite2D.new()
	inner.texture = tex
	inner.centered = false
	group.add_child(inner)
	root.add_child(group)
	host.add_child(root)
	host.move_child(root, 0)
	_free_after(root, PROBE_FRAMES)


static func _free_after(node: Node, frames: int) -> void:
	var tree := node.get_tree()
	for _i in frames:
		await tree.process_frame
	if is_instance_valid(node):
		node.queue_free()
