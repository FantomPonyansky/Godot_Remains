extends RefCounted

## Box.setVisState and Interact.sound: the objs.xml open / close / die sounds
## of a box or door, and the sndAct a lock, terminal or mine plays when the
## action starts. Building a land is quiet (states set while it loads).

const _Registry := preload("res://scripts/map/land_registry.gd")
const _PS := preload("res://scripts/prop_state.gd")
const QUIET_MS := 800

static var _quiet_until := 0


static func hush() -> void:
	_quiet_until = Time.get_ticks_msec() + QUIET_MS


## key is open, close, die or fall (objs.xml attributes).
static func obj(id: String, key: String, volume: float = 1.0) -> void:
	if id == "" or Time.get_ticks_msec() < _quiet_until:
		return
	var sid := str(_Registry.obj(id).get(key, ""))
	if sid != "":
		Fx.sound(sid, Vector2.ZERO, {"volume": volume})


static func node_obj(node: Node, key: String) -> void:
	if node == null:
		return
	obj(str(node.get_meta("door_id", node.get_meta("id", ""))), key)


## Interact.update sndAct: mines rem_act; locks lock_act, terminals term_act,
## electric and broken locks rem_act.
static func act(node: Node) -> void:
	var sid := ""
	if int(_PS.getv(node, "mine", 0)) > 0:
		sid = "rem_act"
	elif float(_PS.getv(node, "lock", 0.0)) > 0.0:
		match int(_PS.getv(node, "locktip", 1)):
			0, 1:
				sid = "lock_act"
			2:
				sid = "term_act"
			4, 5:
				sid = "rem_act"
	if sid != "":
		Fx.sound(sid, Vector2.ZERO)
