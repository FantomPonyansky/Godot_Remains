extends Node

## Named streams for one run. Gameplay streams are seeded per run and per land
## with hash([run_seed, land_id, stream_name]) on run_reset and when the active
## land changes. fx is cosmetic and is not reseeded per land.
## A land build then sets the build stream to that land's stored seed.
## randf_legacy() is the global randf() sequence for that seed (one randi,
## narrowed to float32). RandomNumberGenerator.randf() draws twice, so build
## code must use randf_legacy or a generated land would reshuffle.

const NAMES: Array[StringName] = [&"build", &"spawn", &"loot", &"ai", &"combat", &"fx"]
const GAMEPLAY: Array[StringName] = [&"build", &"spawn", &"loot", &"ai", &"combat"]

var _streams: Dictionary = {}
var _run_seed := 0
var _land_id := ""


func _ready() -> void:
	for n in NAMES:
		_streams[n] = RandomNumberGenerator.new()
	(_streams[&"fx"] as RandomNumberGenerator).randomize()
	if not WorldState.run_reset.is_connected(_on_run_reset):
		WorldState.run_reset.connect(_on_run_reset)
	_on_run_reset()


func stream(stream_name: StringName) -> RandomNumberGenerator:
	var found: Variant = _streams.get(stream_name)
	if found is RandomNumberGenerator:
		return found
	push_error("unknown Rng stream %s" % String(stream_name))
	return _streams[&"fx"]


func randf(stream_name: StringName) -> float:
	return stream(stream_name).randf()


func randi(stream_name: StringName) -> int:
	return stream(stream_name).randi()


func randf_range(stream_name: StringName, from: float, to: float) -> float:
	return stream(stream_name).randf_range(from, to)


func randi_range(stream_name: StringName, from: int, to: int) -> int:
	return stream(stream_name).randi_range(from, to)


func randfn(stream_name: StringName, mean: float = 0.0, deviation: float = 1.0) -> float:
	return stream(stream_name).randfn(mean, deviation)


func pick(stream_name: StringName, items: Array):
	if items.is_empty():
		push_error("Rng.pick on an empty array")
		return null
	return items[self.randi(stream_name) % items.size()]


## In-place Fisher-Yates. Each swap uses one randi from the stream.
func shuffle(stream_name: StringName, items: Array) -> void:
	var n := items.size()
	for i in range(n - 1, 0, -1):
		var j := self.randi(stream_name) % (i + 1)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp


## Global randf() after seed(s): one randi, stored as float32.
func randf_legacy(stream_name: StringName) -> float:
	var u := self.randi(stream_name) & 0xFFFFFFFF
	var narrowed := PackedFloat32Array([float(u) / 4294967296.0])
	return float(narrowed[0])


## A fresh generator for one land or chunk. Does not move the active streams.
func for_land(land_id: String, stream_name: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix(_current_run_seed(), land_id, stream_name)
	return rng


## Reseed gameplay streams for land_id. The same land does not reseed again.
func bind_land(land_id: String) -> void:
	if land_id == _land_id:
		return
	_land_id = land_id
	_run_seed = _current_run_seed()
	_reseed(land_id)


## Build stream only. begin_build passes the land's stored seed.
func seed_build(s: int) -> void:
	stream(&"build").seed = s


func _on_run_reset() -> void:
	_run_seed = _current_run_seed()
	_land_id = ""
	_reseed("")
	stream(&"fx").randomize()


func _reseed(land_id: String) -> void:
	for n in GAMEPLAY:
		stream(n).seed = _mix(_run_seed, land_id, n)


func _mix(run_seed: int, land_id: String, stream_name: StringName) -> int:
	return hash([run_seed, land_id, String(stream_name)])


func _current_run_seed() -> int:
	if WorldState.fixed_seed >= 0:
		return WorldState.fixed_seed
	return WorldState.run_seed
