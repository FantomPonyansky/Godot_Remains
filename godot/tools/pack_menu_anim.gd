extends SceneTree

## Crops extracted_swf/_menu_anim_tmp (export_menu_anim.py) into
## assets/ui/menu/anim/<name>.png horizontal strips plus anim.json
## {name: {frames, w, h, origin}}; origin is the symbol origin inside a frame.
## godot --headless --path godot --script res://tools/pack_menu_anim.gd

const SRC := "res://../original/extracted_swf/_menu_anim_tmp/jobs.json"
const OUT := "res://assets/ui/menu/anim/"
## Only the first frame is wanted; the extra frames come from children that were dropped.
const STILL := ["mane", "ear", "horn", "pistol"]
## Room around the art for the displacement and the lightning glow.
const PAD := {"displ1": 8, "displ2": 8, "moln": 16}


func _init() -> void:
	var jobs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(SRC)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var manifest := {}
	for name: String in jobs:
		var job: Dictionary = jobs[name]
		var files: Array = job["files"]
		if name in STILL:
			files = files.slice(0, 1)
		var images: Array[Image] = []
		var used := Rect2i()
		var mark := Vector2i(-1, -1)
		for path: String in files:
			var img := Image.load_from_file(path)
			img.convert(Image.FORMAT_RGBA8)
			var at := _marker(img)
			if mark.x < 0:
				mark = at
			if at.x >= 0:
				for y in range(at.y - 1, at.y + 4):
					for x in range(at.x - 1, at.x + 4):
						if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
							img.set_pixel(x, y, Color(0, 0, 0, 0))
			var r := img.get_used_rect()
			if r.size.x > 0:
				used = r if used.size.x == 0 else used.merge(r)
			images.append(img)
		if used.size.x == 0:
			used = Rect2i(0, 0, 1, 1)
		if PAD.has(name):
			used = used.grow(int(PAD[name])).intersection(Rect2i(Vector2i.ZERO, images[0].get_size()))
		var strip := Image.create(used.size.x * images.size(), used.size.y, false, Image.FORMAT_RGBA8)
		for i in images.size():
			strip.blit_rect(images[i], used, Vector2i(i * used.size.x, 0))
		strip.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		var origin: Array = job["origin"]
		var corner := Vector2(maxi(mark.x, 0), maxi(mark.y, 0))
		manifest[name] = {"frames": images.size(), "w": used.size.x, "h": used.size.y,
			"origin": [float(origin[0]) + corner.x - used.position.x, float(origin[1]) + corner.y - used.position.y]}
		print(name, " ", images.size(), " ", used, " marker ", mark)
	var f := FileAccess.open(OUT + "anim.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, " "))
	f.close()
	quit()


## Top-left pixel of the opaque magenta origin dot.
func _marker(img: Image) -> Vector2i:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.9 and c.r > 0.9 and c.g < 0.1 and c.b > 0.9:
				return Vector2i(x, y)
	return Vector2i(-1, -1)
