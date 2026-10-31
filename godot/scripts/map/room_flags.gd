class_name RoomFlags
extends RefCounted

## Location room options (Location.buildLoc over LandAct defaults), one row per
## room of the active land, keyed by its layout cell. Built on first use from
## the land's bound rooms. Queries take a world point; without one they use
## the player's.
##
## allows(flag): levit (levitoff), port (portoff), destroy (desoff), pet
## (petoff), black (noblack), map (nomap), and the base bans weapons, tele,
## containers (Location.base: no weapons, telekinesis or opening containers).

const TILE := 40.0
const COLS := 48
const ROWS := 25
const META := "room_env"
const META_GRAV := "tile_grav"
const META_OP := "tile_op"
const _Registry := preload("res://scripts/map/land_registry.gd")

## ColorFilter.ColorTable.
const COLORS := {
	"green": Color(0.80, 1.16, 0.80),
	"red": Color(1.10, 0.90, 0.70),
	"fire": Color(1.10, 0.70, 0.50),
	"lab": Color(0.90, 1.10, 0.70),
	"black": Color(0.50, 0.70, 0.60),
	"blue": Color(0.80, 0.80, 1.16),
	"sky": Color(0.85, 1.12, 1.12),
	"yellow": Color(1.25, 1.20, 0.90),
	"purple": Color(1.08, 0.80, 1.12),
	"pink": Color(1.10, 0.90, 1.00),
	"blood": Color(1.08, 0.60, 1.08),
	"blood2": Color(1.00, 0.10, 0.10),
	"dark": Color(0.00, 0.00, 0.00),
	"mf": Color(0.50, 0.50, 1.08),
}
const BASE_BANS := ["weapons", "tele", "containers"]


## Room env rows of land: {Vector2i layout cell: row}.
static func envs(land: Node) -> Dictionary:
	if land == null:
		return {}
	if land.has_meta(META):
		return land.get_meta(META)
	var out := {}
	var id := str(land.get("land_id")) if land.get("land_id") != null else ""
	if id == "":
		id = "begin"
	var act: Dictionary = _Registry.land(id).get("options", {})
	for room_v in _rooms_of(land):
		var room: Dictionary = room_v
		out[Vector2i(int(room.get("x", 0)), int(room.get("y", 0)))] = row_of(room, act, id)
	land.set_meta(META, out)
	return out


## Location fields for one room dictionary (options, water) over the land's options.
static func row_of(room: Dictionary, act: Dictionary, land_id: String) -> Dictionary:
	var o: Dictionary = room.get("options", {})
	var home := land_id == "stable_pi"
	var atk := land_id == "stable_pi_atk"
	var water := 100
	if room.has("water"):
		water = int(room.water)
	elif o.has("wlevel"):
		water = _Registry.int_of(o.wlevel, 100)
	var color := str(o.get("color", act.get("color", "")))
	if home:
		color = "yellow"
	elif atk:
		color = "fire"
	return {
		"base": o.has("base") or home,
		"train": o.has("train"),
		"bezdna": o.has("bezdna"),
		# Land.buildLand: the second (z = 1) layer of a cell never has a map.
		"map": not o.has("nomap") and int(room.get("z", 0)) == 0,
		"levit": not o.has("levitoff"),
		"port": not o.has("portoff"),
		"destroy": not o.has("desoff"),
		"pet": not o.has("petoff"),
		"black": not o.has("noblack"),
		"rad": _num(o, act, "rad", 0.0),
		"wrad": _num(o, act, "wrad", 1.0),
		"wdam": _num(o, act, "wdam", 0.0),
		"wtipdam": _dam_type(str(o.get("wtipdam", act.get("wtipdam", "venom")))),
		"wtip": int(_num(o, act, "wtip", 0.0)),
		"wopac": _num(o, act, "wopac", 0.0),
		"water": water,
		"wmask": water_mask(room.get("rows", []), water),
		"rows": room.get("rows", []),
		"color": color,
		"dark": int(_Registry.float_of(o.get("dark", act.get("darkness", 0)), 0.0)),
		"backform": _Registry.int_of(o.get("backform"), 0),
	}


static func _num(o: Dictionary, act: Dictionary, key: String, fallback: float) -> float:
	if o.has(key):
		return _Registry.float_of(o[key], fallback)
	if act.has(key):
		return _Registry.float_of(act[key], fallback)
	return fallback


## Resistances.parseDamageType for the names rooms use.
static func _dam_type(raw: String) -> String:
	var key := raw.strip_edges().to_lower()
	if key.begins_with("dam_"):
		return key.to_upper()
	if key.is_valid_int():
		return "DAM_VENOM"
	return "DAM_" + key.to_upper() if key != "" else "DAM_VENOM"


static func _rooms_of(land: Node) -> Array:
	var actors := land.get_node_or_null("Actors")
	if actors:
		var bound: Variant = actors.get("_bound_rooms")
		if bound is Array and not (bound as Array).is_empty():
			return bound
	var fog := land.get_tree().get_first_node_in_group("fog") if land.is_inside_tree() else null
	if fog and fog.has_method("begin_rooms"):
		return fog.begin_rooms()
	return []


static func cell_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / (COLS * TILE)), floori(at.y / (ROWS * TILE)))


static func active_land() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("active_land") if tree else null


static func player_pos() -> Vector2:
	var tree := Engine.get_main_loop() as SceneTree
	var player := tree.get_first_node_in_group("player") as Node2D if tree else null
	return player.global_position if player else Vector2.INF


## The room row at a world point of the active land ({} outside every room).
static func env_at(at: Variant = null, land: Node = null) -> Dictionary:
	var point: Vector2 = player_pos() if at == null else at
	if land == null:
		land = active_land()
	if land == null or point == Vector2.INF:
		return {}
	return envs(land).get(cell_of(point), {})


## RoomFlags.allows("pet") and friends. Rooms without a row allow everything.
static func allows(flag: String, at: Variant = null) -> bool:
	var env := env_at(at)
	if env.is_empty():
		return true
	if flag in BASE_BANS:
		return not bool(env.get("base", false))
	return bool(env.get(flag, true))


## Tile.water of a room's 48 x 25 tiles (index j * COLS + i): the tile text
## carries a "*" after its block (TileRegistry.decode), or the row is at or
## below waterLevel (Location.buildLoc). Empty when the room has no water.
static func water_mask(rows: Array, level: int) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(COLS * ROWS)
	var any := false
	for j in ROWS:
		var parts := str(rows[j]).split(".") if j < rows.size() else PackedStringArray()
		for i in COLS:
			if j >= level or (i < parts.size() and parts[i].find("*", 1) > 0):
				mask[j * COLS + i] = 1
				any = true
	return mask if any else PackedByteArray()


## Tile.water at a world point of the active land.
static func water_at(point: Vector2) -> bool:
	var env := env_at(point)
	var mask: PackedByteArray = env.get("wmask", PackedByteArray())
	if mask.is_empty():
		return false
	var i := floori(point.x / TILE) - cell_of(point).x * COLS
	var j := floori(point.y / TILE) - cell_of(point).y * ROWS
	return i >= 0 and i < COLS and j >= 0 and j < ROWS and mask[j * COLS + i] == 1


## World y of the water surface in the point's tile column: the top of the
## water run holding the point, else of the first one below it; INF without.
static func water_y(at: Variant = null) -> float:
	var point: Vector2 = player_pos() if at == null else at
	var env := env_at(point)
	var mask: PackedByteArray = env.get("wmask", PackedByteArray())
	if mask.is_empty():
		return INF
	var cell := cell_of(point)
	var i := clampi(floori(point.x / TILE) - cell.x * COLS, 0, COLS - 1)
	var j := clampi(floori(point.y / TILE) - cell.y * ROWS, 0, ROWS - 1)
	if mask[j * COLS + i] == 0:
		while j < ROWS and mask[j * COLS + i] == 0:
			j += 1
		if j >= ROWS:
			return INF
	while j > 0 and mask[(j - 1) * COLS + i] == 1:
		j -= 1
	return float(cell.y * ROWS + j) * TILE


static func in_water(point: Vector2) -> bool:
	return water_at(point)


## Tile_Definition.hidingSpot: a backWall overlay O (wall_machinery) or S (wall_pipes)
## after the tile's opening block (TileRegistry.decode).
static func hiding_at(point: Vector2) -> bool:
	var env := env_at(point)
	var rows: Array = env.get("rows", [])
	if rows.is_empty():
		return false
	var i := floori(point.x / TILE) - cell_of(point).x * COLS
	var j := floori(point.y / TILE) - cell_of(point).y * ROWS
	if j < 0 or j >= rows.size():
		return false
	var parts := str(rows[j]).split(".")
	if i < 0 or i >= parts.size():
		return false
	var code := parts[i]
	return code.find("O", 1) > 0 or code.find("S", 1) > 0


## Tile.gravity: Area grav lifts (setLift) by tile, 1 elsewhere.
static func gravity_at(point: Vector2, land: Node = null) -> float:
	if land == null:
		land = active_land()
	if land == null or not land.has_meta(META_GRAV):
		return 1.0
	var cells: Dictionary = land.get_meta(META_GRAV)
	if cells.is_empty():
		return 1.0
	return float(cells.get(Vector2i(floori(point.x / TILE), floori(point.y / TILE)), 1.0))


static func set_gravity(land: Node, cells: Array, value: float) -> void:
	if land == null:
		return
	var map: Dictionary = land.get_meta(META_GRAV) if land.has_meta(META_GRAV) else {}
	for c in cells:
		if is_equal_approx(value, 1.0):
			map.erase(c)
		else:
			map[c] = value
	land.set_meta(META_GRAV, map)


## Area tileop: the opacity of air tiles (Vector2i tile cells) for the fog.
static func set_air_opacity(land: Node, cells: Array, value: float) -> void:
	if land == null:
		return
	var map: Dictionary = land.get_meta(META_OP) if land.has_meta(META_OP) else {}
	for c in cells:
		map[c] = value
	land.set_meta(META_OP, map)
	if land.is_inside_tree():
		land.get_tree().call_group("fog", "air_opacity_changed", land)


