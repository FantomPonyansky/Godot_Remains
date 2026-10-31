extends Node2D

## Actors from the rooms_begin document inside pfe.swf.
## Room 0,0 has no unit tags, so nothing is invented there.
## Other lands bind_rooms + bind_plan: LandSpawn rows, spawned room by room.

const DATA := "res://assets/data/maps/begin_actors.json"
const ROOMS := "res://assets/data/maps/rooms/rooms_begin.json"
const _Enemy := preload("res://scenes/enemy.tscn")
const _EnemyScript := preload("res://scripts/enemy.gd")
const _Prop := preload("res://scripts/map_prop.gd")
const _Held := preload("res://scripts/held_prop.gd")
const _Loot := preload("res://scripts/loot_roll.gd")
const _Lock := preload("res://scripts/lock_use.gd")
const _DoorArt := preload("res://scripts/door_art.gd")
const _ObjArt := preload("res://scripts/map/obj_art.gd")
const _Drop := preload("res://scripts/ground_loot.gd")
const _Memory := preload("res://scripts/map/land_memory.gd")
const _Checkpoint := preload("res://scripts/map/checkpoint.gd")
const _WaterFlow := preload("res://scripts/map/water_flow.gd")
const _Registry := preload("res://scripts/map/land_registry.gd")
const _PropSfx := preload("res://scripts/prop_sfx.gd")
const _Npc := preload("res://scripts/story/npc.gd")
const _Trap := preload("res://scripts/map/trap_unit.gd")
const _RadSource := preload("res://scripts/map/rad_source.gd")
const _EnSpawn := preload("res://scripts/map/en_spawn.gd")
const _Trial := preload("res://scripts/story/trial.gd")
const _RoomLook := preload("res://scripts/map/room_look.gd")
const _RoomFlags := preload("res://scripts/map/room_flags.gd")
const _AreaFx := preload("res://scripts/map/area_fx.gd")
const _Platform := preload("res://scripts/map/platform_mover.gd")
const _MolnTrap := preload("res://scripts/map/moln_trap.gd")
const _ImpactFx := preload("res://scripts/impact_fx.gd")
const _Stand := preload("res://scripts/stand_screen.gd")
const _Signs := preload("res://scripts/map/interact_signs.gd")
## objs.xml allact of the station objects.
const STATION_ACTS := {"work": "work", "himlab": "lab", "stove": "stove", "stand": "stand", "vault": "vault", "table3": "app"}
## objs.xml knop='1': Interact.actOsn toggles open on every act (inter > 0).
const _KNOPS := ["knop1", "knop2", "knop3", "knop4", "detonator", "elpanel", "dsph", "moln1"]
const TILE := 40
const ROOM_W := 48
const ROOM_H := 25
const SPAWN_BUDGET_USEC := 4000

## Native sprite sizes from texture1.swf (viswoodbox, visbox, vismcrate1–5, visbigbox, visbigbox2).
const _CRATE_ART := {
	"woodbox": "res://assets/sprites/props/woodbox.png",
	"box": "res://assets/sprites/props/box.png",
	"mcrate1": "res://assets/sprites/props/mcrate1.png",
	"mcrate2": "res://assets/sprites/props/mcrate2.png",
	"mcrate3": "res://assets/sprites/props/mcrate3.png",
	"mcrate4": "res://assets/sprites/props/mcrate4.png",
	"mcrate5": "res://assets/sprites/props/mcrate5.png",
	"bigbox": "res://assets/sprites/props/bigbox.png",
	"bigbox2": "res://assets/sprites/props/bigbox2.png",
}
const LOOT_REACH := 36.0
## Loot.as osnRad. E takes a dropped item inside this gap.
const DROP_REACH := 50.0
const HEAL := ["pot0", "pot1", "antiradin"]
const AMMO := ["aero", "p32", "oldr", "pb"]
const NAMES := {
	"pot0": "Healing potion",
	"pot1": "Healing potion",
	"antiradin": "Antiradin",
	"aero": "Ammo",
	"p32": "Pistol ammo",
	"oldr": "Old rounds",
	"mont": "Monkey wrench",
	"screwdriver": "Screwdriver",
	"col1": "Collectible",
	"lasp": "Laser pistol",
	"shok": "Shock weapon",
	"bat": "Battery",
	"sphera": "Orb",
}

var _by_uid: Dictionary = {}
var _doors: Array = []
var _buttons: Array = []
var _button_anchors: Dictionary = {}
var _loot: Array = []
var _areas: Dictionary = {}
var _hazards: Dictionary = {}
var _room_attrs: Dictionary = {}
var _alarm_left := 0.0
var _trip := Rect2()
var _budilo_left := 0.0
var _budilo_tick := 0.0
var _alarm_at := Vector2.ZERO
var _from_rooms := false
var _bound_rooms: Array = []
var _plan_rows: Array = []
var _plan_from := Vector2.ZERO
## Room key "x,y" -> plan rows not spawned yet.
var _pending: Dictionary = {}
var _pending_order: Array = []
var _passages: Array = []
## Checkpoints, the wmap table and exits to the next level: use goes to them.
var _uses: Array = []
var _xp_left: Dictionary = {}
var _detected_rooms: Dictionary = {}
## Visits and saves: land_memory.gd. Room edges and crossings: room_bounds.gd.
var _memory: RefCounted
## Enspawn points and the alarm spawn timer: en_spawn.gd.
var _en_spawn: RefCounted
var _signs := _Signs.new()


func bind_rooms(rooms: Array) -> void:
	_from_rooms = true
	_bound_rooms = rooms


## LandSpawn rows for a rooms-mode land. from is the entrance, so its rooms
## spawn first and the rest follow a few rooms per frame.
func bind_plan(rows: Array, from: Vector2) -> void:
	_plan_rows = rows
	_plan_from = from
	var ids: Array = []
	for row_v in rows:
		var uid := str((row_v as Dictionary).get("unit_id", ""))
		if uid != "" and not ids.has(uid):
			ids.append(uid)
	_EnemyScript.prefetch(ids)


func _ready() -> void:
	add_to_group("land_props")
	_PropSfx.hush()
	_memory = _Memory.new(self)
	_en_spawn = _EnSpawn.new(self)
	_memory.begin(_bound_rooms)
	if _from_rooms:
		_index_bound_rooms()
		_bind_doors(_plan_doors())
		_shut_wooden_walls()
		_memory.after_doors()
		_queue_plan()
		_memory.after_plan()
		_spawn_near(_room_key_of(_plan_from))
		call_deferred("_wake_areas")
		call_deferred("_restore_water")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("begin_actors.json missing")
		return
	var data: Dictionary = parsed
	_load_room_index()
	_bind_doors(data.get("doors", []))
	_shut_wooden_walls()
	_memory.after_doors()
	var at := get_child_count()
	_spawn_units(data.get("units", []))
	_memory.stamp_span("u", at)
	at = get_child_count()
	_spawn_hazards(data.get("hazards", []))
	_memory.stamp_span("h", at)
	at = get_child_count()
	_spawn_traps(data.get("traps", []))
	_memory.stamp_span("t", at)
	at = get_child_count()
	_spawn_loot(data.get("loot", []))
	_memory.stamp_span("l", at)
	at = get_child_count()
	_spawn_buttons(data.get("buttons", []))
	_memory.stamp_span("b", at)
	at = get_child_count()
	_spawn_areas(data.get("areas", []))
	_memory.stamp_span("a", at)
	at = get_child_count()
	for row in _begin_checkpoints():
		_spawn_checkpoint(row)
	_memory.stamp_span("c", at)
	_memory.after_plan()
	call_deferred("_wake_areas")
	call_deferred("_restore_water")


func _restore_water() -> void:
	_WaterFlow.restore(self)


## rooms_begin checkpoint objs (begin_actors.json has none) as LandSpawn rows:
## feet at ((x + size / 2) * 40, (y + 1) * 40 - 1) of the room.
func _begin_checkpoints() -> Array:
	var out: Array = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOMS))
	if not parsed is Dictionary:
		return out
	for room_v in (parsed as Dictionary).get("rooms", []):
		var room: Dictionary = room_v
		if int(room.get("z", 0)) != 0 or not room.has("x"):
			continue
		var rx := int(room.x)
		var ry := int(room.y)
		for obj_v in room.get("objs", []):
			var obj: Dictionary = obj_v
			if not str(obj.get("id", "")).begins_with("checkpoint"):
				continue
			var attrs: Dictionary = obj.get("attrs", {})
			var size := float(obj.get("size", 2))
			out.append({
				"id": str(obj.id), "attrs": attrs, "room": [rx, ry], "uid": str(attrs.get("uid", "")),
				"feet": [rx * 1920.0 + (float(obj.x) + 0.5 * size) * 40.0, ry * 1000.0 + (float(obj.y) + 1.0) * 40.0 - 1.0],
			})
	return out


func _exit_tree() -> void:
	if _memory != null:
		_memory.store()


## WorldState: this land's state as land_memory.gd keeps it.
func capture_state() -> Dictionary:
	return _memory.capture() if _memory != null else {}


func restore_state(snapshot: Dictionary) -> void:
	if _memory != null:
		_memory.restore_live(snapshot)
		_WaterFlow.restore(self)


## Called from wall_span.gd when a wall cell breaks.
func note_broken(rect: Rect2) -> void:
	if _memory != null:
		_memory.note_broken(rect)
	_WaterFlow.broke(self, rect)


## Land-level script flags, saved with the land.
func set_flag(key: String, value: Variant) -> void:
	_memory.set_flag(key, value)


func flag(key: String, fallback: Variant = null) -> Variant:
	return _memory.flag(key, fallback)


func _process(delta: float) -> void:
	if not _pending_order.is_empty():
		_spawn_pending()
	if GameState.paused:
		return
	for trap in get_tree().get_nodes_in_group("begin_traps"):
		var left := float(trap.get_meta("cool", 0.0)) - delta
		trap.set_meta("cool", maxf(0.0, left))
	_tick_alarm(delta)
	_tick_alarm_boxes()
	_en_spawn.tick(delta)
	_signs.tick(get_tree(), delta, _sign_point)
	if Travel.blocks_control():
		return
	if Input.is_action_just_pressed("interact"):
		var who := get_tree().get_first_node_in_group("player")
		if who and bool(who.get_meta("tk_claim", false)):
			who.set_meta("tk_claim", false)
		elif not (who and who.get("rat") == true):
			_interact()


## A map object's script (Script.as in ScriptsEngine). owner is "this";
## source names it by uid when owner is not given. Port steps: notice (an
## info line) and _qid (Unit.die questId, after the die script starts).
func run_actions(steps: Array, source: String = "", owner: Node = null, eve: String = "") -> void:
	var acts: Array = []
	var qids: Array = []
	for step_v in steps:
		if typeof(step_v) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_v
		match str(step.get("act", "")):
			"notice":
				_notice(str(step.get("val", "")))
			"_qid":
				qids.append(str(step.get("val", "")))
			_:
				acts.append(step)
	if owner == null and source != "":
		owner = _by_uid.get(source)
	var key := "obj:%d%s" % [owner.get_instance_id(), eve] if owner != null else ""
	ScriptsEngine.run_steps(acts, owner, key)
	for qid in qids:
		ScriptsEngine.quest_unit(qid)


## Script gotoland without n: Game.gotoLand, through the land host so the
## way back is the area you left by.
func script_goto_land(id: String) -> void:
	var host: Node = self
	while host and not host.has_method("goto_land"):
		host = host.get_parent()
	if host:
		host.goto_land(id, _trip)
	else:
		Travel.goto_land(id)


## Area.damTiles: Location.hitTile(destroy, E_Decal.FIRE) on every tile under the area.
func _area_dam(area: Area2D, destroy: int) -> void:
	var shape := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null or not shape.shape is RectangleShape2D:
		for child in area.get_children():
			if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
				shape = child
				break
	if shape == null or not shape.shape is RectangleShape2D:
		return
	var size := (shape.shape as RectangleShape2D).size
	var top_left := area.global_position + shape.position - size * 0.5
	var solids := get_parent().get_node_or_null("Solids")
	if solids == null:
		return
	for j in range(floori(top_left.y / TILE + 0.01), ceili((top_left.y + size.y) / TILE - 0.01)):
		for i in range(floori(top_left.x / TILE + 0.01), ceili((top_left.x + size.x) / TILE - 0.01)):
			var at := (Vector2(i, j) + Vector2(0.5, 0.5)) * TILE
			for wall in solids.get_children():
				if wall.has_method("hit_tile") and wall.has_method("covers") and wall.covers(at):
					wall.hit_tile(at, destroy, "", _ImpactFx.FIRE)
					break


## land.uidObjs[uid] for script steps.
func script_target(uid: String) -> Node:
	var node: Variant = _by_uid.get(uid)
	return node if node is Node and is_instance_valid(node) else null


## Obj / Area / Interact / Unit command from a script step aimed at node.
func script_command(node: Node, act: String, val: String) -> void:
	if node is _Platform:
		node.script_command(act, val)
		return
	# CheckPoint.command: any command activates it.
	if node is _Checkpoint:
		node.activate()
		return
	if node.is_in_group("land_area"):
		match act:
			"on":
				_switch_area(node, true)
			"off":
				_switch_area(node, false)
			"onoff":
				_switch_area(node, not bool(node.get_meta("enabled", false)))
			"dam":
				_area_dam(node as Area2D, int(float(val)) if val.is_valid_float() else 0)
		return
	if node.is_in_group("enemies"):
		var brain: Variant = node.get("_brain")
		if brain != null and brain.has_method("command"):
			brain.command(act, val)
		return
	if node.is_in_group("trap_units"):
		node.command(act, val)
		return
	match act:
		"open":
			if _doors.has(node) or node.has_meta("door_id"):
				body_lock(node, 0.0)
				_apply_door(node, true)
			elif _loot.has(node):
				_open_loot(node)
		"close":
			if _doors.has(node) or node.has_meta("door_id"):
				_apply_door(node, false)
		"swap":
			_apply_door(node, not bool(node.get_meta("door_open", false)))
		"unlock":
			body_lock(node, 0.0)
		"hack":
			if bool(node.get_meta("hackable", false)):
				body_lock(node, 0.0)
		"dam":
			if _hazards.values().has(node) and node.has_method("take_hit"):
				node.take_hit(999)
			elif _buttons.has(node):
				_on_button(node)
		"die":
			if node.has_method("take_hit"):
				node.take_hit(999)
		"off":
			node.set_meta("usable", false)
		"sign":
			_signs.set_sign(node, int(val))


## Location.allAct(null, act, allid) for a script: objects and areas whose
## allid matches get the command (objects with val "13").
func all_act(act: String, allid: String) -> void:
	for node_v in _by_uid.values():
		var node: Node = node_v
		if not is_instance_valid(node) or str(node.get_meta("allid", "")) != allid:
			continue
		script_command(node, act, "13" if not node is Area2D else "")


func body_lock(node: Node, lock: float) -> void:
	node.set_meta("lock", lock)
	node.set_meta("mine", 0)


## first: the bag had none of the item before this pickup.
func collected_item(item_id: String, first: bool = true) -> void:
	ScriptsEngine.item_taken(item_id, first)
	if item_id in HEAL or item_id in AMMO:
		return
	var line := OriginalLines.name_of(item_id)
	_notice(line if line != item_id else str(NAMES.get(item_id, item_id)))


func _bind_doors(rows: Array) -> void:
	var index := {}
	for row_v in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var room: Array = row.get("room", [0, 0])
		var cell: Array = row.get("cell", [0, 0])
		index["%s,%s,%s,%s" % [room[0], room[1], cell[0], cell[1]]] = row
	var root := get_parent().get_node_or_null("Doors")
	if root == null:
		return
	for body in root.get_children():
		var key := "%s,%s,%s,%s" % [
			body.get_meta("room_x", -1), body.get_meta("room_y", -1),
			body.get_meta("cell_x", -1), body.get_meta("cell_y", -1)
		]
		var row: Dictionary = index.get(key, {})
		var uid := str(row.get("uid", body.get_meta("uid", "")))
		body.set_meta("uid", uid)
		body.set_meta("lock", float(row.get("lock", body.get_meta("lock", 0.0))))
		body.set_meta("usable", bool(row.get("usable", true)))
		# septum is a plank. The door list defaults a missed row to usable,
		# which would send it through open/close and lockTip.
		if _wooden_wall(body):
			body.set_meta("usable", false)
		_stamp_door(body)
		var opened := bool(row.get("open", body.get_meta("door_open", false)))
		if _wooden_wall(body):
			opened = false
		_apply_door(body, opened)
		if _wooden_wall(body):
			if uid != "":
				_by_uid[uid] = body
			continue
		_doors.append(body)
		body.add_to_group("tk_use")
		if uid != "":
			_by_uid[uid] = body


func _spawn_units(rows: Array) -> void:
	for row_v in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var body: Array = row.get("body", [40, 30])
		var enemy := _Enemy.instantiate() as CharacterBody2D
		var feet: Array = row.get("feet", [0, 0])
		enemy.position = Vector2(float(feet[0]), float(feet[1]))
		enemy.max_hp = int(row.get("hp", 20))
		enemy.points = int(row.get("xp", 10))
		enemy.levitate_difficulty = float(row.get("diff", 20))
		enemy.set("fight_style", str(row.get("fight", "melee")))
		enemy.set("fixed_post", bool(row.get("fixed", false)))
		enemy.set("move_speed", float(row.get("speed", 60)))
		enemy.set("run_speed", float(row.get("run", 90)))
		enemy.set("melee_damage", int(row.get("damage", 6)))
		enemy.set("body_size", Vector2(float(body[0]), float(body[1])))
		var tint: Array = row.get("tint", [1, 1, 1])
		enemy.set("body_tint", Color(float(tint[0]), float(tint[1]), float(tint[2])))
		enemy.set("die_actions", row.get("actions", []))
		var unit_room: Array = row.get("room", [0, 0])
		enemy.set_meta("room_x", int(unit_room[0]))
		enemy.set_meta("room_y", int(unit_room[1]))
		var unit_id := str(row.get("id", "")).strip_edges()
		if unit_id != "":
			enemy.set_meta("unit_id", unit_id)
			enemy.name = unit_id
			enemy.add_to_group(unit_id)
		var uid := str(row.get("uid", ""))
		if uid != "":
			_by_uid[uid] = enemy
		add_child(enemy)


func _spawn_hazards(rows: Array) -> void:
	for row_v in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var feet: Array = row.get("feet", [0, 0])
		var at := Vector2(float(feet[0]), float(feet[1]))
		var node := _Prop.new()
		node.position = at
		node.collision_layer = 4
		node.collision_mask = 0
		node.hp = 12 if str(row.get("id", "")) == "expl1" else 8
		node.breaks = true
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(28, 18)
		shape.shape = box
		shape.position = Vector2(0, -9)
		node.add_child(shape)
		var still := _ObjArt.sheet_still(_Trap.SHEETS, "mtrap" if str(row.get("id", "")) == "trap" else "damexpl1")
		if still != null:
			node.add_child(still)
		else:
			node.add_child(_quad(Vector2(28, 18), Color(0.55, 0.28, 0.16), Vector2(-14, -18)))
		var uid := str(row.get("uid", ""))
		node.triggered.connect(_on_hazard.bind(row, at))
		if str(row.get("id", "")) == "trap":
			_add_trip(node, int(row.get("damage", 10)))
		add_child(node)
		if uid != "":
			_hazards[uid] = node
			_by_uid[uid] = node


func _add_trip(node: Node, damage: int) -> void:
	var trip := Area2D.new()
	trip.collision_layer = 0
	trip.collision_mask = 2
	trip.monitoring = true
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(28, 16)
	shape.shape = box
	shape.position = Vector2(0, -8)
	trip.add_child(shape)
	trip.body_entered.connect(func(body: Node) -> void:
		if not is_instance_valid(node) or not body.is_in_group("player"):
			return
		if body.has_method("take_hit"):
			body.take_hit(damage)
		if node.has_method("take_hit"):
			node.take_hit(999)
	)
	node.add_child(trip)


func _on_hazard(row: Dictionary, at: Vector2) -> void:
	var radius := float(row.get("radius", 0))
	if radius > 0.0:
		_blast(at, radius, int(row.get("damage", 30)))
	run_actions(row.get("actions", []))


func _spawn_traps(rows: Array) -> void:
	for row_v in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var feet: Array = row.get("feet", [0, 0])
		var area := Area2D.new()
		area.add_to_group("begin_traps")
		area.position = Vector2(float(feet[0]), float(feet[1]) - 20.0)
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitoring = true
		area.set_meta("damage", int(row.get("damage", 15)))
		area.set_meta("cool", 0.0)
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(36, 16 if not bool(row.get("ceiling", false)) else 20)
		shape.shape = box
		area.add_child(shape)
		# Trap.as: vistrap<id> behind units and vistrap<id>2 in front, each on a random frame.
		var key := "trap_" + ("fspikes" if bool(row.get("ceiling", false)) else "spikes")
		if _ObjArt.has(key):
			for layer in [key, key + "2"]:
				var pic := _ObjArt.sprite(layer, randi_range(1, maxi(_ObjArt.frames(key), 1)))
				pic.position = Vector2(0, 20)
				pic.z_index = -1 if layer == key else 2
				area.add_child(pic)
		else:
			var color := Color(0.45, 0.47, 0.5) if not bool(row.get("ceiling", false)) else Color(0.62, 0.5, 0.28)
			area.add_child(_quad(box.size, color, -box.size * 0.5))
		area.set_meta("ceiling", bool(row.get("ceiling", false)))
		add_child(area)


func _physics_process(_delta: float) -> void:
	if GameState.paused:
		return
	for trap in get_tree().get_nodes_in_group("begin_traps"):
		if float(trap.get_meta("cool", 0.0)) > 0.0:
			continue
		for body in (trap as Area2D).get_overlapping_bodies():
			_trap_touch(trap, body)


# Trap.attKorp: floor spikes (att 1) hurt only a unit falling faster than 8 px/tick,
# scaled by dy / 20; ceiling spikes (att 2) only one moving up. Walking through is safe.
func _trap_touch(area: Area2D, body: Node) -> void:
	if not body.is_in_group("player") or not body.has_method("take_hit") or not body is CharacterBody2D:
		return
	if bool(body.get("_is_fly")):
		return
	var dy := (body as CharacterBody2D).velocity.y / 30.0
	var amount := 0.0
	if bool(area.get_meta("ceiling", false)):
		if dy < 0.0:
			amount = float(area.get_meta("damage", 15))
	elif dy > 8.0:
		amount = float(area.get_meta("damage", 15)) * dy / 20.0
	if amount <= 0.0:
		return
	area.set_meta("cool", 1.0)
	body.take_hit(int(round(amount)))


func _spawn_loot(rows: Array) -> void:
	for row_v in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var id := str(row.get("id", ""))
		var info := _Loot.container(id)
		var feet_a: Array = row.get("feet", [0, 0])
		var feet := Vector2(float(feet_a[0]), float(feet_a[1]))
		var stamp_size := Vector2(float(row.get("w", 40)), float(row.get("h", 40)))
		var size := stamp_size
		var art := _crate_texture(id)
		if art:
			size = Vector2(art.get_width(), art.get_height())
		var lock := float(row.get("lock", 0))
		var cont := str(info.get("cont", ""))
		if row.has("cont"):
			cont = str(row.get("cont", ""))
		var items: Array = row.get("items", [])
		var locked := lock > 0.0
		var color := Color(0.42, 0.34, 0.22) if locked else Color(0.5, 0.42, 0.26)
		var node: Node2D
		# objs.xml wall>0 is bolted to the background. Box.as gives it no shelf
		# and never writes tile.collision, so it does not stop bodies or shots.
		# A floor box is not a wall. held_prop keeps the one-way top, stack, and fall.
		var mounted := int(info.get("wall", 0)) > 0 or id == "locker"
		var art_path := _prop_png(id, false)
		if bool(info.get("levitate", false)):
			var held := _Held.new()
			held.set_meta("box", size)
			held.set_meta("levitate_difficulty", float(info.get("difficulty", 10.0)))
			held.set_meta("color", color)
			if art_path != "":
				held.set_meta("art", art_path)
				if art_path.begins_with(_ObjArt.DIR):
					held.set_meta("art_at", Vector2(size.x * 0.5, size.y) + _ObjArt.offset(id))
			held.position = Vector2(feet.x - size.x * 0.5, feet.y - size.y)
			node = held
		else:
			var body := StaticBody2D.new()
			body.position = Vector2(feet.x - size.x * 0.5, feet.y - size.y)
			body.collision_layer = 0
			body.collision_mask = 0
			body.set_meta("blocks_sight", false)
			if not mounted:
				var shape := CollisionShape2D.new()
				var box := RectangleShape2D.new()
				box.size = size
				shape.shape = box
				shape.position = size * 0.5
				# Box.shelf is scX < 40 or wall>0. One-tile floor boxes (40 px) still
				# count as shelves there; testers cannot stand on them, so only wider.
				var stand := size.x > 40.0
				body.collision_layer = 64 if stand else 0
				shape.one_way_collision = stand
				shape.one_way_collision_margin = 8.0
				body.add_child(shape)
			var picture := _crate_sprite(art)
			if picture:
				if art_path.begins_with(_ObjArt.DIR):
					picture.position = Vector2(size.x * 0.5, size.y) + _ObjArt.offset(id)
					picture.set_meta("obj_art", id)
				body.add_child(picture)
			else:
				body.add_child(_quad(size, color, Vector2.ZERO))
			node = body
		node.set_meta("id", id)
		if node.z_index == 0:
			node.z_index = -2
		node.set_meta("size", size)
		node.set_meta("lock", lock)
		node.set_meta("locktip", int(info.get("locktip", 1)))
		node.set_meta("cont", cont)
		node.set_meta("items", items)
		node.set_meta("actions", row.get("actions", []))
		node.set_meta("eves", row.get("eves", {}))
		if bool(row.get("prize", false)):
			node.set_meta("prize", true)
		node.set_meta("feet", feet)
		var loot_room: Array = row.get("room", [0, 0])
		_stamp_at(node, id, lock, loot_room, feet, stamp_size)
		var already := bool(row.get("open", false))
		if already:
			node.set_meta("spent", true)
			node.set_meta("opened", true)
		var rolls := cont != "" and cont != "empty" and cont != "*"
		var secured := float(node.get_meta("lock", 0.0)) > 0.0 or int(node.get_meta("mine", 0)) > 0
		if rolls or not items.is_empty() or secured or locked or _CRATE_ART.has(id):
			_loot.append(node)
			node.add_to_group("tk_use")
		add_child(node)
		_ObjArt.shade(node.get_node_or_null("Visual"), id)
		if already:
			_show_opened(node)


func _prop_png(id: String, opened: bool = false) -> String:
	if opened:
		var open_path := "res://assets/sprites/props/%s_open.png" % id
		if ResourceLoader.exists(open_path):
			return open_path
		var open_fr := _ObjArt.label_frame(id, "open")
		return _ObjArt.path(id, open_fr) if open_fr > 0 else ""
	var closed := "res://assets/sprites/props/%s.png" % id
	if ResourceLoader.exists(closed):
		return closed
	if not _CRATE_ART.has(id) and _ObjArt.has(id):
		return _ObjArt.path(id, maxi(_ObjArt.label_frame(id, "close"), 1))
	return str(_CRATE_ART.get(id, ""))


func _crate_texture(id: String) -> Texture2D:
	return _load_tex(_prop_png(id, false))


func _load_tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _crate_sprite(art: Texture2D) -> Sprite2D:
	if art == null:
		return null
	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.texture = art
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


func _spawn_buttons(rows: Array) -> void:
	for row_v in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var feet: Array = row.get("feet", [0, 0])
		var at := Vector2(float(feet[0]), float(feet[1]))
		var node := _Prop.new()
		node.position = at
		node.collision_layer = 4 if bool(row.get("bullet", false)) else 0
		node.collision_mask = 0
		node.breaks = false
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var box := RectangleShape2D.new()
		box.size = Vector2(18, 18)
		shape.shape = box
		shape.position = Vector2(0, -9)
		node.add_child(shape)
		var art := _button_art(str(row.get("id", "")))
		if art:
			box.size = art.texture.get_size()
			shape.position = Vector2(0, -box.size.y * 0.5)
			node.add_child(art)
			_ObjArt.shade(art, str(row.get("id", "")))
		else:
			node.add_child(_quad(Vector2(18, 18), Color(0.75, 0.25, 0.2), Vector2(-9, -18)))
		node.set_meta("feet", at)
		node.set_meta("actions", row.get("actions", []))
		node.set_meta("eves", row.get("eves", {}))
		node.set_meta("autoclose", int(row.get("autoclose", 0)))
		var button_id := str(row.get("id", ""))
		node.set_meta("id", button_id)
		var button_room: Array = row.get("room", [0, 0])
		_stamp_at(node, button_id, -1.0, button_room, at, Vector2(40, 40))
		if str(row.get("allact", "")) != "":
			node.set_meta("allact", str(row.allact))
		if str(row.get("allid", "")) != "":
			node.set_meta("allid", str(row.allid))
		node.triggered.connect(_on_button.bind(node))
		add_child(node)
		_buttons.append(node)
		node.add_to_group("tk_use")
		if bool(row.get("bullet", false)):
			node.add_to_group("actdam")


## Box vis<id> (texture1.swf) with its registration point from term_anchors.json.
func _button_art(id: String) -> Sprite2D:
	var tex := _load_tex(_prop_png(id, false))
	if tex == null:
		return null
	if _button_anchors.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/props/term_anchors.json"))
		_button_anchors = parsed if parsed is Dictionary else {"_": []}
	var a: Variant = _button_anchors.get(id)
	if not a is Array and _ObjArt.has(id):
		return _ObjArt.sprite(id, maxi(_ObjArt.label_frame(id, "close"), 1))
	if not a is Array:
		a = [tex.get_width() * 0.5, tex.get_height()]
	var sprite := _crate_sprite(tex)
	sprite.offset = -Vector2(float(a[0]), float(a[1]))
	return sprite


## VirtualUnit.damage (objs.xml actdam): any hit sends the box "dam", which is actOsn.
## Interact.actOsn: a knop with allact then Location.allAct (open the linked door).
func _on_button(node: Node) -> void:
	_box_act(node)
	var act := str(node.get_meta("allact", ""))
	if act != "" and str(node.get_meta("id", "")) in _KNOPS:
		all_act(act, str(node.get_meta("allid", "")))
	_run_terminal(node)


## Interact.act scrTouch: the first act runs it instead of the act.
func _box_touch(node: Node) -> bool:
	var eves: Dictionary = node.get_meta("eves", {})
	if not eves.has("touch") or bool(node.get_meta("touched", false)):
		return false
	node.set_meta("touched", true)
	run_actions(eves["touch"], "", node, "touch")
	return true


## Interact.act on a knop: it toggles open (scrOpen / scrClose; autoclose
## shuts it after that many ticks), then scrAct runs.
func _box_act(node: Node) -> void:
	var eves: Dictionary = node.get_meta("eves", {})
	if eves.has("open") or eves.has("close") or str(node.get_meta("id", "")) in _KNOPS:
		var now := Time.get_ticks_msec()
		var open := bool(node.get_meta("box_open", false)) and now < int(node.get_meta("close_at", 0))
		open = not open
		node.set_meta("box_open", open)
		var auto := int(node.get_meta("autoclose", 0))
		node.set_meta("close_at", now + auto * 1000 / 30 if auto > 0 else 1 << 62)
		var pic := node.get_node_or_null("Visual") as Sprite2D
		_ObjArt.set_state(pic, "open" if open else "close")
		if open and auto > 0 and pic != null:
			get_tree().create_timer(auto / 30.0).timeout.connect(func() -> void:
				if is_instance_valid(pic) and Time.get_ticks_msec() >= int(node.get_meta("close_at", 0)):
					_ObjArt.set_state(pic, "close"))
		var eve := "open" if open else "close"
		run_actions(eves.get(eve, []), "", node, eve)
	run_actions(node.get_meta("actions", []), "", node)


func _spawn_areas(rows: Array) -> void:
	for row_v in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var rect: Array = row.get("rect", [0, 0, 40, 40])
		var area := Area2D.new()
		area.position = Vector2(float(rect[0]), float(rect[1]))
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitoring = bool(row.get("enabled", true))
		area.monitorable = false
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(float(rect[2]), float(rect[3]))
		shape.position = box.size * 0.5
		shape.shape = box
		area.add_child(shape)
		area.set_meta("enabled", bool(row.get("enabled", true)))
		area.set_meta("once", bool(row.get("once", false)))
		area.set_meta("mess", str(row.get("mess", "")))
		area.set_meta("actions", row.get("actions", []))
		# Area.as attributes: scr / scrout, trig (once per run by uid), mess
		# (a txt id), down, allact / allid. The stable's rows carry only
		# their rect, so their attributes come from rooms_begin.
		var attrs: Dictionary = row.get("attrs", {}) if row.has("attrs") else _begin_area_attrs(row)
		if not row.has("attrs") and attrs.has("scr"):
			area.set_meta("actions", _Registry.script(str(attrs.scr)).get("acts", []))
		var out: Array = row.get("out_actions", [])
		if out.is_empty() and attrs.has("scrout"):
			out = _Registry.script(str(attrs.scrout)).get("acts", [])
		area.set_meta("out_actions", out)
		area.set_meta("trig", attrs.has("trig"))
		area.set_meta("mess_id", str(attrs.get("mess", "")))
		area.set_meta("down", attrs.has("down"))
		area.set_meta("allact", str(attrs.get("allact", "")))
		area.set_meta("allid", str(attrs.get("allid", "")))
		area.add_to_group("land_area")
		area.body_entered.connect(_on_area.bind(area))
		area.body_exited.connect(_on_area_out.bind(area))
		var uid := str(row.get("uid", ""))
		add_child(area)
		if _AreaFx.wants(attrs):
			var fx: Node2D = _AreaFx.new()
			fx.setup(area, row, attrs, get_parent())
			area.add_child(fx)
		if uid != "":
			_areas[uid] = area
			_by_uid[uid] = area


func _wake_areas() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	for area_v in _areas.values():
		var area := area_v as Area2D
		if area.get_meta("enabled", false) and area.overlaps_body(player):
			_on_area(player, area)


func _on_area(body: Node, area: Area2D) -> void:
	if not body.is_in_group("player") or not bool(area.get_meta("enabled", false)):
		return
	var mess_id := str(area.get_meta("mess_id", ""))
	var mess := _txt(mess_id).replace("[br]", "\n") if mess_id != "" else str(area.get_meta("mess", ""))
	if mess != "":
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_message"):
			hud.show_message(mess, bool(area.get_meta("down", false)))
	var uid := ""
	for key in _areas.keys():
		if _areas[key] == area:
			uid = str(key)
			break
	_trip = _area_rect(area)
	if str(area.get_meta("allact", "")) != "":
		all_act(str(area.get_meta("allact")), str(area.get_meta("allid", "")))
	ScriptsEngine.area_over(area, uid, _plain_steps(area.get_meta("actions", [])), bool(area.get_meta("trig", false)))
	for step_v in area.get_meta("actions", []):
		if str((step_v as Dictionary).get("act", "")) == "notice":
			_notice(str(step_v.get("val", "")))
	if bool(area.get_meta("once", false)):
		area.set_meta("enabled", false)
		area.set_deferred("monitoring", false)


## Area.scrOut.
func _on_area_out(body: Node, area: Area2D) -> void:
	if not body.is_in_group("player") or not bool(area.get_meta("enabled", false)):
		return
	ScriptsEngine.area_out(area, _plain_steps(area.get_meta("out_actions", [])))


func _plain_steps(steps: Array) -> Array:
	return steps.filter(func(s: Variant) -> bool: return s is Dictionary and str(s.get("act", "")) != "notice")


func _switch_area(area: Node, enabled: bool) -> void:
	area.set_meta("enabled", enabled)
	if area is Area2D:
		(area as Area2D).set_deferred("monitoring", enabled)
		if enabled:
			var player := get_tree().get_first_node_in_group("player")
			if player and (area as Area2D).overlaps_body(player):
				_on_area.call_deferred(player, area)


## The rooms_begin area under a stable area row: its cell is the rect's
## bottom-left tile (Area: x, y is the lowest row).
func _begin_area_attrs(row: Dictionary) -> Dictionary:
	var rect: Array = row.get("rect", [0, 0, 40, 40])
	var room: Array = row.get("room", [0, 0])
	var rx := int(room[0])
	var ry := int(room[1])
	var cx := int(round((float(rect[0]) - float(rx * ROOM_W * TILE)) / TILE))
	var cy := int(round((float(rect[1]) + float(rect[3]) - float(ry * ROOM_H * TILE)) / TILE)) - 1
	return _attrs_at(rx, ry, cx, cy, "area")


func _area_rect(area: Area2D) -> Rect2:
	var shape_node := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is RectangleShape2D):
		return Rect2()
	var size := (shape_node.shape as RectangleShape2D).size
	return Rect2(area.global_position, size)


func _interact() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var origin := player.global_position
	var best: Node = null
	var best_d := 72.0
	var kind := ""
	for door in _doors:
		if not bool(door.get_meta("usable", false)):
			continue
		var gap := origin.distance_to(_center(door))
		if gap < best_d:
			best = door
			best_d = gap
			kind = "door"
	for button in _buttons:
		var gap2 := origin.distance_to(button.get_meta("feet", button.global_position))
		if gap2 < best_d:
			best = button
			best_d = gap2
			kind = "button"
	for passage in _passages:
		if not bool(passage.get_meta("usable", true)):
			continue
		var gap5 := origin.distance_to(passage.get_meta("feet", passage.global_position))
		if gap5 < best_d:
			best = passage
			best_d = gap5
			kind = "passage"
	for node in _uses:
		if not is_instance_valid(node) or not bool(node.get_meta("usable", true)):
			continue
		var gap6 := origin.distance_to((node as Node2D).global_position)
		if gap6 < best_d:
			best = node
			best_d = gap6
			kind = "use"
	var body_rect := _player_rect(player)
	for crate in _loot:
		if not is_instance_valid(crate) or bool(crate.get_meta("spent", false)):
			continue
		var gap3 := _rect_gap(body_rect, _crate_rect(crate))
		if gap3 <= LOOT_REACH and gap3 < best_d:
			best = crate
			best_d = gap3
			kind = "loot"
	for drop in get_tree().get_nodes_in_group("ground_loot"):
		if not is_instance_valid(drop) or not drop is Node2D or bool(drop.get_meta("taken", false)):
			continue
		var gap4 := _rect_gap(body_rect, _drop_rect(drop as Node2D))
		if gap4 <= DROP_REACH and gap4 < best_d:
			best = drop
			best_d = gap4
			kind = "drop"
	if best == null:
		return
	if player.has_method("tele_blocks_use") and bool(player.tele_blocks_use(best)):
		return
	if kind == "door":
		_use_door(best)
	elif kind == "button":
		if _box_touch(best) or _hold_for_roll(best):
			return
		if not _pass_lock(best):
			return
		_box_act(best)
		_run_terminal(best)
	elif kind == "drop":
		if best.has_method("pickup"):
			best.pickup()
	elif kind == "passage":
		_go_through(best)
	elif kind == "use":
		use_prop(best)
	else:
		_open_loot(best)


func use_prop(node: Node) -> bool:
	if _wooden_wall(node):
		return false
	if _doors.has(node):
		_use_door(node)
		return true
	if _passages.has(node):
		_go_through(node)
		return true
	if _uses.has(node):
		if _hold_for_roll(node):
			return true
		if int(node.get_meta("mine", 0)) > 0 or float(node.get_meta("lock", 0.0)) > 0.0 or node.has_meta("fun"):
			_pass_lock(node)
			return true
		if node.has_meta("cont") and not _RoomFlags.allows("containers", _point_of(node)):
			return true
		_use_object(node, false)
		return true
	if _buttons.has(node):
		if _box_touch(node) or _hold_for_roll(node) or _hold_for_time(node):
			return true
		if not _pass_lock(node):
			return true
		_on_button(node)
		return true
	if _loot.has(node):
		_open_loot(node)
		return true
	if node.is_in_group("ground_loot") and node.has_method("pickup"):
		node.pickup()
		return true
	# A floor box you can already lift is the same container walk-up opens.
	if node.is_in_group("levitatable") and not node.is_in_group("enemies"):
		_open_loot(node)
		return true
	return false


func commit_use(node: Node) -> void:
	if _wooden_wall(node):
		return
	if _doors.has(node):
		_use_door(node, true)
	elif _uses.has(node):
		if int(node.get_meta("mine", 0)) > 0 or float(node.get_meta("lock", 0.0)) > 0.0:
			_pass_lock(node)
		else:
			_use_object(node, true)
	elif _buttons.has(node):
		if not _pass_lock(node):
			return
		_on_button(node)
	elif _loot.has(node):
		_open_loot(node, true)
	elif _passages.has(node):
		_go_through(node, true)


func _hold_for_roll(node: Node) -> bool:
	if not _Lock.needs_wait(node):
		return false
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("begin_use_timer"):
		player.begin_use_timer(node)
		_PropSfx.act(node)
		return true
	return false


## Interact.t_action (objs.xml time): once unlocked, the use still takes that long.
func _hold_for_time(node: Node) -> bool:
	if int(node.get_meta("act_time", 0)) <= 0:
		return false
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("begin_use_timer"):
		player.begin_use_timer(node)
		_PropSfx.act(node)
		return true
	return false


func _use_door(body: Node, from_timer: bool = false) -> void:
	if _wooden_wall(body):
		return
	if bool(body.get_meta("door_open", false)):
		_apply_door(body, false)
		return
	if not from_timer and _hold_for_roll(body):
		return
	if not from_timer and int(body.get_meta("act_time", 0)) > 0:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("begin_use_timer"):
			player.begin_use_timer(body)
			return
	if not _pass_lock(body):
		return
	# Opening clears the lock, same as Interact.setAct("open").
	body.set_meta("lock", 0.0)
	_apply_door(body, true)
	_run_terminal(body)


func _player_rect(player: Node2D) -> Rect2:
	var shape_node := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		var box := shape_node.shape as RectangleShape2D
		var origin := player.to_global(shape_node.position - box.size * 0.5)
		return Rect2(origin, box.size)
	return Rect2(player.global_position - Vector2(25, 64), Vector2(50, 64))


func _drop_rect(drop: Node2D) -> Rect2:
	var size: Vector2 = drop.get_meta("size", Vector2(24, 16))
	return Rect2(drop.global_position - Vector2(size.x * 0.5, size.y), size)


func _crate_rect(crate: Node) -> Rect2:
	var size: Vector2 = crate.get_meta("size", Vector2(40, 40))
	if crate is Node2D:
		return Rect2((crate as Node2D).global_position, size)
	var feet: Vector2 = crate.get_meta("feet", Vector2.ZERO)
	return Rect2(feet - Vector2(size.x * 0.5, size.y), size)


func _rect_gap(a: Rect2, b: Rect2) -> float:
	if a.intersects(b):
		return 0.0
	var dx := 0.0
	if a.end.x < b.position.x:
		dx = b.position.x - a.end.x
	elif b.end.x < a.position.x:
		dx = a.position.x - b.end.x
	var dy := 0.0
	if a.end.y < b.position.y:
		dy = b.position.y - a.end.y
	elif b.end.y < a.position.y:
		dy = a.position.y - b.end.y
	return sqrt(dx * dx + dy * dy)


func _open_loot(crate: Node, from_timer: bool = false) -> void:
	if bool(crate.get_meta("spent", false)) or bool(crate.get_meta("opened", false)):
		return
	# Location.base: containers stay shut.
	if not _RoomFlags.allows("containers", _point_of(crate)):
		return
	if bool(crate.get_meta("dead", false)) or bool(crate.get_meta("prize_locked", false)):
		return
	if not from_timer and (_box_touch(crate) or _hold_for_roll(crate) or _hold_for_time(crate)):
		return
	if not _pass_lock(crate):
		return
	crate.set_meta("spent", true)
	crate.set_meta("opened", true)
	_show_opened(crate)
	_PropSfx.node_obj(crate, "open")
	var spilled := _spill_contents(crate)
	var term := _terminal_act(crate) != ""
	if spilled == 0 and not term:
		_notice(OriginalLines.info("itsEmpty"))
	run_actions(crate.get_meta("actions", []), "", crate)
	_run_terminal(crate)


func _show_opened(crate: Node) -> void:
	# Interact.setAct("loot") calls setVisState("open"): frame 2 when the clip has it.
	# A container with no open frame stays on the closed picture. It is not removed.
	var visual := crate.get_node_or_null("Visual") as Sprite2D
	if visual == null:
		return
	visual.visible = true
	var open_path := _prop_png(str(crate.get_meta("id", "")), true)
	if open_path == "":
		visual.modulate = Color.WHITE
		return
	var tex := _load_tex(open_path)
	if tex == null:
		visual.modulate = Color.WHITE
		return
	visual.texture = tex
	visual.modulate = Color.WHITE


func _spill_contents(crate: Node, broken := false) -> int:
	var size: Vector2 = crate.get_meta("size", Vector2(40, 40))
	var at := Vector2.ZERO
	if crate is Node2D:
		at = (crate as Node2D).global_position + Vector2(size.x * 0.5, size.y * 0.5)
	var count := 0
	# LootGen.newLoot: a smashed container's items come out at multHP 0.4.
	var mult := 0.4 if broken else 1.0
	for item_v in crate.get_meta("items", []):
		if typeof(item_v) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_v
		var id := str(item.get("id", ""))
		var n := _Loot.caps_count(id, int(item.get("n", 1)))
		if broken:
			n = _Loot.broken_count(id, n)
		if _spill(id, n, at, mult):
			count += 1
	var cont := str(crate.get_meta("cont", ""))
	if cont != "" and cont != "empty" and cont != "*":
		for drop_v in _Loot.roll(cont, broken):
			if typeof(drop_v) != TYPE_DICTIONARY:
				continue
			var drop: Dictionary = drop_v
			if _spill(str(drop.get("id", "")), int(drop.get("n", 1)), at, mult):
				count += 1
	return count


## Box.udarBullet (crack) and Box.damage: a crowbar blow on a locked container
## with contents (bulPlayer) takes destroy - thre off the box's hp. At 0 the
## box dies: Interact.dieCont spills broken loot, sets off its mine and opens it.
## Returns true when the box caught the blow.
func break_crate(crate: Node, destroy: float) -> bool:
	if not _loot.has(crate) or bool(crate.get_meta("opened", false)) or bool(crate.get_meta("dead", false)):
		return false
	var cont := str(crate.get_meta("cont", ""))
	if cont == "" or cont == "empty" or float(crate.get_meta("lock", 0.0)) <= 0.0 or int(crate.get_meta("locktip", 1)) > 1:
		return false
	damage_box(crate, destroy)
	return true


## Box.damage: destroy - thre off the box's hp. Box.die of a prize box does nothing;
## otherwise a box with contents runs Interact.dieCont.
func damage_box(crate: Node, destroy: float) -> void:
	if not _loot.has(crate) or bool(crate.get_meta("dead", false)):
		return
	var info := _Registry.obj(str(crate.get_meta("id", "")))
	var hp := float(crate.get_meta("box_hp", float(str(info.get("hp", "100")))))
	var dam := destroy - float(str(info.get("thre", "0")))
	if dam > 0.0:
		hp -= dam
	crate.set_meta("box_hp", hp)
	if hp > 0.0 or bool(crate.get_meta("prize", false)):
		return
	crate.set_meta("dead", true)
	var cont := str(crate.get_meta("cont", ""))
	if cont != "":
		_die_cont(crate)


## Blast disk: explcrack safes and any crate a crowbar could smash. Original
## Bullet.explosion only Box.damage(targetObj); the port hits every such box
## whose rect meets the disk (PORT_RULES).
func blast_boxes(center: Vector2, radius: float, destroy: float) -> void:
	if destroy <= 0.0 or radius <= 0.0:
		return
	var reach := radius * radius
	for crate in _loot:
		if not is_instance_valid(crate) or not crate is Node2D:
			continue
		if bool(crate.get_meta("dead", false)) or bool(crate.get_meta("opened", false)):
			continue
		if not _box_in_blast(crate as Node2D, center, reach):
			continue
		if _explodes_open(crate):
			damage_box(crate, destroy)
		else:
			break_crate(crate, destroy)


func _box_in_blast(crate: Node2D, center: Vector2, reach: float) -> bool:
	var size: Vector2 = crate.get_meta("size", Vector2(40, 40))
	var box := Rect2(crate.global_position, size)
	var closest := Vector2(
		clampf(center.x, box.position.x, box.end.x),
		clampf(center.y, box.position.y, box.end.y)
	)
	return closest.distance_squared_to(center) <= reach


func _explodes_open(crate: Node) -> bool:
	return str(_Registry.obj(str(crate.get_meta("id", ""))).get("explcrack", "")) != ""


## PhisBullet.run: a player's sticky charge (throwtip 2) clings to the box under the
## cursor when that box opens to explosions (explcrack) and the charge is inside it.
func sticky_box(at: Vector2, cursor: Vector2) -> Node:
	for crate in _loot:
		if not is_instance_valid(crate) or not crate is Node2D or bool(crate.get_meta("dead", false)):
			continue
		if str(_Registry.obj(str(crate.get_meta("id", ""))).get("explcrack", "")) == "":
			continue
		var size: Vector2 = crate.get_meta("size", Vector2(40, 40))
		var box := Rect2((crate as Node2D).global_position, size)
		if box.has_point(at) and box.has_point(cursor):
			return crate
	return null


func _die_cont(crate: Node) -> void:
	var looted := bool(crate.get_meta("opened", false))
	crate.set_meta("lock", 0.0)
	crate.set_meta("spent", true)
	crate.set_meta("opened", true)
	_show_opened(crate)
	if not looted:
		_spill_contents(crate, true)
	var mine := int(crate.get_meta("mine", 0))
	if mine > 0:
		crate.set_meta("mine", 0)
		_notice(OriginalLines.info("remineZhopa"))
		if int(crate.get_meta("mine_tip", 3)) == 6:
			_raise_alarm(_point_of(crate))
			robocells(_point_of(crate))
		else:
			_blast(_point_of(crate), 260.0, int(round(float(mine) * 50.0 * (0.8 + randf() * 0.4))))
	run_actions(crate.get_meta("actions", []), "", crate)


func _spill(id: String, n: int, at: Vector2, mult_hp := 1.0) -> bool:
	if id == "" or n < 1:
		return false
	var drop := _Drop.new() as Node2D
	drop.set("item_id", id)
	drop.set("stack", maxi(1, n))
	if mult_hp < 1.0:
		drop.set_meta("mult_hp", mult_hp)
	add_child(drop)
	drop.global_position = at
	if drop.has_method("shove_clear"):
		drop.shove_clear()
	return true


## mult_hp: Item.multHP; ItemInteraction gives a taken weapon or armor maxhp * multHP.
func grant_dropped(id: String, n: int, mult_hp := 1.0) -> void:
	var lines: PackedStringArray = PackedStringArray()
	_grant(id, n, lines, mult_hp)
	if not lines.is_empty():
		_notice(", ".join(lines))


func _grant(id: String, n: int, lines: PackedStringArray, mult_hp := 1.0) -> void:
	if id == "" or n < 1:
		return
	var give := n
	var base := id.trim_suffix("^1")
	# Invent.take: a weapon already owned mends it, a ^1 copy upgrades the plain one.
	if not Vendors.weapon_data(base).is_empty() and Vendors.owned_variant(base) >= 0 \
			and (Inventory.count(base) > 0 or Inventory.count(base + "^1") > 0):
		Vendors.take_weapon(id, mult_hp, 0)
		collected_item(id, false)
		return
	if _Loot.is_single(id):
		give = 1
		if Inventory.count(id) > 0:
			return
	var first := Inventory.count(id) == 0
	Inventory.add(id, give)
	if first and mult_hp < 1.0:
		if Condition.is_durable_weapon(id):
			Condition.set_weapon_hp(id, float(Condition.weapon_max(id)) * mult_hp)
		elif Condition.is_armor(id):
			Condition.set_armor_hp(id, float(Condition.armor_max(id)) * mult_hp)
	var label := Inventory.name_of(id)
	if give > 1:
		label = "%s x%d" % [label, give]
	lines.append(label)
	ScriptsEngine.item_taken(id, first)


func _set_door(uid: String, is_open: bool, lock: float) -> void:
	var body: Node = _by_uid.get(uid)
	if body == null:
		return
	if lock >= 0.0:
		body.set_meta("lock", lock)
	_apply_door(body, is_open)


func _apply_door(body: Node, is_open: bool) -> void:
	if _wooden_wall(body):
		if not bool(body.get_meta("dead", false)):
			_DoorArt.apply(body, false)
		return
	if bool(body.get_meta("door_open", false)) != is_open and not bool(body.get_meta("dead", false)):
		_PropSfx.node_obj(body, "open" if is_open else "close")
	_DoorArt.apply(body, is_open)
	var stand_in := body.get_node_or_null("StandIn") as CanvasItem
	if stand_in:
		stand_in.visible = not is_open


## objs.xml septum is tip=door so tiles take its hp, but it has no inter.
## A placed inter="0" still builds Interact with action 0. Interact.act
## returns immediately: no open, no close, no lockpick, no hack.
## Breakage is Tile.udar / the die clip, not the door swing.
func _wooden_wall(node: Node) -> bool:
	return node != null and str(node.get_meta("door_id", "")) == "septum"


func _shut_wooden_walls() -> void:
	var root := get_parent().get_node_or_null("Doors")
	if root == null:
		return
	for body in root.get_children():
		if not _wooden_wall(body):
			continue
		body.set_meta("usable", false)
		if body.has_meta("locktip"):
			body.remove_meta("locktip")
		body.remove_from_group("tk_use")
		_doors.erase(body)
		if not bool(body.get_meta("dead", false)):
			_DoorArt.apply(body, false)


## Interact.explosion: Bullet.iExpl from a fresh Unit (fraction 0, destroy 0).
func _blast(at: Vector2, radius: float, damage: int) -> void:
	var host := get_tree().current_scene
	if host == null or damage <= 0:
		return
	var b := preload("res://scenes/bullet.tscn").instantiate() as Area2D
	b.from_player = false
	b.fraction = 0
	b.damage = damage
	b.damage_type = "DAM_EXPLOSION"
	b.block_damage = 0
	b.blast_radius = radius
	b.explode_on_timeout = true
	b.use_velocity = true
	b.velocity = Vector2.ZERO
	b.speed = 0.0
	b.lifetime = 0.02
	b.style = "grenade"
	host.add_child(b)
	b.global_position = at


func _center(body: Node) -> Vector2:
	var size := Vector2(float(body.get_meta("door_w", 40)), float(body.get_meta("door_h", 80)))
	return body.global_position + size * 0.5


func _notice(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notice"):
		hud.show_notice(text)


func _index_bound_rooms() -> void:
	_room_attrs.clear()
	for room_v in _bound_rooms:
		if typeof(room_v) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = room_v
		var rx := int(room.get("x", 0))
		var ry := int(room.get("y", 0))
		for obj_v in room.get("objs", []):
			if typeof(obj_v) != TYPE_DICTIONARY:
				continue
			var obj: Dictionary = obj_v
			if str(obj.get("tag", "obj")) != "obj":
				continue
			var key := "%d,%d,%d,%d,%s" % [rx, ry, int(obj.get("x", 0)), int(obj.get("y", 0)), str(obj.get("id", ""))]
			var attrs: Variant = obj.get("attrs", {})
			_room_attrs[key] = attrs if typeof(attrs) == TYPE_DICTIONARY else {}


func _plan_doors() -> Array:
	var rows: Array = []
	for row_v in _plan_rows:
		var row: Dictionary = row_v
		if str(row.cat) != "door":
			continue
		rows.append({
			"room": row.room,
			"cell": row.cell,
			"uid": row.uid,
			"lock": float(row.get("lock", 0.0)),
			"open": bool(row.get("open", false)),
			"usable": true,
		})
	return rows


func _queue_plan() -> void:
	for row_v in _plan_rows:
		var row: Dictionary = row_v
		var key: String = _memory.queue_key(row)
		if not _pending.has(key):
			_pending[key] = []
			_pending_order.append(key)
		(_pending[key] as Array).append(row)
		if str(row.cat) == "bonus" and str(row.id) == "xp":
			_xp_left[key] = int(_xp_left.get(key, 0)) + 1
	var from := _room_of(_plan_from)
	_pending_order.sort_custom(func(a: String, b: String) -> bool:
		return _room_gap(a, from) < _room_gap(b, from))


## Rooms the AI wakes for (enemy ACTIVE_REACH 1) are spawned at once.
func _spawn_near(key: String) -> void:
	var at := _key_room(key)
	for other in _pending_order.duplicate():
		if _room_gap(other, at) <= 1:
			_spawn_room(other)


func _spawn_pending() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_spawn_near(_room_key_of(player.global_position))
	# Far rooms trickle in row by row under a per-frame budget. A unit whose
	# sheet is still decoding on a worker waits for a later frame.
	var until := Time.get_ticks_usec() + SPAWN_BUDGET_USEC
	while not _pending_order.is_empty() and Time.get_ticks_usec() < until:
		var key := str(_pending_order[0])
		var rows: Array = _pending.get(key, [])
		if rows.is_empty():
			_pending.erase(key)
			_pending_order.remove_at(0)
			continue
		var uid := str((rows[0] as Dictionary).get("unit_id", ""))
		if uid != "" and not _EnemyScript.species_ready(uid):
			break
		_spawn_row(rows.pop_front())


func _spawn_room(key: String) -> void:
	var rows: Array = _pending.get(key, [])
	_pending.erase(key)
	_pending_order.erase(key)
	for row_v in rows:
		_spawn_row(row_v)


func _spawn_row(row: Dictionary) -> void:
	if _memory.skips(row):
		return
	var before := get_child_count()
	_spawn_row_kind(row)
	if get_child_count() > before:
		_RadSource.attach(get_child(before), str(row.get("id", "")))
		var sign := int(str((row.get("attrs", {}) as Dictionary).get("sign", "0")))
		if sign > 0:
			_signs.set_sign(get_child(before), sign)
	_memory.spawned(row, before)


func _spawn_row_kind(row: Dictionary) -> void:
	var cat := str(row.cat)
	match cat:
		"unit":
			# UnitTurret / UnitRaider: a map fraction F_PLAYER (100) is an ally with warn 0.
			if bool(row.get("supported", false)) and str((row.get("attrs", {}) as Dictionary).get("fraction", "")) == "100":
				_spawn_plan_unit(row, true)
			elif bool(row.get("supported", false)) and not bool(row.get("friendly", false)):
				_spawn_plan_unit(row)
			elif bool(row.get("supported", false)) and str(row.get("cl", "")) == "UnitTurret":
				# Location.createUnit homeStable: live, fraction F_PLAYER, warn 0.
				_spawn_plan_unit(row, true)
			else:
				_spawn_stand_in(row)
		"container":
			_spawn_loot([_loot_row(row)])
		"mine":
			if bool(row.get("supported", false)):
				_spawn_plan_unit(row)
			else:
				_spawn_stand_in(row)
		"button", "alarm":
			if row.has("unit_id") and bool(row.get("supported", false)):
				_spawn_plan_unit(row)
			elif row.has("unit_id"):
				_spawn_stand_in(row)
			else:
				var battrs: Dictionary = row.get("attrs", {})
				_spawn_buttons([{
					"id": row.id,
					"feet": row.feet,
					"room": row.room,
					"bullet": str(row.id) == "knop2",
					"actions": _acts(row, [""]),
					"eves": _box_eves(row),
					"autoclose": int(battrs.get("autoclose", 0)),
					"allact": str(battrs.get("allact", "")),
					"allid": str(battrs.get("allid", "")),
				}])
		"trap":
			if str(row.get("cl", "")) == "":
				_spawn_traps([{"feet": row.feet, "damage": int(row.get("damage", 50)), "ceiling": bool(row.get("ceiling", false))}])
			elif _Trap.UNITS.has(str(row.get("unit_id", ""))):
				spawn_trap_unit(row)
			else:
				_spawn_stand_in(row)
		"laser":
			if _Trap.UNITS.has(str(row.get("unit_id", ""))):
				spawn_trap_unit(row)
			else:
				_spawn_stand_in(row)
		"area":
			_spawn_areas([{
				"uid": row.uid,
				"room": row.room,
				"rect": row.rect,
				"enabled": bool(row.get("enabled", true)),
				"once": false,
				"mess": _txt(str(row.get("mess", ""))),
				"actions": _acts(row, ["", "over"]),
				"out_actions": _acts(row, ["out"]),
				"attrs": row.get("attrs", {}),
			}])
		"npc":
			_spawn_npc(row)
		"bonus":
			_spawn_bonus(row)
		"transition":
			_spawn_passage(row)
		"checkpoint":
			_spawn_checkpoint(row)
		"station":
			var node := _spawn_stand_in(row)
			if str(row.id) == "wmap":
				_add_use(node, "beginm")
			elif STATION_ACTS.has(str(row.id)):
				_add_use(node, "use")
				node.set_meta("allact", STATION_ACTS[str(row.id)])
		"enspawn":
			_en_spawn.add_point(row)
		"prob":
			var trial: Node = _Trial.new()
			trial.setup(row, self)
			add_child(trial)
		"door", "spawnpoint":
			pass
		"platform":
			var plat: Node2D = _Platform.new()
			plat.setup(row)
			add_child(plat)
			# Location.allAct reaches allid objects without a uid too.
			var key := str(row.get("uid", ""))
			if key == "" and plat.has_meta("allid"):
				key = "_plat_%d" % plat.get_instance_id()
			if key != "":
				_by_uid[key] = plat
		_:
			var stand := _spawn_stand_in(row)
			var id := str(row.get("id", ""))
			_MolnTrap.attach(stand, id, _Registry.obj(id), row.get("attrs", {}))


## UnitNPC / UnitCaptive / UnitPonPon / UnitTrain: scripts/story/npc.gd.
func _spawn_npc(row: Dictionary) -> void:
	var node: Node2D = _Npc.new()
	node.setup(row, self)
	add_child(node)
	if str(row.get("uid", "")) != "":
		_by_uid[str(row.uid)] = node
	var usable := bool(node.get_meta("usable", true))
	_add_use(node, node.user_action())
	node.set_meta("usable", usable)


## UnitTrigger / UnitDamager / UnitTrap: scripts/map/trap_unit.gd. Triggers make
## their damagers through this too.
func spawn_trap_unit(row: Dictionary) -> Node2D:
	var node: Node2D = _Trap.new()
	node.setup(row, self)
	node.set("die_actions", _acts(row, ["", "die"]))
	add_child(node)
	if str(row.get("uid", "")) != "":
		_by_uid[str(row.uid)] = node
	_add_use(node, node.user_action())
	node.refresh_use()
	return node


func _spawn_plan_unit(row: Dictionary, player_side := false) -> void:
	var enemy := _Enemy.instantiate() as CharacterBody2D
	var feet: Array = row.feet
	enemy.position = Vector2(float(feet[0]), float(feet[1]))
	var unit_id := str(row.unit_id)
	if player_side:
		enemy.set_meta("player_side", true)
	enemy.set_meta("unit_id", unit_id)
	enemy.name = unit_id
	enemy.add_to_group(unit_id)
	enemy.set_meta("room_x", int(row.room[0]))
	enemy.set_meta("room_y", int(row.room[1]))
	enemy.set_meta("level", int(row.get("level", 0)))
	enemy.set_meta("hero", int(row.get("hero", 0)))
	enemy.set_meta("tr", int(row.get("tr", 0)))
	var attrs: Dictionary = row.get("attrs", {})
	for key in ["ai", "dig", "observ", "qid", "trig", "noagro", "dis", "hidden", "pole"]:
		if attrs.has(key):
			enemy.set_meta("ai_tip" if key == "ai" else key, str(attrs[key]))
	var turn := int(float(str(attrs.get("turn", "0"))))
	if turn != 0:
		enemy.set("facing", 1.0 if turn > 0 else -1.0)
	var die := _acts(row, ["", "die"])
	if attrs.has("qid"):
		die.append({"act": "_qid", "val": str(attrs.qid)})
	enemy.set("die_actions", die)
	_add_scripts_meta(row, enemy)
	if str(row.uid) != "":
		_by_uid[str(row.uid)] = enemy
	# Unit.unres: alarms (budilo) never wake it.
	if attrs.has("unres"):
		enemy.set_meta("unres", true)
	add_child(enemy)
	# UnitRaider: map weap replaces the rolled weapon; emit vortices to release when it spots the target.
	if bool(enemy.get("_raider_type")):
		if str(attrs.get("weap", "")) != "" and enemy.has_method("_arm"):
			enemy.call("_arm", str(attrs.weap))
		if attrs.has("emit"):
			enemy.set("_vortex_left", int(float(str(attrs.emit))))
	_rank_unit(enemy, int(row.get("level", 0)), int(row.get("hero", 0)), float(str(attrs.get("hpmult", attrs.get("multhp", "1")))))


## Unit.setLevel and Unit.setHero, after the species stats are in.
func _rank_unit(enemy: Node, level: int, hero: int, hpmult: float) -> void:
	var hp_k := (1.0 + float(level) * 0.11) * maxf(hpmult, 0.01)
	var dam_k := 1.0 + float(level) * 0.07
	match hero:
		1:
			hp_k *= 2.5
			dam_k *= 1.8
		2, 3:
			hp_k *= 3.0
			dam_k *= 1.2
		4:
			hp_k *= 2.0
			dam_k *= 1.4
	var top := maxi(1, int(round(float(int(enemy.get("max_hp"))) * hp_k)))
	enemy.set("max_hp", top)
	enemy.set("hp", top)
	enemy.set("melee_damage", maxi(1, int(round(float(int(enemy.get("melee_damage"))) * dam_k))))
	enemy.set("_bullet_damage", maxi(1, int(round(float(int(enemy.get("_bullet_damage"))) * dam_k))))
	if hero > 0:
		enemy.set("points", int(enemy.get("points")) * 5)


func _loot_row(row: Dictionary) -> Dictionary:
	var loot := {
		"id": row.id,
		"feet": row.feet,
		"w": float(row.get("w", 40)),
		"h": float(row.get("h", 40)),
		"lock": float(row.get("lock", 0.0)),
		"items": row.get("items", []),
		"room": row.room,
		"actions": _acts(row, [""]),
		"eves": _box_eves(row),
		"prize": str((row.get("attrs", {}) as Dictionary).get("prize", "")) != "",
		"open": bool(row.get("open", false)),
	}
	var attrs: Dictionary = row.get("attrs", {})
	if attrs.has("cont"):
		loot["cont"] = str(attrs.cont)
	return loot


## Bonus.take: unXp each, and unXp * maxXp for the last of a generated room's set.
func _spawn_bonus(row: Dictionary) -> void:
	var area := Area2D.new()
	var feet: Array = row.feet
	area.position = Vector2(float(feet[0]), float(feet[1]))
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(TILE, TILE)
	shape.shape = box
	area.add_child(shape)
	if _ObjArt.has("bonus_xp"):
		var pic := _ObjArt.sprite("bonus_xp")
		pic.z_index = 1
		area.add_child(pic)
	else:
		var glow := _quad(Vector2(16, 16), Color(0.55, 0.95, 0.55, 0.85), Vector2(-8, -8))
		glow.rotation = PI * 0.25
		area.add_child(glow)
	area.add_to_group("land_bonus")
	area.body_entered.connect(_on_bonus.bind(area, row))
	add_child(area)


func _on_bonus(body: Node, area: Area2D, row: Dictionary) -> void:
	if not body.is_in_group("player") or bool(area.get_meta("taken", false)):
		return
	area.set_meta("taken", true)
	area.set_deferred("monitoring", false)
	_bonus_vanish(area)
	if str(row.id) != "xp" or Progression == null:
		return
	var key := "%d,%d" % [int(row.room[0]), int(row.room[1])]
	var left := int(_xp_left.get(key, 1)) - 1
	_xp_left[key] = left
	var top := int(row.get("max", 0))
	var each := int(row.get("xp", 100))
	Progression.add_xp(each * top if left == 0 and top > 1 else each)
	if left == 0 and top > 1 and not _detected_rooms.has(key):
		var summ := _room_xp_left(key)
		if summ > 0:
			Progression.add_xp(summ)
			_notice(OriginalLines.info("sneakBonus"))
	SfxBank.play("bonus2" if left == 0 and top > 1 else "bonus1")


## Location.detecting: some foe in the room has had the player as its target.
func note_detected(at: Vector2) -> void:
	_detected_rooms[_room_key_of(at)] = true


## Location.summXp: xp of the room's own units still standing (live spawns carry none).
func _room_xp_left(key: String) -> int:
	var summ := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("_dead") == true or node.get("_friendly") == true:
			continue
		if node.has_meta("wave") or node.has_meta("vortex_minion"):
			continue
		if _room_key_of((node as Node2D).global_position) == key:
			summ += int(node.get("points"))
	return summ


## Bonus.take: gotoAndPlay(2), the clip runs to its last frame at 30 fps, then the object goes.
func _bonus_vanish(area: Area2D) -> void:
	var pic := area.get_node_or_null("Visual") as Sprite2D
	var last := _ObjArt.frames("bonus_xp")
	if pic == null or last < 2:
		area.queue_free()
		return
	var tw := area.create_tween()
	tw.tween_method(func(f: float) -> void: pic.texture = _ObjArt.texture("bonus_xp", int(f)), 2.0, float(last) + 0.99, float(last - 1) / 30.0)
	tw.tween_callback(area.queue_free)


## comein, trial doors and doorout move the player to the linked spot.
## Interact.allAct: a dest `prob` is gotoProb (same land). allact exit with no
## prob is gotoNextLevel. A dest whose room is not built stays as data.
func _spawn_passage(row: Dictionary) -> void:
	var node := _spawn_stand_in(row)
	node.set_meta("id", str(row.get("id", "")))
	node.set_meta("uid", str(row.get("uid", "")))
	var attrs: Dictionary = row.get("attrs", {})
	var pid := str(attrs.get("prob", row.get("prob", "")))
	node.set_meta("dest_prob", pid)
	if pid != "":
		var title := OriginalLines.text("map", pid)
		if title != "":
			node.set_meta("title", title)
	var dest: Variant = row.get("target", null)
	var has_dest := dest is Array and (dest as Array).size() >= 2
	if has_dest:
		var at: Array = dest
		node.set_meta("target", Vector2(float(at[0]), float(at[1])))
	elif pid == "" and str(row.get("kind", "")) == "exit":
		node.set_meta("next_level", true)
	else:
		return
	node.set_meta("feet", Vector2(float(row.feet[0]), float(row.feet[1])))
	var hold := int(str(attrs.get("time", _Registry.obj(str(row.get("id", ""))).get("time", "0"))))
	node.set_meta("hold_use", hold > 0)
	node.set_meta("act_time", hold)
	if attrs.has("lock") or attrs.has("key"):
		_Lock.stamp(node, str(row.get("id", "")), float(row.get("lock", 0.0)), attrs)
	node.add_to_group("tk_use")
	_passages.append(node)


func _spawn_checkpoint(row: Dictionary) -> void:
	var cp: Area2D = _Checkpoint.new()
	var land := get_parent()
	var plan: Variant = land.get("plan") if land != null else null
	var ctx: Dictionary = (plan as Dictionary).get("ctx", {}) if plan is Dictionary else {}
	var owner_id := str(land.get("land_id")) if land != null and land.get("land_id") != null else "begin"
	cp.setup(row, ctx, owner_id)
	var feet: Array = row.feet
	_stamp_at(cp, str(row.id), float(row.get("lock", 0.0)), row.room, Vector2(float(feet[0]), float(feet[1])), _Checkpoint.SIZE)
	if str(row.get("uid", "")) != "":
		_by_uid[str(row.uid)] = cp
	add_child(cp)
	_uses.append(cp)


## allact map (Interact.inter 10) and exit (inter 9).
func _add_use(node: Node2D, action: String) -> void:
	node.set_meta("feet", node.global_position)
	node.set_meta("user_action", action)
	node.set_meta("usable", true)
	node.add_to_group("tk_use")
	_uses.append(node)


func _use_object(node: Node, from_timer: bool) -> void:
	_signs.clear(node)
	if node.has_method("use_object"):
		node.use_object(from_timer)
		return
	match str(node.get_meta("user_action", "")):
		"beginm":
			Travel.open_travel_map()
		"exit":
			Travel.goto_next_level()
		"use":
			_station_act(str(node.get_meta("allact", "")))


## Interact allact of the base furniture (objs.xml): work / lab / stove the
## PipBuck Ремесло page, vault Хранилище, stand the weapon stand, app the
## appearance screen.
func _station_act(act: String) -> void:
	match act:
		"work", "lab", "stove":
			Craft.open_station(act)
		"vault":
			Story.open_pip(9, 0)
		"stand":
			_Stand.open(get_tree())
		"app":
			Story.open_pip(8, 0)


## Location.base for the room at a world point (room options base="1").
func room_options_at(at: Vector2) -> Dictionary:
	var room := _room_of(at)
	for room_v in _bound_rooms:
		var r: Dictionary = room_v
		if int(r.get("x", -999)) == room.x and int(r.get("y", -999)) == room.y and int(r.get("z", 0)) == 0:
			return r.get("options", {})
	return {}


## Land.setGGToSpawnPoint for land room lx:ly: its player cell.
func room_spawn(lx: int, ly: int) -> Variant:
	for room_v in _bound_rooms:
		var r: Dictionary = room_v
		if int(r.get("lx", -999)) != lx or int(r.get("ly", -999)) != ly or int(r.get("z", 0)) != 0:
			continue
		var cell := Vector2i(3, 3)
		var marked := false
		for obj_v in r.get("objs", []):
			var obj: Dictionary = obj_v
			if str(obj.get("id", "")) == "player":
				cell = Vector2i(int(obj.get("x", 3)), int(obj.get("y", 3)))
				marked = true
				break
		if not marked and str(get_parent().get("land_id")) == "editor_play":
			cell = load("res://scripts/editor/editor_play.gd").spawn_cell(r)
		return Vector2((int(r.x) * ROOM_W + cell.x + 1) * TILE, (int(r.y) * ROOM_H + cell.y + 1) * TILE - 1.0)
	return null


## Interact.beginAct plays the door's comein clip when the hold starts; allAct
## (goThroughDoor) runs when the objs.xml time has passed.
func _go_through(node: Node, from_timer: bool = false) -> void:
	if not bool(node.get_meta("usable", true)):
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return
	if float(node.get_meta("lock", 0.0)) > 0.0 and not _pass_lock(node):
		return
	if not from_timer and int(node.get_meta("act_time", 0)) > 0 and player.has_method("begin_use_timer"):
		player.begin_use_timer(node)
		_ObjArt.play(node.get_node_or_null("Visual") as Sprite2D, "comein")
		_PropSfx.node_obj(node, "open")
		return
	# Interact.allAct: prob first (stay on this land), else allact exit.
	if str(node.get_meta("dest_prob", "")) == "" and bool(node.get_meta("next_level", false)):
		Travel.goto_next_level()
		return
	if not node.has_meta("target"):
		return
	player.velocity = Vector2.ZERO
	player.global_position = node.get_meta("target", player.global_position)
	player.reset_physics_interpolation()
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.reset_smoothing()
	_spawn_near(_room_key_of(player.global_position))


func _spawn_stand_in(row: Dictionary) -> Node2D:
	var node: Node2D = load("res://scripts/map/land_object.gd").new()
	var shown := row
	if not row.has("w") and row.has("unit_id"):
		shown = row.duplicate()
		shown["w"] = 40.0
		shown["h"] = 40.0
	node.setup(shown)
	add_child(node)
	if str(row.get("uid", "")) != "":
		_by_uid[str(row.uid)] = node
	return node


func _acts(row: Dictionary, eves: Array) -> Array:
	var scripts: Dictionary = row.get("scripts", {})
	for eve in eves:
		if scripts.has(eve):
			var steps: Array = []
			for step_v in (scripts[eve] as Dictionary).get("acts", []):
				var step: Dictionary = (step_v as Dictionary).duplicate()
				if str(step.get("act", "")) == "mess":
					step["text"] = _txt(str(step.get("val", "")))
				steps.append(step)
			return steps
	return []


## Box scrOpen / scrClose / scrTouch, each its own event (scrAct stays "actions").
func _box_eves(row: Dictionary) -> Dictionary:
	var out := {}
	for eve in ["open", "close", "touch"]:
		if (row.get("scripts", {}) as Dictionary).has(eve):
			out[eve] = _acts(row, [eve])
	return out


func _add_scripts_meta(row: Dictionary, node: Node = null) -> void:
	if node != null and not (row.get("scripts", {}) as Dictionary).is_empty():
		node.set_meta("scripts", row.scripts)


## Area.mess and Script mess are text_*.xml <txt> ids. Unresolved ids stay silent.
func _txt(key: String) -> String:
	if key == "":
		return ""
	var line := OriginalLines.text("txt", key)
	if line == key:
		return ""
	return (load("res://scripts/story/story_text.gd") as GDScript).call("add_keys", line, OriginalLines.keys_of("txt", key))


func _room_of(at: Vector2) -> Vector2i:
	return Vector2i(int(floor(at.x / float(ROOM_W * TILE))), int(floor(at.y / float(ROOM_H * TILE))))


func _room_key_of(at: Vector2) -> String:
	var room := _room_of(at)
	return "%d,%d" % [room.x, room.y]


func _key_room(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


func _room_gap(key: String, at: Vector2i) -> int:
	var room := _key_room(key)
	return maxi(absi(room.x - at.x), absi(room.y - at.y))


func _load_room_index() -> void:
	_room_attrs.clear()
	if not FileAccess.file_exists(ROOMS):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOMS))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for room_v in (parsed as Dictionary).get("rooms", []):
		if typeof(room_v) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = room_v
		var rx := int(room.get("x", 0))
		var ry := int(room.get("y", 0))
		for obj_v in room.get("objs", []):
			if typeof(obj_v) != TYPE_DICTIONARY:
				continue
			var obj: Dictionary = obj_v
			if str(obj.get("tag", "obj")) != "obj":
				continue
			var key := "%d,%d,%d,%d,%s" % [rx, ry, int(obj.get("x", 0)), int(obj.get("y", 0)), str(obj.get("id", ""))]
			var attrs: Variant = obj.get("attrs", {})
			_room_attrs[key] = attrs if typeof(attrs) == TYPE_DICTIONARY else {}


func _attrs_at(rx: int, ry: int, cx: int, cy: int, id: String) -> Dictionary:
	var found: Variant = _room_attrs.get("%d,%d,%d,%d,%s" % [rx, ry, cx, cy, id], {})
	if typeof(found) != TYPE_DICTIONARY:
		return {}
	return found


func _stamp_door(body: Node) -> void:
	var id := str(body.get_meta("door_id", ""))
	var attrs := _attrs_at(
		int(body.get_meta("room_x", 0)), int(body.get_meta("room_y", 0)),
		int(body.get_meta("cell_x", 0)), int(body.get_meta("cell_y", 0)), id
	)
	if _wooden_wall(body):
		body.set_meta("usable", false)
	else:
		_Lock.stamp(body, id, float(body.get_meta("lock", 0.0)), attrs)
	var flag := str(attrs.get("indestruct", ""))
	body.set_meta("indestruct", flag != "" and flag != "0")
	_DoorArt.apply_instance(body)


func _stamp_at(node: Node, id: String, stored: float, room: Array, feet: Vector2, size: Vector2) -> void:
	var rx := int(room[0]) if room.size() > 1 else 0
	var ry := int(room[1]) if room.size() > 1 else 0
	node.set_meta("room_x", rx)
	node.set_meta("room_y", ry)
	var ox := rx * ROOM_W * TILE
	var oy := ry * ROOM_H * TILE
	var cx := int((feet.x - size.x * 0.5 - float(ox)) / float(TILE))
	var cy := int((feet.y - float(oy) - 1.0) / float(TILE))
	var attrs := _attrs_at(rx, ry, cx, cy, id)
	if attrs.has("cont"):
		node.set_meta("cont", str(attrs["cont"]))
	_Lock.stamp(node, id, stored, attrs)


func _pass_lock(node: Node) -> bool:
	if bool(node.get_meta("dead", false)):
		return false
	var lock_before := float(node.get_meta("lock", 0.0))
	var result: Dictionary = _Lock.attempt(node)
	var text := str(result.get("text", ""))
	if text != "":
		_notice(text)
	# Interact.fiascoUnlock (robocellFail): a robocell lock that jams or blocks lets the robots out.
	if str(node.get_meta("allact", "")) == "robocell" and lock_before < 100.0 and float(node.get_meta("lock", 0.0)) >= 100.0:
		robocells(_point_of(node))
	if bool(result.get("alarm", false)):
		# fiascoRemine: alarm2 on the alarm box itself, alarm (which also wakes robocells) elsewhere.
		if str(node.get_meta("id", "")) == "alarm":
			_vis_state(node, "active")
		else:
			robocells(_point_of(node))
	# A mine unit (Mine.as) answers its own Interact: a fumble lights its fuse.
	var brain: Variant = node.get("_brain") if node.is_in_group("enemies") else null
	if brain != null and brain.has_method("lock_result"):
		return brain.lock_result(result)
	if bool(result.get("alarm", false)):
		_raise_alarm(_point_of(node))
	var blast := int(result.get("blast", 0))
	if blast > 0:
		_blast(_point_of(node), 260.0, blast)
	if str(result.get("script", "")) != "":
		ScriptsEngine.run_script(str(result.script), node)
	return bool(result.get("open", false))


func _terminal_act(node: Node) -> String:
	var id := str(node.get_meta("id", ""))
	if id == "":
		id = str(node.get_meta("door_id", ""))
	if not (id.begins_with("term") or id == "alarm" or id == "robocell" or id == "elpanel"):
		return ""
	return str(node.get_meta("allact", ""))


## Also the end of Interact.actOsn for doors, buttons and containers.
func _run_terminal(node: Node) -> void:
	_signs.clear(node)
	var act := _terminal_act(node)
	if act == "":
		return
	node.set_meta("allact", "")
	var rx := int(node.get_meta("room_x", -999))
	var ry := int(node.get_meta("room_y", -999))
	match act:
		"hack_robot":
			_notice(OriginalLines.info("term1Act"))
			_silence_turrets(rx, ry)
		"hack_lock":
			_notice(OriginalLines.info("term2Act"))
			_clear_hack_locks(rx, ry)
		"alarm":
			_notice(OriginalLines.info("alarmOff"))
			node.set_meta("dead", true)
			node.set_meta("spent", true)
			_vis_state(node, "open")
		"robocell":
			_notice(OriginalLines.info("robocellOff"))
			node.set_meta("dead", true)
			node.set_meta("spent", true)
			_vis_state(node, "open")
		"prob_help":
			node.set_meta("allact", act)
			var trial := trial_at(_point_of(node))
			if trial != null:
				trial.show_help()
		"electro_check":
			var env := _RoomFlags.env_at(_point_of(node), get_parent())
			env["electro"] = room_electro(Vector2i(rx, ry))
			if float(env.electro) <= 0.0:
				_notice(OriginalLines.info("electroOff"))
		_:
			_notice(Locale.t("slice_no_quest"))


## Location.electroCheck: the strongest electro of the room's closed generators
## (objs.xml elpanel electro 100).
func room_electro(cell: Vector2i) -> float:
	var top := 0.0
	for node in get_children():
		if str(node.get_meta("id", "")) != "elpanel" or str(node.get_meta("allact", "electro_check")) != "electro_check":
			continue
		if int(node.get_meta("room_x", -999)) == cell.x and int(node.get_meta("room_y", -999)) == cell.y:
			top = maxf(top, float(_Registry.obj("elpanel").get("electro", 100)))
	return top


## Location.allon / alloff (scripts locon / locoff) for the room at a point:
## colour filter yellow / black, lightOn and darkness. allon also switches
## every object back on (Interact.active) and shuts lockTip 4 doors
## (setAct("open", 0)).
func room_power(at: Vector2, on: bool) -> void:
	var cell := _room_of(at)
	var land := get_parent() as Node2D
	var envs: Dictionary = land.get_meta("room_env") if land != null and land.has_meta("room_env") else {}
	if envs.has(cell):
		var env: Dictionary = envs[cell]
		env["color"] = "yellow" if on else "black"
		env["lon"] = 1 if on else -1
		env["dark"] = -20 if on else 20
	_RoomLook.retint(land, cell, "yellow" if on else "black")
	if not on:
		return
	for node in get_children():
		if not node is Node2D or _room_of(_point_of(node)) != cell or bool(node.get_meta("dead", false)):
			continue
		if node.has_meta("usable") and not _wooden_wall(node):
			node.set_meta("usable", true)
		if _doors.has(node) and int(node.get_meta("locktip", 0)) == 4:
			_apply_door(node, false)


## Location.robocellActivate (script robots): each robocell of the room at a
## point lets out a robot (Interact.genRobot) and goes active.
func robocells(at: Vector2) -> void:
	var cell := _room_of(at)
	for node in get_children():
		if not node is Node2D or _room_of(_point_of(node)) != cell:
			continue
		if str(node.get_meta("allact", "")) != "robocell":
			continue
		node.set_meta("allact", "")
		_vis_state(node, "active")
		_spawn_plan_unit({
			"unit_id": "robot",
			"feet": [_point_of(node).x, _point_of(node).y],
			"room": [cell.x, cell.y],
			"level": 0,
			"hero": 0,
			"uid": "",
		})


## Location.prob: the trial whose room holds the point, or null.
func trial_at(at: Vector2) -> Node:
	for trial in get_tree().get_nodes_in_group("trial"):
		if trial.get_parent() == self and trial.holds(at):
			return trial
	return null


## term2 / hack_lock: command("hack") on room objects with objs.xml hack=1
## (door2/3, stdoor, some safes). Ordinary lockpick-only doors stay locked.
func _clear_hack_locks(rx: int, ry: int) -> void:
	for body in _doors:
		if not bool(body.get_meta("hackable", false)):
			continue
		if int(body.get_meta("room_x", -999)) != rx or int(body.get_meta("room_y", -999)) != ry:
			continue
		body.set_meta("lock", 0.0)
		body.set_meta("mine", 0)
	for crate in _loot:
		if not is_instance_valid(crate) or not bool(crate.get_meta("hackable", false)):
			continue
		if int(crate.get_meta("room_x", -999)) != rx or int(crate.get_meta("room_y", -999)) != ry:
			continue
		crate.set_meta("lock", 0.0)
		crate.set_meta("mine", 0)


func _silence_turrets(rx: int, ry: int) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if int(enemy.get_meta("room_x", -999)) != rx or int(enemy.get_meta("room_y", -999)) != ry:
			continue
		var style := str(enemy.get("fight_style"))
		var uid := str(enemy.get_meta("unit_id", ""))
		if style != "turret" and not uid.contains("turret"):
			continue
		# Interact hack_robot: un.hack(pers.security). security 1 reprograms the turret to the player's side.
		var brain: Variant = enemy.get("_brain")
		if brain is Object and (brain as Object).has_method("hack"):
			(brain as Object).call("hack", int(Progression.pers("security", 0.0)))
			continue
		enemy.set_meta("hacked", true)
		enemy.set("ai_state", 0)
		enemy.set("ai_spok", 0)
		enemy.set_physics_process(false)
		if enemy is CharacterBody2D:
			(enemy as CharacterBody2D).velocity = Vector2.ZERO


## Interact.useRuna on an alarm mine (keyCrack): fiascoRemine, then the mine is gone.
func trip_alarm(node: Node) -> void:
	node.set_meta("mine", 0)
	if str(node.get_meta("id", "")) == "alarm":
		_vis_state(node, "active")
	else:
		robocells(_point_of(node))
	if str(node.get_meta("allact", "")) == "alarm":
		node.set_meta("allact", "")
		node.set_meta("dead", true)
	_raise_alarm(_point_of(node))


func _raise_alarm(at: Vector2) -> void:
	# Location.signal(300) is 10s at 30 ticks. The siren wakes the room for 8s.
	# A successful disarm does not switch turrets, traps, or doors off.
	_alarm_left = 10.0
	_budilo_left = 8.0
	_budilo_tick = 0.0
	_alarm_at = at
	var trial := trial_at(at)
	if trial != null:
		trial.alarm()
	_en_spawn.signal_room(_room_key_of(at))


## Location.enemySpawn for the room around at (UnitTrigger allact spawn).
func enemy_spawn(at: Vector2, one: bool, get_gg: bool) -> Node:
	return _en_spawn.spawn(_room_key_of(at), one, get_gg)


## Box setVisState on alarm / robocell: open when switched off, active when it went off.
func _vis_state(node: Node, label: String) -> void:
	node.set_meta("vis_state", label)
	_ObjArt.set_state(node.get_node_or_null("Visual") as Sprite2D, label)


## Interact alarm area (tip raider, over alarm2): an alerted raider touching the
## alarm box raises the alarm and the box goes active.
func _tick_alarm_boxes() -> void:
	if Engine.get_physics_frames() % 3 != 0:
		return
	for node in _buttons:
		if not is_instance_valid(node) or str(node.get_meta("allact", "")) != "alarm" or bool(node.get_meta("dead", false)):
			continue
		var box := Rect2((node as Node2D).global_position + _ObjArt.offset("alarm"), _ObjArt.size("alarm"))
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not bool(enemy.get("_raider_type")) or bool(enemy.get("_dead")) or not enemy.has_method("_is_calm") or bool(enemy.call("_is_calm")):
				continue
			var body_v: Variant = enemy.get("body_size")
			var body: Vector2 = body_v if body_v is Vector2 else Vector2(30, 60)
			var at := (enemy as Node2D).global_position
			if box.intersects(Rect2(at.x - body.x * 0.5, at.y - body.y, body.x, body.y)):
				node.set_meta("allact", "")
				node.set_meta("dead", true)
				_vis_state(node, "active")
				_raise_alarm(_point_of(node))
				break


func _tick_alarm(delta: float) -> void:
	if _alarm_left <= 0.0:
		return
	_alarm_left = maxf(0.0, _alarm_left - delta)
	if _budilo_left <= 0.0:
		return
	_budilo_left = maxf(0.0, _budilo_left - delta)
	_budilo_tick -= delta
	if _budilo_tick > 0.0:
		return
	_budilo_tick = 1.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if bool(enemy.get_meta("hacked", false)) or not enemy.has_method("_alarm_from"):
			continue
		var body := enemy as Node2D
		if body == null or body.global_position.distance_squared_to(_alarm_at) > 1500.0 * 1500.0:
			continue
		enemy.call("_alarm_from", _alarm_at)


## Interact sign spot: the object's middle (coordinates.Y - halfHeight).
func _sign_point(node: Node) -> Vector2:
	if str(node.get_meta("door_id", "")) != "":
		return _center(node)
	return _point_of(node) - Vector2(0, 20)


func _point_of(node: Node) -> Vector2:
	if str(node.get_meta("door_id", "")) != "":
		return _center(node)
	if node is Node2D:
		return node.get_meta("feet", (node as Node2D).global_position)
	return Vector2.ZERO


func _quad(size: Vector2, color: Color, at: Vector2) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = "Visual"
	poly.color = color
	poly.position = at
	poly.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)
	])
	return poly
