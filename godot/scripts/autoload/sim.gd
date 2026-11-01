extends Node

## One 30 Hz clock for the run. Physics is already 30 Hz, so each physics tick
## is one sim tick. physhz can change the physics rate at runtime; only then
## does the accumulator run, and at most MAX_CATCH_UP ticks per callback.
## Pause is a set of reasons. Gameplay phases wait while any reason is set.
## PRESENTATION still runs, so music fades keep moving. get_tree().paused follows
## this flag; GameState.paused listens to pause_changed.

const TICK_RATE := 30
const TICK := 1.0 / TICK_RATE


## Nearest tick for a wall-clock duration. 100 ms is 3, 667 ms is 20.
static func ticks_from_ms(ms: int) -> int:
	return int(round(float(ms) * float(TICK_RATE) / 1000.0))


## Most ticks one physics callback runs. At 30 Hz a callback is one tick, so
## this only applies when physhz differs.
const MAX_CATCH_UP := 5

enum Phase {
	INPUT,
	PLAYERS,
	UNITS,
	PROJECTILES,
	WORLD,
	STORY,
	EFFECTS,
	PRESENTATION,
}

## Ticks since boot, including ticks that only run PRESENTATION while paused.
var tick := 0
## Ticks whose gameplay phases ran. Reset when a run starts or a slot loads.
var run_tick := 0

signal pause_changed(on: bool)

## Reasons that come from one player's screen. They mark that player busy and
## pause the world only while pause_world is on (single player).
const PLAYER_REASONS: Array[StringName] = [&"pipbuck", &"menu", &"sats", &"dialogue", &"stand", &"craft", &"wheel"]

var pause_world := true
var _reasons: Dictionary = {}
## player id (0 is the local player) -> {reason: true}
var _busy: Dictionary = {}
var _was_paused := false
var _subs: Array = []
var _acc := 0.0
## Gameplay steps in the physics callback that just ran. 1 at 30 Hz, 0 while
## paused. Scene _physics_process runs after this autoload, so it sees the count.
var frame_steps := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_subs.clear()
	for _i in Phase.size():
		var row: Array[Callable] = []
		_subs.append(row)
	if not WorldState.run_reset.is_connected(_on_run_reset):
		WorldState.run_reset.connect(_on_run_reset)


func _physics_process(delta: float) -> void:
	frame_steps = 0
	if Engine.physics_ticks_per_second == TICK_RATE:
		_acc = 0.0
		_step()
		return
	_acc += delta
	var n := 0
	while _acc >= TICK and n < MAX_CATCH_UP:
		_acc -= TICK
		_step()
		n += 1


## phase is a Phase value. Calls happen in phase order, then registration order.
## A callable whose object was freed is dropped.
func register(phase: int, callable: Callable) -> void:
	if phase < 0 or phase >= _subs.size() or not callable.is_valid():
		return
	var row: Array = _subs[phase]
	if row.has(callable):
		return
	row.append(callable)


func unregister(callable: Callable) -> void:
	for row in _subs:
		(row as Array).erase(callable)


func paused() -> bool:
	return not _reasons.is_empty()


## on adds reason, off removes it. The game stays paused while any reason remains.
## A PLAYER_REASONS reason also marks player pid busy.
func set_paused(on: bool, reason: StringName, pid := 0) -> void:
	if reason == &"":
		return
	var own := PLAYER_REASONS.has(reason)
	if own:
		var mine: Dictionary = _busy.get(pid, {})
		if on:
			mine[reason] = true
		else:
			mine.erase(reason)
		if mine.is_empty():
			_busy.erase(pid)
		else:
			_busy[pid] = mine
	var hold := on
	if own:
		hold = pause_world and _busy.values().any(func(s: Dictionary) -> bool: return s.has(reason))
	if hold:
		_reasons[reason] = true
	else:
		_reasons.erase(reason)
	_sync_pause()


## True while player pid has a screen open (PipBuck, SATS, dialogue, trade...).
func busy(pid := 0) -> bool:
	return _busy.has(pid)


## Drops every reason. Leaving for the menu, loading a slot, or the editor.
func clear_paused() -> void:
	_reasons.clear()
	_busy.clear()
	_sync_pause()


func _on_run_reset() -> void:
	run_tick = 0


func _step() -> void:
	tick += 1
	var live := _reasons.is_empty()
	if live:
		run_tick += 1
		frame_steps += 1
	for phase in Phase.size():
		if not live and phase != Phase.PRESENTATION:
			continue
		var row: Array = _subs[phase]
		var batch: Array = row.duplicate()
		for c in batch:
			var call: Callable = c
			if not row.has(call):
				continue
			if not call.is_valid():
				row.erase(call)
				continue
			call.call()


func _sync_pause() -> void:
	var on := not _reasons.is_empty()
	var tree := get_tree()
	if tree != null and tree.paused != on:
		tree.paused = on
	if on != _was_paused:
		_was_paused = on
		pause_changed.emit(on)
