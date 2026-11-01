extends RefCounted

## Gameplay fields for doors, props, areas and trap use-timers.
## put() writes the property when the node has _field_set and that key, and
## does not mirror meta.
## Nodes without _field_set keep the key in meta: walls, platforms, slopes,
## room edges, NPCs, checkpoints and unit brains.
## getv() returns the property when the set-mark is on, else meta, else the
## caller's fallback (an unset box_hp is not 0). hasv() is the old
## has_meta("was this ever set"). clear() drops the mark and the meta.
## Builders may set_meta before _ready; absorb() copies those keys once and
## drops the meta. That is play_land._stand_in_door
## (hp, thre, breakable), play_land._spawn_doors and begin_land._add_door
## (usable), and held_prop._ready (blocks_sight).
## Trap meta "dead" is the remembered flag, not the destroyed property, so
## traps keep writing that one with set_meta and absorb does not see it.

const FIELDS: Array[String] = [
	"door_open", "lock", "hp", "thre", "breakable", "dead", "usable", "blocks_sight",
	"mine", "hackable", "locktip", "lock_hp", "lock_level", "lock_att", "mine_tip",
	"allact", "allid", "once", "act_time", "lock_key", "keyloss", "fun", "sec",
	"user_action", "hold_use", "spent", "opened", "box_hp", "vis_state", "enabled",
	"touched", "box_open", "close_at", "cool", "taken", "damage", "ceiling", "prize_locked",
]

const MIRROR: Array[String] = []


static func absorb(node: Node) -> void:
	if node == null or not ("_fields_live" in node) or not ("_field_set" in node):
		return
	var flags := _copy_flags(node)
	for key in FIELDS:
		if not (key in node) or not node.has_meta(key):
			continue
		node.set(key, node.get_meta(key))
		flags[key] = true
		if not MIRROR.has(key):
			node.remove_meta(key)
	node.set("_field_set", flags)
	node.set("_fields_live", true)


static func put(node: Node, key: String, value: Variant) -> void:
	if node == null:
		return
	if "_field_set" in node and key in node:
		node.set(key, value)
		var flags := _copy_flags(node)
		flags[key] = true
		node.set("_field_set", flags)
		if MIRROR.has(key):
			node.set_meta(key, value)
		elif node.has_meta(key):
			node.remove_meta(key)
		return
	node.set_meta(key, value)


static func clear(node: Node, key: String) -> void:
	if node == null:
		return
	if "_field_set" in node and key in node:
		var flags := _copy_flags(node)
		flags.erase(key)
		node.set("_field_set", flags)
	if node.has_meta(key):
		node.remove_meta(key)


static func getv(node: Node, key: String, fallback: Variant = null) -> Variant:
	if node == null:
		return fallback
	if _marked(node, key):
		return node.get(key)
	if node.has_meta(key):
		return node.get_meta(key)
	if _owns(node, key):
		return fallback if fallback != null else node.get(key)
	return fallback


## True when put, absorb or a pre-ready set_meta wrote this key.
static func hasv(node: Node, key: String) -> bool:
	if node == null:
		return false
	if _marked(node, key):
		return true
	if _owns(node, key):
		return false
	return node.has_meta(key)


## The ents row land_memory stores. Same keys as the old meta capture.
static func record(node: Node) -> Dictionary:
	var out := {}
	if hasv(node, "lock"):
		out["lock"] = float(getv(node, "lock", 0.0))
	if bool(getv(node, "opened", false)):
		out["open"] = true
	if bool(getv(node, "dead", false)):
		out["dead"] = true
	if hasv(node, "box_hp"):
		out["box_hp"] = float(getv(node, "box_hp", 0.0))
	if hasv(node, "vis_state"):
		out["vis"] = str(getv(node, "vis_state", ""))
	if node is Area2D and hasv(node, "enabled"):
		out["on"] = bool(getv(node, "enabled", false))
	if node.is_in_group("floor_box") or node.is_in_group("levitatable"):
		var at := (node as Node2D).position
		out["pos"] = [at.x, at.y]
	if node.has_method("memory_state"):
		var state: Dictionary = node.call("memory_state")
		if not state.is_empty():
			out["state"] = state
	return out


static func apply_fields(node: Node, rec: Dictionary) -> void:
	if rec.has("lock"):
		put(node, "lock", float(rec.lock))
	if bool(rec.get("open", false)):
		put(node, "spent", true)
		put(node, "opened", true)
	if bool(rec.get("dead", false)):
		put(node, "dead", true)
		put(node, "spent", true)
	if rec.has("box_hp"):
		put(node, "box_hp", float(rec.box_hp))
	if rec.has("vis"):
		put(node, "vis_state", str(rec.vis))
		put(node, "allact", "")
	if rec.has("on") and node is Area2D:
		put(node, "enabled", bool(rec.on))


static func door_record(node: Node) -> Dictionary:
	return {
		"open": bool(getv(node, "door_open", false)),
		"lock": float(getv(node, "lock", 0.0)),
		"dead": bool(getv(node, "dead", false)),
		"hp": int(getv(node, "hp", 0)),
	}


static func _owns(node: Node, key: String) -> bool:
	return "_field_set" in node and key in node and "_fields_live" in node and bool(node.get("_fields_live"))


static func _marked(node: Node, key: String) -> bool:
	if node == null or not ("_field_set" in node) or not (key in node):
		return false
	var flags: Variant = node.get("_field_set")
	return flags is Dictionary and (flags as Dictionary).has(key)


static func _copy_flags(node: Node) -> Dictionary:
	var flags: Variant = node.get("_field_set")
	if flags is Dictionary:
		return (flags as Dictionary).duplicate()
	return {}
