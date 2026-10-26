extends AnimatableBody2D

## Floor crate or container. Box.as: not a wall.
## shelf (hit width >= 40) is a one-way top. Units and other crates land on it.
## Sides do not stop movement. Stacks ride osnova and sleep while stay and vx == 0.
## Wall-mounted containers are not this body.

@export var levitate_difficulty: float = 10.0

## Box.stay. Public so a crate stacked above can read it.
var resting: bool = false
var held: bool = false
## Box.shelf. False when the hit width is under 40.
var shelf: bool = false
## Box.massa. Explicit objs.xml massa/50, else width * height * height / 250000 * massaMult.
var massa: float = 1.0
## Pixel shift this physics frame. A crate standing on this one copies it (Box.cdx / cdy).
var cdx: float = 0.0
var cdy: float = 0.0

var _vx: float = 0.0
var _vy: float = 0.0
var _osnova: Node = null
var _art := Vector2(40, 40)
var _hit := Vector2(40, 40)
var _hit_origin := Vector2.ZERO
var _rect: RectangleShape2D
var _bank: float = 0.0
var _snd_on := false
## Box.isPlav / isPlav2 / fixPlav, and ddyPlav (objs.xml plav; < 0 floats up).
var _plav := false
var _plav2 := false
var _fix_plav := false
var _ddy_plav := 1.0

## GameContainer.ddy is 1 px/tick and maxdy is 20. At 30 Hz that is 900 and 600.
const TICK := 1.0 / 30.0
const GRAVITY := 900.0
const MAX_FALL := 600.0
## GameContainer.maxdelta. Collision is tested at most this many pixels at a time.
const MAX_STEP := 9.0
const WALL_MASK := 1
const PLATFORM_MASK := 64
## One-way shelves live on the same layer as map platforms.
const SHELF_LAYER := 64

## Box.t_throw: ticks after a telekinetic throw in which a hit only stuns.
var t_throw: int = 0
var _frac_player := false

## GameContainer.boxDamage. Unit.neujazMax is 20 ticks for enemies.
const BOX_DAMAGE := 0.2
const NEUJAZ_TICKS := 20.0
const _Resistances := preload("res://scripts/resistances.gd")
const _UnitMassa := preload("res://scripts/unit_massa.gd")
const _Flags := preload("res://scripts/map/room_flags.gd")
const _UnitWater := preload("res://scripts/map/unit_water.gd")
const _Registry := preload("res://scripts/map/land_registry.gd")

static var _batch_frame: int = -1

## objs.xml massa='N' is stored as N/50. Others use the size formula.
const _MASSA := {
	"woodbox": 0.3, "mcrate1": 0.5, "box": 1.0, "mcrate2": 1.5, "mcrate3": 2.4,
	"bigbox": 3.5, "bigbox2": 10.0, "mcrate4": 20.0, "mcrate5": 10.0,
	"radbarrel": 2.0, "radbigbarrel": 22.0, "reactor": 1000.0,
}
const _MULT := {
	"safe": 1.5, "case": 0.5, "weapbox": 1.5, "weapcase": 2.0, "bigmed": 0.5,
	"instr1": 1.2, "table": 0.5, "trash": 0.5, "ccup": 1.5, "tap": 1.5,
	"couch": 4.0, "himlab": 0.5, "stove": 2.0, "enclcase": 2.0,
	"table1": 0.5, "table2": 0.5, "table3": 0.5, "table4": 0.5, "longtable": 0.5,
}
## scx / scy from objs.xml. 0 keeps the sprite size on that axis. Bottom-aligned.
const _TRIM := {
	"couch": Vector2(0, 20), "bed": Vector2(0, 28), "tap": Vector2(0, 45),
	"work": Vector2(0, 37), "himlab": Vector2(0, 33), "table3": Vector2(0, 28),
	"detonator": Vector2(36, 30), "reactor": Vector2(0, 220),
	"case": Vector2(36, 0), "ammobox": Vector2(36, 0),
}


func _ready() -> void:
	_art = get_meta("box", Vector2(40, 40))
	if _art.x < 1.0 or _art.y < 1.0:
		_art = Vector2(40, 40)
	var id := str(get_meta("id", ""))
	_hit = _art
	if _TRIM.has(id):
		var trim: Vector2 = _TRIM[id]
		if trim.x > 0.0:
			_hit.x = trim.x
		if trim.y > 0.0:
			_hit.y = trim.y
	_hit_origin = Vector2((_art.x - _hit.x) * 0.5, _art.y - _hit.y)
	# Box.as: width < 40 clears shelf. wall > 0 never reaches this script.
	shelf = _hit.x >= 40.0
	if _MASSA.has(id):
		massa = float(_MASSA[id])
	else:
		var mult := float(_MULT.get(id, 1.0))
		massa = _hit.x * _hit.y * _hit.y / 250000.0 * mult
	set_meta("massa", massa)
	set_meta("shelf", shelf)
	_ddy_plav = float(_Registry.obj(id).get("plav", 1.0))
	levitate_difficulty = float(get_meta("levitate_difficulty", 10.0))
	add_to_group("levitatable")
	add_to_group("floor_box")
	# Location draws objs (boxes) under the units.
	z_index = -2
	sync_to_physics = false
	collision_mask = 0
	set_meta("blocks_sight", false)
	set_meta("sight_transparency", 1.0)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	_rect = RectangleShape2D.new()
	_rect.size = _hit
	shape.shape = _rect
	shape.position = _hit_origin + _hit * 0.5
	shape.one_way_collision = shelf
	shape.one_way_collision_margin = 8.0
	add_child(shape)
	_apply_layer()
	var art_path := str(get_meta("art", ""))
	var art: Texture2D = null
	if art_path != "" and ResourceLoader.exists(art_path):
		art = load(art_path) as Texture2D
	if art:
		var sprite := Sprite2D.new()
		sprite.name = "Visual"
		sprite.texture = art
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = get_meta("art_at", Vector2.ZERO)
		add_child(sprite)
	else:
		var poly := Polygon2D.new()
		poly.name = "Visual"
		poly.color = get_meta("color", Color(0.5, 0.42, 0.26))
		poly.polygon = PackedVector2Array([
			Vector2.ZERO, Vector2(_art.x, 0), _art, Vector2(0, _art.y)
		])
		add_child(poly)


func _physics_process(delta: float) -> void:
	# Lower crates rest first, so a stack links in one frame (Box.checkShelf needs stay).
	var frame := Engine.get_physics_frames()
	if _batch_frame == frame:
		return
	_batch_frame = frame
	if GameState.paused:
		return
	# Frozen crates (room_bounds: far from the player) are skipped before the sort;
	# a land holds hundreds of them.
	var boxes: Array = []
	for box in get_tree().get_nodes_in_group("floor_box"):
		if box.has_method("_sim") and (box.held or not bool(box.get_meta("frozen", false))):
			boxes.append([box.crate_bottom(), box])
	boxes.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for entry in boxes:
		var box: Variant = entry[1]
		if is_instance_valid(box):
			box._sim(delta)


func crate_top() -> float:
	return global_position.y + _hit_origin.y


func crate_bottom() -> float:
	return global_position.y + _hit_origin.y + _hit.y


func crate_left() -> float:
	return global_position.x + _hit_origin.x


func crate_right() -> float:
	return global_position.x + _hit_origin.x + _hit.x


func crate_center_x() -> float:
	return global_position.x + _hit_origin.x + _hit.x * 0.5


func crate_disabled() -> bool:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	return shape_node != null and shape_node.disabled


func _sim(delta: float) -> void:
	# room_bounds.gd sets this while the box is in a room too far from the player to run.
	if bool(get_meta("frozen", false)) and not held:
		return
	var origin := global_position
	_apply_layer()
	if crate_disabled():
		cdx = 0.0
		cdy = 0.0
		return
	if held:
		resting = false
		_fix_plav = false
		_osnova = null
		cdx = 0.0
		cdy = 0.0
		return
	_ride()
	if _fix_plav and not _Flags.water_at(Vector2(crate_center_x(), crate_bottom() - _hit.y * 0.45)):
		_fix_plav = false
	# Box.step skips forces when stay and velocity.X == 0, or while fixPlav.
	if (resting and absf(_vx) < 1.0) or _fix_plav:
		_bank = 0.0
		cdx = global_position.x - origin.x
		cdy = global_position.y - origin.y
		_report_velocity(delta)
		return
	_bank += delta
	var steps := 0
	while _bank >= TICK and steps < 4:
		if resting and absf(_vx) < 1.0:
			break
		_bank -= TICK
		steps += 1
		_original_tick()
	cdx = global_position.x - origin.x
	cdy = global_position.y - origin.y
	_report_velocity(delta)


func _apply_layer() -> void:
	# A carried box is levit: Unit.checkShelf ignores it, so nothing stands on it.
	if crate_disabled() or held or not shelf:
		collision_layer = 0
		return
	collision_layer = SHELF_LAYER


func _ride() -> void:
	if _osnova == null or not is_instance_valid(_osnova):
		_osnova = null
		return
	var base_held := bool(_osnova.get("held"))
	var base_rest := bool(_osnova.get("resting"))
	if base_held or not base_rest:
		resting = false
		_osnova = null
		return
	var shift := Vector2(float(_osnova.get("cdx")), float(_osnova.get("cdy")))
	if shift == Vector2.ZERO:
		return
	# Box.step: follow osnova unless the shift would hit a solid tile.
	if _cast_frac(shift, WALL_MASK) < 0.999:
		resting = false
		_osnova = null
		return
	global_position += shift


func _original_tick() -> void:
	# Box.forces: no gravity while isPlav unless isPlav2, then ddy * ddyPlav; velocity * 0.65 afloat.
	if not _plav and _vy < MAX_FALL:
		_vy = minf(MAX_FALL, _vy + GRAVITY * TICK)
	elif _plav and _plav2:
		_vy += GRAVITY * _ddy_plav * TICK
	if _plav:
		_vx *= 0.65
		_vy *= 0.65
	var vx_px := _vx * TICK
	var vy_px := _vy * TICK
	var div := int(maxf(absf(vx_px), absf(vy_px)) / MAX_STEP) + 1
	var sx := vx_px / float(div)
	var sy := vy_px / float(div)
	for _i in div:
		if not _sub(sx, sy):
			break
	_check_water()
	if not _fix_plav and _plav and not _plav2 and absf(_vy) < 60.0 and _ddy_plav < 0.0:
		_vx = 0.0
		_vy = 0.0
		_fix_plav = true
	if absf(_vx) > 150.0 or absf(_vy) > 150.0:
		_att_drop()
	if t_throw > 0:
		t_throw -= 1


## Box.checkWater: isPlav at 0.45 of the height, isPlav2 at 0.55; 'kap' and the
## fall_water sound by mass on the change.
func _check_water() -> void:
	var was := _plav
	var at := Vector2(crate_center_x(), crate_bottom())
	_plav = _Flags.water_at(at - Vector2(0, _hit.y * 0.45))
	_plav2 = _Flags.water_at(at - Vector2(0, _hit.y * 0.55))
	if was == _plav:
		return
	var vy := _vy / 30.0
	if absf(vy) > 8.0:
		UnitFx.emit(get_tree(), "kap", Vector2(at.x, at.y - _hit.y * 0.25 + vy),
			{"dy": -absf(vy) * (randf() * 0.3 + 0.3), "kol": clampi(int(absf(vy * massa * 2.0) - 5.0), 0, 100)})
	if vy > 5.0:
		_UnitWater.fall_sound(massa, vy / 10.0)


## Box.attDrop: a crate moving faster than 5 px/tick strikes each enemy it overlaps
## for massa * (vel2 - 50) * boxDamage blunt damage, then velocities are shared by
## mass. Within t_throw of a telekinetic throw it only sets neujaz.
func _att_drop() -> void:
	var vel2 := (_vx * _vx + _vy * _vy) / 900.0
	if vel2 < 50.0:
		return
	var rect := Rect2(global_position + _hit_origin, _hit)
	var now := Time.get_ticks_msec()
	var targets := get_tree().get_nodes_in_group("enemies")
	# fracLevit: a crate the player lifted spares the player's side until it lands.
	if not _frac_player:
		targets.append_array(get_tree().get_nodes_in_group("player"))
	for node in targets:
		if not node is Node2D or not is_instance_valid(node) or node.get("_dead") == true:
			continue
		if now < int(node.get_meta("neujaz_until", 0)):
			continue
		if not rect.intersects(_unit_rect(node as Node2D)):
			continue
		if t_throw > 0:
			node.set_meta("neujaz_until", now + 400)
			continue
		node.set_meta("neujaz_until", now + int(NEUJAZ_TICKS * 1000.0 / 30.0))
		var dam := massa * (vel2 - 50.0) * BOX_DAMAGE
		if "velocity" in node:
			var um := _unit_massa(node)
			var mine := Vector2(_vx, _vy)
			var theirs: Vector2 = node.velocity
			var shared := (mine * massa + theirs * um) / (massa + um)
			node.velocity = (-theirs + shared) + shared
			mine = (-mine + shared) * 0.25 + shared
			_vx = mine.x
			_vy = mine.y
		if node.is_in_group("player"):
			node.take_hit(maxi(1, roundi(dam)), "DAM_BLUNT")
		else:
			_Resistances.apply(node, dam, "DAM_BLUNT")
		vel2 = (_vx * _vx + _vy * _vy) / 900.0
		if vel2 < 50.0:
			return


func _unit_rect(node: Node2D) -> Rect2:
	var shape_node := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		var size := (shape_node.shape as RectangleShape2D).size
		return Rect2(shape_node.global_position - size * 0.5, size)
	return Rect2(node.global_position - Vector2(20, 40), Vector2(40, 40))


func _unit_massa(node: Node) -> float:
	return maxf(0.01, _UnitMassa.massa(node))


func _sub(sx: float, sy: float) -> bool:
	if absf(sx) > 0.0001:
		var frac := _cast_frac(Vector2(sx, 0.0), WALL_MASK)
		if frac >= 0.999:
			global_position.x += sx
		else:
			global_position.x += sx * frac
			# Box.run: faster than 10 px/tick rebounds at 0.2, otherwise it stops.
			if absf(_vx) > 300.0:
				_vx = -_vx * 0.2
			else:
				_vx = 0.0
	if sy > 0.0001 and _vy > 0.0:
		return _drop(sy)
	if sy < -0.0001 and _vy < 0.0:
		return _rise(sy)
	return true


func _drop(sy: float) -> bool:
	resting = false
	# A crate placed on a floor already touches it. cast_motion then misses and the body tunnels.
	var lip := _lip_under(4.0)
	if lip < 1.0e19:
		global_position.y += lip - crate_bottom()
		_osnova = null
		_land()
		return false
	var wall_dist := sy * minf(_cast_frac(Vector2(0.0, sy), WALL_MASK), _cast_frac(Vector2(0.0, sy), PLATFORM_MASK))
	var found := _find_shelf(sy)
	if not found.is_empty() and float(found.dist) < wall_dist - 0.01:
		global_position.y += float(found.dist)
		_osnova = found.node
		_land()
		return false
	if wall_dist < sy - 0.01:
		global_position.y += wall_dist
		_osnova = null
		_land()
		return false
	global_position.y += sy
	_osnova = null
	return true


func _lip_under(reach: float) -> float:
	var space := get_world_2d().direct_space_state
	if space == null:
		return 1.0e20
	var bottom := crate_bottom()
	var best := 1.0e20
	var exclude := _exclude()
	for x in [crate_left() + 1.0, crate_center_x(), crate_right() - 1.0]:
		var query := PhysicsRayQueryParameters2D.create(Vector2(x, bottom - reach), Vector2(x, bottom + reach), WALL_MASK | PLATFORM_MASK)
		query.exclude = exclude
		query.collide_with_areas = false
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		if hit.is_empty() or float(hit.normal.y) >= -0.5:
			continue
		var top := float(hit.position.y)
		if absf(top - bottom) <= reach and top < best:
			best = top
	return best


func _rise(sy: float) -> bool:
	resting = false
	_osnova = null
	var frac := _cast_frac(Vector2(0.0, sy), WALL_MASK)
	if frac >= 0.999:
		global_position.y += sy
		return true
	global_position.y += sy * frac
	_vy = 0.0
	return false


func _land() -> void:
	# Thresholds are px/tick (5 and the massa > 1 stop). Velocity here is px/s.
	var frame_vy := _vy / 30.0
	var frame_vx := _vx / 30.0
	if frame_vy > 4.0 and frame_vy * massa > 5.0 and CamShake != null:
		CamShake.quake(0.0, frame_vy * sqrt(massa) / 2.0)
	# Box.sndOn: the first touchdown after spawn is silent.
	if frame_vy > 5.0 and _snd_on:
		preload("res://scripts/prop_sfx.gd").obj(str(get_meta("id", "")), "fall", minf(frame_vy / 15.0, 1.0))
	_snd_on = true
	if frame_vy < 5.0 or massa > 1.0:
		_vy = 0.0
	else:
		_vy = -_vy * 0.2
	if absf(frame_vx) < 5.0:
		_vx = 0.0
	else:
		_vx *= 0.92
	resting = true
	_frac_player = false


func _find_shelf(dy: float) -> Dictionary:
	# Box.checkShelf: center X inside a resting shelf, and this step crosses its top.
	var bottom := crate_bottom()
	var cx := crate_center_x()
	var best: Node = null
	var best_top := 1.0e20
	for node in get_tree().get_nodes_in_group("floor_box"):
		if node == self or not is_instance_valid(node):
			continue
		if not bool(node.get("shelf")) or bool(node.get("held")) or not bool(node.get("resting")):
			continue
		if node.has_method("crate_disabled") and bool(node.call("crate_disabled")):
			continue
		var left := float(node.call("crate_left"))
		var right := float(node.call("crate_right"))
		var top := float(node.call("crate_top"))
		if cx < left or cx > right:
			continue
		if bottom <= top + 1.0 and bottom + dy > top and top < best_top:
			best_top = top
			best = node
	if best == null:
		return {}
	return {"node": best, "top": best_top, "dist": best_top - bottom}


func _cast_frac(motion: Vector2, mask: int) -> float:
	if motion.length_squared() < 0.0000001 or _rect == null:
		return 1.0
	var space := get_world_2d().direct_space_state
	if space == null:
		return 1.0
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _rect
	params.transform = Transform2D(0.0, global_position + _hit_origin + _hit * 0.5)
	params.motion = motion
	params.collision_mask = mask
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = _exclude()
	var hit: PackedFloat32Array = space.cast_motion(params)
	if hit.is_empty():
		return 1.0
	return hit[0]


func _exclude() -> Array[RID]:
	var out: Array[RID] = [get_rid()]
	for node in get_tree().get_nodes_in_group("floor_box"):
		if node == self or not node is CollisionObject2D:
			continue
		out.append((node as CollisionObject2D).get_rid())
	return out


func _report_velocity(delta: float) -> void:
	var vel := Vector2.ZERO
	if delta > 0.0:
		vel = Vector2(cdx, cdy) / delta
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, vel)


func hold_at(cursor: Vector2, delta: float, speed: float = 220.0) -> void:
	held = true
	_frac_player = true
	resting = false
	_osnova = null
	_vx = 0.0
	_vy = 0.0
	_apply_layer()
	# Speed 0 only marks the grab. The player applies Telekinesis.hold.
	if speed > 0.0:
		global_position = global_position.move_toward(cursor, speed * delta)
	modulate = preload("res://scripts/magic_aura.gd").tele_tint()


func release() -> void:
	release_vel(Vector2.ZERO)


func release_vel(vel: Vector2) -> void:
	if not held:
		return
	held = false
	resting = false
	_osnova = null
	_vx = vel.x
	_vy = vel.y
	if _vy < 40.0 and absf(_vx) < 1.0:
		_vy = 40.0
	_apply_layer()
	modulate = Color.WHITE
