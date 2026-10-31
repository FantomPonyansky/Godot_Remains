extends Node

## World state per land, kept for the run and written into save slots
## (world.json next to the run files in save_slots.gd).
##
## A land's snapshot is taken by its land_props (land_memory.gd) when the land
## leaves the tree and whenever a slot is saved. A land built again later
## (after a load, or by anything that rebuilds lands) gets it back, the way
## the original keeps visited lands until the run is reset. Lands are built
## from a per-land seed and level kept here, so a rebuild plans the same rows.
##
## Other systems persist their own state with
##   WorldState.register(provider_id, get_callable, set_callable)
## get_callable() -> Variant returns JSON-safe data; set_callable(data) gets it
## back after a load (at once if the save was loaded before registering).
## Data of providers that never register in a run is kept and saved again.

signal run_reset
signal restored

const VERSION := 2
## Version 2 took the 2021 room files: these lands' room pools changed, so a
## version 1 snapshot (rows named by plan placement) no longer fits their plan.
const REPLANNED_V2 := ["random_canter", "random_mane", "random_stable", "random_encl", "random_plant", "random_sewer"]
const FILE := "world.json"
const LandGen := preload("res://scripts/map/land_gen.gd")
const RESUME_FRAMES := 600
const AUTOSAVE_SLOT := 0

var run_seed := 0
var autosave_on_travel := true

var _lands := {}
var _builds := {}
var _live := {}
var _providers := {}
var _provider_data := {}
var _resume := {}
var _resume_left := 0
var _resume_sent := false
var _active_id := ""
var _autosave_in := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_run()


## A new run: every land is forgotten. game.gd calls this as the run starts.
func reset_run() -> void:
	_lands.clear()
	_builds.clear()
	_live.clear()
	_resume.clear()
	_resume_sent = false
	_active_id = ""
	_autosave_in = -1
	randomize()
	run_seed = randi()
	run_reset.emit()


func register(provider_id: String, get_callable: Callable, set_callable: Callable) -> void:
	_providers[provider_id] = [get_callable, set_callable]
	if _provider_data.has(provider_id):
		var data: Variant = _provider_data[provider_id]
		_provider_data.erase(provider_id)
		if set_callable.is_valid():
			set_callable.call(data)


## Drops what is known about a land; its next build starts fresh, from a new
## seed (Game.crea: a new Land, so a generated land gets a new layout).
func forget_land(land_id: String) -> void:
	_lands.erase(land_id)
	_live.erase(land_id)
	_builds[land_id] = {"seed": randi(), "lvl": -1}


# --- building ------------------------------------------------------------

## play_land.gd make(): seeds the global RNG so the land plans the same way again.
func begin_build(land_id: String) -> void:
	var info := _build_info(land_id)
	LandGen.keep_seed = true
	seed(int(info.seed))


func end_build(_land_id: String) -> void:
	LandGen.keep_seed = false
	randomize()


## The level a land was first planned at. lvl is the level it would use now.
func build_level(land_id: String, lvl: int) -> int:
	var info := _build_info(land_id)
	if int(info.get("lvl", -1)) < 0:
		info["lvl"] = lvl
	return int(info.lvl)


## Any other build input (land stage, visited, triggers) as it was when the
## land was first planned, so a rebuild of the same Land plans the same rows.
func build_value(land_id: String, key: String, value: Variant) -> Variant:
	var info := _build_info(land_id)
	var known: Dictionary = info.get("in", {})
	if not known.has(key):
		known[key] = value
		info["in"] = known
	return known[key]


func _build_info(land_id: String) -> Dictionary:
	if not _builds.has(land_id):
		var stored: Dictionary = (_lands.get(land_id, {}) as Dictionary).get("build", {})
		if stored.has("seed"):
			_builds[land_id] = stored.duplicate(true)
		else:
			_builds[land_id] = {"seed": absi(hash("%d:%s" % [run_seed, land_id])), "lvl": -1}
	return _builds[land_id]


# --- land snapshots ------------------------------------------------------

## land_memory.gd: a land's props came up. Returns its stored snapshot or {}.
func adopt(land_id: String, land: Node) -> Dictionary:
	_live[land_id] = weakref(land)
	return (_lands.get(land_id, {}) as Dictionary).duplicate(true)


## land_memory.gd: a land's props went out of the tree with this state.
func store(land_id: String, snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	if _builds.has(land_id):
		snapshot["build"] = (_builds[land_id] as Dictionary).duplicate(true)
	_lands[land_id] = snapshot


func _refresh(land_id: String) -> void:
	var ref: WeakRef = _live.get(land_id)
	if ref == null:
		return
	var land := ref.get_ref() as Node
	if land == null:
		_live.erase(land_id)
		return
	if not land.is_inside_tree():
		return
	var props := land.get_node_or_null("Actors")
	if props and props.has_method("capture_state"):
		store(land_id, props.capture_state())


# --- saves ---------------------------------------------------------------

func to_save() -> Dictionary:
	for id in _live.keys():
		_refresh(str(id))
	var providers := _provider_data.duplicate(true)
	for id in _providers:
		var getter: Callable = (_providers[id] as Array)[0]
		if getter.is_valid():
			providers[id] = getter.call()
	var out := {
		"version": VERSION,
		"run_seed": run_seed,
		"lands": _lands.duplicate(true),
		"providers": providers,
	}
	var land := _active_land()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if land and player:
		var at := player.global_position
		out["land"] = _id_of(land)
		out["pos"] = [at.x, at.y]
		out["room"] = [floori(at.x / 1920.0), floori(at.y / 1000.0)]
	return out


## A save's world data, applied after game.tscn reset the run. The player goes
## to the saved land and spot once that land is up.
func from_save(data: Dictionary) -> bool:
	if int(data.get("version", 0)) < 1 or int(data.get("version", 0)) > VERSION:
		push_warning("world save version %s not supported" % str(data.get("version")))
		return false
	run_seed = int(data.get("run_seed", run_seed))
	_lands = (data.get("lands", {}) as Dictionary).duplicate(true)
	if int(data.get("version", 0)) < 2:
		for id in REPLANNED_V2:
			_lands.erase(id)
	_builds.clear()
	var providers: Dictionary = data.get("providers", {})
	_provider_data.clear()
	for id in providers:
		if _providers.has(id):
			var setter: Callable = (_providers[id] as Array)[1]
			if setter.is_valid():
				setter.call(providers[id])
		else:
			_provider_data[id] = providers[id]
	var pos: Array = data.get("pos", [])
	if str(data.get("land", "")) != "" and pos.size() == 2:
		_resume = {"land": str(data.land), "pos": Vector2(float(pos[0]), float(pos[1]))}
		_resume_left = RESUME_FRAMES
		_resume_sent = false
	# The stable is already up when a save loads; it takes its state back now.
	var begin := _live.get("begin") as WeakRef
	if begin != null and begin.get_ref() != null:
		var props := (begin.get_ref() as Node).get_node_or_null("Actors")
		if props and props.has_method("restore_state"):
			props.restore_state(_lands.get("begin", {}))
	restored.emit()
	return true


func write(dir: String) -> bool:
	var file := FileAccess.open(dir + FILE, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_save()))
	file.close()
	return true


func read(dir: String) -> bool:
	if not FileAccess.file_exists(dir + FILE):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + FILE))
	if not parsed is Dictionary:
		push_warning("world save unreadable: %s" % (dir + FILE))
		return false
	return from_save(parsed)


func current_land_id() -> String:
	var land := _active_land()
	return _id_of(land) if land else ""


func _active_land() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("active_land")


func _id_of(land: Node) -> String:
	var value: Variant = land.get("land_id")
	if value != null and str(value) != "":
		return str(value)
	return "begin"


func _process(_delta: float) -> void:
	if not _resume.is_empty():
		_tick_resume()
		return
	var id := current_land_id()
	if id != _active_id:
		var was := _active_id
		_active_id = id
		if was != "" and id != "" and autosave_on_travel:
			_autosave_in = 2
	if _autosave_in > 0:
		_autosave_in -= 1
		if _autosave_in == 0:
			_autosave_in = -1
			SaveSlots.save(AUTOSAVE_SLOT)


## True while a loaded save is still waiting to put the player back.
func resuming() -> bool:
	return not _resume.is_empty()


func _tick_resume() -> void:
	_resume_left -= 1
	if _resume_left <= 0:
		_resume.clear()
		return
	var target := str(_resume.land)
	var id := current_land_id()
	if id == "":
		return
	# Travel picks the land a save resumes in (a generated land goes back to
	# the camp); the saved spot only counts in the saved land.
	var travel := get_node_or_null("/root/Travel")
	if travel != null:
		if str(travel.get("cur_land_id")) != target:
			_resume.clear()
			return
		if int(travel.get("exit_state")) != 0 or id != target:
			return
	elif id != target:
		if not _resume_sent:
			var host := get_tree().current_scene
			if host and host.has_method("goto_land"):
				_resume_sent = true
				host.goto_land(target)
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return
	player.global_position = _resume.pos
	player.reset_physics_interpolation()
	player.velocity = Vector2.ZERO
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.reset_smoothing()
	_resume.clear()
	_active_id = id
