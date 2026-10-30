extends SceneTree

## Crops one base-pixel rect (x,y,w,h after --) from frames_sheet / rig / other, side by side, 3x.

const DIR := "D:/Games/FoE Remains Port/tmp/shots/"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var r := Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
	var out := Image.create_empty(r.size.x * 3, r.size.y, false, Image.FORMAT_RGBA8)
	var i := 0
	for f in ["frames_sheet.png", "frames_rig.png", "frames_other.png"]:
		var img := Image.load_from_file(DIR + f)
		img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != 1280:
			img.resize(1280, int(img.get_height() * 1280.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
		out.blit_rect(img, r, Vector2i(i * r.size.x, 0))
		i += 1
	out.resize(out.get_width() * 3, out.get_height() * 3, Image.INTERPOLATE_NEAREST)
	out.save_png(DIR + "crop_compare.png")
	quit()
