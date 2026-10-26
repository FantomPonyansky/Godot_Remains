extends SceneTree

## pack_units.gd for extracted_swf/trap_vis/jobs.json (export_traps.py): one sheet
## per trap in assets/sprites/sheets/traps/ and traps/manifest.json.
## Every render has a magenta 3px dot at (-half, -half) of the unit's root,
## which gives the origin even when FFDec pads the canvas for filters.
## Run: godot --headless --path godot -s res://tools/pack_traps.gd [id ...]

const JOBS := "../original/extracted_swf/trap_vis/jobs.json"
const OUT := "res://assets/sprites/sheets/traps/"
const PAD := 2
const MAX_W := 4096
const HALF_ABOVE := 6_000_000


func _init() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var jobs_path := root.path_join(JOBS).simplify_path()
	var jobs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(jobs_path))
	var only: Array = OS.get_cmdline_user_args()
	var manifest_path := ProjectSettings.globalize_path(OUT + "manifest.json")
	var manifest: Dictionary = {}
	if FileAccess.file_exists(manifest_path):
		manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for unit in jobs.keys():
		if not only.is_empty() and not only.has(unit):
			continue
		var job: Dictionary = jobs[unit]
		var half := int(job.origin[0])
		var clip_imgs := {}
		for clip in job.clips.keys():
			var imgs: Array = []
			for f in job.clips[clip].files:
				imgs.append(_load_marked(str(f), half))
			clip_imgs[clip] = imgs
		var packed := _pack(clip_imgs, ProjectSettings.globalize_path(OUT + "%s.png" % unit))
		var entry := {"sheet": "%s.png" % unit, "cell": packed.cell, "anchor": packed.anchor, "cols": packed.cols, "clips": {}, "parts": {}}
		if int(packed.scale) != 1:
			entry["scale"] = packed.scale
		for clip in job.clips.keys():
			entry.clips[clip] = {"frames": packed.frames[clip], "loop": bool(job.clips[clip].loop)}
		for part in job.get("parts", {}).keys():
			var pj: Dictionary = job.parts[part]
			var imgs: Array = []
			for f in pj.files:
				imgs.append(_load_marked(str(f), half))
			var pp := _pack({"all": imgs}, ProjectSettings.globalize_path(OUT + "%s_%s.png" % [unit, part]))
			entry.parts[part] = {"sheet": "%s_%s.png" % [unit, part], "cell": pp.cell, "anchor": pp.anchor, "cols": pp.cols,
				"frames": pp.frames["all"], "pivot": pj.pivot, "rot": pj.get("rot", [1, 0, 0, 1])}
		manifest[unit] = entry
		print("packed ", unit, " cell ", packed.cell, " anchor ", packed.anchor, " uniq ", packed.count)
	var fa := FileAccess.open(manifest_path, FileAccess.WRITE)
	fa.store_string(JSON.stringify(manifest, " ", false))
	fa.close()
	quit()


## Image with the marker erased, plus where the unit origin sits in it.
func _load_marked(path: String, half: int) -> Dictionary:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGBA8)
	var mx := -1
	var my := -1
	var span := mini(64, mini(img.get_width(), img.get_height()))
	for y in span:
		for x in span:
			var c := img.get_pixel(x, y)
			if c.r > 0.8 and c.g < 0.25 and c.b > 0.8 and c.a > 0.8:
				if mx < 0 or x + y < mx + my:
					mx = x
					my = y
	if mx < 0:
		push_error("no marker in %s" % path)
		mx = 0
		my = 0
	for y in range(maxi(0, my - 1), mini(img.get_height(), my + 5)):
		for x in range(maxi(0, mx - 1), mini(img.get_width(), mx + 5)):
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	return {"img": img, "origin": Vector2i(mx + half, my + half)}


func _pack(clips: Dictionary, out_path: String) -> Dictionary:
	var union := Rect2i()
	var have := false
	for clip in clips.keys():
		for e in clips[clip]:
			var used: Rect2i = (e.img as Image).get_used_rect()
			if used.size == Vector2i.ZERO:
				continue
			var r := Rect2i(used.position - Vector2i(e.origin), used.size)
			union = r if not have else union.merge(r)
			have = true
	if not have:
		union = Rect2i(0, 0, 1, 1)
	var cell := union.size + Vector2i(PAD * 2, PAD * 2)
	var anchor := -union.position + Vector2i(PAD, PAD)
	var uniq: Array = []
	var seen := {}
	var frames := {}
	for clip in clips.keys():
		var idx: Array = []
		for e in clips[clip]:
			var img: Image = e.img
			var tile := Image.create(cell.x, cell.y, false, Image.FORMAT_RGBA8)
			var src := Rect2i(Vector2i(e.origin) + union.position, union.size)
			tile.blit_rect(img, src, Vector2i(PAD, PAD))
			var key := hash(tile.get_data())
			if not seen.has(key):
				seen[key] = uniq.size()
				uniq.append(tile)
			idx.append(seen[key])
		frames[clip] = idx
	# Full-screen blasts (baleblast, necrblast) would be 60 MB sheets; they pack at half
	# size and the manifest scale tells the game to draw them back at 2x.
	var scale := 1
	if uniq.size() * cell.x * cell.y > HALF_ABOVE:
		scale = 2
		cell = Vector2i(ceili(cell.x / 2.0), ceili(cell.y / 2.0))
		anchor = Vector2i(anchor.x / 2, anchor.y / 2)
		for i in uniq.size():
			(uniq[i] as Image).resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
	var cols := maxi(1, mini(uniq.size(), MAX_W / cell.x))
	var rows := int(ceil(float(uniq.size()) / float(cols)))
	var sheet := Image.create(cols * cell.x, rows * cell.y, false, Image.FORMAT_RGBA8)
	for i in uniq.size():
		sheet.blit_rect(uniq[i], Rect2i(Vector2i.ZERO, cell), Vector2i((i % cols) * cell.x, (i / cols) * cell.y))
	sheet.save_png(out_path)
	return {"cell": [cell.x, cell.y], "anchor": [anchor.x, anchor.y], "cols": cols, "frames": frames, "count": uniq.size(), "scale": scale}
