extends RefCounted

## What a land remembers between visits and saves, for one land_props. Rows
## of the land plan are named by what they are and where they were placed
## (a wid). Units keep hp and position (so a unit that walked into another
## room comes back there), bodies stay where they fell, containers stay
## opened or unlocked, taken bonuses and dead units stay gone. Doors, broken
## wall cells, dropped items, trigger areas, the land's flags and fog
## exploration come back too. The stable (begin_actors.json) names its rows by
## list and index instead.

const _Bounds := preload("res://scripts/map/room_bounds.gd")
const _Drop := preload("res://scripts/ground_loot.gd")
const _DoorArt := preload("res://scripts/door_art.gd")
const _FogSight := preload("res://scripts/fog_sight.gd")
const _ObjArt := preload("res://scripts/map/obj_art.gd")
const _UNIT_SCENE := "res://scenes/enemy.tscn"
## Unit metas a runtime unit is made again with.
const _UNIT_METAS := ["unit_id", "level", "hero", "tr", "vortex_minion", "ai_tip", "noagro", "hidden", "pole"]

const VERSION := 1
const TILE := 40.0
const ROOM_W := 1920.0
const ROOM_H := 1000.0

var props: Node2D
var land_id := ""
var bounds: Node2D
var _saved := {}
var _ents := {}
var _nodes := {}
var _broken := {}
var _flags := {}
var _names := {}
## Units made at run time (summons, reinforcements): wid -> how to make them again.
var _extra := {}
var _extra_n := 0
## Wids remembered as fog ghosts in the save; the real node starts hidden.
var _hidden := {}


func _init(owner: Node2D) -> void:
	props = owner


func land() -> Node:
	return props.get_parent()


## land_props._ready, before anything is spawned.
func begin(rooms: Array) -> void:
	var host := land()
	var value: Variant = host.get("land_id") if host else null
	land_id = str(value) if value != null and str(value) != "" else "begin"
	var ws := _ws()
	_load(ws.adopt(land_id, host) if ws else {})
	bounds = _Bounds.new()
	bounds.setup(props, rooms)
	props.add_child(bounds)
	_restore_fog()
	_restore_drops()
	_restore_extra()
	var scene := host.get_parent() if host else null
	if scene and not scene.child_entered_tree.is_connected(_on_scene_child):
		scene.child_entered_tree.connect(_on_scene_child)


func _load(snapshot: Dictionary) -> void:
	_saved = snapshot
	_ents = (snapshot.get("ents", {}) as Dictionary).duplicate(true)
	_extra = (snapshot.get("extra", {}) as Dictionary).duplicate(true)
	_flags = (snapshot.get("flags", {}) as Dictionary).duplicate(true)
	for key in _flags:
		var value: Variant = _flags[key]
		# JSON gives every number back as a float.
		if value is float and value == floorf(value) and absf(value) < 1e15:
			_flags[key] = int(value)
	_broken.clear()
	for key in snapshot.get("broken", []):
		_broken[str(key)] = true


## After the doors are bound and the wooden walls shut.
func after_doors() -> void:
	var root := land().get_node_or_null("Doors")
	var saved: Dictionary = _saved.get("doors", {})
	if root and not saved.is_empty():
		for body in root.get_children():
			var rec: Variant = saved.get(str(body.name))
			if rec is Dictionary:
				_restore_door(body, rec)
	_restore_broken()


func _restore_door(body: Node, rec: Dictionary) -> void:
	if bool(rec.get("dead", false)):
		_DoorArt.break_open(body)
		var stand_in := body.get_node_or_null("StandIn") as CanvasItem
		if stand_in:
			stand_in.visible = false
		return
	if rec.has("lock"):
		body.set_meta("lock", float(rec.lock))
	if rec.has("hp"):
		body.set_meta("hp", int(rec.hp))
	if bool(rec.get("open", false)) != bool(body.get_meta("door_open", false)):
		props.call("_apply_door", body, bool(rec.get("open", false)))


## Plan rows are queued: the bonus count per room comes back as it was left.
func after_plan() -> void:
	if _saved.has("xp_left"):
		props.set("_xp_left", (_saved.xp_left as Dictionary).duplicate())


## Names the row and returns the pending room key it spawns with: the room a
## remembered unit or box is in now, else the room it was placed in.
func queue_key(row: Dictionary) -> String:
	var feet: Variant = row.get("feet", row.get("rect", ""))
	var base := "%s|%s|%s|%s|%s" % [str(row.get("cat", "")), str(row.get("id", "")), str(row.get("unit_id", "")), str(row.get("room", "")), str(feet)]
	var n := int(_names.get(base, 0))
	_names[base] = n + 1
	var wid := base if n == 0 else "%s#%d" % [base, n]
	row["wid"] = wid
	var room: Array = row.get("room", [0, 0])
	var rec: Variant = _ents.get(wid)
	if rec is Dictionary and (rec as Dictionary).has("pos"):
		var pos: Array = rec.pos
		return "%d,%d" % [floori(float(pos[0]) / ROOM_W), floori(float(pos[1]) / ROOM_H)]
	return "%d,%d" % [int(room[0]), int(room[1])]


## True when the row is remembered as gone and is not spawned.
func skips(row: Dictionary) -> bool:
	var rec: Variant = _ents.get(str(row.get("wid", "")))
	return rec is Dictionary and bool((rec as Dictionary).get("gone", false))


## After _spawn_row: the row's first new child carries its wid.
func spawned(row: Dictionary, before: int) -> void:
	var wid := str(row.get("wid", ""))
	if wid == "" or props.get_child_count() <= before:
		return
	_adopt_node(wid, props.get_child(before))


## The stable: children from index before were spawned from list prefix, in order.
func stamp_span(prefix: String, before: int) -> void:
	var k := 0
	for i in range(before, props.get_child_count()):
		var node := props.get_child(i)
		if node == bounds or node is _Drop:
			continue
		_adopt_node("%s%d" % [prefix, k], node)
		k += 1


func _adopt_node(wid: String, node: Node) -> void:
	node.set_meta("wid", wid)
	_nodes[wid] = node
	var rec: Variant = _ents.get(wid)
	if rec is Dictionary:
		_apply(node, rec)
	if _hidden.has(wid):
		_FogSight.hide_restored(node)


## A unit made at run time on this land's scene joins the land, so it is
## saved, frozen and carried with the land like the planned ones.
func _on_scene_child(node: Node) -> void:
	if node is CharacterBody2D and node.has_method("is_alert") and not node.has_meta("wid"):
		_adopt_runtime.call_deferred(node)


func _adopt_runtime(node: Node) -> void:
	var host := land()
	if not is_instance_valid(node) or node.is_queued_for_deletion() or host == null:
		return
	if not host.is_inside_tree() or not host.is_in_group("active_land") or node.has_meta("wid"):
		return
	if node.get_parent() != host.get_parent():
		return
	node.reparent(props)
	_extra_n += 1
	var wid := "x|%s|%d" % [str(node.get_meta("unit_id", "")), _extra_n]
	while _extra.has(wid) or _nodes.has(wid):
		_extra_n += 1
		wid = "x|%s|%d" % [str(node.get_meta("unit_id", "")), _extra_n]
	var metas := {}
	for key in _UNIT_METAS:
		if node.has_meta(key):
			metas[key] = node.get_meta(key)
	_extra[wid] = metas
	_adopt_node(wid, node)
	_stamp_room(node)


func _restore_extra() -> void:
	if _extra.is_empty():
		return
	var packed := load(_UNIT_SCENE) as PackedScene
	if packed == null:
		return
	for wid_v in _extra.keys():
		var wid := str(wid_v)
		var rec: Variant = _ents.get(wid)
		if not rec is Dictionary or not (rec as Dictionary).has("pos"):
			_extra.erase(wid)
			continue
		var node := packed.instantiate() as CharacterBody2D
		var metas: Dictionary = _extra[wid]
		for key in metas:
			var value: Variant = metas[key]
			if value is float and value == floorf(value):
				value = int(value)
			node.set_meta(str(key), value)
		var pos: Array = (rec as Dictionary).pos
		node.position = Vector2(float(pos[0]), float(pos[1]))
		props.add_child(node)
		_adopt_node(wid, node)
		var n := int(wid.get_slice("|", 2))
		_extra_n = maxi(_extra_n, n)


func _apply(node: Node, rec: Dictionary) -> void:
	if bool(rec.get("gone", false)):
		node.queue_free()
		return
	var pos: Array = rec.get("pos", [])
	if _is_unit(node):
		if pos.size() == 2:
			(node as Node2D).position = Vector2(float(pos[0]), float(pos[1]))
		if bool(rec.get("corpse", false)):
			node.set("hp", 0)
			if node.has_method("_become_corpse"):
				node.call("_become_corpse")
		elif rec.has("hp"):
			node.set("hp", clampi(int(rec.hp), 1, maxi(1, int(node.get("max_hp")))))
		_stamp_room(node)
		return
	if rec.has("lock"):
		node.set_meta("lock", float(rec.lock))
	if bool(rec.get("open", false)):
		node.set_meta("spent", true)
		node.set_meta("opened", true)
		if props.has_method("_show_opened"):
			props.call("_show_opened", node)
	if bool(rec.get("dead", false)):
		node.set_meta("dead", true)
		node.set_meta("spent", true)
	if rec.has("box_hp"):
		node.set_meta("box_hp", float(rec.box_hp))
	if rec.has("vis"):
		node.set_meta("vis_state", str(rec.vis))
		node.set_meta("allact", "")
		_ObjArt.set_state(node.get_node_or_null("Visual") as Sprite2D, str(rec.vis))
	if rec.has("state") and node.has_method("load_memory"):
		node.call("load_memory", rec.state)
	if rec.has("on") and node is Area2D:
		node.set_meta("enabled", bool(rec.on))
		(node as Area2D).set_deferred("monitoring", bool(rec.on))
	if pos.size() == 2 and node is Node2D:
		(node as Node2D).position = Vector2(float(pos[0]), float(pos[1]))
		_stamp_room(node)


func _stamp_room(node: Node) -> void:
	var at := (node as Node2D).position
	node.set_meta("room_x", floori(at.x / ROOM_W))
	node.set_meta("room_y", floori(at.y / ROOM_H))


func _is_unit(node: Node) -> bool:
	return node is CharacterBody2D and node.has_method("is_alert")


func _moves(node: Node) -> bool:
	return node.is_in_group("floor_box") or node.is_in_group("levitatable")


func _capture_node(node: Node) -> Dictionary:
	var at := (node as Node2D).position if node is Node2D else Vector2.ZERO
	if _is_unit(node):
		var rec := {"pos": [at.x, at.y]}
		if bool(node.get("_dead")):
			rec["corpse"] = true
		else:
			rec["hp"] = int(node.get("hp"))
		return rec
	var out := {}
	if node.has_meta("lock"):
		out["lock"] = float(node.get_meta("lock"))
	if bool(node.get_meta("opened", false)):
		out["open"] = true
	if bool(node.get_meta("dead", false)):
		out["dead"] = true
	if node.has_meta("box_hp"):
		out["box_hp"] = float(node.get_meta("box_hp"))
	if node.has_meta("vis_state"):
		out["vis"] = str(node.get_meta("vis_state"))
	if node is Area2D and node.has_meta("enabled"):
		out["on"] = bool(node.get_meta("enabled"))
	if _moves(node):
		out["pos"] = [at.x, at.y]
	if node.has_method("memory_state"):
		var state: Dictionary = node.call("memory_state")
		if not state.is_empty():
			out["state"] = state
	return out


## Wall cell centre (world px) that broke, from wall_span.gd.
func note_broken(rect: Rect2) -> void:
	var c := rect.get_center()
	_broken["%d,%d" % [floori(c.x / TILE), floori(c.y / TILE)]] = true


func _restore_broken() -> void:
	if _broken.is_empty():
		return
	var solids := land().get_node_or_null("Solids")
	if solids == null:
		return
	var walls: Array = []
	for child in solids.get_children():
		if child.has_method("break_at") and child.has_method("covers"):
			walls.append(child)
	for key in _broken:
		var parts := str(key).split(",")
		var at := Vector2((float(parts[0]) + 0.5) * TILE, (float(parts[1]) + 0.5) * TILE)
		for wall in walls:
			if is_instance_valid(wall) and wall.covers(at):
				wall.break_at(at)
				break


func set_flag(key: String, value: Variant) -> void:
	_flags[key] = value


func flag(key: String, fallback: Variant = null) -> Variant:
	return _flags.get(key, fallback)


func _restore_drops() -> void:
	for row_v in _saved.get("drops", []):
		if not row_v is Dictionary:
			continue
		var row: Dictionary = row_v
		var pos: Array = row.get("pos", [0, 0])
		var drop := _Drop.new()
		drop.item_id = str(row.get("id", ""))
		drop.stack = maxi(1, int(row.get("n", 1)))
		drop.auto = bool(row.get("auto", true))
		if row.has("mult_hp"):
			drop.set_meta("mult_hp", float(row.mult_hp))
		props.add_child(drop)
		drop.position = Vector2(float(pos[0]), float(pos[1]))
		drop.velocity = Vector2.ZERO
		_stamp_room(drop)


func _restore_fog() -> void:
	var fog := _fog()
	var data: Dictionary = _saved.get("fog", {})
	var memory: Dictionary = _saved.get("fog_mem", {})
	if fog and fog.has_method("restore_land"):
		fog.restore_land(land(), data, memory)
	_hidden = _FogSight.restore_ghosts(land(), _saved.get("ghosts", [])) if _saved.has("ghosts") else {}


func _fog() -> Node:
	if not props.is_inside_tree():
		return null
	return props.get_tree().get_first_node_in_group("fog")


## The stable is already up when a save is loaded onto it.
func restore_live(snapshot: Dictionary) -> void:
	_load(snapshot)
	after_doors()
	for wid in _nodes:
		var node: Variant = _nodes[wid]
		var rec: Variant = _ents.get(wid)
		if is_instance_valid(node) and rec is Dictionary:
			_apply(node, rec)
	for child in props.get_children():
		if child is _Drop:
			child.queue_free()
	_restore_drops()
	_restore_fog()
	for wid in _hidden:
		var node: Variant = _nodes.get(wid)
		if is_instance_valid(node):
			_FogSight.hide_restored(node)
	_restore_extra()
	var fog := _fog()
	if fog and fog.has_method("rewatch"):
		fog.rewatch(land())
	after_plan()


func capture() -> Dictionary:
	var ents := _ents.duplicate(true)
	var extra := {}
	for wid in _nodes:
		var node_v: Variant = _nodes[wid]
		if not is_instance_valid(node_v) or (node_v as Node).is_queued_for_deletion():
			if _extra.has(wid):
				ents.erase(wid)
			else:
				ents[wid] = {"gone": true}
			continue
		var node: Node = node_v
		if _extra.has(wid):
			extra[wid] = _extra[wid]
		var rec := _capture_node(node)
		if rec.is_empty():
			ents.erase(wid)
		else:
			ents[wid] = rec
	var doors := {}
	var root := land().get_node_or_null("Doors")
	if root:
		for body in root.get_children():
			doors[str(body.name)] = {
				"open": bool(body.get_meta("door_open", false)),
				"lock": float(body.get_meta("lock", 0.0)),
				"dead": bool(body.get_meta("dead", false)),
				"hp": int(body.get_meta("hp", 0)),
			}
	var drops: Array = []
	for child in props.get_children():
		if child is _Drop and not bool(child.get_meta("taken", false)) and not child.is_queued_for_deletion():
			var at := (child as Node2D).position
			var drop_rec := {"id": str(child.get("item_id")), "n": int(child.get("stack")), "pos": [at.x, at.y]}
			if child.has_meta("mult_hp"):
				drop_rec["mult_hp"] = float(child.get_meta("mult_hp"))
			if not bool(child.get("auto")):
				drop_rec["auto"] = false
			drops.append(drop_rec)
	var out := {
		"version": VERSION,
		"ents": ents,
		"doors": doors,
		"broken": _broken.keys(),
		"drops": drops,
		"flags": _flags.duplicate(true),
		"xp_left": (props.get("_xp_left") as Dictionary).duplicate(),
		"extra": extra,
		"ghosts": _FogSight.capture_ghosts(land()),
	}
	var fog := _fog()
	if fog and fog.has_method("capture_land"):
		out["fog"] = fog.capture_land(land())
		out["fog_mem"] = fog.capture_memory(land())
	else:
		for key in ["fog", "fog_mem"]:
			if _saved.has(key):
				out[key] = _saved[key]
	return out


func store() -> void:
	var ws := _ws()
	if ws:
		ws.store(land_id, capture())


func _ws() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("WorldState") if tree else null
