extends RefCounted

## Telekinesis.as for enemy casters: alicorn1-3, Blood Moon (bossalicorn) and
## ghouls with ss 2 / 7. One held body. Units keep levit as the struggle counter
## (the player's jump counts it down) and tele_holder / frac_levit name the caster.
## Crates carry the same through held and meta tele_holder. All motion is in
## pixels per 30 Hz tick; Godot velocities are that times TPS.

const TPS := 30.0
## Vanilla's carry speed as a multiple of accel (Settings.VANILLA_THROW is on).
const RELEASE := 4.0
const EASE := 0.35
const BESIDE_UNIT := 150.0
const BESIDE_OBJECT := 80.0
const HOLD_HEIGHT := 40.0
const HEAVY_MASS := 1.0
const BOX_CHANCE := 0.3
const FLING := Vector2(100.0, -30.0)
const ARC_LIFT := 4.0
## GameContainer.boxDamage for a thrown crate striking the player (Box.attDrop).
const BOX_DAMAGE := 0.2
const _Aura := preload("res://scripts/magic_aura.gd")
const _UnitMassa := preload("res://scripts/unit_massa.gd")

var owner: CharacterBody2D
var speed: float
var accel: float
## teleFilter GlowFilter colour; a held player takes it as levitFilter2.
var color: Color
var held: Node2D = null
var _grab_levit := 0
var _box_vel := Vector2.ZERO
var _thrown: Node2D = null
var _thrown_t := 0
var _thrown_at := Vector2.ZERO


func _init(caster: CharacterBody2D, speed_: float, accel_: float, color_: Color) -> void:
	owner = caster
	speed = speed_
	accel = accel_
	color = color_


static func is_crate(node: Node) -> bool:
	return node != null and node.has_method("crate_top")


## grab: any previous hold is released first.
func grab(target: Node2D, levit: int = 2) -> void:
	if target == null or not is_instance_valid(target):
		return
	if held != null:
		release()
	held = target
	_grab_levit = levit
	if is_crate(target):
		_box_vel = Vector2.ZERO
		target.set_meta("tele_holder", owner)
		if target.has_method("hold_at"):
			target.call("hold_at", center_of(target), 0.0, 0.0)
		# hold_at tints with the player's teleTransform; foes pass no tint.
		(target as CanvasItem).modulate = Color.WHITE
		_Aura.attach(target, color)
		var layer := target.get_parent()
		if layer != null:
			layer.move_child(target, layer.get_child_count() - 1)
		return
	target.set("levit", levit)
	target.set("tele_holder", owner)
	target.set("frac_levit", int(owner.get("fraction")))
	target.set_meta("tele_frame", Engine.get_physics_frames())
	if target.is_in_group("player"):
		target.set_meta("levit_by", color)
	else:
		_Aura.attach(target, color)


## Steer the held centre toward a point; lets go if another caster took it,
## it broke free, or the game reset it.
func hold(at: Vector2) -> void:
	if held == null:
		return
	if not is_instance_valid(held):
		held = null
		return
	if _holder_of(held) != owner:
		held = null
		return
	var levit := _levit_of(held)
	if levit == 0 or (levit == 1 and _grab_levit != 1):
		release(false)
		return
	var crate := is_crate(held)
	if not crate:
		held.set("_climbing", false)
		held.set_meta("tele_frame", Engine.get_physics_frames())
	var d := at - center_of(held)
	var dist := d.length()
	var approach := minf(speed, minf(sqrt(2.0 * accel * dist + accel * accel / 4.0) - accel / 2.0, dist * EASE))
	var cur := _box_vel if crate else (held as CharacterBody2D).velocity / TPS
	var steer := -cur
	if dist > 0.0:
		steer += d / dist * approach
	steer = steer.limit_length(accel)
	if crate:
		_box_vel = _move_box(held, cur + steer)
	else:
		(held as CharacterBody2D).velocity = (cur + steer) * TPS


## Units 150 px beside the caster, crates 80, centre 40 px above its feet.
func hold_beside(side: float) -> void:
	if held == null or not is_instance_valid(held):
		held = null
		return
	var feet: Vector2 = owner.call("_feet", owner)
	var beside := BESIDE_OBJECT if is_crate(held) else BESIDE_UNIT
	hold(Vector2(feet.x + side * beside, feet.y - HOLD_HEIGHT - half_height(held)))


## A crate worth lifting within max_distance that the caster can see.
func find_box(max_distance: float) -> Node2D:
	var eye: Vector2 = owner.call("_body_center", owner)
	var space := owner.get_world_2d().direct_space_state
	for node in owner.get_tree().get_nodes_in_group("floor_box"):
		var box := node as Node2D
		if box == null or not is_instance_valid(box) or not is_crate(box):
			continue
		if bool(box.get("held")) or bool(box.call("crate_disabled")):
			continue
		if box.has_meta("levit_poss") and not bool(box.get_meta("levit_poss")):
			continue
		if float(box.get("massa")) < HEAVY_MASS or randf() >= BOX_CHANCE:
			continue
		var bc := center_of(box)
		if eye.distance_squared_to(bc) > max_distance * max_distance:
			continue
		var q := PhysicsRayQueryParameters2D.create(eye, bc, 1)
		q.exclude = [owner.get_rid(), box.get_rid()]
		if space.intersect_ray(q).is_empty():
			return box
	return null


## Add (dx, dy), capped at force, to the held velocity and let go untrimmed.
func throw_toward(dir: Vector2, force: float) -> void:
	if held == null or not is_instance_valid(held):
		held = null
		return
	_trim()
	var impulse := dir.limit_length(force)
	if is_crate(held):
		_box_vel += impulse
		_thrown = held
		_thrown_t = 60
		_thrown_at = center_of(held)
	else:
		(held as CharacterBody2D).velocity += impulse * TPS
	release(false)


## Units are flung sideways and up; crates fly in an arc at the point.
func throw_at(at: Vector2, force: float, side: float) -> void:
	if held == null or not is_instance_valid(held):
		held = null
		return
	var m := float(held.get("massa")) if is_crate(held) else _UnitMassa.massa(held)
	if m > HEAVY_MASS:
		force /= sqrt(m)
	if is_crate(held):
		var c := center_of(held)
		var dx := at.x - c.x
		throw_toward(Vector2(dx, at.y - c.y - absf(dx) / ARC_LIFT), force)
	else:
		throw_toward(Vector2(FLING.x * side, FLING.y), force)


## trim slows the body to accel * RELEASE first.
func release(trim: bool = true) -> void:
	var body := held
	held = null
	if body == null or not is_instance_valid(body):
		return
	if _holder_of(body) != owner:
		return
	if is_crate(body):
		if trim:
			_box_vel = _box_vel.limit_length(accel * RELEASE)
		if body.has_meta("tele_holder"):
			body.remove_meta("tele_holder")
		_Aura.clear(body)
		if body.has_method("release_vel"):
			body.call("release_vel", _box_vel * TPS)
		_box_vel = Vector2.ZERO
		return
	if trim:
		var cb := body as CharacterBody2D
		cb.velocity = (cb.velocity / TPS).limit_length(accel * RELEASE) * TPS
	body.set("levit", 0)
	body.set("tele_holder", null)
	if body.is_in_group("player"):
		if body.has_meta("levit_by"):
			body.remove_meta("levit_by")
	else:
		_Aura.clear(body)


## Box.attDrop for a crate this caster threw: it strikes the player it flies into.
func step_thrown() -> void:
	if _thrown == null or not is_instance_valid(_thrown) or _thrown_t <= 0:
		_thrown = null
		return
	_thrown_t -= 1
	var c := center_of(_thrown)
	var v := c - _thrown_at
	_thrown_at = c
	var vel2 := v.length_squared()
	if vel2 < 50.0:
		return
	var p := owner.get_tree().get_first_node_in_group("player") as Node2D
	if p == null or not p.has_method("take_hit"):
		return
	var hh := half_height(_thrown)
	var half_w := (float(_thrown.call("crate_right")) - float(_thrown.call("crate_left"))) * 0.5
	var box := Rect2(c - Vector2(half_w, hh), Vector2(half_w, hh) * 2.0)
	var size: Vector2 = owner.call("_body_size", p)
	var pc: Vector2 = owner.call("_body_center", p)
	if box.intersects(Rect2(pc - size * 0.5, size)):
		p.take_hit(int(round(float(_thrown.get("massa")) * (vel2 - 50.0) * BOX_DAMAGE)), "DAM_BLUNT")
		_thrown = null


func held_is_player() -> bool:
	return held != null and is_instance_valid(held) and held.is_in_group("player")


func center_of(node: Node2D) -> Vector2:
	if is_crate(node):
		return Vector2(float(node.call("crate_center_x")), (float(node.call("crate_top")) + float(node.call("crate_bottom"))) * 0.5)
	return owner.call("_body_center", node)


func half_height(node: Node2D) -> float:
	if is_crate(node):
		return (float(node.call("crate_bottom")) - float(node.call("crate_top"))) * 0.5
	return (owner.call("_body_size", node) as Vector2).y * 0.5


func _holder_of(node: Node2D) -> Variant:
	if is_crate(node):
		return node.get_meta("tele_holder") if bool(node.get("held")) and node.has_meta("tele_holder") else null
	return node.get("tele_holder")


func _levit_of(node: Node2D) -> int:
	if is_crate(node):
		return _grab_levit if bool(node.get("held")) else 0
	return int(node.get("levit"))


func _trim() -> void:
	if is_crate(held):
		_box_vel = _box_vel.limit_length(accel * RELEASE)
	else:
		var cb := held as CharacterBody2D
		cb.velocity = (cb.velocity / TPS).limit_length(accel * RELEASE) * TPS


## Box.run for a held crate: it stops on walls.
func _move_box(box: Node2D, v: Vector2) -> Vector2:
	var shape := box.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		box.global_position += v
		return v
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape.shape
	q.transform = shape.global_transform
	q.motion = v
	q.collision_mask = 1
	q.exclude = [box.get_rid(), owner.get_rid()]
	var frac := owner.get_world_2d().direct_space_state.cast_motion(q)
	var f := frac[0] if frac.size() > 0 else 1.0
	box.global_position += v * f
	return v if f >= 1.0 else Vector2.ZERO
