extends RefCounted

## Cell grid of one room: 48 x 25 bytes per layer, index j * COLS + i, kept on
## the room's RoomFlags record (the env dict) so it lives and is saved with it.
## - water: 0 dry .. FULL; wet when >= WET. Empty when the room has no water.
##   water0 is the built state; the land memory saves only cells that differ.
## - solid: SOLID for a live wall cell or a closed door, WALL_OPEN where a wall
##   covers the cell but that cell broke, FREE otherwise (other bodies are
##   asked live). Filled on first use and dropped when a wall or door changes.
## - gas: density 0..255, GAS_PER_RAD per unit of rad per tick, that rad
##   sources (radiation, gas and pink cloud boxes) and room rad write. Read by
##   nothing yet; damage still comes from rad_source and the room rad rules.
## A PackedByteArray in a dict is a copy, so every write puts the array back.

const COLS := 48
const ROWS := 25
const TILE := 40.0
const FULL := 255
const WET := 128
const FREE := 0
const SOLID := 1
const WALL_OPEN := 2
const WATER := "grid_water"
const WATER0 := "grid_water0"
const SOLIDS := "grid_solid"
const GAS := "grid_gas"
## Gas byte per unit of rad per tick (objs.xml rad is about 5..25).
const GAS_PER_RAD := 4.0


## Tile.water of a room: the tile text carries a "*" after its block
## (TileRegistry.decode), or the row is at or below waterLevel
## (Location.buildLoc). Empty when the room has no water.
static func build_water(rows: Array, level: int) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(COLS * ROWS)
	var any := false
	for j in ROWS:
		var parts := str(rows[j]).split(".") if j < rows.size() else PackedStringArray()
		for i in COLS:
			if j >= level or (i < parts.size() and parts[i].find("*", 1) > 0):
				cells[j * COLS + i] = FULL
				any = true
	return cells if any else PackedByteArray()


static func has_water(env: Dictionary) -> bool:
	return not (env.get(WATER, PackedByteArray()) as PackedByteArray).is_empty()


static func water(env: Dictionary) -> PackedByteArray:
	return env.get(WATER, PackedByteArray())


static func wet(env: Dictionary, i: int, j: int) -> bool:
	if i < 0 or i >= COLS or j < 0 or j >= ROWS:
		return false
	var cells: PackedByteArray = env.get(WATER, PackedByteArray())
	return not cells.is_empty() and cells[j * COLS + i] >= WET


## Level of cell (i, j). A room without water is not changed.
static func set_water(env: Dictionary, i: int, j: int, level: int) -> void:
	var cells: PackedByteArray = env.get(WATER, PackedByteArray())
	if cells.is_empty():
		return
	if not env.has(WATER0):
		env[WATER0] = cells.duplicate()
	cells[j * COLS + i] = clampi(level, 0, FULL)
	env[WATER] = cells


## True when cell (i, j) holds the level it was built with.
static func is_built_water(env: Dictionary, i: int, j: int, level: int) -> bool:
	var base: PackedByteArray = env.get(WATER0, env.get(WATER, PackedByteArray()))
	return not base.is_empty() and base[j * COLS + i] == clampi(level, 0, FULL)


## Back to the built water. False when nothing was ever written.
static func reset_water(env: Dictionary) -> bool:
	if not env.has(WATER0):
		return false
	env[WATER] = (env[WATER0] as PackedByteArray).duplicate()
	return true


## FREE, SOLID or WALL_OPEN for cell (i, j). land holds the Solids walls;
## props is its land_props (the doors).
static func solid(env: Dictionary, land: Node, props: Node, room: Vector2i, i: int, j: int) -> int:
	if not env.has(SOLIDS):
		env[SOLIDS] = _fill_solid(land, props, room)
	return (env[SOLIDS] as PackedByteArray)[j * COLS + i]


static func forget_solid(env: Dictionary) -> void:
	env.erase(SOLIDS)


static func add_gas(env: Dictionary, i: int, j: int, amount: int) -> void:
	if i < 0 or i >= COLS or j < 0 or j >= ROWS or amount <= 0:
		return
	var cells: PackedByteArray = env.get(GAS, PackedByteArray())
	if cells.is_empty():
		cells.resize(COLS * ROWS)
	var k := j * COLS + i
	cells[k] = mini(FULL, cells[k] + amount)
	env[GAS] = cells


static func gas(env: Dictionary, i: int, j: int) -> int:
	var cells: PackedByteArray = env.get(GAS, PackedByteArray())
	if cells.is_empty() or i < 0 or i >= COLS or j < 0 or j >= ROWS:
		return 0
	return cells[j * COLS + i]


## Room rad as an even gas density (empty when the room has none).
static func room_gas(rad: float) -> PackedByteArray:
	var cells := PackedByteArray()
	var level := clampi(roundi(rad * GAS_PER_RAD), 0, FULL)
	if level <= 0:
		return cells
	cells.resize(COLS * ROWS)
	cells.fill(level)
	return cells


## A source of rad per tick at its centre, fading to 0 at radius (rad_source).
## dir -1 takes it back. envs is the land's RoomFlags record table.
static func add_gas_disk(envs: Dictionary, centre: Vector2, radius: float, rad: float, dir := 1) -> void:
	if radius <= 0.0 or rad <= 0.0:
		return
	var r2 := radius * radius
	var t0 := Vector2i(floori((centre.x - radius) / TILE), floori((centre.y - radius) / TILE))
	var t1 := Vector2i(floori((centre.x + radius) / TILE), floori((centre.y + radius) / TILE))
	for ty in range(t0.y, t1.y + 1):
		for tx in range(t0.x, t1.x + 1):
			var at := (Vector2(tx, ty) + Vector2(0.5, 0.5)) * TILE
			var d2 := at.distance_squared_to(centre)
			if d2 >= r2:
				continue
			var room := Vector2i(floori(float(tx) / COLS), floori(float(ty) / ROWS))
			if not envs.has(room):
				continue
			var amount := roundi(rad * (radius - sqrt(d2)) / radius * GAS_PER_RAD)
			if amount <= 0:
				continue
			var env: Dictionary = envs[room]
			var i := posmod(tx, COLS)
			var j := posmod(ty, ROWS)
			if dir > 0:
				add_gas(env, i, j, amount)
			else:
				var cells: PackedByteArray = env.get(GAS, PackedByteArray())
				if not cells.is_empty():
					cells[j * COLS + i] = maxi(0, cells[j * COLS + i] - amount)
					env[GAS] = cells


## The room tiles (i, j) whose centre lies in a world rect.
static func _tiles_in(room: Vector2i, rect: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var origin := Vector2(room.x * COLS, room.y * ROWS) * TILE
	var i0 := maxi(0, ceili((rect.position.x - origin.x) / TILE - 0.5))
	var i1 := mini(COLS - 1, floori((rect.end.x - origin.x) / TILE - 0.5))
	var j0 := maxi(0, ceili((rect.position.y - origin.y) / TILE - 0.5))
	var j1 := mini(ROWS - 1, floori((rect.end.y - origin.y) / TILE - 0.5))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var at := origin + (Vector2(i, j) + Vector2(0.5, 0.5)) * TILE
			if rect.has_point(at):
				out.append(Vector2i(i, j))
	return out


## The first wall that covers a tile centre decides it, as water_flow did.
static func _fill_solid(land: Node, props: Node, room: Vector2i) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(COLS * ROWS)
	var room_rect := Rect2(Vector2(room.x * COLS, room.y * ROWS) * TILE, Vector2(COLS, ROWS) * TILE)
	var taken := PackedByteArray()
	taken.resize(COLS * ROWS)
	var solids := land.get_node_or_null("Solids") if land != null else null
	if solids != null:
		for wall in solids.get_children():
			if not wall.has_method("cell_rects"):
				continue
			for entry in wall.call("cell_rects", room_rect):
				for t in _tiles_in(room, entry[0]):
					var k := t.y * COLS + t.x
					if taken[k] == 0:
						taken[k] = 1
						cells[k] = SOLID if entry[1] else WALL_OPEN
	var doors: Variant = props.get("_doors") if props != null else null
	if doors is Array:
		for body in doors:
			var rect := door_rect(body)
			if rect.size == Vector2.ZERO:
				continue
			for t in _tiles_in(room, rect):
				var k := t.y * COLS + t.x
				if taken[k] == 0:
					cells[k] = SOLID
	return cells


## World rect of a closed door's collision box; zero when it is open or gone.
static func door_rect(body: Variant) -> Rect2:
	if not (body is CollisionObject2D) or not is_instance_valid(body):
		return Rect2()
	var obj := body as CollisionObject2D
	if (obj.collision_layer & 1) == 0:
		return Rect2()
	var shape := obj.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null or shape.disabled or not (shape.shape is RectangleShape2D):
		return Rect2()
	var size := (shape.shape as RectangleShape2D).size
	var centre := shape.global_position
	return Rect2(centre - size * 0.5, size)
