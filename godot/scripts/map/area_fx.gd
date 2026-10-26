extends Node2D

## Area.as effects of one land area (land_props._spawn_areas):
## - tilehp / tilethre: Tile.hp (indestructible off, threshold capped at hp) and
##   damageThreshold on every tile under the area.
## - tileop: Tile.opacity of the tiles without collision, for the fog.
## - grav: setLift, Tile.gravity of the tiles while the area is enabled.
## - emit + dens: Emitter cast over the area, frec = dens * rx * ry / 100 per tick,
##   while the area's room is the player's.
## - port "X:Y": the player entering goes to ((X + 1) * 40, (Y + 1) * 40 - 1) of
##   the room unless that spot collides.
## - norad: the player inside takes no radiation.
## - vis: visArea art at the area's size, screen blended, alpha 0.1 while off.

const TPS := 30.0
const TILE := 40.0
const ROOM_PX := Vector2(1920, 1000)
const ART := "res://assets/sprites/areas/"
const KEYS := ["tilehp", "tilethre", "tileop", "grav", "emit", "port", "norad", "vis"]
## parts.xml purple_spark: vis purple_spark, alph, minliv 40, rsc 0.7, screen.
const SPARK_LIV := 40
const SPARK_RSC := 0.7
const _Flags := preload("res://scripts/map/room_flags.gd")
const _UnitFx := preload("res://scripts/units/unit_fx.gd")

static var _anchors: Dictionary = {}
static var _add: CanvasItemMaterial

var area: Area2D
var land: Node
var rect := Rect2()
var room := Vector2i.ZERO
var lift := 1.0
var emit_id := ""
var frec := 0.0
var port := Vector2.INF
var no_rad := false
var _cells: Array = []
var _t_frec := 0.0
var _acc := 0.0
var _enabled := true
var _inside := false
var _vis: Sprite2D
var _sparks: Array = []
var _spark_tex: Texture2D
## Walls take the tile stats on the first physics tick, once their bodies are in the space.
var _tile_stats: Array = []


static func wants(attrs: Dictionary) -> bool:
	for key in KEYS:
		if attrs.has(key):
			return true
	return false


func setup(host: Area2D, row: Dictionary, attrs: Dictionary, owner_land: Node) -> void:
	area = host
	land = owner_land
	var r: Array = row.get("rect", [0, 0, 40, 40])
	rect = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var rm: Array = row.get("room", [0, 0])
	room = Vector2i(int(rm[0]), int(rm[1])) if rm.size() > 1 else _Flags.cell_of(rect.get_center())
	for j in range(floori(rect.position.y / TILE), ceili(rect.end.y / TILE)):
		for i in range(floori(rect.position.x / TILE), ceili(rect.end.x / TILE)):
			_cells.append(Vector2i(i, j))
	_enabled = bool(area.get_meta("enabled", true))
	if attrs.has("tilehp") or attrs.has("tilethre"):
		_tile_stats = [_int(attrs.get("tilehp"), -1), _int(attrs.get("tilethre"), -1)]
	if attrs.has("tileop"):
		_Flags.set_air_opacity(land, _cells, _float(attrs.tileop, 0.0))
	if attrs.has("grav"):
		lift = _float(attrs.grav, 1.0)
		if lift != 1.0 and _enabled:
			_Flags.set_gravity(land, _cells, lift)
	if attrs.has("emit"):
		emit_id = str(attrs.emit)
		frec = _float(attrs.get("dens", 1), 1.0) * (rect.size.x / TILE) * (rect.size.y / TILE) / 100.0
		if emit_id == "purple_spark":
			_spark_tex = load(ART + "purple_spark.png") as Texture2D
	if attrs.has("port"):
		var parts := str(attrs.port).split(":")
		if parts.size() >= 2:
			port = Vector2(room) * ROOM_PX + Vector2((int(parts[0]) + 1) * TILE, (int(parts[1]) + 1) * TILE - 1.0)
	no_rad = attrs.has("norad")
	if attrs.has("vis"):
		_make_vis(str(attrs.vis).to_lower())


func _physics_process(delta: float) -> void:
	if not _tile_stats.is_empty():
		_set_tiles(int(_tile_stats[0]), int(_tile_stats[1]))
		_tile_stats = []
	_acc += delta * TPS
	if _acc < 1.0:
		return
	var ticks := mini(int(_acc), 4)
	_acc -= int(_acc)
	var now := bool(area.get_meta("enabled", true))
	if now != _enabled:
		_enabled = now
		if lift != 1.0:
			_Flags.set_gravity(land, _cells, lift if now else 1.0)
		if _vis:
			_vis.modulate.a = 1.0 if now else 0.1
	_step_sparks(ticks)
	if not _enabled:
		_inside = false
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or _Flags.cell_of(player.global_position) != room:
		_inside = false
		return
	if emit_id != "":
		for _i in ticks:
			_t_frec += frec
		if _t_frec > 1.0:
			var kol := int(_t_frec)
			_t_frec -= kol
			_emit(kol)
	var inside := area.monitoring and area.overlaps_body(player)
	if inside and no_rad:
		player.set_meta("no_rad", true)
	if inside and not _inside and port != Vector2.INF:
		_teleport(player)
	_inside = inside


func _set_tiles(hp: int, thre: int) -> void:
	var space := get_world_2d().direct_space_state
	for c_v in _cells:
		var c: Vector2i = c_v
		var q := PhysicsPointQueryParameters2D.new()
		q.position = (Vector2(c) + Vector2(0.5, 0.5)) * TILE
		q.collision_mask = 1
		for hit in space.intersect_point(q, 4):
			var body: Object = hit.get("collider")
			if body and body.has_method("set_cell_stats"):
				body.call("set_cell_stats", q.position, hp, thre)


func _teleport(player: Node2D) -> void:
	var body := player as CharacterBody2D
	var shape_node := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body and shape_node and shape_node.shape:
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = shape_node.shape
		q.transform = Transform2D(0.0, port) * shape_node.transform
		q.collision_mask = 1
		q.exclude = [body.get_rid()]
		if not get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty():
			return
	player.global_position = port
	player.reset_physics_interpolation()
	if body:
		body.velocity = Vector2.ZERO


func _emit(kol: int) -> void:
	if emit_id != "purple_spark":
		_UnitFx.emit(get_tree(), emit_id, rect.get_center(), {"kol": kol, "rx": rect.size.x, "ry": rect.size.y})
		return
	if _spark_tex == null:
		return
	for _i in mini(kol, 20):
		var spr := Sprite2D.new()
		spr.texture = _spark_tex
		spr.material = _blend()
		spr.offset = -_anchor("purple_spark")
		spr.centered = false
		var sc := 1.0 - SPARK_RSC + randf() * SPARK_RSC
		spr.scale = Vector2(sc, sc)
		spr.global_position = rect.get_center() + Vector2((randf() - 0.5) * rect.size.x, (randf() - 0.5) * rect.size.y)
		spr.z_index = 6
		spr.z_as_relative = false
		add_child(spr)
		_sparks.append([spr, SPARK_LIV])


func _step_sparks(ticks: int) -> void:
	var i := 0
	while i < _sparks.size():
		var p: Array = _sparks[i]
		p[1] = int(p[1]) - ticks
		var spr := p[0] as Sprite2D
		if int(p[1]) <= 0:
			spr.queue_free()
			_sparks.remove_at(i)
			continue
		if int(p[1]) < 9:
			spr.modulate.a = float(p[1]) / 10.0
		i += 1


func _make_vis(id: String) -> void:
	var tex := load(ART + id + ".png") as Texture2D if ResourceLoader.exists(ART + id + ".png") else null
	if tex == null:
		return
	_vis = Sprite2D.new()
	_vis.texture = tex
	_vis.centered = false
	_vis.offset = -_anchor(id)
	_vis.material = _blend()
	_vis.scale = rect.size / 100.0
	_vis.global_position = Vector2(rect.position.x, rect.end.y)
	_vis.modulate.a = 1.0 if _enabled else 0.1
	add_child(_vis)
	_vis.global_position = Vector2(rect.position.x, rect.end.y)


static func _anchor(id: String) -> Vector2:
	if _anchors.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART + "anchors.json")) if FileAccess.file_exists(ART + "anchors.json") else null
		_anchors = parsed if parsed is Dictionary else {"_": []}
	var a: Variant = _anchors.get(id)
	return Vector2(float(a[0]), float(a[1])) if a is Array and (a as Array).size() >= 2 else Vector2.ZERO


static func _blend() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add


static func _int(v: Variant, fallback: int) -> int:
	if v == null or str(v) == "":
		return fallback
	return int(float(str(v)))


static func _float(v: Variant, fallback: float) -> float:
	if v == null or not str(v).is_valid_float():
		return fallback
	return float(str(v))
