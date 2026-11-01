extends Node

## Presentation bus. The sim emits; SfxBank, CamShake, Hud and UnitFx play the
## event in the same call, so a sound or shake lands on the same frame as before.
## Each event carries the source eid and local: true for a world event or one
## whose player is the local player. Listeners play every event. A later peer
## skips HUD events whose local is false.

signal sounded(id: String, at: Vector2, opts: Dictionary, eid: String, local: bool)
signal shaken(amount: float, at: Vector2, opts: Dictionary, eid: String, local: bool)
signal float_numbered(value: String, at: Vector2, kind: String, opts: Dictionary, eid: String, local: bool)
signal noticed(text: String, opts: Dictionary, eid: String, local: bool)
signal particled(kind: String, at: Vector2, opts: Dictionary, eid: String, local: bool)
signal flashed(at: Vector2, opts: Dictionary, eid: String, local: bool)
## AI channel: saw, lost, heard, damaged, died, alarmed, spawned. Sim-side
## facts about a unit, not presentation; listeners must not change the sim.
signal ai_event(kind: StringName, eid: String, at: Vector2, opts: Dictionary)

const AI_KINDS: Array[StringName] = [&"saw", &"lost", &"heard", &"damaged", &"died", &"alarmed", &"spawned"]

var _prep_player: AudioStreamPlayer
var _prep_path := ""
var _prep_was := false

var counts := {
	"sound": 0,
	"shake": 0,
	"float_number": 0,
	"notice": 0,
	"particles": 0,
	"flash": 0,
	"blood": 0,
	"hum": 0,
	"ai": 0,
}
var _ai_log := false


## Weapon prep loop. The player sends one update a tick; this seeks the clip
## the way Weapon.actions sndPrep did (start at t_prep * 30 ms, loop marks).
func prep(id: String, opts: Dictionary = {}) -> void:
	var attacking := bool(opts.get("attacking", false))
	var ticks := float(opts.get("prep", 0.0))
	var was := _prep_was
	_prep_was = attacking
	if id == "":
		_prep_stop()
		return
	if _prep_player == null:
		_prep_player = AudioStreamPlayer.new()
		_prep_player.name = "PrepSound"
		add_child(_prep_player)
	var path := "res://assets/sfx/%s.wav" % id
	if not ResourceLoader.exists(path):
		path = "res://assets/sfx/%s.mp3" % id
	if not ResourceLoader.exists(path):
		_prep_stop()
		return
	if _prep_player.stream == null or _prep_path != path:
		_prep_player.stream = load(path) as AudioStream
		_prep_path = path
	var t1 := float(opts.get("t1", 0.0))
	var t2 := float(opts.get("t2", 0.0))
	var length := _prep_player.stream.get_length() * 1000.0 if _prep_player.stream else 0.0
	var pos := _prep_player.get_playback_position() * 1000.0 if _prep_player.playing else length
	if not was and attacking:
		_prep_player.play(ticks * 30.0 / 1000.0)
		_count("sound")
	elif t1 > 0.0 and attacking and pos > t2 - 300.0:
		_prep_player.play((t1 + 200.0) / 1000.0)
		_count("sound")
	elif t2 > 0.0 and was and not attacking and ticks > 0.0 and _prep_player.playing and pos < t2 - 400.0:
		_prep_player.play((t2 + 100.0) / 1000.0)
		_count("sound")


func _prep_stop() -> void:
	_prep_was = false
	if _prep_player != null and _prep_player.playing:
		_prep_player.stop()


var _quake_left: Callable = Callable()


## CamShake registers the live count. No listener means no quake (0).
func bind_quake(left_of: Callable) -> void:
	_quake_left = left_of


## Quake ticks still running. Units toss whoever stands on the floor.
func quake_left() -> int:
	if _quake_left.is_valid():
		return int(_quake_left.call())
	return 0


func sound(id: String, at: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> void:
	if id == "":
		return
	if bool(opts.get("hum", false)):
		_count("hum")
	else:
		_count("sound")
	_emit_sound(id, at, opts)


func shake(amount: float, at: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> void:
	_count("shake")
	shaken.emit(amount, at, opts, _eid(opts), _belongs_local(opts))


func float_number(value: Variant, at: Vector2, kind: String = "hit", opts: Dictionary = {}) -> void:
	_count("float_number")
	float_numbered.emit(str(value), at, kind, opts, _eid(opts), _belongs_local(opts))


func notice(text: String, opts: Dictionary = {}) -> void:
	if text == "" and not bool(opts.get("message", false)):
		return
	_count("notice")
	noticed.emit(text, opts, _eid(opts), _belongs_local(opts))


func particles(kind: String, at: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> void:
	if kind == "":
		return
	_count("particles")
	_emit_particles(kind, at, opts)


## Blood spray. kind defaults to blood; gblood, pblood and bloodexpl pass kind.
func blood(at: Vector2, opts: Dictionary = {}) -> void:
	var kind := str(opts.get("kind", "blood"))
	if kind == "":
		return
	var rest := opts.duplicate()
	rest.erase("kind")
	_count("blood")
	_count("particles")
	_emit_particles(kind, at, rest)


## No listener yet: bullet tracer ghosts are still drawn on the bullet.
func flash(at: Vector2, opts: Dictionary = {}) -> void:
	_count("flash")
	flashed.emit(at, opts, _eid(opts), _belongs_local(opts))


## A unit event on the AI channel. unit is the enemy body; at defaults to its position.
func ai(kind: StringName, unit: Node2D, opts: Dictionary = {}) -> void:
	_count("ai")
	if ai_event.get_connections().is_empty():
		return
	var at: Vector2 = opts.get("at", unit.global_position)
	ai_event.emit(kind, Entity.eid_of(unit), at, opts)


## Debug listener: prints every AI event while on.
func set_ai_log(on: bool) -> void:
	if on == _ai_log:
		return
	_ai_log = on
	if on:
		ai_event.connect(_print_ai)
	else:
		ai_event.disconnect(_print_ai)


func ai_log_on() -> bool:
	return _ai_log


func _print_ai(kind: StringName, eid: String, at: Vector2, opts: Dictionary) -> void:
	print("AI %d %s %s (%d, %d) %s" % [Sim.tick, kind, eid, int(at.x), int(at.y), opts])


func summary() -> String:
	return "sound %d shake %d float %d notice %d particles %d blood %d hum %d flash %d ai %d" % [
		int(counts.sound), int(counts.shake), int(counts.float_number), int(counts.notice),
		int(counts.particles), int(counts.blood), int(counts.hum), int(counts.flash), int(counts.ai)]


func _emit_sound(id: String, at: Vector2, opts: Dictionary) -> void:
	sounded.emit(id, at, opts, _eid(opts), _belongs_local(opts))


func _emit_particles(kind: String, at: Vector2, opts: Dictionary) -> void:
	var tree := get_tree()
	if tree != null:
		UnitFx.host(tree)
	if particled.get_connections().is_empty():
		if tree != null:
			UnitFx.emit(tree, kind, at, opts)
		return
	particled.emit(kind, at, opts, _eid(opts), _belongs_local(opts))


func _eid(opts: Dictionary) -> String:
	if opts.has("eid"):
		return str(opts.eid)
	var source: Variant = opts.get("source", null)
	if source is Node:
		return Entity.eid_of(source)
	return ""


func _belongs_local(opts: Dictionary) -> bool:
	if opts.has("local"):
		return opts.local == true
	var source: Variant = opts.get("source", null)
	if not source is Node or not is_instance_valid(source):
		return true
	var owner := _player_owner(source)
	if owner == null:
		return true
	var lp := Run.local_player()
	return lp == null or owner == lp


func _player_owner(node: Node) -> Node:
	if node.is_in_group("player"):
		return node
	var cur := node.get_parent()
	while cur != null:
		if cur.is_in_group("player"):
			return cur
		cur = cur.get_parent()
	if node.get("from_player") == true:
		return Run.local_player()
	return null


func _count(key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _exit_tree() -> void:
	if OS.get_environment("FOE_FX_LOG") == "1":
		print("Fx " + summary())
