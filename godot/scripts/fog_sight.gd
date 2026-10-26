extends Node

## What things look like outside live sight, for fog.gd's memory layer (a
## port feature). Moving things (awake units, shots, falling loot, thrown or
## carried bodies) are not drawn outside live sight. Things that stay put
## (containers, doors, props, corpses, loot at rest, units that have not moved
## or turrets) leave a ghost as they go out of sight: plain sprites of their
## last seen frame where they were, dimmed by the fog like the tiles. The real
## node is hidden until its own spot is seen again, and the ghost goes when
## its spot is. @retdark rooms keep no ghosts.
## Hidden nodes are on canvas layer HIDE_LAYER, which the game viewport does
## not draw; the node keeps its own visible flag. Static things are looked at
## only when fog.gd reports their tile crossed SEEN; moving ones are polled.

const SEEN := 0.2
const HIDE_LAYER := 19
const GHOSTS := "FogGhosts"
const META_HIDDEN := "fog_layer"
const META_SEEN := "fog_seen"
const META_LAST := "fog_last"
const STILL_PX := 1.5
const SLEEP_POLL := 10
const BODY_POLL := 3
const UNIT_LIFT := 20.0
const TILE := 40.0
const UNIT_GROUPS := ["enemies", "allies"]
const SHOT_GROUPS := ["player_bullets", "enemy_bullets"]
const BODY_GROUPS := ["ground_loot", "levitatable"]
const FX_HOSTS := ["unit_fx", "weapon_fx"]

var _fog: Node
var _land: Node
var _ghosts: Node2D
## Tile index -> statics and ghosts watched there.
var _at := {}
var _dyn := {}
var _tick := 0
var _vis := PackedFloat64Array()
var _tw := 1
var _th := 1


func _init(fog: Node) -> void:
	_fog = fog
	name = "Sight"


func _ready() -> void:
	get_viewport().set_canvas_cull_mask_bit(HIDE_LAYER, false)


## fog.gd retarget: the statics and ghosts of land are watched from now on.
func attach(land: Node) -> void:
	_at.clear()
	_dyn.clear()
	var state: Object = _fog.get("_state")
	if state != null:
		var watch: PackedByteArray = state.watch
		state.watch = PackedByteArray()
		watch.fill(0)
		state.watch = watch
	if is_instance_valid(_land):
		var old := _land.get_node_or_null("Actors")
		if old and old.child_entered_tree.is_connected(_on_actor):
			old.child_entered_tree.disconnect(_on_actor)
	_land = land
	_ghosts = null
	if land == null:
		return
	_ghosts = ghost_root(land)
	for ghost in _ghosts.get_children():
		_watch(ghost, _ghost_probe(ghost))
	var actors := land.get_node_or_null("Actors")
	if actors:
		for child in actors.get_children():
			_add_static(child)
		actors.child_entered_tree.connect(_on_actor)
	var doors := land.get_node_or_null("Doors")
	if doors:
		for child in doors.get_children():
			_add_static(child)


## Under the land's Actors, which sits at the land origin like the land.
static func ghost_root(land: Node) -> Node2D:
	var host := land.get_node_or_null("Actors")
	if host == null:
		host = land
	var root := host.get_node_or_null(GHOSTS) as Node2D
	if root == null:
		root = Node2D.new()
		root.name = GHOSTS
		host.add_child(root)
	return root


func _on_actor(node: Node) -> void:
	_add_static.call_deferred(node)


func _add_static(node: Node) -> void:
	if not is_instance_valid(node) or not node is Node2D or not _is_static(node):
		return
	if not is_instance_valid(_land) or not _land.is_ancestor_of(node):
		return
	var probe := _probe(node)
	if not _has_art(node):
		return
	var seen := _seen_at(probe)
	node.set_meta(META_SEEN, seen)
	if seen and node.has_meta(META_HIDDEN):
		_show(node)
	_watch(node, probe)


func _watch(node: Node, probe: Vector2) -> void:
	var index := _index(probe)
	if index < 0:
		return
	var list: Array = _at.get(index, [])
	list.append(node)
	_at[index] = list
	var state: Object = _fog.get("_state")
	var watch: PackedByteArray = state.watch
	state.watch = PackedByteArray()
	watch[index] = mini(255, watch[index] + 1)
	state.watch = watch


## fog.gd after a pass: tiles whose live visibility crossed SEEN.
func crossed(tiles: PackedInt32Array) -> void:
	for index in tiles:
		var list: Variant = _at.get(index)
		if list == null:
			continue
		var keep: Array = []
		for node in list:
			if not is_instance_valid(node) or node.is_queued_for_deletion():
				continue
			if node.has_meta("fog_ghost"):
				if _seen_index(index):
					node.queue_free()
					continue
			else:
				_static_sight(node, _seen_index(index), index)
			keep.append(node)
		if keep.is_empty():
			_at.erase(index)
		else:
			_at[index] = keep


func _static_sight(node: Node, seen: bool, index: int) -> void:
	var was := bool(node.get_meta(META_SEEN, false))
	node.set_meta(META_SEEN, seen)
	if seen:
		if node.has_meta(META_HIDDEN):
			_show(node)
	elif was and not node.has_meta(META_HIDDEN):
		if _remembers(index):
			_leave_ghost(node, _probe(node))
		_hide(node)


var _carried: Node = null


## fog.gd every tick: moving things and units. Each unit is looked at every
## other tick, loot and bodies every BODY_POLL ticks, frozen units seldom.
func poll() -> void:
	if _land == null or not is_instance_valid(_land):
		return
	var state: Object = _fog.get("_state")
	if state == null:
		return
	_tick += 1
	_vis = state.vis
	_tw = state.tiles_w
	_th = state.tiles_h
	var tree := get_tree()
	var player := tree.get_first_node_in_group("player")
	var carried: Variant = player.get("_tele_obj") if player != null else null
	_carried = carried if is_instance_valid(carried) and carried is Node else null
	for group in UNIT_GROUPS:
		var units := tree.get_nodes_in_group(group)
		for k in range(_tick & 1, units.size(), 2):
			var unit: Node2D = units[k]
			if unit.is_physics_processing() or (_tick + k) % SLEEP_POLL < 2:
				var at := unit.global_position
				_poll(unit, at.x, at.y - UNIT_LIFT, true)
	for group in SHOT_GROUPS:
		for shot in tree.get_nodes_in_group(group):
			var at: Vector2 = (shot as Node2D).global_position
			_poll(shot, at.x, at.y, false)
	if _carried is Node2D:
		var held_at := (_carried as Node2D).global_position
		_poll(_carried as Node2D, held_at.x, held_at.y, false)
	if _tick & 1 == 0:
		_poll_fx(tree)
	if _tick % BODY_POLL == 0:
		for group in BODY_GROUPS:
			for body in tree.get_nodes_in_group(group):
				if body.is_physics_processing():
					var at: Vector2 = (body as Node2D).global_position
					_poll(body, at.x, at.y - 8.0, true)
	if _tick % 300 == 0:
		for node in _dyn.keys():
			if not is_instance_valid(node):
				_dyn.erase(node)
	_vis = PackedFloat64Array()


## Explosions, sparks, flashes and tracers are not drawn outside live sight
## either: the parts of the fx hosts and the flash nodes shots leave on the scene.
func _poll_fx(tree: SceneTree) -> void:
	for group in FX_HOSTS:
		var host := tree.get_first_node_in_group(group)
		if host == null:
			continue
		for part in host.get_children():
			if part is Node2D:
				var at: Vector2 = (part as Node2D).global_position
				_poll(part, at.x, at.y, false)
	var scene := tree.current_scene
	if scene == null:
		return
	for node in scene.get_children():
		if node is Line2D:
			var line := node as Line2D
			if line.get_point_count() > 0:
				var tip := line.to_global(line.get_point_position(line.get_point_count() - 1))
				_poll(line, tip.x, tip.y, false)
		elif node is Polygon2D or node is Sprite2D or node is CPUParticles2D or node is GPUParticles2D:
			var at: Vector2 = (node as Node2D).global_position
			_poll(node, at.x, at.y, false)


## Per polled node: [seen last time, x, y, hidden].
func _poll(node: Node2D, px: float, py: float, may_ghost: bool) -> void:
	var i := int(px / TILE)
	var j := int(py / TILE)
	var seen := px >= 0.0 and py >= 0.0 and i < _tw and j < _th and _vis[j * _tw + i] >= SEEN
	# The player's telekinesis keeps hold of it, so it is always drawn.
	if node == _carried:
		seen = true
	var st: Variant = _dyn.get(node)
	if st == null:
		st = [false, px, py, node.has_meta(META_HIDDEN)]
		_dyn[node] = st
	var row: Array = st
	if seen:
		row[0] = true
		row[1] = px
		row[2] = py
		if row[3]:
			_show(node)
			row[3] = false
		return
	if row[3]:
		row[0] = false
		return
	var still := absf(px - float(row[1])) + absf(py - float(row[2])) <= STILL_PX
	var was: bool = row[0]
	row[0] = false
	row[1] = px
	row[2] = py
	if was and may_ghost and still and _stays(node):
		var index := j * _tw + i
		if _remembers(index):
			_leave_ghost(node, Vector2(px, py))
	_hide(node)
	row[3] = true


func _stays(node: Node) -> bool:
	if node.get("held") == true:
		return false
	if node.has_method("is_alert") and not bool(node.get("_dead")):
		var style := str(node.get("fight_style"))
		if style == "turret" or style == "mine" or bool(node.get("fixed_post")):
			return true
		return not bool(node.call("is_alert"))
	return true


func _is_static(node: Node) -> bool:
	if node.has_method("is_alert") or node is GroundLoot:
		return false
	if node.is_in_group("levitatable") or node.is_in_group("floor_box"):
		return false
	if node.has_meta("fog_ghost") or node.name == "RoomBounds" or node.name == GHOSTS:
		return false
	return node is CanvasItem


func _hide(node: Node) -> void:
	var item := node as CanvasItem
	if item == null or node.has_meta(META_HIDDEN):
		return
	node.set_meta(META_HIDDEN, item.visibility_layer)
	item.visibility_layer = 1 << HIDE_LAYER


func _show(node: Node) -> void:
	var item := node as CanvasItem
	if item == null:
		return
	item.visibility_layer = int(node.get_meta(META_HIDDEN, 1))
	node.remove_meta(META_HIDDEN)


## land_memory.gd: a node restored from a save that was remembered as a ghost.
static func hide_restored(node: Node) -> void:
	var item := node as CanvasItem
	if item == null or node.has_meta(META_HIDDEN):
		return
	node.set_meta(META_HIDDEN, item.visibility_layer)
	node.set_meta(META_SEEN, false)
	item.visibility_layer = 1 << HIDE_LAYER


# --- sight lookups ---------------------------------------------------------

func _index(at: Vector2) -> int:
	var state: Object = _fog.get("_state")
	if state == null:
		return -1
	var i := floori(at.x / TILE)
	var j := floori(at.y / TILE)
	var tw: int = state.tiles_w
	if i < 0 or j < 0 or i >= tw or j >= int(state.tiles_h):
		return -1
	return j * tw + i


func _seen_at(at: Vector2) -> bool:
	var index := _index(at)
	return index >= 0 and _seen_index(index)


func _seen_index(index: int) -> bool:
	var state: Object = _fog.get("_state")
	return (state.vis as PackedFloat64Array)[index] >= SEEN


func _remembers(index: int) -> bool:
	var state: Object = _fog.get("_state")
	return (state.live as PackedByteArray)[index] == 1


# --- ghosts ------------------------------------------------------------------

func _probe(node: Node) -> Vector2:
	if node.has_method("is_alert"):
		return (node as Node2D).global_position - Vector2(0, UNIT_LIFT)
	var box := _art_rect(node)
	if box.size != Vector2.ZERO:
		return box.get_center()
	return (node as Node2D).global_position


func _has_art(node: Node) -> bool:
	var parts: Array = []
	_collect(node, parts, 0)
	return not parts.is_empty()


func _art_rect(node: Node) -> Rect2:
	var parts: Array = []
	_collect(node, parts, 0)
	var box := Rect2()
	var first := true
	for item_v in parts:
		var item := item_v as Node2D
		var local: Rect2 = item.call("get_rect") if item.has_method("get_rect") else Rect2()
		var rect := item.global_transform * local
		box = rect if first else box.merge(rect)
		first = false
	return box


func _collect(node: Node, out: Array, depth: int) -> void:
	if depth > 4:
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Sprite2D and (node as Sprite2D).texture != null:
		out.append(node)
	elif node is AnimatedSprite2D and (node as AnimatedSprite2D).sprite_frames != null:
		out.append(node)
	for child in node.get_children():
		if child is CanvasItem:
			_collect(child, out, depth + 1)


func _leave_ghost(node: Node, probe: Vector2) -> void:
	var parts: Array = []
	var items: Array = []
	_collect(node, items, 0)
	for item_v in items:
		var part := _part_of(item_v as Node2D)
		if not part.is_empty():
			parts.append(part)
	if parts.is_empty() or _ghosts == null:
		return
	var ghost := make_ghost(_ghosts, parts, probe, str(node.get_meta("wid", "")))
	_watch(ghost, probe)


func _part_of(item: Node2D) -> Dictionary:
	var tex: Texture2D = null
	var part := {}
	if item is AnimatedSprite2D:
		var anim := item as AnimatedSprite2D
		tex = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
		part["c"] = anim.centered
		part["off"] = anim.offset
		part["fh"] = anim.flip_h
		part["fv"] = anim.flip_v
	else:
		var sprite := item as Sprite2D
		tex = sprite.texture
		part["c"] = sprite.centered
		part["off"] = sprite.offset
		part["fh"] = sprite.flip_h
		part["fv"] = sprite.flip_v
		part["hf"] = sprite.hframes
		part["vf"] = sprite.vframes
		part["f"] = sprite.frame
		if sprite.region_enabled:
			part["region"] = sprite.region_rect
	if tex == null:
		return {}
	part["tex"] = tex
	part["xf"] = (_ghosts.global_transform.affine_inverse() * item.global_transform) if _ghosts else item.global_transform
	part["z"] = _abs_z(item)
	part["m"] = _tint(item)
	part["filter"] = item.texture_filter
	return part


func _abs_z(item: CanvasItem) -> int:
	var z := 0
	var node: Node = item
	while node is CanvasItem:
		var canvas := node as CanvasItem
		z += canvas.z_index
		if not canvas.z_as_relative:
			break
		node = node.get_parent()
	return clampi(z, RenderingServer.CANVAS_ITEM_Z_MIN, RenderingServer.CANVAS_ITEM_Z_MAX)


func _tint(item: CanvasItem) -> Color:
	var color := item.self_modulate
	var node: Node = item
	while node is CanvasItem:
		color *= (node as CanvasItem).modulate
		if node == _land:
			break
		node = node.get_parent()
	return color


static func make_ghost(root: Node2D, parts: Array, probe: Vector2, wid: String) -> Node2D:
	var ghost := Node2D.new()
	ghost.set_meta("fog_ghost", true)
	ghost.set_meta("probe", probe)
	ghost.set_meta("wid", wid)
	root.add_child(ghost)
	for part_v in parts:
		var part: Dictionary = part_v
		var sprite := Sprite2D.new()
		sprite.texture = part.tex
		sprite.centered = bool(part.get("c", true))
		sprite.offset = part.get("off", Vector2.ZERO)
		sprite.flip_h = bool(part.get("fh", false))
		sprite.flip_v = bool(part.get("fv", false))
		sprite.hframes = maxi(1, int(part.get("hf", 1)))
		sprite.vframes = maxi(1, int(part.get("vf", 1)))
		sprite.frame = clampi(int(part.get("f", 0)), 0, sprite.hframes * sprite.vframes - 1)
		if part.has("region"):
			sprite.region_enabled = true
			sprite.region_rect = part.region
		sprite.z_as_relative = false
		sprite.z_index = int(part.get("z", 0))
		sprite.modulate = part.get("m", Color.WHITE)
		sprite.texture_filter = int(part.get("filter", CanvasItem.TEXTURE_FILTER_PARENT_NODE))
		sprite.transform = part.xf
		ghost.add_child(sprite)
	return ghost


func _ghost_probe(ghost: Node) -> Vector2:
	return ghost.get_meta("probe", Vector2.ZERO)


# --- saves ---------------------------------------------------------------------

## land_memory.gd: the ghosts of land, JSON-safe. Parts whose texture has no
## resource path (made at run time) are not kept.
static func capture_ghosts(land: Node) -> Array:
	var host := land.get_node_or_null("Actors")
	var root := (host if host else land).get_node_or_null(GHOSTS)
	if root == null:
		return []
	var out: Array = []
	for ghost in root.get_children():
		if ghost.is_queued_for_deletion():
			continue
		var parts: Array = []
		for sprite_v in ghost.get_children():
			var sprite := sprite_v as Sprite2D
			if sprite == null or sprite.texture == null:
				continue
			var row := _texture_row(sprite.texture)
			if row.is_empty():
				continue
			var xf := sprite.transform
			var m := sprite.modulate
			row.merge({
				"xf": [xf.x.x, xf.x.y, xf.y.x, xf.y.y, xf.origin.x, xf.origin.y],
				"z": sprite.z_index, "c": sprite.centered, "off": [sprite.offset.x, sprite.offset.y],
				"fh": sprite.flip_h, "fv": sprite.flip_v, "hf": sprite.hframes, "vf": sprite.vframes,
				"f": sprite.frame, "m": [m.r, m.g, m.b, m.a], "filter": sprite.texture_filter,
			})
			if sprite.region_enabled:
				var r := sprite.region_rect
				row["region"] = [r.position.x, r.position.y, r.size.x, r.size.y]
			parts.append(row)
		if parts.is_empty():
			continue
		var probe: Vector2 = ghost.get_meta("probe", Vector2.ZERO)
		out.append({"probe": [probe.x, probe.y], "wid": str(ghost.get_meta("wid", "")), "parts": parts})
	return out


static func _texture_row(tex: Texture2D) -> Dictionary:
	if tex.resource_path != "" and not tex.resource_path.contains("::"):
		return {"tex": tex.resource_path}
	if tex is AtlasTexture:
		var atlas := (tex as AtlasTexture).atlas
		if atlas != null and atlas.resource_path != "" and not atlas.resource_path.contains("::"):
			var r := (tex as AtlasTexture).region
			return {"atlas": atlas.resource_path, "ar": [r.position.x, r.position.y, r.size.x, r.size.y]}
	return {}


## land_memory.gd: ghosts back from a save. Returns the wids they stand for.
static func restore_ghosts(land: Node, rows: Array) -> Dictionary:
	var root := ghost_root(land)
	for child in root.get_children():
		child.queue_free()
	var wids := {}
	for row_v in rows:
		if not row_v is Dictionary:
			continue
		var row: Dictionary = row_v
		var parts: Array = []
		for part_v in row.get("parts", []):
			var part: Dictionary = (part_v as Dictionary).duplicate()
			var tex := _load_texture(part)
			if tex == null:
				continue
			var xf: Array = part.get("xf", [1, 0, 0, 1, 0, 0])
			part["tex"] = tex
			part["xf"] = Transform2D(Vector2(xf[0], xf[1]), Vector2(xf[2], xf[3]), Vector2(xf[4], xf[5]))
			var off: Array = part.get("off", [0, 0])
			part["off"] = Vector2(off[0], off[1])
			var m: Array = part.get("m", [1, 1, 1, 1])
			part["m"] = Color(m[0], m[1], m[2], m[3])
			if part.has("region"):
				var r: Array = part.region
				part["region"] = Rect2(r[0], r[1], r[2], r[3])
			parts.append(part)
		if parts.is_empty():
			continue
		var probe: Array = row.get("probe", [0, 0])
		var wid := str(row.get("wid", ""))
		make_ghost(root, parts, Vector2(probe[0], probe[1]), wid)
		if wid != "":
			wids[wid] = true
	return wids


static func _load_texture(part: Dictionary) -> Texture2D:
	if part.has("tex"):
		var path := str(part.tex)
		return load(path) as Texture2D if ResourceLoader.exists(path) else null
	if part.has("atlas"):
		var path := str(part.atlas)
		if not ResourceLoader.exists(path):
			return null
		var atlas := AtlasTexture.new()
		atlas.atlas = load(path) as Texture2D
		var r: Array = part.get("ar", [0, 0, 0, 0])
		atlas.region = Rect2(r[0], r[1], r[2], r[3])
		return atlas
	return null
