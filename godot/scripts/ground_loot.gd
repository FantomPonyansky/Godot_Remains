class_name GroundLoot
extends AnimatableBody2D

## World drop from Loot.as. Not a wall: layer 0, so the player, enemies, and
## bullets pass through. It falls with gravity 900 and rests on floors and
## platforms. Only the feet land, so a ledge or door cap that meets the
## sprite cannot leave it in the air. Crates and wall containers are not a
## floor. Doors and map walls block the sides.
## Original pop is (rand*10-5, rand*5-10) pixels per 30 Hz tick.
##
## Telekinesis:
##   group: ground_loot
##   levitate_difficulty: light, Loot.massa is 0.10 (crates are about 10)
##   hold_at(cursor, delta, speed) — called when the grab starts; sets held
##   release_vel(pixels_per_second) — drop it; the body falls from that velocity
##   release() — drop with a short downward kick
##   held / velocity — readable while it is carried or in the air
##   While meta tele_driven is true, this body does not move itself.
## Pickup: pickup() -> land_props.grant_dropped -> Inventory.add. One grant.
## Autopick (Loot.osnRad) grants on the same frame inside 50px, including a held drop.

const GRAVITY := 900.0
const TERMINAL := 600.0
const STEP := 10.0
## Loot.osnRad. take() pulls a drop in when both axes are inside this box
## around the player's body center, then grants it. E stays a separate 50px reach.
const AUTO_REACH := 50.0
const WORLD_MASK := 1 | 64
const ITEM_DIR := "res://assets/sprites/loot/items/"
const AMMO_DIR := "res://assets/sprites/loot/ammo/"
const WEAP_DIR := "res://assets/sprites/loot/weapons/"
## visualItem frame canvas is 104x108. The SVG places the clip origin at
## (51.9, 68.45), so the icon bottom is there and ~39px of the canvas is empty.
const ITEM_REG := Vector2(51.9, 68.45)
## visualAmmo frame canvas is 57x22. The clip origin is (27.5, 18).
const AMMO_REG := Vector2(27.5, 18.0)

## ItemInteraction.dropWeapon / dropArmor: the Item carries sost = hp / maxhp.
## Call before the item leaves the bag. Sets mult_hp on the drop when it is worn.
static func keep_condition(drop: Node, id: String) -> void:
	var cap := 0.0
	var hp := 0.0
	if Condition.is_durable_weapon(id):
		cap = float(Condition.weapon_max(id))
		hp = Condition.weapon_hp(id)
	elif Condition.is_armor(id):
		cap = float(Condition.armor_max(id))
		hp = Condition.armor_hp(id)
	if cap > 0.0 and hp < cap:
		drop.set_meta("mult_hp", clampf(hp / cap, 0.0, 1.0))


## Loot.sndFall per id (weapons snd fall, items fall, books and schemes fall_paper).
const FALL_PATH := "res://assets/data/loot_fall.json"

static var _cache: Dictionary = {}
static var _reg_cache: Dictionary = {}
static var _fall: Variant = null

@export var levitate_difficulty: float = 1.0
@export var item_id: String = ""
@export var stack: int = 1
## Loot.auto: LootGen drops take part in autopick; items the player drops do not.
@export var auto: bool = true

var held: bool = false
var velocity: Vector2 = Vector2.ZERO

var _asleep: bool = false
var _taken: bool = false
var _spawn_cleared: bool = false
var _foot: RectangleShape2D
var _skip: Array[RID] = []
var _skip_frame: int = -1
var _in_water := false


func _ready() -> void:
	add_to_group("ground_loot")
	z_index = 3
	# Static sync would pin the body where it spawned. Layer 0 keeps it from
	# blocking the player, enemies, and bullets. Mask is world + platforms.
	sync_to_physics = false
	collision_layer = 0
	collision_mask = WORLD_MASK
	var tex := _texture(item_id)
	var size := tex.get_size() if tex else Vector2(16, 16)
	size = Vector2(maxf(size.x, 8.0), maxf(size.y, 8.0))
	set_meta("size", size)
	_foot = RectangleShape2D.new()
	_foot.size = Vector2(maxf(size.x - 1.0, 4.0), 4.0)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0.0, -size.y * 0.5)
	add_child(shape)
	# The tall sprite shape stays off while falling. An AnimatableBody2D left
	# overlapping a lip is pushed back out by the physics server and hangs there.
	_arm_body(false)
	if tex:
		var sprite := Sprite2D.new()
		sprite.name = "Visual"
		sprite.texture = tex
		sprite.centered = false
		# Scale stays 1. The foot is the clip origin, not the canvas bottom.
		sprite.position = -_registration(item_id, tex)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	velocity = Vector2(randf_range(-5.0, 5.0) * 30.0, randf_range(-10.0, -5.0) * 30.0)
	collision_layer = 0
	collision_mask = WORLD_MASK
	_ignore_crates()


func hold_at(cursor: Vector2, delta: float, speed: float = 220.0) -> void:
	# The telekinesis owner steers global_position after this. held stops the fall.
	held = true
	_asleep = false
	velocity = Vector2.ZERO
	_arm_body(true)
	# speed 0 is only the grab mark. The telekinesis owner moves global_position.
	if speed > 0.0 and delta > 0.0:
		var step := cursor - global_position
		var cap := speed * delta
		if step.length() > cap:
			step = step.limit_length(cap)
		if step.length() > 0.0:
			_slide(step)
	modulate = preload("res://scripts/magic_aura.gd").tele_tint()


func release() -> void:
	if not held:
		return
	release_vel(Vector2.ZERO)


func release_vel(leftover: Vector2 = Vector2.ZERO) -> void:
	held = false
	velocity = leftover
	if velocity.length() < 1.0:
		velocity.y = 40.0
	_asleep = false
	_arm_body(false)
	modulate = Color.WHITE


func pickup() -> void:
	if _taken:
		return
	_taken = true
	set_meta("taken", true)
	var host := get_tree().get_first_node_in_group("land_props")
	if host and host.has_method("grant_dropped"):
		host.grant_dropped(item_id, stack, float(get_meta("mult_hp", 1.0)))
	queue_free()


func _physics_process(delta: float) -> void:
	if _taken:
		return
	if not _spawn_cleared:
		shove_clear()
	# Same frame as the overlap. Landed, falling, or still in the air all count.
	try_autopick()
	if _taken or held or _asleep or bool(get_meta("tele_driven", false)):
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, TERMINAL)
	_ignore_crates()
	_arm_body(false)
	_slide(velocity * delta)
	_check_water()


## Loot.checkWater: crossing the water line faster than 5 px/tick splashes.
func _check_water() -> void:
	var wet := RoomFlags.in_water(global_position)
	if wet == _in_water:
		return
	_in_water = wet
	var vy := velocity.y / 30.0
	if vy > 5.0:
		UnitFx.emit(get_tree(), "kap", global_position, {"dy": -absf(vy) * (randf() * 0.3 + 0.3), "kol": 5})
		SfxBank.play("fall_item_water", minf(vy / 10.0, 1.0))


## Loot.run on touchdown: sndFall above 5 px/tick at volume vy / 15.
func _land_sound() -> void:
	var vy := velocity.y / 30.0
	if vy <= 5.0:
		return
	if _fall == null:
		_fall = JSON.parse_string(FileAccess.get_file_as_string(FALL_PATH)) if FileAccess.file_exists(FALL_PATH) else {}
	var snd := str((_fall as Dictionary).get(item_id, "fall_item")) if _fall is Dictionary else "fall_item"
	if snd != "":
		SfxBank.play(snd, minf(vy / 15.0, 1.0))


## Loot.osnRad. Both axes, not a circle. Grants immediately when autopick is on.
func try_autopick() -> void:
	if _taken or not auto:
		return
	if Autopick == null or not Autopick.enabled:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not _within_osn(player):
		return
	if not Autopick.wants(item_id, maxi(1, stack)):
		return
	if player.get("_tele_obj") == self and player.has_method("_drop_tele"):
		player._drop_tele()
	pickup()


func _within_osn(player: Node2D) -> bool:
	var center := player.global_position + Vector2(0.0, -39.0)
	var shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		center = player.to_global(shape.position)
	var here := _body_center()
	return absf(center.x - here.x) < AUTO_REACH and absf(center.y - here.y) < AUTO_REACH


func _body_center() -> Vector2:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		return shape.global_position
	return global_position


func _arm_body(solid: bool) -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.disabled = not solid


func _slide(motion: Vector2) -> void:
	# Sides and the fall are separate. A door cap or a ledge beside the sprite
	# must not cancel the fall before the feet arrive.
	if absf(motion.x) > 0.01:
		_axis(Vector2(motion.x, 0.0), false)
	if _asleep or _taken:
		return
	if absf(motion.y) > 0.01:
		_axis(Vector2(0.0, motion.y), true)


func _axis(motion: Vector2, vertical: bool) -> void:
	var extra: Array[RID] = []
	var guard := 0
	while motion.length() > 0.01 and guard < 8:
		guard += 1
		var slice := motion
		if slice.length() > STEP:
			slice = slice.limit_length(STEP)
		var info := _query(global_position, slice, extra, vertical)
		if info.is_empty():
			if vertical and _ray_land(slice.length() + 8.0):
				return
			global_position += slice
			motion -= slice
			continue
		var node := _node_of(info)
		var normal: Vector2 = info.get("normal", Vector2.ZERO)
		var travel: Vector2 = info.get("travel", Vector2.ZERO)
		if node == null:
			node = _foot_overlap(global_position)
		# A face that points downward cannot hold a falling drop.
		if vertical and normal.y > 0.5 and velocity.y > 0.0:
			_ban(extra, info, node)
			continue
		if node == null:
			if vertical and _ray_land(slice.length() + 8.0):
				return
			_ban(extra, info, null)
			if travel.length() >= 0.2:
				global_position += travel
			motion -= slice
			continue
		if node is CollisionObject2D and (_is_crate(node) or _is_loose(node) or (vertical and _is_door(node))):
			_ban(extra, info, node)
			continue
		if vertical and _is_floor(node) and normal.y < -0.5:
			global_position += travel
			if _stand_on(node):
				return
			global_position -= travel
			_ban(extra, info, node)
			continue
		# A wall beside the feet is not a floor. Step sideways and keep falling.
		if vertical and normal.length_squared() > 0.01 and absf(normal.x) >= absf(normal.y):
			if not _push_out_x(node):
				_ban(extra, info, node)
			continue
		global_position += travel
		motion -= slice
		if vertical and normal.y > 0.5 and velocity.y < 0.0 and _is_floor(node):
			velocity.y = 0.0
			return
		if not vertical and absf(normal.x) > 0.5:
			velocity.x = absf(velocity.x) if normal.x > 0.0 else -absf(velocity.x)
			if travel.length() < 0.2 and not _push_out_x(node):
				global_position.x += signf(normal.x if absf(normal.x) > 0.01 else 1.0) * 1.0
			return
		_ban(extra, info, node)
		global_position -= travel
		continue


## Feet rest only when they are over a floor, slope, or platform.
## One-way margins sit a few pixels high; the feet snap down onto the lip.
func _stand_on(node: Node) -> bool:
	if velocity.y <= 0.0 or _foot == null:
		return false
	var surface := _top_of(node)
	if surface > 1.0e19:
		return false
	var rise := global_position.y - surface
	if rise > 48.0 or rise < -12.0:
		return false
	global_position.y = surface
	_land_sound()
	velocity = Vector2.ZERO
	_asleep = true
	return true


func _top_of(node: Node) -> float:
	if not _foot_over(node):
		return 1.0e20
	var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and shape.shape is RectangleShape2D and node is Node2D:
		var sz: Vector2 = (shape.shape as RectangleShape2D).size
		return (node as Node2D).to_global(shape.position - sz * 0.5).y
	var poly := node.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if poly and node is Node2D:
		var points := poly.polygon
		var best := 1.0e20
		var half := _foot.size.x * 0.5
		for i in points.size():
			var a: Vector2 = (node as Node2D).to_global(points[i])
			var b: Vector2 = (node as Node2D).to_global(points[(i + 1) % points.size()])
			if maxf(a.x, b.x) < global_position.x - half or minf(a.x, b.x) > global_position.x + half:
				continue
			if absf(a.x - b.x) < 0.01:
				best = minf(best, minf(a.y, b.y))
				continue
			var t := clampf((global_position.x - a.x) / (b.x - a.x), 0.0, 1.0)
			best = minf(best, lerpf(a.y, b.y, t))
		if best < 1.0e19:
			return best
	return 1.0e20


func _foot_over(node: Node) -> bool:
	if _foot == null:
		return false
	var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null or not (shape.shape is RectangleShape2D) or not node is Node2D:
		return node.get_node_or_null("CollisionPolygon2D") != null
	var sz: Vector2 = (shape.shape as RectangleShape2D).size
	var origin: Vector2 = (node as Node2D).to_global(shape.position - sz * 0.5)
	var half := _foot.size.x * 0.5
	return global_position.x + half > origin.x and global_position.x - half < origin.x + sz.x


func _query(from: Vector2, motion: Vector2, extra: Array[RID], vertical: bool) -> Dictionary:
	var space := get_world_2d().direct_space_state
	if space == null or _foot == null or motion.length_squared() < 0.0000001:
		return {}
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _foot
	params.transform = _foot_at(from)
	params.motion = motion
	params.collision_mask = WORLD_MASK if vertical else 1
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var exclude: Array[RID] = []
	exclude.append_array(_skip_rids())
	for rid in extra:
		if not exclude.has(rid):
			exclude.append(rid)
	params.exclude = exclude
	var fractions: PackedFloat32Array = space.cast_motion(params)
	if fractions.is_empty() or fractions[0] >= 0.999:
		return {}
	var travel := motion * fractions[0]
	params.transform = _foot_at(from + travel)
	var info := space.get_rest_info(params)
	if info.is_empty():
		return {"travel": travel, "normal": Vector2.ZERO, "point": from + travel, "collider": null}
	info["travel"] = travel
	return info


func _node_of(info: Dictionary) -> Node:
	var node := info.get("collider") as Node
	if node:
		return node
	var raw = info.get("collider_id", 0)
	if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_OBJECT:
		return instance_from_id(int(raw)) as Node
	return null


func _ban(extra: Array[RID], info: Dictionary, node: Node) -> void:
	var raw = info.get("rid")
	if raw is RID and (raw as RID).is_valid() and not extra.has(raw):
		extra.append(raw)
	if node is CollisionObject2D:
		var rid := (node as CollisionObject2D).get_rid()
		if rid.is_valid() and not extra.has(rid):
			extra.append(rid)


func _foot_at(at: Vector2) -> Transform2D:
	return Transform2D(0.0, at + Vector2(0.0, -_foot.size.y * 0.5))


func _push_out_x(node: Node) -> bool:
	if node == null:
		return false
	var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null or not (shape.shape is RectangleShape2D) or not node is Node2D or _foot == null:
		return false
	var sz: Vector2 = (shape.shape as RectangleShape2D).size
	var origin: Vector2 = (node as Node2D).to_global(shape.position - sz * 0.5)
	var half := _foot.size.x * 0.5
	var left := origin.x - half - 1.0
	var right := origin.x + sz.x + half + 1.0
	var prefer_left := global_position.x < origin.x + sz.x * 0.5
	var options: Array[float] = [left, right] if prefer_left else [right, left]
	for x in options:
		if _foot_blocked(Vector2(x, global_position.y)):
			continue
		global_position.x = x
		return true
	return false


func _ray_land(reach: float) -> bool:
	if velocity.y <= 0.0 or reach <= 0.0 or _foot == null:
		return false
	var space := get_world_2d().direct_space_state
	if space == null:
		return false
	var half := maxf(_foot.size.x * 0.5 - 0.5, 0.0)
	var best := reach + 1.0
	var best_node: Node = null
	var columns: Array[float] = [-half, 0.0, half]
	for ox in columns:
		var from := global_position + Vector2(ox, -1.0)
		var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, reach + 1.0), WORLD_MASK)
		query.exclude = _skip_rids()
		query.collide_with_areas = false
		query.hit_from_inside = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var body := hit.collider as Node
		if not _is_floor(body):
			continue
		var gap := float(hit.position.y) - global_position.y
		if gap < -0.5 or gap > reach:
			continue
		if gap < best:
			best = gap
			best_node = body
	if best_node == null:
		return false
	global_position.y += maxf(best, 0.0)
	var surface := _top_of(best_node)
	if surface < 1.0e19:
		var rise := global_position.y - surface
		if rise >= -12.0 and rise <= 48.0:
			global_position.y = surface
	_land_sound()
	velocity = Vector2.ZERO
	_asleep = true
	return true


func _foot_overlap(at: Vector2) -> Node:
	var space := get_world_2d().direct_space_state
	if space == null or _foot == null:
		return null
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _foot
	params.transform = _foot_at(at)
	params.collision_mask = WORLD_MASK
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = _skip_rids()
	var hits := space.intersect_shape(params, 1)
	if hits.is_empty():
		return null
	return hits[0].collider as Node


func _foot_blocked(at: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	if space == null or _foot == null:
		return false
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _foot
	params.transform = _foot_at(at)
	params.collision_mask = 1
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = _skip_rids()
	return not space.intersect_shape(params, 1).is_empty()


func _skip_rids() -> Array[RID]:
	var frame := Engine.get_physics_frames()
	if _skip_frame == frame:
		return _skip
	_skip_frame = frame
	_skip = [get_rid()]
	for group_name in ["floor_box", "levitatable", "tk_use"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is CollisionObject2D and _is_crate(node):
				var rid := (node as CollisionObject2D).get_rid()
				if not _skip.has(rid):
					_skip.append(rid)
	return _skip


## Move out of a map wall, a closed door, the wooden septum, or a loose prop
## before physics runs. Crates are left alone so the drop falls through them.
func shove_clear() -> void:
	_spawn_cleared = true
	if not _blocked(global_position):
		return
	var origin := global_position
	var dirs: Array[Vector2] = _clear_dirs()
	for dist in [12.0, 24.0, 36.0, 48.0, 64.0, 80.0, 96.0, 128.0]:
		for dir in dirs:
			var at := origin + dir.normalized() * float(dist)
			if not _blocked(at):
				global_position = at
				return


func _clear_dirs() -> Array[Vector2]:
	# A door cap is not a floor. Step out the side before stepping up onto it.
	if _touching_door(global_position):
		return [
			Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN, Vector2.UP,
			Vector2(-0.7, 0.7), Vector2(0.7, 0.7), Vector2(-0.7, -0.7), Vector2(0.7, -0.7),
		]
	return [
		Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN,
		Vector2(-0.7, -0.7), Vector2(0.7, -0.7), Vector2(-0.7, 0.7), Vector2(0.7, 0.7),
	]


func _blocked(at: Vector2) -> bool:
	for body in _overlaps(at):
		if _is_crate(body):
			continue
		return true
	return false


func _touching_door(at: Vector2) -> bool:
	for body in _overlaps(at):
		if _is_door(body):
			return true
	return false


func _overlaps(at: Vector2) -> Array[Node]:
	var found: Array[Node] = []
	var space := get_world_2d().direct_space_state
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if space == null or shape == null or shape.shape == null:
		return found
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape.shape
	params.transform = Transform2D(0.0, at + shape.position)
	params.collision_mask = WORLD_MASK
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = [get_rid()]
	for hit in space.intersect_shape(params, 8):
		var body := hit.collider as Node
		if body and body != self:
			found.append(body)
	return found


func _is_crate(node: Node) -> bool:
	if node == null or node == self:
		return false
	if node.is_in_group("floor_box"):
		return true
	if node.is_in_group("enemies") or node.is_in_group("player") or node.is_in_group("ground_loot"):
		return false
	# Closed doors and the wooden septum stay solid. They are not crates.
	if node.has_meta("door_id") or node.has_meta("door_open"):
		return false
	var parent := node.get_parent()
	var pname := str(parent.name) if parent else ""
	if pname in ["Solids", "Slopes", "Platforms", "Ladders", "Doors"]:
		return false
	return node.is_in_group("levitatable") or node.is_in_group("tk_use")


func _is_floor(node: Node) -> bool:
	if node == null or _is_crate(node) or _is_door(node):
		return false
	var parent := node.get_parent()
	var pname := str(parent.name) if parent else ""
	return pname in ["Solids", "Slopes", "Platforms"]


func _is_door(node: Node) -> bool:
	if node == null:
		return false
	if not node.has_meta("door_id") and not node.has_meta("door_open"):
		return false
	if bool(node.get_meta("dead", false)) or bool(node.get_meta("door_open", false)):
		return false
	if node is CollisionObject2D and (node as CollisionObject2D).collision_layer == 0:
		return false
	var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and shape.disabled:
		return false
	return true


## A prop that is not a crate, a door, or the map. The drop must not rest on it.
func _is_loose(node: Node) -> bool:
	return node != null and not _is_crate(node) and not _is_door(node) and not _is_floor(node)


func _ignore_crates() -> void:
	for node in get_tree().get_nodes_in_group("floor_box"):
		if node is PhysicsBody2D and node != self:
			add_collision_exception_with(node)
	var host := get_parent()
	if host == null:
		return
	for child in host.get_children():
		if child == self or not child is PhysicsBody2D:
			continue
		if _is_crate(child):
			add_collision_exception_with(child)


## Flash registration inside the exported frame. visualItem and visualAmmo
## keep the clip origin. Weapon vis clips are shifted so the frame bounds
## sit on that origin, which is what Loot.as does before dery cancels the +10.
static func _registration(id: String, tex: Texture2D) -> Vector2:
	if _reg_cache.has(id):
		return _reg_cache[id] as Vector2
	var path := _path_for(id)
	var size := tex.get_size()
	var anchor := Vector2(size.x * 0.5, size.y)
	if path.begins_with(ITEM_DIR) and size.x == 104.0 and size.y == 108.0:
		anchor = ITEM_REG
	elif path.begins_with(AMMO_DIR) and size.x == 57.0 and size.y == 22.0:
		anchor = AMMO_REG
	else:
		var image := tex.get_image()
		if image:
			var used := image.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				anchor = Vector2(used.position.x + used.size.x * 0.5, used.position.y + used.size.y)
	_reg_cache[id] = anchor
	return anchor


static func _texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var path := _path_for(id)
	var tex: Texture2D = _load_tex(path) if path != "" else null
	_cache[id] = tex
	return tex


static func _path_for(id: String) -> String:
	var names: PackedStringArray = PackedStringArray()
	var base := id
	var variant := ""
	if id.contains("^"):
		var parts := id.split("^")
		base = parts[0]
		variant = parts[1] if parts.size() > 1 else ""
	if variant != "":
		names.append(WEAP_DIR + "%s_%s.png" % [base, variant])
	names.append(WEAP_DIR + base + ".png")
	names.append(ITEM_DIR + id + ".png")
	names.append(AMMO_DIR + id + ".png")
	var cut := id.rfind("_")
	if cut > 0 and id.substr(cut + 1).is_valid_int():
		names.append(AMMO_DIR + id.substr(0, cut) + ".png")
	if id.begins_with("s_"):
		names.append(ITEM_DIR + "scheme.png")
	names.append(ITEM_DIR + "_generic.png")
	for path in names:
		if ResourceLoader.exists(path):
			return path
	return ""


static func _load_tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
