extends RefCounted

## Read-only room art for the editor. Same lookup as land_preview / play_land:
## TileCatalog.decode, file_for, front_file, beam_texture, RoomLook.backwall_rects.
## Objects: PropArt.still, feet at the footprint's bottom centre.
## Backs: backs.json frame path / ox / oy, same anchor as back_decor.paint.
## Markers with no art are outlines (player, enspawn, area), never a solid fill.

const Catalog := preload("res://scripts/map/tile_catalog.gd")
const Look := preload("res://scripts/map/room_look.gd")
const Codec := preload("res://scripts/editor/room_codec.gd")
const Palette := preload("res://scripts/editor/editor_palette.gd")
const Groups := preload("res://scripts/editor/editor_groups.gd")
const PropArt := preload("res://scripts/map/prop_art.gd")
const Forms := preload("res://scripts/editor/editor_forms.gd")

const GAME := 40.0
const CELL := 16.0

const FON_DIR := "res://assets/sprites/fon/"

var _cells: Array = []
var _checker: Texture2D
var _wall := ""
var _fon := ""
var _form := 0
var _tex: Dictionary = {}
var _room: Dictionary = {}
var _fade := 1.0
static var _kinds: Dictionary = {}


func rebuild(grid: Array, wall: String, form: int, room: Dictionary = {}, fon_name := "") -> void:
	_wall = wall
	_fon = fon_name
	_form = form
	_room = room
	_cells.clear()
	for y in Codec.ROWS:
		var line: Array = []
		var row: Array = grid[y] if y < grid.size() else []
		for x in Codec.COLS:
			var cell: Dictionary = row[x] if x < row.size() else Codec.empty_cell()
			line.append({
				"info": Catalog.decode(Codec.encode_token(cell)),
				"water": str(cell.get("water", "")) == "*",
			})
		_cells.append(line)


func paint(c: CanvasItem, pan: Vector2, zoom: float, show_front: bool, show_back: bool, room: Dictionary = {}, show_objs := true, show_decors := true, layers: Dictionary = {}) -> void:
	if not room.is_empty():
		_room = room
	if _cells.is_empty() or zoom <= 0.0:
		return
	var show := _show_map(show_front, show_back, show_objs, show_decors, layers)
	var scale := CELL * zoom / GAME
	var bounds := Rect2(pan, Vector2(Codec.COLS, Codec.ROWS) * CELL * zoom)
	c.draw_rect(bounds, Color(0.02, 0.025, 0.03))
	_draw_fon(c, bounds)
	if _wall != "sky" and _wall != "":
		var tex := _named(_wall)
		if tex:
			for rect_v in Look.backwall_rects(_form):
				var rect: Rect2 = rect_v
				_tile(c, tex, Rect2(pan + rect.position * scale, rect.size * scale), pan, scale)
	if bool(show.get("backdrop", true)):
		_draw_kind(c, pan, zoom, true, show)
	var px := CELL * zoom
	var view := Vector2(4096, 4096)
	if c is Control:
		view = (c as Control).size
	for layer in 3:
		for y in Codec.ROWS:
			for x in Codec.COLS:
				var at := pan + Vector2(x, y) * px
				if at.x > view.x or at.y > view.y or at.x + px < 0.0 or at.y + px < 0.0:
					continue
				_cell(c, x, y, at, pan, px, scale, layer, show)
	if bool(show.ladder):
		for y in Codec.ROWS:
			for x in Codec.COLS:
				_ladder(c, x, y, pan + Vector2(x, y) * px, scale)
	if bool(show.water):
		for y in Codec.ROWS:
			for x in Codec.COLS:
				if not (_cells[y][x] as Dictionary).water:
					continue
				var at := pan + Vector2(x, y) * px
				var body := _named_path("res://assets/sprites/water/water0_body.png")
				if body:
					c.draw_texture_rect(body, Rect2(at, Vector2(px, px)), false, Color(1, 1, 1, 0.6))
				else:
					c.draw_rect(Rect2(at, Vector2(px, px)), Color(0.12, 0.4, 0.72, 0.35))
	if bool(show.get("obj", true)) or show.has("doors") or show.has("actors") or show.has("props"):
		_draw_kind(c, pan, zoom, false, show)
	if bool(show.get("area", true)):
		paint_areas(c, pan, px, _room, true)


func _show_map(show_front: bool, show_back: bool, show_objs: bool, show_decors: bool, layers: Dictionary) -> Dictionary:
	var show := {
		"front": show_front,
		"back": show_back,
		"obj": show_objs,
		"backdrop": show_decors,
		"water": true,
		"beam": show_front,
		"stair": show_front,
		"ladder": show_front,
	}
	for k in layers.keys():
		show[str(k)] = bool(layers[k])
	if layers.has("front") and not layers.has("water"):
		show["water"] = bool(layers["front"])
	if layers.has("stairs"):
		var on := bool(layers["stairs"])
		if not layers.has("beam"):
			show["beam"] = on
		if not layers.has("stair"):
			show["stair"] = on
		if not layers.has("ladder"):
			show["ladder"] = on
	return show


func _cell(c: CanvasItem, x: int, y: int, at: Vector2, pan: Vector2, px: float, scale: float, layer: int, show: Dictionary) -> void:
	var info: Dictionary = (_cells[y][x] as Dictionary).info
	if layer == 0:
		if not bool(show.get("back", true)):
			return
		if bool(show.get("front", true)) and str(info.block) != "" and int(info.height) == 4:
			return
		var wall := str(info.wall)
		if wall == "":
			return
		var wall_tex := _named(wall)
		if wall_tex:
			_tile(c, wall_tex, Rect2(at, Vector2(px, px)), pan, scale)
		return
	if layer == 1:
		if bool(show.get("beam", true)):
			for beam_v in info.beams:
				var beam_tex := _named(Catalog.beam_texture(str(beam_v)))
				if beam_tex:
					var bh := minf(float(beam_tex.get_height()), GAME) * scale
					_tile(c, beam_tex, Rect2(at, Vector2(px, bh)), pan, scale)
		if bool(show.get("stair", true)):
			var frame := int(info.slope_frame)
			if frame > 0:
				var step := _front(frame)
				if step:
					c.draw_texture_rect(step, Rect2(at - Catalog.FRONT_ORIGIN * scale, step.get_size() * scale), false)
				else:
					var side := str(info.slope_side)
					var pts: PackedVector2Array
					if side == "left":
						pts = PackedVector2Array([at, at + Vector2(0, px), at + Vector2(px, px)])
					else:
						pts = PackedVector2Array([at + Vector2(0, px), at + Vector2(px, px), at + Vector2(px, 0)])
					c.draw_colored_polygon(pts, Color(0.45, 0.38, 0.28))
		return
	if not bool(show.get("front", true)):
		return
	var block := str(info.block)
	if block == "":
		return
	var rect := _solid(at, px, int(info.height))
	var tex := _named(str(info.texture))
	if tex:
		_tile(c, tex, rect, pan, scale)
	var top_name := str(info.top)
	if top_name == "":
		return
	var above_open := y == 0 or str((_cells[y - 1][x] as Dictionary).info.block) == ""
	if not above_open:
		return
	var lip := _named(top_name)
	if lip:
		var lip_h := minf(Catalog.FLOOR_LIP * scale, rect.size.y)
		_tile(c, lip, Rect2(rect.position, Vector2(rect.size.x, lip_h)), pan, scale)


func _ladder(c: CanvasItem, x: int, y: int, at: Vector2, scale: float) -> void:
	var info: Dictionary = (_cells[y][x] as Dictionary).info
	var frame := int(info.ladder_frame)
	if frame == 0:
		return
	var above := 0
	if y > 0:
		above = int((_cells[y - 1][x] as Dictionary).info.ladder_frame)
	if above != frame:
		frame += 1
	var tex := _front(frame)
	if tex == null:
		return
	c.draw_texture_rect(tex, Rect2(at - Catalog.FRONT_ORIGIN * scale, tex.get_size() * scale), false)


func _solid(at: Vector2, px: float, height: int) -> Rect2:
	var h := clampi(height, 1, 4)
	var top := float(4 - h) * (px / 4.0)
	return Rect2(at + Vector2(0, top), Vector2(px, px - top))


## Integer dest edges so the next cell starts on the pixel this one ends on.
func _tile(c: CanvasItem, tex: Texture2D, dest: Rect2, origin: Vector2, scale: float) -> void:
	if tex == null or dest.size.x < 0.5 or dest.size.y < 0.5 or scale <= 0.0:
		return
	var tw := tex.get_width()
	var th := tex.get_height()
	if tw < 1 or th < 1:
		return
	var x0 := int(floor(dest.position.x))
	var y0 := int(floor(dest.position.y))
	var x1 := int(floor(dest.position.x + dest.size.x))
	var y1 := int(floor(dest.position.y + dest.size.y))
	if x1 <= x0 or y1 <= y0:
		return
	var sx := int(floor(fposmod((float(x0) - origin.x) / scale, float(tw))))
	var sy := int(floor(fposmod((float(y0) - origin.y) / scale, float(th))))
	var sw := maxi(1, int(round(float(x1 - x0) / scale)))
	var sh := maxi(1, int(round(float(y1 - y0) / scale)))
	_blit(c, tex, x0, y0, x1 - x0, y1 - y0, sx, sy, sw, sh, tw, th)


func _blit(c: CanvasItem, tex: Texture2D, dx: int, dy: int, dw: int, dh: int, sx: int, sy: int, sw: int, sh: int, tw: int, th: int) -> void:
	var left := sw
	var src_x := sx
	var dest_x := dx
	var remain_w := dw
	while left > 0 and remain_w > 0:
		var chunk_w := mini(left, tw - src_x)
		var piece_w := remain_w if left == chunk_w else maxi(1, int(round(float(dw) * float(chunk_w) / float(sw))))
		piece_w = mini(piece_w, remain_w)
		var top := sh
		var src_y := sy
		var dest_y := dy
		var remain_h := dh
		while top > 0 and remain_h > 0:
			var chunk_h := mini(top, th - src_y)
			var piece_h := remain_h if top == chunk_h else maxi(1, int(round(float(dh) * float(chunk_h) / float(sh))))
			piece_h = mini(piece_h, remain_h)
			c.draw_texture_rect_region(tex, Rect2(dest_x, dest_y, piece_w, piece_h), Rect2(src_x, src_y, chunk_w, chunk_h))
			dest_y += piece_h
			remain_h -= piece_h
			top -= chunk_h
			src_y = 0 if src_y + chunk_h >= th else src_y + chunk_h
		dest_x += piece_w
		remain_w -= piece_w
		left -= chunk_w
		src_x = 0 if src_x + chunk_w >= tw else src_x + chunk_w


## Cover the room with the land sky picture. No parallax. Empty name draws nothing.
func _draw_fon(c: CanvasItem, bounds: Rect2) -> void:
	if _fon == "" or bounds.size.x < 1.0 or bounds.size.y < 1.0:
		return
	var tex := _fon_tex(_fon)
	if tex == null:
		return
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	if tw < 1.0 or th < 1.0:
		return
	var s := maxf(bounds.size.x / tw, bounds.size.y / th)
	var src := Rect2((tw - bounds.size.x / s) * 0.5, (th - bounds.size.y / s) * 0.5, bounds.size.x / s, bounds.size.y / s)
	c.draw_texture_rect_region(tex, bounds, src)


func _fon_tex(fon_name: String) -> Texture2D:
	var key := "fon:" + fon_name
	if _tex.has(key):
		return _tex[key]
	var path := FON_DIR + fon_name + ".png"
	if not ResourceLoader.exists(path):
		path = FON_DIR + "fonDefault.png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[key] = tex
	return tex


func _named(key: String) -> Texture2D:
	if key == "":
		return null
	if _tex.has(key):
		return _tex[key]
	var path := Catalog.file_for(key)
	var tex: Texture2D = load(path) if path != "" else null
	_tex[key] = tex
	return tex


func _named_path(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[path] = tex
	return tex


func draw_faded(c: CanvasItem, obj: Dictionary, pan: Vector2, zoom: float, alpha: float) -> void:
	_fade = clampf(alpha, 0.0, 1.0)
	var px := CELL * zoom
	var game_scale := px / GAME
	if str(obj.get("tag", "obj")) == "back":
		_draw_back(c, obj, pan, px, game_scale)
	else:
		_draw_object(c, obj, pan, px, game_scale)
	_fade = 1.0


func swatch(slot: String, id: String) -> Texture2D:
	var key := "swatch:%s:%s" % [slot, id]
	if _tex.has(key):
		return _tex[key]
	var tex: Texture2D = null
	match slot:
		"front":
			tex = _square(_named(str(Catalog.decode(id).texture)), key)
		"back":
			tex = _square(_named(str(Catalog.decode("_" + id).wall)), key)
		"stair":
			tex = _square(_front(_frame(id)), key)
		"diag":
			if Palette.diag_kind(id) == "beam":
				tex = _square(_named(Catalog.beam_texture(id)), key)
			else:
				tex = _square(_front(_frame(id)), key)
		"water":
			tex = _square(_named_path("res://assets/sprites/water/water0_body.png"), key)
		"obj":
			tex = _prop_swatch(id, key)
		"backdrop":
			tex = _back_swatch(id, key)
	_tex[key] = tex
	return tex


func _frame(id: String) -> int:
	var piece: Array = Catalog.OVERLAY.get(id, [])
	if piece.size() < 4:
		return 0
	return int(piece[3])


func _square(tex: Texture2D, key: String) -> Texture2D:
	if tex == null:
		return null
	_tex[key + "#src"] = tex
	var side := mini(mini(tex.get_width(), tex.get_height()), 40)
	if side < 1:
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(0, 0, side, side)
	return atlas


func _prop_swatch(id: String, key: String) -> Texture2D:
	var art := PropArt.still(id)
	var tex: Texture2D = art.get("tex")
	if tex == null:
		return null
	_tex[key + "#src"] = tex
	var region: Rect2 = art.get("region", Rect2())
	if region.size.x > 1.0 and region.size.y > 1.0:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = region
		return atlas
	return tex


func checker() -> Texture2D:
	if _checker != null:
		return _checker
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var light := (int(x / 4) + int(y / 4)) % 2 == 0
			img.set_pixel(x, y, Color(0.62, 0.62, 0.64) if light else Color(0.40, 0.40, 0.42))
	_checker = ImageTexture.create_from_image(img)
	return _checker


## Full frame, cropped to the opaque pixels. The old top-left 40px cut was empty on large sheets.
func _back_swatch(id: String, key: String) -> Texture2D:
	var spec: Dictionary = _back_kinds().get(id, {})
	var frames: Array = spec.get("t", [])
	if frames.is_empty():
		frames = spec.get("l", [])
	if frames.is_empty():
		return null
	var pic: Dictionary = frames[0]
	var tex := _named_path(str(pic.get("path", "")))
	if tex == null:
		return null
	_tex[key + "#src"] = tex
	var img := tex.get_image()
	if img == null or img.is_empty():
		return tex
	var used := img.get_used_rect()
	if used.size.x < 1 or used.size.y < 1:
		return tex
	if used.position == Vector2i.ZERO and used.size == Vector2i(img.get_width(), img.get_height()):
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(used)
	return atlas


func _front(frame: int) -> Texture2D:
	var key := "front_%d" % frame
	if _tex.has(key):
		return _tex[key]
	var path := Catalog.front_file(frame)
	var tex: Texture2D = load(path) if path != "" else null
	_tex[key] = tex
	return tex


func _layer_on(show: Dictionary, lay: String, is_back: bool) -> bool:
	if show.has(lay):
		return bool(show[lay])
	if is_back:
		return bool(show.get("backdrop", true))
	return bool(show.get("obj", true))


func _draw_kind(c: CanvasItem, pan: Vector2, zoom: float, backs: bool, show: Dictionary = {}) -> void:
	var px := CELL * zoom
	var game_scale := px / GAME
	for obj_v in _room.get("objs", []):
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		var obj: Dictionary = obj_v
		if Forms.is_area(obj):
			continue
		var is_back := str(obj.get("tag", "obj")) == "back"
		if is_back != backs:
			continue
		var lay := "backdrop" if is_back else Groups.obj_layer(obj)
		if not _layer_on(show, lay, is_back):
			continue
		if is_back:
			_draw_back(c, obj, pan, px, game_scale)
		else:
			_draw_object(c, obj, pan, px, game_scale)


func _draw_object(c: CanvasItem, obj: Dictionary, pan: Vector2, px: float, game_scale: float) -> void:
	var id := str(obj.get("id", ""))
	var foot := obj_rect(obj)
	var fill := Rect2(pan + Vector2(foot.position) * px, Vector2(foot.size) * px)
	var art := PropArt.still(id)
	var tex: Texture2D = art.get("tex")
	if tex == null:
		_draw_marker(c, obj, foot, fill, pan, px, game_scale)
		return
	var key := tex.resource_path if tex.resource_path != "" else id
	_tex[key] = tex
	var origin := pan + Vector2(foot.position.x + foot.size.x * 0.5, foot.end.y) * px
	origin.y -= game_scale
	var mul := game_scale * float(art.get("scale", 1.0))
	var anchor: Vector2 = art.get("anchor", Vector2(tex.get_width() * 0.5, tex.get_height()))
	var region: Rect2 = art.get("region", Rect2())
	var sz: Vector2 = region.size if region.size.x > 0.0 and region.size.y > 0.0 else tex.get_size()
	var dest := Rect2(origin - anchor * mul, sz * mul)
	var tint := Color(1, 1, 1, _fade)
	if region.size.x > 0.0 and region.size.y > 0.0:
		c.draw_texture_rect_region(tex, dest, region, tint)
	else:
		c.draw_texture_rect(tex, dest, false, tint)


func _draw_marker(c: CanvasItem, obj: Dictionary, foot: Rect2i, fill: Rect2, pan: Vector2, px: float, game_scale: float) -> void:
	var id := str(obj.get("id", ""))
	var kind := str(Palette.object_meta(id).get("kind", ""))
	if id == "player":
		var feet := pan + Vector2(foot.position.x + foot.size.x * 0.5, foot.end.y) * px
		feet.y -= game_scale
		var body := Rect2(feet - Vector2(24, 72) * game_scale, Vector2(48, 72) * game_scale)
		var col := Color(0.25, 0.95, 1.0)
		c.draw_rect(body, col, false, 2.0)
		_mark_letter(c, body, "P", col)
		return
	if id == "enspawn":
		var col := Color(1.0, 0.28, 0.22)
		c.draw_rect(fill, col, false, 2.0)
		_mark_letter(c, fill, "E", col)
		return
	if id == "area":
		var attrs: Dictionary = obj.get("attrs", {})
		var w := foot.size.x
		var h := foot.size.y
		if attrs.has("w"):
			w = maxi(int(float(str(attrs.w))), 1)
		if attrs.has("h"):
			h = maxi(int(float(str(attrs.h))), 1)
		var rect := Rect2(pan + Vector2(foot.position.x, foot.end.y - h) * px, Vector2(w, h) * px)
		c.draw_rect(rect, Color(1.0, 0.88, 0.2, 0.28))
		c.draw_rect(rect, Color(1.0, 0.85, 0.15, 0.85), false, 1.0)
		return
	var col := Color(1.0, 0.55, 0.15) if kind == "up" else Color(0.85, 0.85, 0.9)
	c.draw_rect(fill, col, false, 1.5)
	_mark_letter(c, fill, id.substr(0, 1).to_upper(), col)


func _mark_letter(c: CanvasItem, rect: Rect2, text: String, col: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null or text == "":
		return
	var size := 11
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	c.draw_string(font, rect.position + (rect.size - ts) * 0.5 + Vector2(0, ts.y * 0.75), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_back(c: CanvasItem, obj: Dictionary, pan: Vector2, px: float, game_scale: float) -> void:
	var id := str(obj.get("id", ""))
	var spec: Dictionary = _back_kinds().get(id, {})
	var frames: Array = spec.get("t", [])
	if frames.is_empty():
		frames = spec.get("l", [])
	var foot := obj_rect(obj)
	var fill := Rect2(pan + Vector2(foot.position) * px, Vector2(foot.size) * px)
	if frames.is_empty():
		c.draw_rect(fill, Color(0.3, 0.75, 0.95, 0.55))
		return
	var fr := int(spec.get("fr", 0))
	if fr < 1:
		fr = 1
	var pic: Dictionary = frames[clampi(fr, 1, frames.size()) - 1]
	var tex := _named_path(str(pic.get("path", "")))
	if tex == null:
		c.draw_rect(fill, Color(0.3, 0.75, 0.95, 0.55))
		return
	var attrs: Dictionary = obj.get("attrs", {})
	var sx := float(attrs.get("w", 1.0))
	var sy := float(attrs.get("h", 1.0))
	if sx == 0.0:
		sx = 1.0
	if sy == 0.0:
		sy = 1.0
	var at := pan + Vector2(int(obj.get("x", 0)), int(obj.get("y", 0))) * px
	var off := Vector2(float(pic.get("ox", 0.0)), float(pic.get("oy", 0.0))) * game_scale
	var sz := tex.get_size() * Vector2(absf(sx), absf(sy)) * game_scale
	var dw := sz.x if sx >= 0.0 else -sz.x
	var dh := sz.y if sy >= 0.0 else -sz.y
	var alpha := float(spec.get("alpha", 1.0))
	c.draw_texture_rect(tex, Rect2(at + off, Vector2(dw, dh)), false, Color(1, 1, 1, alpha * _fade))


static func _back_kinds() -> Dictionary:
	if not _kinds.is_empty():
		return _kinds
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/backs.json"))
	if typeof(data) == TYPE_DICTIONARY:
		_kinds = (data as Dictionary).get("kinds", {})
	return _kinds


## Cell footprint. An object anchor is the bottom row; a back anchor is the top-left.
## An area anchor is the bottom-left cell; the zone is w by h upward.
static func obj_rect(obj: Dictionary) -> Rect2i:
	if Forms.is_area(obj):
		return Forms.area_rect(obj)
	var x := int(obj.get("x", 0))
	var y := int(obj.get("y", 0))
	if str(obj.get("tag", "obj")) == "back":
		var spec: Dictionary = _back_kinds().get(str(obj.get("id", "")), {})
		var attrs: Dictionary = obj.get("attrs", {})
		var w := float(spec.get("x2", 1.0))
		var h := float(spec.get("y2", 1.0))
		if attrs.has("w"):
			w = absf(float(attrs.w))
		if attrs.has("h"):
			h = absf(float(attrs.h))
		return Rect2i(x, y, maxi(int(ceil(w)), 1), maxi(int(ceil(h)), 1))
	var meta := Palette.object_meta(str(obj.get("id", "")))
	var ww := int(obj.get("size", meta.get("size", 1)))
	var hh := int(obj.get("wid", obj.get("height", meta.get("wid", 1))))
	if typeof(obj.get("size", 1)) == TYPE_STRING:
		ww = int(str(obj.get("size", "1")))
	if typeof(obj.get("wid", obj.get("height", 1))) == TYPE_STRING:
		hh = int(str(obj.get("wid", obj.get("height", "1"))))
	if ww < 1:
		ww = int(meta.get("size", 1))
	if hh < 1:
		hh = int(meta.get("wid", 1))
	if ww < 1:
		ww = 1
	if hh < 1:
		hh = 1
	return Rect2i(x, y - (hh - 1), ww, hh)


static func paint_room_preview(canvas: CanvasItem, room: Dictionary, rect: Rect2, textured: bool) -> void:
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var zoom := minf(rect.size.x / (Codec.COLS * CELL), rect.size.y / (Codec.ROWS * CELL))
	var room_px := Vector2(Codec.COLS, Codec.ROWS) * CELL * zoom
	var pan := rect.position + (rect.size - room_px) * 0.5
	if not textured:
		_paint_plain(canvas, room, pan, zoom)
		return
	# Textures live only as long as the view's cache; draw commands need them until the frame renders.
	var view = canvas.get_meta("view") if canvas.has_meta("view") else null
	if view == null:
		view = load("res://scripts/editor/editor_view.gd").new()
		canvas.set_meta("view", view)
	var opt: Dictionary = room.get("options", {})
	var wall := str(opt.get("backwall", ""))
	if wall == "":
		wall = "tBackWall"
	view.rebuild(Codec.grid_from_rows(room.get("rows", [])), wall, int(str(opt.get("backform", "0"))), room)
	view.paint(canvas, pan, zoom, true, true, room)


static func _paint_plain(canvas: CanvasItem, room: Dictionary, pan: Vector2, zoom: float) -> void:
	var px := CELL * zoom
	canvas.draw_rect(Rect2(pan, Vector2(Codec.COLS, Codec.ROWS) * px), Color(0.08, 0.08, 0.08))
	var grid := Codec.grid_from_rows(room.get("rows", []))
	for y in Codec.ROWS:
		var row: Array = grid[y] if y < grid.size() else []
		for x in Codec.COLS:
			var cell: Dictionary = row[x] if x < row.size() else {}
			var at := Rect2(pan + Vector2(x, y) * px, Vector2(px, px))
			if str(cell.get("back", "")) != "":
				canvas.draw_rect(at, Color(0.25, 0.25, 0.3, 0.7))
			if str(cell.get("front", "")) != "":
				var h := 1.0 - int(cell.get("zform", 0)) * 0.25
				var block := at
				block.position.y += block.size.y * (1.0 - h)
				block.size.y *= h
				canvas.draw_rect(block, Color(0.45, 0.47, 0.5))
			if str(cell.get("water", "")) == "*":
				canvas.draw_rect(at, Color(0.2, 0.45, 0.8, 0.35))
	for obj_v in room.get("objs", []):
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		var foot := obj_rect(obj_v)
		if Forms.is_area(obj_v):
			continue
		var col := Color(0.3, 0.75, 0.95, 0.55) if str(obj_v.get("tag", "obj")) == "back" else Color(0.2, 0.9, 0.4, 0.5)
		canvas.draw_rect(Rect2(pan + Vector2(foot.position) * px, Vector2(foot.size) * px), col)
	paint_areas(canvas, pan, px, room, false)


static func paint_areas(c: CanvasItem, pan: Vector2, px: float, room: Dictionary, textured: bool) -> void:
	var font := ThemeDB.fallback_font
	for obj_v in room.get("objs", []):
		if typeof(obj_v) != TYPE_DICTIONARY or not Forms.is_area(obj_v):
			continue
		var obj: Dictionary = obj_v
		var rect := Forms.area_rect(obj)
		var box := Rect2(pan + Vector2(rect.position) * px, Vector2(rect.size) * px)
		var col: Color = Forms.area_color(obj)
		var vis := str((obj.get("attrs", {}) as Dictionary).get("vis", "")).strip_edges()
		var drew := false
		if textured and vis != "":
			var tex := Forms.vis_texture(vis)
			if tex != null:
				c.draw_texture_rect(tex, box, false)
				drew = true
		c.draw_rect(box, Color(col.r, col.g, col.b, 0.28))
		c.draw_rect(box, Color(col.r, col.g, col.b, 0.95), false, maxf(1.0, px * 0.08))
		if font == null:
			continue
		var label := Forms.area_label(obj)
		if textured and vis != "" and not drew:
			label = "%s (%s)" % [label, Locale.t("ed_area_noart")]
		c.draw_string(font, box.position + Vector2(2, minf(12.0, box.size.y - 1.0)), label, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 2.0, 10, col)


static func paint_minimap(canvas: CanvasItem, doc: Dictionary, rect: Rect2, selected: Vector2i, highlight_free: bool, zoom := 1.0, pan := Vector2.ZERO) -> void:
	canvas.draw_rect(rect, Color(0.05, 0.05, 0.08))
	var g := _mm_geom(doc, rect, zoom, pan)
	if not g.ok or not bool(doc.get("placed", false)):
		return
	var z0 := {}
	var z1 := {}
	for room_v in doc.get("rooms", []):
		if typeof(room_v) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = room_v
		if not room.has("x") or not room.has("y"):
			continue
		var at := Vector2i(int(room.x), int(room.y))
		if int(room.get("z", 0)) == 0:
			z0[at] = true
		else:
			z1[at] = true
	var cell: float = g.cell
	var origin: Vector2 = g.origin
	var minp: Vector2i = g.min
	for key in z0:
		var at: Vector2i = key
		var p := origin + Vector2(at - minp) * cell
		var col := Color("00ff99") if at == selected else Color("446688")
		canvas.draw_rect(Rect2(p, Vector2(cell - 1.0, cell - 1.0)), col)
	for key in z1:
		var at: Vector2i = key
		var p := origin + Vector2(at - minp) * cell
		var col := Color("66ffcc") if at == selected else Color("885533")
		var inset := cell * 0.22 if z0.has(at) else 0.0
		canvas.draw_rect(Rect2(p + Vector2(inset, inset), Vector2(cell - 1.0 - inset * 2.0, cell - 1.0 - inset * 2.0)), col)
	if not highlight_free:
		return
	var filled := {}
	for at in z0:
		filled[at] = true
	for at in z1:
		filled[at] = true
	var seen := {}
	for key in filled:
		var at: Vector2i = key
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = at + step
			if filled.has(n) or seen.has(n):
				continue
			seen[n] = true
			var p := origin + Vector2(n - minp) * cell
			canvas.draw_rect(Rect2(p, Vector2(cell - 1.0, cell - 1.0)), Color(1, 1, 1, 0.85), false, 1.0)


static func minimap_cell_rect(doc: Dictionary, rect: Rect2, cell: Vector2i, zoom := 1.0, pan := Vector2.ZERO) -> Rect2:
	var g := _mm_geom(doc, rect, zoom, pan)
	if not g.ok:
		return Rect2()
	var origin: Vector2 = g.origin
	var size: float = g.cell
	var minp: Vector2i = g.min
	var p := origin + Vector2(cell - minp) * size
	return Rect2(p, Vector2(size - 1.0, size - 1.0))


static func minimap_cell_at(doc: Dictionary, rect: Rect2, pos: Vector2, zoom := 1.0, pan := Vector2.ZERO) -> Vector2i:
	var g := _mm_geom(doc, rect, zoom, pan)
	if not g.ok or not bool(doc.get("placed", false)):
		return Vector2i(-1, -1)
	var local := pos - (g.origin as Vector2)
	var cell: float = g.cell
	if cell <= 0.0 or local.x < 0.0 or local.y < 0.0:
		return Vector2i(-1, -1)
	var minp: Vector2i = g.min
	var maxp: Vector2i = g.max
	var span := maxp - minp
	var at := Vector2i(int(floor(local.x / cell)), int(floor(local.y / cell)))
	if at.x < 0 or at.y < 0 or at.x > span.x or at.y > span.y:
		return Vector2i(-1, -1)
	return at + minp


static func _mm_geom(doc: Dictionary, rect: Rect2, zoom: float = 1.0, pan: Vector2 = Vector2.ZERO) -> Dictionary:
	var minx := 1 << 20
	var miny := 1 << 20
	var maxx := -(1 << 20)
	var maxy := -(1 << 20)
	var any := false
	for room_v in doc.get("rooms", []):
		if typeof(room_v) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = room_v
		if not room.has("x") or not room.has("y"):
			continue
		any = true
		minx = mini(minx, int(room.x))
		miny = mini(miny, int(room.y))
		maxx = maxi(maxx, int(room.x))
		maxy = maxi(maxy, int(room.y))
	if not any or rect.size.x < 1.0 or rect.size.y < 1.0:
		return {"ok": false}
	minx -= 1
	miny -= 1
	maxx += 1
	maxy += 1
	var span := Vector2i(maxx - minx + 1, maxy - miny + 1)
	var fit := minf(rect.size.x / float(span.x), rect.size.y / float(span.y))
	var z := zoom if zoom > 0.0 else 1.0
	var cell := fit * z
	var center := rect.position + Vector2(span) * fit * 0.5
	var origin := center - Vector2(span) * cell * 0.5 + pan
	return {"ok": true, "min": Vector2i(minx, miny), "max": Vector2i(maxx, maxy), "cell": cell, "origin": origin, "fit": fit}
