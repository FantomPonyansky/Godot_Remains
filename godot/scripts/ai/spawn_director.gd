class_name SpawnDirector
extends RefCounted

## One per land, held by land_props as _en_spawn. Every way a unit appears goes
## through it: build plans (land_spawn asks SpawnPolicy.room_count), the room
## spawners in en_spawn.gd (siren chain, allact spawn triggers, trial waves) and
## brain summons. The policy decides; the director counts what appeared.

const _EnSpawn := preload("res://scripts/map/en_spawn.gd")
const _Enemy := preload("res://scenes/enemy.tscn")

var props: Node
var policy: SpawnPolicy
## The room spawners (enspawn points, kolEnSpawn, the alarm timer).
var rooms: RefCounted
## Units spawned on this land by source (alarm, trigger, wave, summon) and by room key.
var by_source := {}
var by_room := {}


func _init(host: Node) -> void:
	props = host
	policy = SpawnPolicy.current()
	rooms = _EnSpawn.new(host, policy, note)


func add_point(row: Dictionary) -> void:
	rooms.add_point(row)


func left(key: String) -> int:
	return rooms.left(key)


func signal_room(key: String, n: int = 300) -> void:
	rooms.signal_room(key, n)


func tick(delta: float) -> void:
	rooms.tick(delta)


func spawn(key: String, one: bool, get_gg: bool) -> Node:
	return rooms.spawn(key, one, get_gg, &"trigger")


func wave_spawn(key: String, obj: Dictionary, n: int) -> Node:
	return rooms.wave_spawn(key, obj, n)


func note(unit: Node, source: StringName, key: String) -> void:
	if unit == null:
		return
	by_source[source] = int(by_source.get(source, 0)) + 1
	if key != "":
		by_room[key] = int(by_room.get(key, 0)) + 1


## The director of the land node is on, or null (a test arena without a land).
static func of(node: Node) -> SpawnDirector:
	if node == null or not node.is_inside_tree():
		return null
	var host := node.get_tree().get_first_node_in_group("land_props")
	return host.get("_en_spawn") as SpawnDirector if host != null else null


## loc.createUnit for a brain (UnitBrain.spawn_unit): a new enemy at the feet
## point, already awake toward wake_at when alert is set.
static func summon(owner: Node, uid: String, at: Vector2, metas: Dictionary, alert: bool, wake_at: Variant) -> CharacterBody2D:
	var director := of(owner)
	var pol := director.policy if director != null else SpawnPolicy.current()
	if not pol.allow_summon(owner, uid):
		return null
	var host := owner.get_tree().current_scene
	if host == null:
		return null
	var node := _Enemy.instantiate() as CharacterBody2D
	node.set_meta("unit_id", uid)
	for k in metas.keys():
		node.set_meta(k, metas[k])
	node.set_meta("owner_eid", Entity.eid_of(owner))
	node.position = at
	host.add_child(node)
	node.global_position = at
	if alert and node.has_method("_become_alert"):
		node.call("_become_alert", wake_at if wake_at is Vector2 else at)
	if director != null:
		director.note(node, &"summon", "")
	return node
