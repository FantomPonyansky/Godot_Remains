extends StaticBody2D

## One merged wall rect, with Tile.udar tracked per 40px cell.
## A hit is ignored when the cell is indestructible, or its threshold is
## above char_destroy, or the hit is 0 (EMP). Otherwise the full hit comes
## off that cell. At 0 the cell is no longer solid and no longer blocks sight.
## Pieces with a wall patch leave that patch (tilePieces leavesWall). Junk does not.
## Room-edge cells use the border rule: 10000 HP, indestructible, the border
## block's threshold. The drawn block stays the one the room placed.

const Catalog := preload("res://scripts/map/tile_catalog.gd")
const _ImpactFx := preload("res://scripts/impact_fx.gd")
const _RoomFlags := preload("res://scripts/map/room_flags.gd")
const _Outline := preload("res://scripts/map/tile_outline.gd")

const TILE := 40.0
const ROOM_W := 48
const ROOM_H := 25
## Grafon bakes decals into the wall bitmap. Here each is a node, so a span keeps its newest.
const MAX_DECALS := 96

static var _textures: Dictionary = {}


static func drop_cache() -> void:
	_textures.clear()

var _origin := Vector2.ZERO
var _tex_origin := Vector2.ZERO
var _cols := 0
var _rows := 0
var _cw: Array[float] = []
var _ch: Array[float] = []
var _hp: Array[int] = []
var _thre: Array[int] = []
var _hard: Array[bool] = []
var _alive: Array[bool] = []
## Tile.isFakeWall: Area tilehp <= 1 set it; the cell crumbles to dust.
var _fake: Array[bool] = []
var _mat := ""
var _block_tex: Texture2D
var _tint := Color(0.46, 0.47, 0.43)
var _wall_tex: Texture2D
var _pending := false
var _decals: Array[Dictionary] = []
var _decal_host: Control
## Cells broken since the last rebuild, by index, with the E_Decal that broke them.
var _fresh: Dictionary = {}
var _tip := 0


static func attach(body: StaticBody2D, code: String, border: String) -> void:
	if Catalog.wall_of(code).is_empty():
		return
	body.set_script(load("res://scripts/wall_span.gd"))
	body.call("bind_grid", code, border)


func bind_grid(code: String, border: String) -> void:
	var stats := Catalog.wall_of(code)
	if stats.is_empty():
		return
	var shape := _shape()
	if shape == null or not (shape.shape is RectangleShape2D):
		return
	var size := (shape.shape as RectangleShape2D).size
	_origin = to_global(shape.position - size * 0.5)
	_tex_origin = _origin
	_grab_art()
	_wall_tex = _texture(str(stats.wall))
	_mat = str(stats.mat)
	set_meta("surface", _mat)
	set_meta("code", str(stats.letter))
	var border_stats := Catalog.wall_of(border)
	_slice(size)
	var n := _cols * _rows
	_hp.resize(n)
	_thre.resize(n)
	_hard.resize(n)
	_alive.resize(n)
	_fake.resize(n)
	var breakable := false
	for cy in _rows:
		for cx in _cols:
			var i := cy * _cols + cx
			var rect := _cell_rect(cx, cy)
			var hard := bool(stats.indestruct)
			var hp := int(stats.hp)
			var thre := int(stats.thre)
			if _on_edge(rect) and not border_stats.is_empty():
				hard = true
				hp = 10000
				thre = int(border_stats.thre)
			_hp[i] = hp
			_thre[i] = thre
			_hard[i] = hard
			_alive[i] = true
			if not hard:
				breakable = true
	var full := size.x >= TILE - 1.5 and size.y >= TILE - 1.5
	set_meta("blocks_sight", full)
	if breakable:
		add_to_group("destructibles")


func take_hit(amount: int = 0, type: String = "") -> void:
	if _cols == 0:
		return
	var cell := _cell_at(_impact_point())
	if _hurt(cell.x, cell.y, amount, type):
		_schedule()


## Location.hitTile for one shot or blow at a point: damage the cell, then the
## hole Grafon.dyrka leaves. A hit the cell shrugs off leaves the soft mark.
func hit_tile(at: Vector2, hit: int, type: String, tip: int) -> void:
	if _cols == 0:
		return
	var cell := _cell_at(at)
	_hit_cell(cell.x, cell.y, at, hit, type, tip)


## Bullet.explDestroy: every tile whose center lies inside the disk, once, no falloff.
## tip is the shot's E_Decal; 0 leaves no marks.
func apply_blast(amount: int, type: String, center: Vector2, radius: float, tip: int = 0) -> void:
	if _cols == 0 or radius <= 0.0:
		return
	var reach := radius * radius
	var broke := false
	for cy in _rows:
		for cx in _cols:
			var at := _center(cx, cy)
			if at.distance_squared_to(center) >= reach:
				continue
			if tip > 0:
				broke = _hit_cell(cx, cy, at, amount, type, tip) or broke
			elif _hurt(cx, cy, amount, type):
				broke = true
	if broke:
		_schedule()


func _hit_cell(cx: int, cy: int, at: Vector2, hit: int, type: String, tip: int) -> bool:
	var i := cy * _cols + cx
	if not _alive[i]:
		return false
	var ver := float(hit) / maxf(float(_hp[i]), 1.0)
	var mat := _ImpactFx.surface(_mat)
	var lands := not _hard[i] and _thre[i] <= hit and hit > 0 and type != "DAM_EMP" and not _des_off(i, at)
	if not lands:
		_ImpactFx.dyrka(self, at, tip, mat, true, ver)
		return false
	_tip = tip
	var broke := _hurt(cx, cy, hit, type)
	_tip = 0
	if broke:
		_schedule()
		return true
	_ImpactFx.dyrka(self, at, tip, mat, false, ver)
	return false


func decal_rect() -> Rect2:
	if _cols == 0:
		return Rect2()
	return Rect2(_origin, _span_size())


func add_decal(rec: Dictionary) -> void:
	if _cols == 0:
		return
	var host := _decal_layer()
	if _decals.size() >= MAX_DECALS:
		_decals.pop_front()
		if host.get_child_count() > 0:
			host.get_child(0).free()
	_decals.append(rec)
	var node := _ImpactFx.build(rec, _wall_tex)
	node.position = (rec.at as Vector2) - _origin
	host.add_child(node)


func _decal_layer() -> Control:
	if _decal_host == null or not is_instance_valid(_decal_host):
		_decal_host = Control.new()
		_decal_host.name = "Decals"
		_decal_host.clip_contents = true
		_decal_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_decal_host.position = to_local(_origin)
		_decal_host.size = _span_size()
		add_child(_decal_host)
	return _decal_host


## Location.hitTile: under @desoff a tile over 500 hp only takes a dent.
func _des_off(i: int, at: Vector2) -> bool:
	return _hp[i] > 500 and not _RoomFlags.allows("destroy", at)


## Area tilehp / tilethre on the cell at a world point (-1 leaves a stat alone).
func set_cell_stats(world: Vector2, hp: int, thre: int) -> void:
	if _cols == 0:
		return
	var c := _cell_at(world)
	var i := c.y * _cols + c.x
	if not _alive[i]:
		return
	if hp >= 0:
		_hp[i] = hp
		_hard[i] = false
		_thre[i] = mini(_thre[i], hp)
		if hp <= 1:
			_fake[i] = true
	if thre >= 0:
		_hard[i] = false
		_thre[i] = thre
	add_to_group("destructibles")


func _hurt(cx: int, cy: int, amount: int, type: String) -> bool:
	if cx < 0 or cy < 0 or cx >= _cols or cy >= _rows:
		return false
	var i := cy * _cols + cx
	if not _alive[i] or _hard[i]:
		return false
	var hit := amount
	if type == "DAM_EMP":
		hit = 0
	if _thre[i] > hit or hit <= 0 or _des_off(i, _center(cx, cy)):
		return false
	_hp[i] -= hit
	if _hp[i] > 0:
		return false
	_hp[i] = 0
	_alive[i] = false
	_fresh[i] = _tip
	if is_inside_tree():
		get_tree().call_group("fog", "mark_dirty", _cell_rect(cx, cy))
		get_tree().call_group("land_props", "note_broken", _cell_rect(cx, cy))
	return true


func covers(world: Vector2) -> bool:
	if _cols == 0:
		return false
	var width := 0.0
	for dw in _cw:
		width += dw
	var height := 0.0
	for dh in _ch:
		height += dh
	return Rect2(_origin, Vector2(width, height)).has_point(world)


## A saved broken cell (land_memory.gd). The fog hears of it a frame later,
## once it is looking at this land.
func break_at(world: Vector2) -> void:
	if _cols == 0:
		return
	var cell := _cell_at(world)
	var i := cell.y * _cols + cell.x
	if not _alive[i]:
		return
	_hp[i] = 0
	_alive[i] = false
	_mark_fog.call_deferred(_cell_rect(cell.x, cell.y))
	_schedule()


## Tile.collision of the cell under a world point (false outside the span).
func solid_at(world: Vector2) -> bool:
	if _cols == 0 or not covers(world):
		return false
	var cell := _cell_at(world)
	return bool(_alive[cell.y * _cols + cell.x])


func _mark_fog(rect: Rect2) -> void:
	if is_inside_tree():
		get_tree().call_group("fog", "mark_dirty", rect)


func _schedule() -> void:
	if _pending:
		return
	_pending = true
	call_deferred("_rebuild")


func _rebuild() -> void:
	if _cols == 0 or not is_inside_tree():
		return
	var live: Array[Dictionary] = []
	var broken: Array[Vector2] = []
	var broken_tip: Array[int] = []
	var broken_fake: Array[bool] = []
	for cy in _rows:
		for cx in _cols:
			var rect := _cell_rect(cx, cy)
			var i := cy * _cols + cx
			if not _alive[i]:
				_Outline.cell_gone(rect.get_center())
				_leave_patch(rect)
				if _fresh.has(i):
					broken.append(rect.get_center())
					broken_tip.append(int(_fresh[i]))
					broken_fake.append(_fake[i])
				continue
			live.append({
				"x": rect.position.x,
				"y": rect.position.y,
				"w": rect.size.x,
				"h": rect.size.y,
				"hp": _hp[i],
				"thre": _thre[i],
				"hard": _hard[i],
				"fake": _fake[i],
			})
	_cols = 0
	collision_layer = 0
	set_meta("blocks_sight", false)
	set_meta("dead", true)
	var shape := _shape()
	if shape:
		shape.set_deferred("disabled", true)
	var art := _art()
	if art:
		art.visible = false
	remove_from_group("destructibles")
	remove_from_group(_Outline.GROUP)
	var parent := get_parent()
	if parent and not live.is_empty():
		var spawned: Array[Node] = []
		for rect_v in _mesh(live):
			spawned.append(_spawn(parent, rect_v))
		for rec in _decals:
			var area := _ImpactFx.reach(rec)
			for body in spawned:
				if body.call("decal_rect").intersects(area):
					body.call("add_decal", rec)
	if parent:
		_Outline.refresh(get_tree(), broken)
		var mat := _ImpactFx.surface(_mat)
		for k in broken.size():
			_ImpactFx.tile_die(self, broken[k], broken_tip[k], mat, broken_fake[k])
	queue_free()


func _spawn(parent: Node, rect: Dictionary) -> Node:
	var body := StaticBody2D.new()
	body.set_script(get_script())
	body.collision_layer = 1
	body.collision_mask = 0
	var origin := Vector2(float(rect.x), float(rect.y))
	body.position = parent.to_local(origin) if parent is Node2D else origin
	body.set_meta("code", get_meta("code", ""))
	parent.add_child(body)
	body.call("adopt", rect, _block_tex, _tint, _wall_tex, _mat, _tex_origin)
	return body


func adopt(rect: Dictionary, block_tex: Texture2D, tint: Color, wall_tex: Texture2D, mat: String, tex_origin: Vector2) -> void:
	_block_tex = block_tex
	_tint = tint
	_wall_tex = wall_tex
	_mat = mat
	_tex_origin = tex_origin
	set_meta("surface", mat)
	var cols := int(rect.w)
	var rows := int(rect.h)
	var cw := float(rect.cw)
	var ch := float(rect.ch)
	_cols = cols
	_rows = rows
	_cw = []
	_ch = []
	_cw.resize(cols)
	_ch.resize(rows)
	_cw.fill(cw)
	_ch.fill(ch)
	var size := Vector2(cw * float(cols), ch * float(rows))
	_origin = to_global(Vector2.ZERO)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	shape.position = size * 0.5
	add_child(shape)
	var phase := _origin - _tex_origin
	if _block_tex:
		var visual := _tiled(_block_tex, size, phase)
		add_child(visual)
		_Outline.dress(self, visual, str(get_meta("code", "")), size)
	else:
		var poly := Polygon2D.new()
		poly.name = "Visual"
		poly.color = _tint
		poly.polygon = PackedVector2Array([
			Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)
		])
		add_child(poly)
	var n := cols * rows
	_hp.resize(n)
	_thre.resize(n)
	_hard.resize(n)
	_alive.resize(n)
	_fake.resize(n)
	var breakable := false
	for cell_v in rect.cells:
		var cell: Dictionary = cell_v
		var cx := int(round((float(cell.x) - float(rect.x)) / cw))
		var cy := int(round((float(cell.y) - float(rect.y)) / ch))
		cx = clampi(cx, 0, cols - 1)
		cy = clampi(cy, 0, rows - 1)
		var i := cy * cols + cx
		_hp[i] = int(cell.hp)
		_thre[i] = int(cell.thre)
		_hard[i] = bool(cell.hard)
		_fake[i] = bool(cell.get("fake", false))
		_alive[i] = true
		if not _hard[i]:
			breakable = true
	var full := cw >= TILE - 1.5 and ch >= TILE - 1.5
	set_meta("blocks_sight", full)
	if breakable:
		add_to_group("destructibles")


func _slice(size: Vector2) -> void:
	_cw = []
	_ch = []
	var x := 0.0
	while x < size.x - 0.5:
		var dw := minf(TILE, size.x - x)
		_cw.append(dw)
		x += dw
	var y := 0.0
	while y < size.y - 0.5:
		var dh := minf(TILE, size.y - y)
		_ch.append(dh)
		y += dh
	_cols = _cw.size()
	_rows = _ch.size()


func _cell_rect(cx: int, cy: int) -> Rect2:
	var x := _origin.x
	for i in cx:
		x += _cw[i]
	var y := _origin.y
	for i in cy:
		y += _ch[i]
	return Rect2(Vector2(x, y), Vector2(_cw[cx], _ch[cy]))


func _center(cx: int, cy: int) -> Vector2:
	return _cell_rect(cx, cy).get_center()


func _cell_at(world: Vector2) -> Vector2i:
	var local := world - _origin
	var width := 0.0
	for dw in _cw:
		width += dw
	var height := 0.0
	for dh in _ch:
		height += dh
	local.x = clampf(local.x, 0.0, maxf(width - 0.01, 0.0))
	local.y = clampf(local.y, 0.0, maxf(height - 0.01, 0.0))
	return Vector2i(
		clampi(int(floor(local.x / TILE)), 0, _cols - 1),
		clampi(int(floor(local.y / TILE)), 0, _rows - 1)
	)


func _on_edge(rect: Rect2) -> bool:
	var tx := int(floor((rect.position.x + rect.size.x * 0.5) / TILE))
	var ty := int(floor((rect.position.y + rect.size.y * 0.5) / TILE))
	var cx := posmod(tx, ROOM_W)
	var cy := posmod(ty, ROOM_H)
	return cx == 0 or cx == ROOM_W - 1 or cy == 0 or cy == ROOM_H - 1


func _impact_point() -> Vector2:
	if has_meta("hit_at"):
		var at: Variant = get_meta("hit_at")
		remove_meta("hit_at")
		if at is Vector2:
			return at
	var rect := Rect2(_origin, _span_size())
	var tree := get_tree()
	if tree == null:
		return rect.get_center()
	for node in tree.get_nodes_in_group("enemies"):
		var ray := node.get_node_or_null("WallCheck") as RayCast2D
		if ray and ray.is_colliding() and ray.get_collider() == self:
			return ray.get_collision_point()
	var player := tree.get_first_node_in_group("player") as Node2D
	if player:
		var aimed := _player_aim(player, rect)
		if aimed != Vector2.INF:
			return aimed
		return Vector2(
			clampf(player.global_position.x, rect.position.x, rect.end.x - 0.01),
			clampf(player.global_position.y, rect.position.y, rect.end.y - 0.01)
		)
	return rect.get_center()


func _player_aim(player: Node2D, rect: Rect2) -> Vector2:
	var aim: Variant = player.get("aim_dir")
	var origin := player.global_position + Vector2(0.0, -36.0)
	if aim is Vector2 and (aim as Vector2).length_squared() > 0.01:
		var hit: Variant = _ray_rect(origin, aim as Vector2, rect)
		if hit is Vector2 and origin.distance_to(hit) <= 180.0:
			return hit
	var facing := 1.0
	var face: Variant = player.get("facing")
	if face != null and float(face) < 0.0:
		facing = -1.0
	var hoof: Variant = _ray_rect(player.global_position + Vector2(0.0, -30.0), Vector2(facing, 0.0), rect)
	if hoof is Vector2:
		return hoof
	return Vector2.INF


func _ray_rect(origin: Vector2, dir: Vector2, rect: Rect2) -> Variant:
	if dir.length_squared() < 0.0001:
		return null
	dir = dir.normalized()
	var tmin := 0.0
	var tmax := 4000.0
	if absf(dir.x) < 0.00001:
		if origin.x < rect.position.x or origin.x > rect.end.x:
			return null
	else:
		var inv_x := 1.0 / dir.x
		var tx1 := (rect.position.x - origin.x) * inv_x
		var tx2 := (rect.end.x - origin.x) * inv_x
		tmin = maxf(tmin, minf(tx1, tx2))
		tmax = minf(tmax, maxf(tx1, tx2))
	if absf(dir.y) < 0.00001:
		if origin.y < rect.position.y or origin.y > rect.end.y:
			return null
	else:
		var inv_y := 1.0 / dir.y
		var ty1 := (rect.position.y - origin.y) * inv_y
		var ty2 := (rect.end.y - origin.y) * inv_y
		tmin = maxf(tmin, minf(ty1, ty2))
		tmax = minf(tmax, maxf(ty1, ty2))
	if tmin > tmax or tmax < 0.0:
		return null
	var t := tmin if tmin >= 0.0 else tmax
	if t < 0.0:
		return null
	return origin + dir * t


func _span_size() -> Vector2:
	var w := 0.0
	for dw in _cw:
		w += dw
	var h := 0.0
	for dh in _ch:
		h += dh
	return Vector2(w, h)


func _leave_patch(rect: Rect2) -> void:
	if _wall_tex == null or rect.size.y < TILE - 1.5 or rect.size.x < TILE - 1.5:
		return
	var host := _dressing()
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = _wall_tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = -8
	sprite.set_meta("blocks_sight", false)
	var tw := float(_wall_tex.get_width())
	var th := float(_wall_tex.get_height())
	if tw >= 1.0 and th >= 1.0:
		sprite.region_enabled = true
		sprite.region_rect = Rect2(
			fposmod(rect.position.x, tw), fposmod(rect.position.y, th),
			minf(rect.size.x, tw), minf(rect.size.y, th)
		)
	sprite.position = host.to_local(rect.position) if host is Node2D else rect.position
	host.add_child(sprite)


func _dressing() -> Node:
	var solids := get_parent()
	if solids == null:
		return self
	var land := solids.get_parent()
	if land == null:
		return solids
	var dress := land.get_node_or_null("RoomDressing")
	return dress if dress else solids


func _mesh(cells: Array[Dictionary]) -> Array:
	var remaining := {}
	for cell in cells:
		remaining[Vector2i(int(round(float(cell.x))), int(round(float(cell.y))))] = cell
	var keys: Array = remaining.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	var rects: Array = []
	for key in keys:
		if not remaining.has(key):
			continue
		var sample: Dictionary = remaining[key]
		remaining.erase(key)
		var span: Array[Dictionary] = [sample]
		var cw := float(sample.w)
		var ch := float(sample.h)
		var w := 1
		while true:
			var nxt_key := Vector2i(int(round(float(sample.x) + cw * float(w))), int(round(float(sample.y))))
			if not remaining.has(nxt_key):
				break
			var nxt: Dictionary = remaining[nxt_key]
			if absf(float(nxt.w) - cw) > 0.5 or absf(float(nxt.h) - ch) > 0.5:
				break
			span.append(nxt)
			remaining.erase(nxt_key)
			w += 1
		var h := 1
		while true:
			var row: Array[Dictionary] = []
			var ok := true
			for dx in w:
				var nxt_key := Vector2i(
					int(round(float(sample.x) + cw * float(dx))),
					int(round(float(sample.y) + ch * float(h)))
				)
				if not remaining.has(nxt_key):
					ok = false
					break
				var nxt: Dictionary = remaining[nxt_key]
				if absf(float(nxt.w) - cw) > 0.5 or absf(float(nxt.h) - ch) > 0.5:
					ok = false
					break
				row.append(nxt)
			if not ok:
				break
			for dx in w:
				remaining.erase(Vector2i(
					int(round(float(sample.x) + cw * float(dx))),
					int(round(float(sample.y) + ch * float(h)))
				))
			span.append_array(row)
			h += 1
		rects.append({
			"x": sample.x, "y": sample.y, "w": w, "h": h,
			"cw": cw, "ch": ch, "cells": span,
		})
	return rects


func _tiled(texture: Texture2D, size: Vector2, phase: Vector2) -> Node2D:
	var root := Node2D.new()
	root.name = "Visual"
	var tw := float(texture.get_width())
	var th := float(texture.get_height())
	if tw < 1.0 or th < 1.0:
		return root
	var y := 0.0
	while y < size.y - 0.5:
		var src_y := fposmod(phase.y + y, th)
		var dh := minf(th - src_y, size.y - y)
		var x := 0.0
		while x < size.x - 0.5:
			var src_x := fposmod(phase.x + x, tw)
			var dw := minf(tw - src_x, size.x - x)
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.region_enabled = true
			sprite.region_rect = Rect2(src_x, src_y, dw, dh)
			sprite.position = Vector2(x, y)
			root.add_child(sprite)
			x += dw
		y += dh
	return root


func _grab_art() -> void:
	var art := _art()
	if art is Polygon2D:
		_tint = (art as Polygon2D).color
		return
	if art is Sprite2D and (art as Sprite2D).texture:
		_block_tex = (art as Sprite2D).texture
		return
	if art == null:
		return
	for child in art.get_children():
		if child is Sprite2D and (child as Sprite2D).texture:
			_block_tex = (child as Sprite2D).texture
			return
		if child is Polygon2D:
			_tint = (child as Polygon2D).color
			return


func _shape() -> CollisionShape2D:
	for child in get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
			return child
	return null


func _art() -> Node2D:
	for child in get_children():
		if child is CollisionShape2D:
			continue
		if child is Node2D:
			return child
	return null


static func _texture(name: String) -> Texture2D:
	if name == "":
		return null
	if _textures.has(name):
		return _textures[name] as Texture2D
	var path := Catalog.file_for(name)
	var tex: Texture2D = load(path) if path != "" else null
	_textures[name] = tex
	return tex
