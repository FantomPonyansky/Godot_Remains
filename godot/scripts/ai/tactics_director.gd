class_name TacticsDirector
extends RefCounted

## One per land (land_props._tactics, AiWorld.tactics while the land is in).
## Every regroup_ticks it groups awake hostile units into squads by fraction and
## room, asks the policy for roles and orders, and writes each order into the
## unit's brain if its takes_order() accepts the kind. Brains ask ask() for an
## attack slot. Squads are rebuilt from scratch and are not saved; losses are
## kept per fraction and room for the land's life.

class Squad extends RefCounted:
	var id := 0
	var fraction := 0
	var room := Vector2i.ZERO
	## Vector3i(fraction, room.x, room.y): the same across regroups.
	var key := Vector3i.ZERO
	var members: Array = []
	## unit instance id -> role
	var roles: Dictionary = {}
	var centre := Vector2.ZERO
	## The player a member tracks, or null.
	var target: Node2D = null
	## Members of this fraction and room that died on this land.
	var losses := 0


var props: Node
var policy: TacticsPolicy
var squads: Array = []
var _by_unit := {}
## unit instance id -> [unit, brain given the order]
var _ordered := {}
## squad key -> deaths seen at regroup
var losses := {}
var _bad_kinds := {}
var _next_id := 1
var _last := -1
## target instance id -> [tick, slots granted that tick]
var _attackers := {}
var granted := 0
var denied := 0


func _init(host: Node) -> void:
	props = host
	policy = TacticsPolicy.current()


func tick() -> void:
	if _last >= 0 and Sim.tick - _last < policy.regroup_ticks() and Sim.tick >= _last:
		return
	regroup_now()


func regroup_now() -> void:
	_last = Sim.tick
	for sq: Squad in squads:
		for unit in sq.members:
			if not is_instance_valid(unit) or bool((unit as Node).get("_dead")):
				losses[sq.key] = int(losses.get(sq.key, 0)) + 1
	squads.clear()
	_by_unit.clear()
	var keyed := {}
	for node in Units.enemies():
		var unit := node as Node2D
		if unit == null or not is_instance_valid(unit) or bool(unit.get("_dead")) or bool(unit.get("_asleep")) or bool(unit.get("_friendly")):
			continue
		var fraction := int(unit.get("fraction"))
		var room := Units.room_of(unit.global_position)
		var key := Vector3i(fraction, room.x, room.y)
		var sq: Squad = keyed.get(key)
		if sq == null:
			sq = Squad.new()
			sq.id = _next_id
			_next_id += 1
			sq.fraction = fraction
			sq.room = room
			sq.key = key
			sq.losses = int(losses.get(key, 0))
			keyed[key] = sq
			squads.append(sq)
		sq.members.append(unit)
		_by_unit[unit.get_instance_id()] = sq
		if sq.target == null and bool(unit.get("_track_player")):
			sq.target = unit.get("_player") as Node2D
	var now_ordered := {}
	for sq: Squad in squads:
		var sum := Vector2.ZERO
		for unit: Node2D in sq.members:
			sum += unit.global_position
		sq.centre = sum / float(sq.members.size())
		sq.roles = policy.roles(sq)
		for unit: Node2D in sq.members:
			var order := _checked(policy.order(unit, sq, sq.roles.get(unit.get_instance_id(), &"")))
			if order.is_empty():
				continue
			var brain: Variant = unit.call("_ai") if unit.has_method("_ai") else null
			if brain != null and brain.takes_order(StringName(order.kind)):
				brain.order = order
				now_ordered[unit.get_instance_id()] = [unit, brain]
	for iid in _ordered:
		var was: Array = _ordered[iid]
		var kept: Array = now_ordered.get(iid, [])
		if kept.is_empty() or kept[1] != was[1]:
			if is_instance_valid(was[0]):
				was[1].order = {}
	_ordered = now_ordered


## The order with a known kind, else {} (warned once per kind).
func _checked(order: Dictionary) -> Dictionary:
	if order.is_empty():
		return order
	var kind := StringName(str(order.get("kind", "")))
	if kind in TacticsPolicy.ORDERS:
		return order
	if not _bad_kinds.has(kind):
		_bad_kinds[kind] = true
		push_warning("TacticsDirector: unknown order kind %s" % kind)
	return {}


## Attack slot for unit on target through the current land's director; with no
## land (a test arena) every slot is granted.
static func ask(unit: Node, target: Node, kind: StringName) -> bool:
	var tactics := AiWorld.tactics
	return tactics == null or tactics.grant(unit, target, kind)


func squad_of(unit: Node) -> Squad:
	return _by_unit.get(unit.get_instance_id()) if unit != null else null


## An attack slot for unit on target this tick. The default policy grants all.
func grant(unit: Node, target: Node, kind: StringName) -> bool:
	var n := 0
	var rec: Array = []
	if target != null:
		rec = _attackers.get(target.get_instance_id(), [])
		if rec.is_empty() or int(rec[0]) != Sim.tick:
			rec = [Sim.tick, 0]
		n = int(rec[1])
	if not policy.grant(unit, target, kind, n):
		denied += 1
		return false
	granted += 1
	if target != null:
		rec[1] = n + 1
		_attackers[target.get_instance_id()] = rec
	return true
