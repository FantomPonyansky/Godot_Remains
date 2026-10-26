extends SceneTree

## Crops extracted_swf/objects/jobs.json (export_objects.py) into per-frame PNGs:
## obj_<id> -> assets/sprites/objects/<id>/, back_* -> assets/sprites/backs/<clip>/,
## bonus_xp / trap_* -> assets/sprites/objects/<key>/. Every frame of a clip is
## cut to the same rect, so one offset (top-left from the clip origin) fits all.
## The magenta 3px dot of each render sits at (-half, -half) of the clip origin.
## Writes extracted_swf/objects/out.json with the offsets and frame labels.
## Run: godot --headless --path godot -s res://tools/pack_objects.gd

const JOBS := "../original/extracted_swf/objects/jobs.json"
const OUT := "../original/extracted_swf/objects/out.json"


func _init() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var jobs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join(JOBS).simplify_path()))
	var out := {}
	for key: String in jobs.keys():
		var job: Dictionary = jobs[key]
		var half := int(job.half)
		var imgs: Array = []
		for f in job.files:
			imgs.append(_load_marked(str(f), half))
		var union := Rect2i()
		var have := false
		for e in imgs:
			var used: Rect2i = (e.img as Image).get_used_rect()
			if used.size == Vector2i.ZERO:
				continue
			var r := Rect2i(used.position - Vector2i(e.origin), used.size)
			union = r if not have else union.merge(r)
			have = true
		if not have:
			union = Rect2i(0, 0, 1, 1)
		var dir := _dir(key, str(job.symbol))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		for i in imgs.size():
			var e: Dictionary = imgs[i]
			var tile := Image.create(union.size.x, union.size.y, false, Image.FORMAT_RGBA8)
			tile.blit_rect(e.img, Rect2i(Vector2i(e.origin) + union.position, union.size), Vector2i.ZERO)
			tile.save_png(ProjectSettings.globalize_path(dir.path_join("%d.png" % (i + 1))))
		out[key] = {"dir": dir, "frames": imgs.size(), "ox": union.position.x, "oy": union.position.y,
			"w": union.size.x, "h": union.size.y, "labels": job.labels}
		print("packed ", key, " ", union)
	var fa := FileAccess.open(root.path_join(OUT).simplify_path(), FileAccess.WRITE)
	fa.store_string(JSON.stringify(out, " ", true))
	fa.close()
	quit()


func _dir(key: String, symbol: String) -> String:
	if key.begins_with("obj_"):
		return "res://assets/sprites/objects/" + key.trim_prefix("obj_")
	if key.begins_with("back_"):
		return "res://assets/sprites/backs/" + symbol
	return "res://assets/sprites/objects/" + key


func _load_marked(path: String, half: int) -> Dictionary:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGBA8)
	var at := _find_dot(img, mini(64, mini(img.get_width(), img.get_height())))
	if at.x < 0:
		at = _find_dot(img, maxi(img.get_width(), img.get_height()))
	if at.x < 0:
		push_error("no marker in %s" % path)
		at = Vector2i.ZERO
	for y in range(maxi(0, at.y - 1), mini(img.get_height(), at.y + 5)):
		for x in range(maxi(0, at.x - 1), mini(img.get_width(), at.x + 5)):
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	return {"img": img, "origin": at + Vector2i(half, half)}


func _find_dot(img: Image, span: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	for y in mini(span, img.get_height()):
		for x in mini(span, img.get_width()):
			var c := img.get_pixel(x, y)
			if c.r > 0.8 and c.g < 0.25 and c.b > 0.8 and c.a > 0.8:
				if best.x < 0 or x + y < best.x + best.y:
					best = Vector2i(x, y)
		if best.x >= 0 and y > best.y + 4:
			break
	return best
