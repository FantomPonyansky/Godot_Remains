extends Node

## Line of sight against world + platform geometry.
## A body blocks sight unless it sets blocks_sight = false
## or sight_transparency >= 1 (fully see-through). Values in between
## are reserved: anything below 1 still blocks for this slice.

const MASK := 65  # world (1) + platforms (64)


func los_clear(from: Vector2, to: Vector2, target: Node = null) -> bool:
	var tree := get_tree()
	if tree == null:
		return true
	var world := tree.root.get_viewport().world_2d
	if world == null:
		return true
	var space := world.direct_space_state
	var exclude: Array[RID] = []
	var origin := from
	for _step in 8:
		var query := PhysicsRayQueryParameters2D.create(origin, to, MASK)
		query.exclude = exclude
		query.collide_with_areas = false
		query.hit_from_inside = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider: Object = hit.collider
		if target != null and collider == target:
			return true
		if not _blocks_sight(collider):
			exclude.append(hit.rid)
			var dir := to - origin
			if dir.length_squared() < 1.0:
				return true
			origin = hit.position + dir.normalized() * 2.0
			continue
		return false
	return false


func _blocks_sight(collider: Object) -> bool:
	if not collider is Node:
		return true
	var node := collider as Node
	if node.has_meta("blocks_sight") and not bool(node.get_meta("blocks_sight")):
		return false
	if node.has_meta("sight_transparency") and float(node.get_meta("sight_transparency")) >= 0.99:
		return false
	return true
