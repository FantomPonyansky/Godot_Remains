extends RefCounted

## Box/door vis<id> clips from texture1.swf and visualBonus / vistrap* from pfe.swf,
## cut by tools/pack_objects.gd into objects/<key>/<frame>.png. Every frame of a clip
## shares one crop; ox/oy is that crop's top-left from the clip origin. For a Box the
## origin is its coordinates point, the bottom centre of the object (Box.as vis.x/y).
## labels maps the clip's frame labels (close/open/active/comein/die/moln) to frames.

const DIR := "res://assets/sprites/objects/"
const _Registry := preload("res://scripts/map/land_registry.gd")

static var shadows := true
static var _shadow_mat: ShaderMaterial

static var _manifest: Dictionary = {}
static var _loaded := false
static var _tex: Dictionary = {}
static var _sheets: Dictionary = {}


static func drop_cache() -> void:
	_tex.clear()
	_sheets.clear()


static func _all() -> Dictionary:
	if not _loaded:
		_loaded = true
		var f := FileAccess.open(DIR + "manifest.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_manifest = parsed
	return _manifest


static func has(key: String) -> bool:
	return _all().has(key)


static func entry(key: String) -> Dictionary:
	return _all().get(key, {})


static func frames(key: String) -> int:
	return int(entry(key).get("frames", 0))


static func size(key: String) -> Vector2:
	var e := entry(key)
	return Vector2(float(e.get("w", 0)), float(e.get("h", 0)))


static func offset(key: String) -> Vector2:
	var e := entry(key)
	return Vector2(float(e.get("ox", 0)), float(e.get("oy", 0)))


## Frame for a label, 0 when the clip has no such label.
static func label_frame(key: String, label: String) -> int:
	var labels: Dictionary = entry(key).get("labels", {})
	return int(labels.get(label, 0))


static func path(key: String, frame: int = 1) -> String:
	return DIR + key + "/" + str(frame) + ".png"


static func texture(key: String, frame: int = 1) -> Texture2D:
	var p := path(key, frame)
	if _tex.has(p):
		return _tex[p] as Texture2D
	var tex: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_tex[p] = tex
	return tex


## A Sprite2D whose position is the clip origin.
static func sprite(key: String, frame: int = 1) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = "Visual"
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.offset = offset(key)
	s.texture = texture(key, frame)
	s.set_meta("obj_art", key)
	return s


## One cell of a packed unit/trap sheet (sheets/<kind>/manifest.json), drawn from its anchor.
static func sheet_still(sheets_dir: String, key: String, frame: int = -1) -> Sprite2D:
	if not _sheets.has(sheets_dir):
		var f := FileAccess.open(sheets_dir + "manifest.json", FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_sheets[sheets_dir] = parsed if parsed is Dictionary else {}
	var e: Dictionary = (_sheets[sheets_dir] as Dictionary).get(key, {})
	if e.is_empty():
		return null
	if frame < 0:
		var clips: Dictionary = e.get("clips", {})
		var first: Dictionary = clips.get("stay", clips.values()[0] if not clips.is_empty() else {})
		var list: Array = first.get("frames", e.get("frames", [0]))
		frame = int(list[0]) if not list.is_empty() else 0
	return _cell(sheets_dir, e, frame)


## The sheet stills of a unit: its body and the first frame of each part.
static func unit_still(sheets_dir: String, key: String) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	var body := sheet_still(sheets_dir, key)
	if body == null:
		return out
	out.append(body)
	var parts: Dictionary = ((_sheets[sheets_dir] as Dictionary)[key] as Dictionary).get("parts", {})
	for part in parts:
		var p: Dictionary = parts[part]
		var fr: Array = p.get("frames", [0])
		var s := _cell(sheets_dir, p, int(fr[0]) if not fr.is_empty() else 0)
		if s != null:
			out.append(s)
	return out


## A rigged unit's rig held on its stay pose (the manifest's osn frame), Flash origin at 0.
static func rig_still(unit_id: String) -> Node2D:
	var enemy_script: GDScript = load("res://scripts/enemy.gd")
	var path: String = enemy_script.rig_path(unit_id)
	if path == "":
		return null
	var rig := (load(path) as PackedScene).instantiate() as RigView
	var row: Dictionary = enemy_script._catalog_row(unit_id)
	var entry := UnitBrain.vis_of(str(row.get("vis", ""))) if str(row.get("vis", "")) != "" \
			else UnitBrain.vis_of(str(row.get("pack", unit_id)))
	var stay: Dictionary = (entry.get("clips", {}) as Dictionary).get("stay", {})
	var osn := int(stay.get("osn", 1))
	rig.ready.connect(func() -> void:
		var idle := rig.idle_clip()
		if idle != "":
			rig.anim_player.play(idle)
			rig.anim_player.seek(float(osn - 1) / 30.0, true)
			rig.anim_player.pause(), CONNECT_ONE_SHOT)
	return rig


static func _cell(sheets_dir: String, e: Dictionary, frame: int) -> Sprite2D:
	var path := sheets_dir + str(e.get("sheet", ""))
	if not ResourceLoader.exists(path):
		return null
	var cell: Array = e.get("cell", [0, 0])
	var anchor: Array = e.get("anchor", [0, 0])
	var cols := maxi(int(e.get("cols", 1)), 1)
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path) as Texture2D
	atlas.region = Rect2(float(frame % cols) * float(cell[0]), float(frame / cols) * float(cell[1]), float(cell[0]), float(cell[1]))
	var s := Sprite2D.new()
	s.name = "Visual"
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.texture = atlas
	s.offset = -Vector2(float(anchor[0]), float(anchor[1]))
	return s


## Box.shad: a second copy of vis with dsf (hideObject), so only the blurred black
## silhouette shows, 6 px lower (2 for wall objects) and behind every object;
## wall > 1 has alpha 0. The copy follows the visual's frame and visibility.
static func shade(visual: CanvasItem, id: String) -> void:
	if not shadows or not visual is Sprite2D or visual.has_node("Shadow"):
		return
	var wall := int(str(_Registry.obj(id).get("wall", "0"))) if id != "" else 0
	if wall > 1:
		return
	if _shadow_mat == null:
		_shadow_mat = ShaderMaterial.new()
		_shadow_mat.shader = load("res://assets/shaders/obj_shadow.gdshader")
	var v := visual as Sprite2D
	var s := Sprite2D.new()
	s.name = "Shadow"
	s.material = _shadow_mat
	s.show_behind_parent = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.centered = v.centered
	s.offset = v.offset
	s.position = Vector2(0, 2 if wall > 0 else 6)
	s.texture = v.texture
	v.texture_changed.connect(func() -> void: s.texture = v.texture)
	v.add_child(s)


## gotoAndPlay(label) at 30 fps to the clip's last frame, then frame 1 again
## (the clips stop on their first frame).
static func play(s: Sprite2D, label: String) -> void:
	if s == null or not s.has_meta("obj_art"):
		return
	var key := str(s.get_meta("obj_art"))
	var first := label_frame(key, label)
	var last := frames(key)
	if first <= 0 or last < first:
		return
	if s.has_meta("obj_tween"):
		var old: Variant = s.get_meta("obj_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := s.create_tween()
	tw.tween_method(func(f: float) -> void: s.texture = texture(key, int(f)), float(first), float(last) + 0.99, float(last - first + 1) / 30.0)
	tw.tween_callback(func() -> void: s.texture = texture(key, 1))
	s.set_meta("obj_tween", tw)


## gotoAndStop(label) on a sprite from sprite(); unknown labels leave it as is.
static func set_state(s: Sprite2D, label: String) -> void:
	if s == null or not s.has_meta("obj_art"):
		return
	var key := str(s.get_meta("obj_art"))
	var fr := label_frame(key, label)
	if fr > 0:
		s.texture = texture(key, fr)
