class_name TacticsPolicy
extends RefCounted

## What a land's TacticsDirector tells its squads. This base class is the
## default: no roles, no orders, every attack slot granted, no random numbers,
## so units fight as the original's do (each on its own, woken by _budilo).
## assets/data/ai/tactics.json names the policy; its "script" may point at a
## subclass (a mod or a game mode). A subclass that rolls uses the Rng tactics
## stream, so the units' own ai draws stay as they are.

const CONFIG := "res://assets/data/ai/tactics.json"
## The roles and order kinds a policy may hand out. The director drops any
## other order kind; a brain takes only the kinds its takes_order() accepts.
const ROLES: Array[StringName] = [&"point", &"support", &"flanker", &"sniper"]
const ORDERS: Array[StringName] = [&"move", &"regroup", &"fall_back", &"hold", &"suppress", &"call_help"]

static var _current: TacticsPolicy = null

## The tuning file as loaded (mod overrides applied).
var config: Dictionary = {}


static func current() -> TacticsPolicy:
	if _current == null:
		_current = _from_config()
	return _current


## Swap the policy (tests, a mode switch). null reloads the config on next use.
static func use(policy: TacticsPolicy) -> void:
	_current = policy


static func _from_config() -> TacticsPolicy:
	var cfg_v: Variant = DataLib.load(CONFIG)
	var cfg: Dictionary = cfg_v if cfg_v is Dictionary else {}
	var path := str(cfg.get("script", ""))
	if path != "":
		var script := load(path) as Script
		var made: Variant = script.new() if script != null and script.can_instantiate() else null
		if made is TacticsPolicy:
			(made as TacticsPolicy).config = cfg
			return made
		push_warning("TacticsPolicy: %s is not a TacticsPolicy; using the default" % path)
	var policy := TacticsPolicy.new()
	policy.config = cfg
	return policy


## Sim ticks between squad rebuilds.
func regroup_ticks() -> int:
	return maxi(1, int(config.get("regroup_ticks", 30)))


## The roles a unit may take, from tactics.json "units" keyed by catalog id
## (enemies.json is left as the original's). Empty: any role.
func roles_for(unit: Node) -> Array:
	var units: Dictionary = config.get("units", {}) if config.get("units") is Dictionary else {}
	var row: Variant = units.get(str(unit.get("_species_id")) if unit != null else "")
	return (row as Dictionary).get("roles", []) if row is Dictionary else []


## Roles for a squad just built: unit instance id -> role (one of ROLES).
## squad is a TacticsDirector.Squad (members, centre, target, losses).
func roles(_squad: RefCounted) -> Dictionary:
	return {}


## One unit's order: {kind, at, ...}, kind one of ORDERS. move, regroup and
## fall_back go to at; hold holds; suppress (fire at at) and call_help (run to
## the siren) wait for a brain that takes them. {} leaves the brain alone.
func order(_unit: Node, _squad: RefCounted, _role: StringName) -> Dictionary:
	return {}


## Attack slot, asked before each gun try, melee swing or ram (kind gun, melee,
## ram). attackers is how many slots on target were granted this tick. false
## skips this attack. target is null for a unit not tracking a player.
func grant(_unit: Node, _target: Node, _kind: StringName, _attackers: int) -> bool:
	return true
