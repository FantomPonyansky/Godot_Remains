class_name Entity
extends RefCounted

## Duck-typed contract for a thing that can be hit and saved. GDScript has no
## interfaces, so this is not a base class. A node meets it when it has
## eid, kind, faction (units keep fraction; faction_of reads both),
## take_hit(hit: HitInfo), snapshot() -> Dictionary and restore(d).
## authority (see has_authority) gates simulation, never presentation.
## Doors and props keep gameplay state on fields (prop_state.gd). These helpers
## still read a property first, then meta, so a wid or a door_id stamped at
## build time keeps working.

static func eid_of(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	var prop: Variant = node.get("eid")
	if prop is String and prop != "":
		return prop
	if node.has_meta("eid"):
		var stamped := str(node.get_meta("eid"))
		if stamped != "":
			return stamped
	if node.has_meta("wid"):
		return str(node.get_meta("wid"))
	return ""


static func kind_of(node: Node) -> StringName:
	if node == null or not is_instance_valid(node):
		return &""
	var prop: Variant = node.get("kind")
	if prop is StringName and prop != &"":
		return prop
	if prop is String and str(prop) != "":
		return StringName(str(prop))
	if node.has_meta("kind"):
		var stamped := str(node.get_meta("kind"))
		if stamped != "":
			return StringName(stamped)
	if node.is_in_group("player"):
		return &"player"
	if node.is_in_group("story_npc"):
		return &"npc"
	if node.is_in_group("player_bullets") or node.is_in_group("enemy_bullets") or node.is_in_group("radio_mines"):
		return &"bullet"
	if node.is_in_group("trap_units") or node.is_in_group("begin_traps"):
		return &"trap"
	if node.is_in_group("ground_loot"):
		return &"drop"
	if node.is_in_group("enemies") or node.is_in_group("allies") or node.is_in_group("pets"):
		return &"unit"
	if node.has_meta("door_id") or node.has_meta("door_open"):
		return &"door"
	if node.has_method("is_alert"):
		return &"unit"
	return &"prop"


static func faction_of(node: Node) -> int:
	if node == null or not is_instance_valid(node):
		return 0
	var prop: Variant = node.get("faction")
	if (prop is int or prop is float) and not (prop is bool):
		return int(prop)
	prop = node.get("fraction")
	if prop is int or prop is float:
		return int(prop)
	if node.has_meta("fraction"):
		return int(node.get_meta("fraction"))
	if node.is_in_group("player") or bool(node.get("from_player")):
		return 100
	return 0


## False when another peer simulates the node and this one only shows it.
## Always true in single player; a node without the field has authority.
static func has_authority(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var prop: Variant = node.get("authority")
	return prop if prop is bool else true


## Stamps kind and an eid. An authored wid is the eid. Anything else gets
## <owner_eid>/s<counter> from Run.alloc_eid (owner "run" when owner_eid is empty).
static func claim(node: Node, node_kind: StringName, owner_eid: String = "") -> String:
	if node == null or not is_instance_valid(node):
		return ""
	var current: Variant = node.get("kind")
	if current == null or str(current) == "":
		if "kind" in node:
			node.set("kind", node_kind)
		else:
			node.set_meta("kind", String(node_kind))
	var existing := eid_of(node)
	if existing != "":
		_stamp(node, existing)
		return existing
	var owner := owner_eid
	if owner == "" and node.has_meta("owner_eid"):
		owner = str(node.get_meta("owner_eid"))
	var id := ""
	if node.is_inside_tree():
		var run := node.get_node_or_null("/root/Run")
		if run != null and run.has_method("alloc_eid"):
			id = str(run.call("alloc_eid", owner))
	if id == "":
		return ""
	_stamp(node, id)
	return id


## The dict land_memory already stores for this node. Empty when the land has
## nothing to say about it (a bullet, the player).
static func captured(node: Node) -> Dictionary:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return {}
	var props := node.get_tree().get_first_node_in_group("land_props")
	if props != null and props.has_method("capture_one"):
		var rec: Variant = props.call("capture_one", node)
		if rec is Dictionary:
			return rec
	return {}


static func apply_captured(node: Node, data: Dictionary) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	var props := node.get_tree().get_first_node_in_group("land_props")
	if props != null and props.has_method("apply_one"):
		props.call("apply_one", node, data)


static func _stamp(node: Node, id: String) -> void:
	node.set_meta("eid", id)
	if "eid" in node:
		node.set("eid", id)
	note(node, id)


## eid -> WeakRef of every node claim stamped (and players). A rebuilt land
## stamps the same eid again and replaces the freed node.
static var _index: Dictionary = {}


static func note(node: Node, id: String) -> void:
	if id != "":
		_index[id] = weakref(node)


## The live node with this eid, or null.
static func node_of(id: String) -> Node:
	var ref: WeakRef = _index.get(id)
	if ref == null:
		return null
	var node := ref.get_ref() as Node
	if node == null or not is_instance_valid(node):
		_index.erase(id)
		return null
	return node
