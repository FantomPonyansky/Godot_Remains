extends Node2D

const _BeginLand := preload("res://scenes/begin_land.tscn")
const PlayLand := preload("res://scripts/map/play_land.gd")
const _Outline := preload("res://scripts/map/tile_outline.gd")
const _ArtCache := preload("res://scripts/art_cache.gd")
## Feet just left of the begin exit area (rooms_begin room 3,2), where the Surf
## return tunnel arrives.
const BEGIN_EXIT := Vector2(7560, 2799)

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D

var _shown: Node2D
var _stable: Node2D
var _away: Dictionary = {}
var _door_back: Dictionary = {}


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_add_surroundings()
	var _ed := load("res://scripts/editor/editor_play.gd")
	var _job: Dictionary = {}
	if _ed.has_pending():
		_job = _ed.install()
	var boot := DebugConsole.take_land().split(":")
	var start := _start_land(_job, boot[0], _ed.ID)
	if start == "begin":
		_show_begin()
	camera.make_current()
	CameraDistance.apply()
	GameState.reset_run()
	WorldState.reset_run()
	# reset_run clears the cover. Put it back once the run state is reset,
	# and keep it until the land fade. A save's land is not built yet.
	if start != "begin":
		Travel.cover()
	if not _job.is_empty():
		var _cell: Vector2i = _job.get("cell", Vector2i.ZERO)
		Travel.goto_land(_ed.ID, "%d:%d" % [_cell.x, _cell.y], true)
	elif start == boot[0] and start != "begin" and not SaveSlots.has_pending():
		Travel.goto_land(boot[0], "%s:%s" % [boot[1], boot[2]] if boot.size() >= 3 else "", true)
	elif start == "begin" or not SaveSlots.has_pending():
		Travel.begin_run()
	# beginBeg grants the leg PipBuck during the black wake-up, after the
	# item exists. The count alone does not draw it.
	var bags := get_node_or_null("/root/Inventory")
	if bags and bags.has_method("grant_leg_pip"):
		bags.grant_leg_pip()
	GameState.enemies_remaining = 0
	add_child(load("res://scripts/fog.gd").new())
	add_child(load("res://scripts/aim_cursor.gd").new())
	var _preview := load("res://scripts/editor/editor_preview.gd")
	if _preview.running():
		_preview.attach(self)


## The land this scene opens on. Only begin is built here; any other start (a
## save made elsewhere, an editor test, --land, a new game that skips training)
## loads straight in through Travel, and begin is built when first entered.
func _start_land(job: Dictionary, boot_land: String, editor_id: String) -> String:
	if not job.is_empty():
		return editor_id
	if SaveSlots.has_pending():
		return SaveSlots.pending_land()
	if boot_land != "" and Travel.lands.has(boot_land):
		return boot_land
	if bool(UiSettings.value("game", "propusk", false)):
		return Travel.base_id
	return "begin"


func _show_begin() -> void:
	var land := _make_begin()
	add_child(land)
	_stable = land
	_shown = land
	land.add_to_group("active_land")
	player.position = land.get("spawn_px")
	_frame_camera(land)
	var sky := get_node_or_null("Sky") as ColorRect
	if sky:
		sky.offset_right = land.map_px.x
		sky.offset_bottom = land.map_px.y
	AudioManager.play_begin()


func _make_begin() -> Node2D:
	var land := _BeginLand.instantiate() as Node2D
	land.name = "BeginLand"
	return land


## A land exit: Travel runs the exit sequence and calls enter_land.
func goto_land(next_id: String, from_rect: Rect2 = Rect2()) -> void:
	if _shown == null or next_id == "":
		return
	var here := _id_of(_shown)
	if next_id == here and next_id == Travel.cur_land_id:
		return
	if from_rect.size.x >= 1.0:
		_door_back[here] = Vector2(from_rect.position.x - 40.0, from_rect.end.y - 1.0)
	Travel.goto_land(next_id)


## Travel: show land next_id (built anew when rebuild). Returns it, or null.
func enter_land(next_id: String, rebuild: bool) -> Node2D:
	if rebuild or _shown == null or _id_of(_shown) != next_id:
		_ArtCache.drop_land_art()
	var dest: Node2D = null
	if next_id == "begin":
		if _stable == null:
			_stable = _make_begin()
		dest = _stable
	else:
		dest = _away.get(next_id)
		if rebuild and dest != null:
			_away.erase(next_id)
			if dest != _shown:
				dest.queue_free()
			else:
				dest.remove_from_group("active_land")
				remove_child(dest)
				_shown = null
				dest.queue_free()
			dest = null
		if rebuild:
			WorldState.forget_land(next_id)
		if dest == null:
			dest = PlayLand.make(next_id)
			if dest == null:
				return null
			_away[next_id] = dest
	if dest != _shown:
		if _shown != null:
			_shown.remove_from_group("active_land")
			remove_child(_shown)
			# A land left behind keeps its GPU textures while it lives. WorldState
			# holds its snapshot and build seed, so it is rebuilt the same on return.
			if _shown != _stable:
				_away.erase(_id_of(_shown))
				_shown.queue_free()
		_shown = dest
		add_child(dest)
		dest.add_to_group("active_land")
	_Outline.use(dest)
	_frame_camera(dest)
	var sky := get_node_or_null("Sky") as ColorRect
	if sky:
		var bounds := _vec(dest, "map_px", Vector2(9600, 5000))
		sky.offset_right = bounds.x
		sky.offset_bottom = bounds.y
	var fog := get_node_or_null("Fog")
	if fog and fog.has_method("retarget"):
		fog.retarget(dest)
	return dest


func place_player(at: Vector2) -> void:
	player.velocity = Vector2.ZERO
	player.global_position = at
	player.reset_physics_interpolation()
	# Top-level camera does not follow until the next physics snap. Room
	# culling reads it this frame, so it has to be on the player now.
	if camera.has_method("snap"):
		camera.snap()
	else:
		camera.reset_smoothing()


## Land.setGGToSpawnPoint: the land's begLoc spawn, or back at the door used
## to leave it.
func entrance(land_id: String) -> Vector2:
	var land := _shown if _shown != null and _id_of(_shown) == land_id else null
	var at := _vec(land, "spawn_px", Vector2(320, 639)) if land else Vector2(320, 639)
	if land_id == "begin" and land:
		at = BEGIN_EXIT
	if _door_back.has(land_id) and land:
		var saved: Vector2 = _door_back[land_id]
		var bounds := _vec(land, "map_px", Vector2(9600, 5000))
		if saved.x >= 40.0 and saved.x < bounds.x - 20.0 and saved.y > 0.0 and saved.y < bounds.y:
			at = saved
	return at


func _frame_camera(land: Node) -> void:
	var bounds := _vec(land, "map_px", Vector2(9600, 5000))
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(bounds.x)
	camera.limit_bottom = int(bounds.y)


func _id_of(node: Node) -> String:
	var value = node.get("land_id")
	if value != null and str(value) != "":
		return str(value)
	return "begin"


func _vec(node: Node, key: String, fallback: Vector2) -> Vector2:
	var value = node.get(key)
	if value is Vector2:
		return value
	return fallback


func _add_surroundings() -> void:
	if has_node("Surroundings"):
		return
	var node := preload("res://scenes/surroundings.tscn").instantiate()
	node.name = "Surroundings"
	add_child(node)
	move_child(node, 0)
	# Port placeholder art, not in the original; it only hides the scene's
	# placeholder nodes now. The land backdrop is map/land_fon.gd.
	node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
