extends Node

## Unit registry. A cached copy of the "enemies" group in group (tree) order,
## rebuilt once per physics tick or after a unit enters, leaves or changes the
## group (touch), plus the same list bucketed by room. Every query returns group
## order, so a caller visits the same units in the same order as a group scan.
## Rooms are padded by one so a unit that moved this tick is still a candidate;
## callers keep their own exact distance or rect test.

const GROUP := "enemies"
const ROOM := Vector2(1920.0, 1000.0)

var _frame := -1
var _dirty := true
var _list: Array = []
var _rooms := {}
## Largest unit _ear in the list (budilo reach is rad * ear).
var max_ear := 1.0
var rebuilds := 0


func touch() -> void:
	_dirty = true


## Every unit in the group. Read only; it is shared until the next rebuild.
func enemies() -> Array:
	_refresh()
	return _list


## Units whose room is within one of a room the rect touches.
func in_rect(rect: Rect2) -> Array:
	_refresh()
	var a := room_of(rect.position) - Vector2i.ONE
	var b := room_of(rect.end) + Vector2i.ONE
	var picks := PackedInt32Array()
	for room: Vector2i in _rooms:
		if room.x >= a.x and room.x <= b.x and room.y >= a.y and room.y <= b.y:
			picks.append_array(_rooms[room])
	picks.sort()
	var out: Array = []
	out.resize(picks.size())
	for i in picks.size():
		out[i] = _list[picks[i]]
	return out


## Candidates within radius of at (a superset; test the distance yourself).
func near(at: Vector2, radius: float) -> Array:
	return in_rect(Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0))


## The live unit with this eid, or null.
func of(eid: String) -> Node:
	return Entity.node_of(eid)


static func room_of(at: Vector2) -> Vector2i:
	return Vector2i(int(floor(at.x / ROOM.x)), int(floor(at.y / ROOM.y)))


func _refresh() -> void:
	var frame := Engine.get_physics_frames()
	if not _dirty and frame == _frame:
		return
	_dirty = false
	_frame = frame
	rebuilds += 1
	_list = get_tree().get_nodes_in_group(GROUP)
	_rooms = {}
	max_ear = 1.0
	for i in _list.size():
		var n2 := _list[i] as Node2D
		if n2 == null:
			continue
		var room := room_of(n2.global_position)
		var bucket: PackedInt32Array = _rooms.get(room, PackedInt32Array())
		bucket.append(i)
		_rooms[room] = bucket
		var ear: Variant = n2.get("_ear")
		if ear != null and float(ear) > max_ear:
			max_ear = float(ear)
