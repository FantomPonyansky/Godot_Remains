extends Node

## One entry per world change. Gameplay calls these instead of changing doors,
## containers, drops, hits, triggers, travel, trades or the stash directly.
## Single player applies each at once. With authority off (a client) a call only
## emits requested; the host's result reaches this peer as a snapshot.
## A target is a node or an eid (Entity.node_of). A target whose authority is
## false is also only requested.
## applied fires after each change, for mods and for systems that react to it
## (water on doors and walls).
## Owners register run-wide handlers in their _ready (Travel, Vendors, Stash), so
## this node depends on none of them. Land objects go to the land_props node
## they belong to, so a preview and the game each keep their own land.
## Snapshot restores and land building do not come through here. Things a
## change spawns (spilled loot, drops of a killed unit) are made inside it on the
## peer that applies it. Moving bodies (thrown crates, falling drops, traps) are
## simulation; their ticks branch on authority instead.
## pid on a call is the acting player (0 is the local one). Handlers read it
## from actor while they run; the character they change is Run.character(actor).

signal applied(op: StringName, args: Array)
signal requested(op: StringName, args: Array)

var authority := true
## Acting player of the change being applied.
var actor := 0
var _handlers: Dictionary = {}


func handle(op: StringName, callable: Callable) -> void:
	_handlers[op] = callable


## Door swing; lock >= 0 also sets the lock (0 clears it).
func open_door(door: Variant, is_open: bool, lock := -1.0) -> void:
	_land(&"open_door", door, "door_op", [is_open, lock])


## Opens a container: lock and touch checks, spill, its actions and terminal.
func open_container(crate: Variant, from_timer := false) -> void:
	_land(&"open_container", crate, "_open_loot", [from_timer])


## A crowbar or blast blow on a locked container. True when the box caught it.
func break_object(crate: Variant, destroy: float) -> bool:
	return _land(&"break_object", crate, "break_crate", [destroy]) == true


func damage_object(crate: Variant, destroy: float) -> void:
	_land(&"damage_object", crate, "damage_box", [destroy])


## A wall cell (rect in land space) broke. source is any node of that land.
func break_cell(source: Node, rect: Rect2) -> void:
	_land(&"break_cell", source, "note_broken", [rect], false)


## Sets the lock (0 unlocks).
func unlock(target: Variant, lock := 0.0) -> void:
	_land(&"unlock", target, "body_lock", [lock])


## A lock pick, hack or key try. True when it opened.
func pick_lock(target: Variant, pid := 0) -> bool:
	return _land(&"pick_lock", target, "_pass_lock", [], true, pid) == true


func press_button(target: Variant, pid := 0) -> void:
	_land(&"press_button", target, "_on_button", [], true, pid)


func use_object(target: Variant, from_timer := false, pid := 0) -> void:
	_land(&"use_object", target, "_use_object", [from_timer], true, pid)


func use_terminal(target: Variant, pid := 0) -> void:
	_land(&"use_terminal", target, "_run_terminal", [], true, pid)


## A passage between rooms or lands.
func pass_through(target: Variant, from_timer := false, pid := 0) -> void:
	_land(&"pass_through", target, "_go_through", [from_timer], true, pid)


## Object script steps (die actions of units and traps). source is any node
## of the land; owner is the object the steps act for.
func run_actions(source: Node, steps: Variant, owner: Node = null) -> void:
	_land(&"run_actions", source, "run_actions", [steps, "", owner], false)


func take_loot(drop: Variant, pid := 0) -> void:
	_on(&"take_loot", drop, "pickup", [], pid)


func damage(target: Variant, hit: HitInfo) -> void:
	_on(&"damage", target, "take_hit", [hit])


func kill(target: Variant) -> void:
	_on(&"kill", target, "take_hit", [HitInfo.plain(999)])


func set_trigger(key: String, value: Variant = 1) -> void:
	_run(&"set_trigger", [key, value])


func travel(land_id: String) -> void:
	_run(&"travel", [land_id])


func activate_checkpoint(cp: Node, land_id: String, code: String, pid := 0) -> void:
	_run(&"activate_checkpoint", [cp, land_id, code], pid)


func add_quest(id: String, load_obj: Dictionary = {}, no_vis := false, snd := true, show_dial := true) -> void:
	_run(&"add_quest", [id, load_obj, no_vis, snd, show_dial])


func close_quest(id: String, sid: String = "") -> void:
	_run(&"close_quest", [id, sid])


func inc_quests(cid: String, n: int = 1) -> void:
	_run(&"inc_quests", [cid, n])


func add_note(id: String) -> void:
	_run(&"add_note", [id])


func set_npc_rep(id: String, value: int) -> void:
	_run(&"set_npc_rep", [id, value])


func trade(rows: Array, pid := 0) -> bool:
	return _run(&"trade", [rows], pid) == true


func sell(rows: Array, pid := 0) -> bool:
	return _run(&"sell", [rows], pid) == true


func sell_all(rows: Array, pid := 0) -> bool:
	return _run(&"sell_all", [rows], pid) == true


func take_weapon(uid: String, sost: float, tr: int, pid := 0) -> void:
	_run(&"take_weapon", [uid, sost, tr], pid)


func take_all_tasks(pid := 0) -> void:
	_run(&"take_all_tasks", [], pid)


func store_armor(id: String, stored: bool, pid := 0) -> bool:
	return _run(&"store_armor", [id, stored], pid) == true


## For host-only code that is not one op (story scripts): true when this peer
## runs it; otherwise emits requested and the caller stops.
func applies(op: StringName, args: Array = []) -> bool:
	if authority:
		return true
	requested.emit(op, args)
	return false


func _run(op: StringName, args: Array, pid := 0) -> Variant:
	if not authority:
		requested.emit(op, args)
		return null
	var call: Callable = _handlers.get(op, Callable())
	if not call.is_valid():
		push_warning("WorldOps: no handler for %s" % op)
		return null
	var out: Variant = _call(pid, call, args)
	applied.emit(op, args)
	return out


func _call(pid: int, call: Callable, args: Array) -> Variant:
	var was := actor
	actor = pid
	var out: Variant = call.callv(args)
	actor = was
	return out


## Calls method on the target itself.
func _on(op: StringName, target: Variant, method: String, args: Array, pid := 0) -> Variant:
	var node := _node(target)
	if node == null or not node.has_method(method):
		return null
	return _apply(op, node, node, method, args, pid)


## Calls method on the target's land_props with the target first.
func _land(op: StringName, target: Variant, method: String, args: Array, pass_target := true, pid := 0) -> Variant:
	var node := _node(target)
	var props := _props_of(node)
	if props == null or not props.has_method(method):
		return null
	return _apply(op, node, props, method, ([node] + args) if pass_target else args, pid)


func _apply(op: StringName, node: Node, owner: Object, method: String, args: Array, pid := 0) -> Variant:
	var report: Array = args if not args.is_empty() and args[0] is Node and args[0] == node else [node] + args
	if not authority or not Entity.has_authority(node):
		requested.emit(op, report)
		return null
	var out: Variant = _call(pid, Callable(owner, method), args)
	applied.emit(op, report)
	return out


func _node(target: Variant) -> Node:
	if target is Node:
		return target if is_instance_valid(target) else null
	if target is String or target is StringName:
		return Entity.node_of(str(target))
	return null


func _props_of(node: Node) -> Node:
	if node == null:
		return null
	var at := node
	while at != null:
		if at.is_in_group("land_props"):
			return at
		at = at.get_parent()
	if node.is_inside_tree():
		return node.get_tree().get_first_node_in_group("land_props")
	return null
