extends SceneTree

## Crops and packs export_story_art.py renders. Sheet jobs become one sheet
## per key in the unit-sheet manifest format; frame jobs (scenes) become one
## cropped png per distinct frame plus offsets. Run:
## godot --headless --path <this dir> -s pack.gd -- [key ...]

var WORK := ProjectSettings.globalize_path("res://").path_join("../../../original/extracted_swf/story_art/").simplify_path() + "/"
var NPC_OUT := ProjectSettings.globalize_path("res://").path_join("../../../godot/assets/sprites/npcs/").simplify_path() + "/"
var SCENE_OUT := ProjectSettings.globalize_path("res://").path_join("../../../godot/assets/sprites/scenes/").simplify_path() + "/"
const MAX_W := 4096
const PAD := 1


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	var jobs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORK + "jobs.json"))
	var npc_manifest := _read(NPC_OUT + "manifest.json")
	var scene_manifest := _read(SCENE_OUT + "scenes.json")
	DirAccess.make_dir_recursive_absolute(NPC_OUT)
	DirAccess.make_dir_recursive_absolute(SCENE_OUT)
	for key in jobs:
		if not only.is_empty() and not only.has(key):
			continue
		var job: Dictionary = jobs[key]
		if str(job.kind) == "frames":
			scene_manifest[key] = _pack_frames(job)
		elif str(job.kind) == "path":
			npc_manifest[key] = _pack_path(job)
		else:
			npc_manifest[key] = _pack_sheet(job)
		print("packed ", key)
	_write(NPC_OUT + "manifest.json", npc_manifest)
	_write(SCENE_OUT + "scenes.json", scene_manifest)
	quit()


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, " ", true))
	f.close()


## The magenta dot marks the box corner; returns the origin in the image.
func _origin(img: Image, box0: Vector2) -> Vector2:
	# FFDec may pad the canvas: the dot is then the top-left of the used rect.
	for start: Vector2i in [Vector2i.ZERO, img.get_used_rect().position]:
		for y in range(start.y, mini(img.get_height(), start.y + 12)):
			for x in range(start.x, mini(img.get_width(), start.x + 12)):
				var c := img.get_pixel(x, y)
				if c.a > 0.9 and c.r > 0.9 and c.g < 0.1 and c.b > 0.9:
					for dy in range(-1, 5):
						for dx in range(-1, 5):
							if x + dx >= 0 and y + dy >= 0 and x + dx < img.get_width() and y + dy < img.get_height():
								img.set_pixel(x + dx, y + dy, Color(0, 0, 0, 0))
					return Vector2(x, y) - box0
	var at := _find_dot(img)
	if at.x >= 0:
		for dy in range(-1, 5):
			for dx in range(-1, 5):
				if at.x + dx >= 0 and at.y + dy >= 0 and at.x + dx < img.get_width() and at.y + dy < img.get_height():
					img.set_pixel(at.x + dx, at.y + dy, Color(0, 0, 0, 0))
		return Vector2(at) - box0
	push_warning("no marker")
	return -box0


## Anywhere in the image: the first pure magenta pixel (RGBA8 ff00ffff).
func _find_dot(img: Image) -> Vector2i:
	var hex := img.get_data().hex_encode()
	var from := 0
	while true:
		var i := hex.find("ff00ffff", from)
		if i < 0:
			return Vector2i(-1, -1)
		if i % 8 == 0:
			var p := i / 8
			return Vector2i(p % img.get_width(), p / img.get_width())
		from = i + 1
	return Vector2i(-1, -1)


func _box0(job: Dictionary) -> Vector2:
	if job.has("box"):
		return Vector2(float(job.box[0]), float(job.box[1]))
	if str(job.kind) == "frames":
		return Vector2.ZERO
	return Vector2(-100, -100) if str(job.key) == "npcico" else Vector2(-260, -260)


func _pack_sheet(job: Dictionary) -> Dictionary:
	var box0 := _box0(job)
	var imgs: Array[Image] = []
	var origins: Array[Vector2] = []
	var clip_frames := {}
	var by_hash := {}
	var union := Rect2i()
	var have := false
	for clip in job.clips:
		var idx: Array = []
		for path in job.clips[clip].files:
			var img := Image.load_from_file(str(path))
			img.convert(Image.FORMAT_RGBA8)
			var o := _origin(img, box0)
			var used := img.get_used_rect()
			var h := hash(img.get_data())
			if by_hash.has(h):
				idx.append(by_hash[h])
				continue
			by_hash[h] = imgs.size()
			idx.append(imgs.size())
			imgs.append(img)
			origins.append(o)
			if used.size.x > 0:
				var rel := Rect2i(used.position - Vector2i(o), used.size)
				union = rel if not have else union.merge(rel)
				have = true
		clip_frames[clip] = {"frames": idx, "loop": bool(job.clips[clip].loop)}
	if not have:
		union = Rect2i(0, 0, 1, 1)
	var cw := union.size.x + PAD * 2
	var ch := union.size.y + PAD * 2
	var cols := clampi(MAX_W / cw, 1, imgs.size())
	var rows := ceili(float(imgs.size()) / cols)
	var sheet := Image.create(cw * cols, ch * rows, false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		var src := Rect2i(union.position + Vector2i(origins[i]), union.size)
		var at := Vector2i((i % cols) * cw + PAD, (i / cols) * ch + PAD)
		sheet.blit_rect(imgs[i], src, at)
	var name := str(job.key) + ".png"
	sheet.save_png(NPC_OUT + name)
	return {
		"sheet": name,
		"cell": [cw, ch],
		"anchor": [PAD - union.position.x, PAD - union.position.y],
		"cols": cols,
		"clips": clip_frames,
	}


## A layer rendered alone per frame: its offset from the first closed frame.
func _pack_path(job: Dictionary) -> Dictionary:
	var box0 := _box0(job)
	var base := Vector2i.ZERO
	var have := false
	var offsets := {}
	for clip in ["closed", "open", "opened"]:
		var out: Array = []
		for path in job.clips[clip].files:
			var img := Image.load_from_file(str(path))
			img.convert(Image.FORMAT_RGBA8)
			var o := _origin(img, box0)
			var at := img.get_used_rect().position - Vector2i(o)
			if not have:
				base = at
				have = true
			out.append([at.x - base.x, at.y - base.y])
		offsets[clip] = out
	return {"offsets": offsets}


func _pack_frames(job: Dictionary) -> Dictionary:
	var dir := SCENE_OUT + str(job.key) + "/"
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	var by_hash := {}
	var frames: Array = []
	var files := 0
	for path in job.files:
		var img := Image.load_from_file(str(path))
		img.convert(Image.FORMAT_RGBA8)
		var o := _origin(img, _box0(job))
		var used := img.get_used_rect()
		if used.size.x <= 0:
			frames.append(null)
			continue
		var part := img.get_region(used)
		var h := hash(part.get_data())
		var key := "%d_%d_%d" % [h, used.position.x, used.position.y]
		if not by_hash.has(key):
			files += 1
			var name := "%03d.png" % files
			part.save_png(dir + name)
			by_hash[key] = name
		frames.append([by_hash[key], used.position.x - int(o.x), used.position.y - int(o.y)])
	return {"stage": job.stage, "frames": frames}
