class_name SpawnPolicy
extends RefCounted

## How units appear. This base class is the default policy: every request is
## granted, counts and timers stay as the original computed them, and it draws
## no random numbers, so a run plays as before. assets/data/ai/spawn.json names
## the policy; its "script" may point at a subclass (a mod or a game mode).
## A subclass that draws random numbers uses the Rng spawn stream.

const CONFIG := "res://assets/data/ai/spawn.json"

static var _current: SpawnPolicy = null

## The tuning file as loaded (mod overrides applied).
var config: Dictionary = {}


static func current() -> SpawnPolicy:
	if _current == null:
		_current = _from_config()
	return _current


## Swap the policy (tests, a mode switch). null reloads the config on next use.
static func use(policy: SpawnPolicy) -> void:
	_current = policy


static func _from_config() -> SpawnPolicy:
	var cfg_v: Variant = DataLib.load(CONFIG)
	var cfg: Dictionary = cfg_v if cfg_v is Dictionary else {}
	var path := str(cfg.get("script", ""))
	if path != "":
		var script := load(path) as Script
		var made: Variant = script.new() if script != null and script.can_instantiate() else null
		if made is SpawnPolicy:
			(made as SpawnPolicy).config = cfg
			return made
		push_warning("SpawnPolicy: %s is not a SpawnPolicy; using the default" % path)
	var policy := SpawnPolicy.new()
	policy.config = cfg
	return policy


## Build time (land_spawn._set_random_units): how many units of tip the room
## plans. tip is a TIP_EN entry, or "hidden" for kol_hid.
func room_count(_loc: Dictionary, _tip: String, kol: int) -> int:
	return kol


## Runtime room spawner: false refuses this spawn before it spends the room's kol.
## source is alarm (the siren chain), trigger (allact spawn) or wave (trials).
func allow_room(_key: String, _source: StringName, _left: int) -> bool:
	return true


## The siren (Location.signal): ticks until the room's first alarm spawn.
func alarm_delay(_key: String, delay: int) -> int:
	return delay


## Boss, emitter, vortex and Thunderhead summons (UnitBrain.spawn_unit).
func allow_summon(_owner: Node, _uid: String) -> bool:
	return true
