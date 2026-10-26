extends RefCounted

## Grafon.drawTileSprite for front blocks: each material's texture shows through
## a per-tile mask (four quarter clips, frame from Location.insKontur), its edge
## texture through a second mask, and mats.xml's filter darkens the composite.
## Neighbours count as solid when collision == 1, a door, or outside the rooms
## (Location.uslKontur). Masks are built at half size, with a margin that
## records solid neighbours so the edge shading does not show at span seams.

const TILE := 40.0
const SCALE := 0.5
const MARGIN := 20.0
const DIR := "res://assets/sprites/tiles/masks/"
const SHADER := preload("res://assets/shaders/tile_outline.gdshader")

## mats.xml main mask, edge texture, edge mask, filter.
const MATS := {
	"A": ["", "tKlep", "maskSimple", "cont"],
	"B": ["maskBare", "tBorder", "maskBorderBare", "potek"],
	"C": ["maskBare", "tBorder", "maskBorderBare", ""],
	"D": ["maskDamaged", "tSkol", "maskSkol", "potek"],
	"E": ["maskDamaged", "tSkol", "maskSkol", "potek"],
	"F": ["maskDamaged", "", "", "cont_th"],
	"G": ["maskStone", "tSkol", "maskStoneBorder", ""],
	"H": ["maskDirt", "tDirt2", "maskDirtBorder", "potek"],
	"I": ["maskBare", "", "", ""],
	"J": ["", "tKlep2", "maskMetalBorder", "cont_metal"],
	"K": ["", "", "", "cont_metal"],
	"L": ["maskDirt", "tMoss", "maskDirtBorder", "potek"],
	"M": ["", "tKlep", "maskSimple", "cont"],
	"N": ["maskDirt", "tConRough", "maskDirtBorder", ""],
	"O": ["", "tKlep2", "maskMetalBorder", "cont_metal"],
	"P": ["maskBare", "", "", ""],
	"Q": ["maskBare", "tBorder", "maskBorderBare", ""],
	"R": ["maskDirt", "", "", "potek"],
	"S": ["", "tKlep3", "maskMetalBorder", "cont_metal"],
	"T": ["", "tKlep3", "maskMetalBorder", "cont_metal"],
}

## TilePieceTextures.FILTERS as inner glows (px, alpha) x2 and the potek bevel
## (px, alpha) that shades under open tops.
const FILTERS := {
	"potek": [2.0, 1.0, 0.0, 0.0, 10.0, 0.5],
	"cont": [15.0, 0.8, 0.0, 0.0, 0.0, 0.0],
	"cont_th": [5.0, 0.8, 2.0, 1.0, 0.0, 0.0],
	"cont_metal": [2.0, 1.0, 15.0, 0.8, 0.0, 0.0],
}

const GROUP := "tile_outline"

## Vector2i cell -> true when solid. Cells missing from both maps are outside the rooms.
static var solid := {}
static var inside := {}
static var land: Node2D
static var _pieces := {}
static var _full: Image


static func begin(land_node: Node2D, solids: Dictionary, doors: Dictionary, rooms: Array, cols: int, rows: int) -> void:
	land = land_node
	solid = {}
	inside = {}
	for room_v in rooms:
		var room: Dictionary = room_v
		var ox := int(room.x) * cols
		var oy := int(room.y) * rows
		for j in rows:
			for i in cols:
				inside[Vector2i(ox + i, oy + j)] = true
	for at in solids:
		solid[at] = true
	for at in doors:
		solid[at] = true
	land_node.set_meta("ol_state", [solid, inside])


## Lands stay cached while away; the shown land brings its own cell maps back.
static func use(land_node: Node) -> void:
	if land_node == null or not land_node.has_meta("ol_state"):
		return
	var state: Array = land_node.get_meta("ol_state")
	land = land_node as Node2D
	solid = state[0]
	inside = state[1]


static func _is_solid(at: Vector2i) -> bool:
	return solid.has(at) or not inside.has(at)


## Location.insKontur: a = the vertical neighbour, b = the side one, c = the diagonal.
static func _kontur(a: bool, b: bool, c: bool) -> int:
	if a and b:
		return 0 if c else 1
	if b:
		return 2
	if a:
		return 3
	return 4


static func _piece(mask: String, q: int, k: int) -> Image:
	var key := "%s/%d_%d" % [mask, q, k]
	if _pieces.has(key):
		return _pieces[key]
	var img: Image = null
	var tex := load(DIR + mask + "/%d_%d.png" % [q, k]) as Texture2D
	if tex != null:
		var src := tex.get_image()
		if src.is_compressed():
			src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		var ox := 20 + (q % 2) * 20
		var oy := 20 + (q / 2) * 20
		img = Image.create(20, 20, false, Image.FORMAT_L8)
		for y in 20:
			for x in 20:
				var a := src.get_pixel(ox + x, oy + y).a
				img.set_pixel(x, y, Color(a, a, a))
		img.resize(int(20 * SCALE), int(20 * SCALE), Image.INTERPOLATE_BILINEAR)
	_pieces[key] = img
	return img


static func _full_piece() -> Image:
	if _full == null:
		_full = Image.create(int(20 * SCALE), int(20 * SCALE), false, Image.FORMAT_L8)
		_full.fill(Color.WHITE)
	return _full


## Masks the body's tiled art and adds the edge texture. art is the node
## holding the tiled sprites; size is the drawn rect from the body origin.
static func dress(body: Node2D, art: Node2D, letter: String, size: Vector2) -> void:
	if land == null or not is_instance_valid(land) or not MATS.has(letter) or art == null:
		return
	if size.x < 1.0 or size.y < 1.0:
		return
	var row: Array = MATS[letter]
	body.set_meta("ol_letter", letter)
	body.set_meta("ol_size", size)
	body.set_meta("ol_art", art)
	if not body.is_in_group(GROUP):
		body.add_to_group(GROUP)
	var masks := _build(body, str(row[0]), str(row[2]), size)
	var origin := body.global_position - Vector2(MARGIN, MARGIN)
	var span := size + Vector2(MARGIN, MARGIN) * 2.0
	var filt: Array = FILTERS.get(str(row[3]), [0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var mat := art.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		art.material = mat
		for child in art.get_children():
			if child is CanvasItem:
				(child as CanvasItem).use_parent_material = true
	_set_uniforms(mat, masks, origin, span, filt, 0)
	var edge_name := str(row[1])
	var edge := body.get_node_or_null("OutlineEdge") as Node2D
	if edge_name == "":
		return
	if edge == null:
		var tex := _texture(edge_name)
		if tex == null:
			return
		edge = _tiled(tex, size, body.global_position)
		edge.name = "OutlineEdge"
		edge.material = ShaderMaterial.new()
		(edge.material as ShaderMaterial).shader = SHADER
		body.add_child(edge)
		body.move_child(edge, art.get_index() + 1)
	_set_uniforms(edge.material as ShaderMaterial, masks, origin, span, filt, 1)


static func _set_uniforms(mat: ShaderMaterial, masks: Array, origin: Vector2, span: Vector2, filt: Array, mode: int) -> void:
	mat.set_shader_parameter("main_mask", masks[0])
	mat.set_shader_parameter("edge_mask", masks[1])
	mat.set_shader_parameter("mask_origin", origin)
	mat.set_shader_parameter("mask_size", span)
	mat.set_shader_parameter("glow", Vector4(float(filt[0]), float(filt[1]), float(filt[2]), float(filt[3])))
	mat.set_shader_parameter("bevel", Vector2(float(filt[4]), float(filt[5])))
	mat.set_shader_parameter("mode", mode)


static func _build(body: Node2D, main: String, edge: String, size: Vector2) -> Array:
	var local := land.to_local(body.global_position)
	var c0 := Vector2i(floori((local.x + 0.5) / TILE), floori((local.y + 0.5) / TILE))
	var cols := maxi(1, roundi(size.x / TILE))
	var rows := maxi(1, roundi(size.y / TILE)) if size.y >= TILE - 1.5 else 1
	var cw := size.x / float(cols)
	var ch := size.y / float(rows)
	var w := int(ceil((size.x + MARGIN * 2.0) * SCALE))
	var h := int(ceil((size.y + MARGIN * 2.0) * SCALE))
	var img_main := Image.create(w, h, false, Image.FORMAT_L8)
	var img_edge := Image.create(w, h, false, Image.FORMAT_L8)
	var m := MARGIN * SCALE
	for j in range(-1, rows + 1):
		for i in range(-1, cols + 1):
			if i >= 0 and i < cols and j >= 0 and j < rows:
				continue
			if not _is_solid(c0 + Vector2i(i, j)):
				continue
			var px := m + float(i) * cw * SCALE
			var py := m + float(j) * ch * SCALE
			if j < 0:
				py = m - TILE * SCALE
			img_main.fill_rect(Rect2i(int(px), int(py), int(ceil(cw * SCALE)), int(ceil((TILE if j < 0 or j >= rows else ch) * SCALE))), Color.WHITE)
	img_main.fill_rect(Rect2i(int(m), int(m), int(ceil(size.x * SCALE)), int(ceil(size.y * SCALE))), Color.WHITE)
	for j in rows:
		for i in cols:
			var at := c0 + Vector2i(i, j)
			if (j > 0 and j < rows - 1 and i > 0 and i < cols - 1) or (_is_solid(at + Vector2i(-1, -1)) and _is_solid(at + Vector2i(1, 1)) and _is_solid(at + Vector2i(1, -1)) and _is_solid(at + Vector2i(-1, 1)) and _is_solid(at + Vector2i(0, -1)) and _is_solid(at + Vector2i(0, 1)) and _is_solid(at + Vector2i(-1, 0)) and _is_solid(at + Vector2i(1, 0))):
				continue
			var a0 := _is_solid(at + Vector2i(-1, -1))
			var a1 := _is_solid(at + Vector2i(0, -1))
			var a2 := _is_solid(at + Vector2i(1, -1))
			var a3 := _is_solid(at + Vector2i(1, 0))
			var a4 := _is_solid(at + Vector2i(1, 1))
			var a5 := _is_solid(at + Vector2i(0, 1))
			var a6 := _is_solid(at + Vector2i(-1, 1))
			var a7 := _is_solid(at + Vector2i(-1, 0))
			var ks := [_kontur(a1, a7, a0), _kontur(a1, a3, a2), _kontur(a5, a7, a6), _kontur(a5, a3, a4)]
			var px := m + float(i) * cw * SCALE
			var py := m + float(j) * ch * SCALE
			for q in 4:
				var k: int = ks[q]
				var dst := Vector2i(int(px + (q % 2) * cw * 0.5 * SCALE), int(py + (q / 2) * ch * 0.5 * SCALE))
				var mp: Image = _full_piece() if main == "" else _piece(main, q, k)
				_put(img_main, mp, dst, ch)
				if edge != "":
					var ep := _piece(edge, q, k)
					_put(img_edge, ep, dst, ch)
	return [ImageTexture.create_from_image(img_main), ImageTexture.create_from_image(img_edge)]


## Lowered tiles squash the clip to the block's height (Grafon mc.scaleY).
static func _put(dst: Image, piece: Image, at: Vector2i, ch: float) -> void:
	if piece == null:
		return
	var src := piece
	var want_h := maxi(1, int(round(ch * 0.5 * SCALE)))
	if want_h != src.get_height():
		src = piece.duplicate() as Image
		src.resize(src.get_width(), want_h, Image.INTERPOLATE_BILINEAR)
	dst.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)


## A cell broke: it no longer counts as solid, and the spans next to it redraw.
static func cell_gone(world: Vector2) -> void:
	if land == null or not is_instance_valid(land):
		return
	var local := land.to_local(world)
	solid.erase(Vector2i(floori(local.x / TILE), floori(local.y / TILE)))


static func refresh(tree: SceneTree, near: Array) -> void:
	if land == null or not is_instance_valid(land) or near.is_empty():
		return
	for node in tree.get_nodes_in_group(GROUP):
		var body := node as Node2D
		if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		var size: Vector2 = body.get_meta("ol_size", Vector2.ZERO)
		var rect := Rect2(body.global_position - Vector2(TILE, TILE), size + Vector2(TILE, TILE) * 2.0)
		for p in near:
			if rect.has_point(p):
				var art = body.get_meta("ol_art", null)
				if art is Node2D and is_instance_valid(art):
					dress(body, art, str(body.get_meta("ol_letter")), size)
				break


static var _tex := {}


static func drop_cache() -> void:
	_tex.clear()


static func _texture(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := "res://assets/sprites/tiles/%s.png" % name
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[name] = t
	return t


## Edge textures are laid from the land origin, as Grafon fills them per room.
static func _tiled(texture: Texture2D, size: Vector2, world: Vector2) -> Node2D:
	var root := Node2D.new()
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	var phase := land.to_local(world) if land != null else world
	sprite.region_rect = Rect2(phase, size)
	sprite.use_parent_material = true
	root.add_child(sprite)
	return root
