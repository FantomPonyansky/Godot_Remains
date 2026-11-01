extends Node

## AI blackboard (architecture step R6.1). What units share about the
## world, kept here instead of enemy_senses statics and player meta:
## - per player: the meters units raise and read (noise, observation,
##   demask; UnitPlayer.noise / observation / demask) and the facts every unit
##   reads for that player this frame (room darkness, sneak, stealth, armour
##   visiMult, critInvis);
## - for all players: the grenades in flight, the player shots already heard,
##   and the room the player watch last reported;
## - per faction: the last place and tick each player was seen, and the tick
##   each room was alarmed. Nothing reads these yet (R6.6 directors will).
## enemy_senses.gd does the math as before and stores it here. A player node
## that is replaced (a new run) starts with fresh meters, as its meta did.

class Meters:
	var owner_id := 0
	var noise := 0.0
	var obs := 0.0
	var is_obs := 0.0
	var demask := 0.0


class Facts:
	var frame := -1
	var room := Vector2i(-99999, -99999)
	var vis_mult := 1.0
	var sneak := 0.0
	var stealth := 1.0
	var visi := 1.0
	var crit_invis := 0.0


const NO_ROOM := Vector2i(-99999, -99999)
## The faction key a room siren (land_props._raise_alarm) records under.
const SIREN := -1

## The player room RoomWatch reported last (enemy.gd room activity).
var room := NO_ROOM
## Grenade positions in flight, refreshed once per physics frame.
var danger: Array = []
## Physics frame the shared meters were last ticked in.
var sense_frame := -1
## Player bullet instance ids already heard.
var known_shots := {}
## The land in play's TacticsDirector (land_props sets and clears it), or null.
var tactics: TacticsDirector = null

var _meters := {}
var _facts := {}
var _seen := {}
var _alarms := {}


func meters(player: Node) -> Meters:
	var pid := _pid(player)
	var m: Meters = _meters.get(pid)
	var id := player.get_instance_id() if player != null else 0
	if m == null or m.owner_id != id:
		m = Meters.new()
		m.owner_id = id
		_meters[pid] = m
	return m


## Facts for player; facts(null) is the local player's (enemy.gd damage).
func facts(player: Node = null) -> Facts:
	var pid := _pid(player)
	var f: Facts = _facts.get(pid)
	if f == null:
		f = Facts.new()
		_facts[pid] = f
	return f


func note_seen(fraction: int, player: Node, at: Vector2) -> void:
	if not _seen.has(fraction):
		_seen[fraction] = {}
	(_seen[fraction] as Dictionary)[_pid(player)] = {"pos": at, "tick": Sim.tick}


## {pos, tick} of the last time fraction saw player; {} if never.
func last_seen(fraction: int, player: Node) -> Dictionary:
	return (_seen.get(fraction, {}) as Dictionary).get(_pid(player), {})


func note_alarm(fraction: int, at_room: Vector2i) -> void:
	if not _alarms.has(fraction):
		_alarms[fraction] = {}
	(_alarms[fraction] as Dictionary)[at_room] = Sim.tick


## Tick fraction was last alarmed in at_room, -1 if never.
func alarmed_at(fraction: int, at_room: Vector2i) -> int:
	return int((_alarms.get(fraction, {}) as Dictionary).get(at_room, -1))


## fraction -> pid -> {pos, tick}. Read only (the debug view).
func seen_all() -> Dictionary:
	return _seen


## fraction -> room -> tick. Read only (the debug view).
func alarms_all() -> Dictionary:
	return _alarms


func _ready() -> void:
	_connect_travel.call_deferred()


func _connect_travel() -> void:
	var travel := get_node_or_null("/root/Travel")
	if travel != null and travel.has_signal("land_entered"):
		travel.land_entered.connect(func(_id: String) -> void: clear_land())


## A new land: faction knowledge starts over. Meters, the watched room and
## the per-frame lists carry on as the enemy_senses statics did.
func clear_land() -> void:
	_seen.clear()
	_alarms.clear()


## The policies keep their instance in a static var; drop them so the scripts free at exit.
func _exit_tree() -> void:
	SpawnPolicy.use(null)
	TacticsPolicy.use(null)
	tactics = null


func _pid(player: Node) -> int:
	if player == null:
		return 0
	var v: Variant = player.get("pid")
	return int(v) if v != null else 0
