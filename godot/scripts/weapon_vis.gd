extends RefCounted

## Held-weapon art. WeaponFactory names the clip vis + id (visp10mm, visknife,
## vismont_1). A missing variant falls back to the base clip, then visp10mm.
## The anchor is the Flash registration point: the grip sits on the node origin
## and the barrel runs along +X. emit is the muzzle, in that same space.
## Each clip is one padded sheet of its unique timeline frames. map turns a
## timeline frame into a sheet cell, and script holds the clip's frame scripts
## (frame 1 stop(), the last shoot frame gotoAndStop(1)). The pad leaves room
## for the teleFilter glow.

const DIR := "res://assets/sprites/weapons/held/"
const _GLOW := preload("res://assets/shaders/glow_filter.gdshader")
const _Look := preload("res://scripts/pony_look.gd")

static var _data: Dictionary = {}
static var _loaded := false
static var _textures: Dictionary = {}


class Clip:
	## One MovieClip playhead. advance() is one 30 Hz Flash frame.
	var rec: Dictionary
	var tex: Texture2D
	var kor: Texture2D
	var frame := 1
	var playing := false
	var total := 1

	func _init(record: Dictionary, sheet: Texture2D, kor_sheet: Texture2D = null) -> void:
		rec = record
		tex = sheet
		kor = kor_sheet
		var map: Array = rec.get("map", [0])
		total = maxi(map.size(), 1)

	func label(name: String) -> int:
		var labels: Dictionary = rec.get("labels", {})
		return int(labels.get(name, 0))

	func goto_stop(target: Variant) -> void:
		frame = _resolve(target)
		playing = false
		_enter()

	func goto_play(target: Variant) -> void:
		frame = _resolve(target)
		playing = true
		_enter()

	func advance() -> void:
		if not playing:
			return
		frame += 1
		if frame > total:
			frame = 1
		_enter()

	func show(sprite: Sprite2D) -> bool:
		if sprite != null:
			sprite.set_meta("kor", kor)
		return place(sprite, rec, tex, frame)

	func _resolve(target: Variant) -> int:
		if typeof(target) == TYPE_STRING:
			var text := str(target)
			if text.is_valid_int():
				return clampi(int(text), 1, total)
			var at := label(text)
			return at if at > 0 else frame
		return clampi(int(target), 1, total)

	func _enter() -> void:
		var script: Dictionary = rec.get("script", {})
		for _hop in 3:
			var act: Variant = script.get(str(frame))
			if not (act is Array) or (act as Array).size() < 2:
				return
			var verb := str(act[0])
			if act[1] == null:
				if verb == "stop":
					playing = false
				return
			var to := _resolve(act[1])
			playing = verb == "play"
			if to == frame:
				return
			frame = to

	static func place(sprite: Sprite2D, record: Dictionary, sheet: Texture2D, at: int) -> bool:
		if sprite == null or sheet == null:
			return false
		sprite.texture = sheet
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var point: Array = record.get("anchor", [0, 0])
		var grip := Vector2(float(point[0]), float(point[1])) if point.size() >= 2 else Vector2.ZERO
		var map: Array = record.get("map", [])
		if map.is_empty():
			sprite.region_enabled = false
			sprite.offset = -grip
			return true
		var cell: Array = record.get("cell", [1, 1])
		var cols := maxi(int(record.get("cols", 1)), 1)
		var pad := float(record.get("pad", 0))
		var idx := int(map[clampi(at, 1, map.size()) - 1])
		var size := Vector2(float(cell[0]), float(cell[1]))
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2(float(idx % cols) * size.x, float(idx / cols) * size.y), size)
		sprite.offset = -(grip + Vector2(pad, pad))
		return true


static func dress(sprite: Sprite2D, weapon_id: String) -> bool:
	var found := clip(weapon_id)
	if found == null:
		if sprite != null:
			sprite.texture = null
		return false
	return found.show(sprite)


## True only when the weapon has its own clip, without the visp10mm fallback.
static func has_art(weapon_id: String) -> bool:
	_ensure()
	var ids: Dictionary = _data.get("ids", {})
	var name := str(ids.get(weapon_id, ids.get(weapon_id.split("^")[0], "")))
	return name != "" and (_data.get("clips", {}) as Dictionary).has(name)


static func clip(weapon_id: String) -> Clip:
	var rec := _record(weapon_id)
	var tex := _sheet(rec)
	if tex == null:
		return null
	return Clip.new(rec, tex, _load(str(rec.get("kor_sheet", ""))))


static func fx_clip(name: String) -> Clip:
	_ensure()
	var extra: Dictionary = _data.get("fx_clips", {})
	var rec: Dictionary = extra.get(name, {})
	var tex := _sheet(rec)
	if tex == null:
		return null
	return Clip.new(rec, tex)


## Presentation fields from the original weapons.json that the catalog lacks:
## recoil, drot2, massa, shell, flare, snd_reload, snd_prep, mtip, lasm, pow, combo, tipdec, tip.
static func fx(weapon_id: String) -> Dictionary:
	_ensure()
	var table: Dictionary = _data.get("fx", {})
	if table.has(weapon_id):
		return table[weapon_id]
	return table.get(weapon_id.split("^")[0], {})


## UnitPon.weaponLevit puts teleFilter on vis.kor when the clip has one, else on vis.
## kor_sheet is that layer alone, laid out like the clip's sheet.
static func make_glow(sprite: Sprite2D) -> Sprite2D:
	var glow := Sprite2D.new()
	glow.name = "Glow"
	glow.show_behind_parent = true
	var mat := ShaderMaterial.new()
	mat.shader = _GLOW
	glow.material = mat
	sprite.add_child(glow)
	return glow


## UnitPlayer.teleColor is app.cMagic, the raw appearance colour (not its transform).
static func tele_color() -> Color:
	var rgb: Array = _Look.state().get("magic", [0, 255, 0])
	return Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))


static func sync_glow(sprite: Sprite2D, glow: Sprite2D, color: Color, on: bool) -> void:
	if glow == null:
		return
	glow.visible = on and sprite != null and sprite.texture != null and sprite.visible
	if not glow.visible:
		return
	var kor: Variant = sprite.get_meta("kor") if sprite.has_meta("kor") else null
	glow.texture = kor if kor is Texture2D else sprite.texture
	glow.centered = sprite.centered
	glow.offset = sprite.offset
	glow.region_enabled = sprite.region_enabled
	glow.region_rect = sprite.region_rect
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := glow.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("glow_color", Color(color.r, color.g, color.b, 1.0))


static func emit(weapon_id: String) -> Vector2:
	var rec := _record(weapon_id)
	if rec.has("emit"):
		var point: Array = rec["emit"]
		return Vector2(float(point[0]), float(point[1]))
	var grip := anchor(weapon_id)
	var png: Array = rec.get("png", [0, 0])
	return Vector2(maxf(float(png[0]) - grip.x, 8.0), 0.0)


static func anchor(weapon_id: String) -> Vector2:
	var rec := _record(weapon_id)
	var point: Array = rec.get("anchor", [0, 0])
	if point.size() < 2:
		return Vector2.ZERO
	return Vector2(float(point[0]), float(point[1]))


static func texture(weapon_id: String) -> Texture2D:
	var rec := _record(weapon_id)
	return _load(str(rec.get("file", "")))


static func _sheet(rec: Dictionary) -> Texture2D:
	var sheet := _load(str(rec.get("sheet", "")))
	if sheet != null:
		return sheet
	return _load(str(rec.get("file", "")))


static func _load(file: String) -> Texture2D:
	if file == "":
		return null
	if _textures.has(file):
		return _textures[file]
	var path := DIR + file
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	_textures[file] = tex
	return tex


static func _record(weapon_id: String) -> Dictionary:
	_ensure()
	var clips: Dictionary = _data.get("clips", {})
	var name := _clip(weapon_id)
	if clips.has(name):
		return clips[name]
	if clips.has("visp10mm"):
		return clips["visp10mm"]
	return {}


static func _clip(weapon_id: String) -> String:
	_ensure()
	var ids: Dictionary = _data.get("ids", {})
	if ids.has(weapon_id):
		return str(ids[weapon_id])
	var base := weapon_id.split("^")[0]
	if ids.has(base):
		return str(ids[base])
	return "visp10mm"


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var path := DIR + "manifest.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		_data = parsed
