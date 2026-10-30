extends SceneTree

## Stacks frames_rig / frames_other (ours scaled to 1280 wide) into
## tmp/shots/frames_compare.png. Arg after --: h=<base px height of the crop from the top>.

const DIR := "D:/Games/FoE Remains Port/tmp/shots/"


func _initialize() -> void:
	var h := 720
	for a in OS.get_cmdline_user_args():
		if a.begins_with("h="):
			h = int(a.substr(2))
	var imgs := []
	for f in ["frames_rig.png", "frames_other.png"]:
		var img := Image.load_from_file(DIR + f)
		img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != 1280:
			img.resize(1280, int(img.get_height() * 1280.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
		imgs.append(img)
	var out := Image.create_empty(1280, h * 2, false, Image.FORMAT_RGBA8)
	for i in 2:
		out.blit_rect(imgs[i], Rect2i(0, 0, 1280, h), Vector2i(0, i * h))
	out.save_png(DIR + "frames_compare.png")
	quit()
