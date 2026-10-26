class_name CheckMark

## Flash CheckBox skin marks on a 13 px box: a green tick when on, a red cross when off.


static func icon(on: bool, frame := Color("00ff99")) -> ImageTexture:
	var img := Image.create_empty(13, 13, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.12, 0.08, 0.7))
	for n in 13:
		for p in [Vector2i(n, 0), Vector2i(n, 12), Vector2i(0, n), Vector2i(12, n)]:
			img.set_pixelv(p, frame)
	draw(img, on)
	return ImageTexture.create_from_image(img)


static func draw(img: Image, on: bool) -> void:
	if on:
		var green := Color("20d040")
		for p in [Vector2i(3, 6), Vector2i(4, 7), Vector2i(5, 8), Vector2i(6, 7), Vector2i(7, 6),
				Vector2i(8, 5), Vector2i(9, 4), Vector2i(10, 3)]:
			img.set_pixelv(p, green)
			img.set_pixelv(p + Vector2i(0, 1), green)
	else:
		var red := Color("ff2020")
		for n in range(3, 10):
			for w in 2:
				img.set_pixel(n, clampi(n + w - 1, 3, 9), red)
				img.set_pixel(n, clampi(12 - n + w - 1, 3, 9), red)
