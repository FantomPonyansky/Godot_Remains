extends SceneTree

## A primed mod room with pools joins that land's draw. No mods folder writes.
## godot --headless --path godot -s res://tests/test_room_pool.gd -- --user-dir=<temp>

const PLANT := "res://assets/data/maps/rooms/rooms_plant.json"
const LandGen := preload("res://scripts/map/land_gen.gd")
const RoomFile := preload("res://scripts/map/room_file.gd")
const TRIES := 30
const PROBE := "pool_probe_room"

var _bad := false


func _init() -> void:
	var plant := _plant()
	if plant.is_empty():
		_fail("missing rooms_plant")
		return
	var rows := _blank()
	var good := {
		"name": PROBE,
		"pools": ["random_plant"],
		"options": {"test": 1},
		"rows": rows,
	}
	var bad := {
		"name": "pool_probe_bad",
		"pools": ["random_plant"],
		"options": "nope",
		"rows": rows,
	}
	var user := {"file": "rooms_pool_user", "rooms": [good, bad]}
	_delta_keeps(user, plant)
	if _bad:
		return
	RoomFile.drop_cache()
	RoomFile.prime("rooms_plant", plant)
	RoomFile.prime("rooms_pool_user", user)
	_api(good, bad, rows)
	if _bad:
		return
	var hit := _draw()
	if _bad:
		return
	RoomFile.drop_cache()
	if not RoomFile.pool_rooms("random_plant").is_empty():
		_fail("drop_cache left pooled rooms")
		return
	print("POOL_OK hit ", hit)
	quit()


func _delta_keeps(user: Dictionary, plant: Dictionary) -> void:
	var whole: Dictionary = RoomFile._delta("rooms_pool_user", user)
	if not _has_pools(whole, PROBE, ["random_plant"]):
		_fail("new-file delta dropped pools")
	var edited: Dictionary = plant.duplicate(true)
	var rooms: Array = edited.get("rooms", [])
	if rooms.is_empty():
		_fail("plant has no rooms")
	var first: Dictionary = rooms[0]
	var name := str(first.get("name", ""))
	first["pools"] = ["random_sewer"]
	var delta: Dictionary = RoomFile._delta("rooms_plant", edited)
	if not _has_pools(delta, name, ["random_sewer"]):
		_fail("delta dropped pools on %s" % name)


func _has_pools(doc: Dictionary, room_name: String, pools: Array) -> bool:
	for room_v in doc.get("rooms", []):
		if str(room_v.get("name", "")) != room_name:
			continue
		return room_v.get("pools", []) == pools
	return false


func _api(good: Dictionary, bad: Dictionary, rows: Array) -> void:
	var found := false
	for land_v in RoomFile.random_lands():
		var land: Dictionary = land_v
		if str(land.get("id", "")) == "random_plant" and str(land.get("file", "")) == "rooms_plant" and str(land.get("name", "")) != "":
			found = true
	if not found:
		_fail("random_lands missing random_plant")
	var names := {}
	for row_v in RoomFile.pool_rooms("random_plant"):
		names[str(row_v.get("name", ""))] = str(row_v.get("file", ""))
	if str(names.get(PROBE, "")) != "rooms_pool_user" or str(names.get("pool_probe_bad", "")) != "rooms_pool_user":
		_fail("pool_rooms %s" % names)
	if not RoomFile.pool_rooms("random_sewer").is_empty():
		_fail("sewer picked up a plant pool")
	var ok: Array = RoomFile.check_pool_room(good, "random_plant")
	if not ok.is_empty():
		_fail("probe rejected: %s" % ok)
	var bad_problems: Array = RoomFile.check_pool_room(bad, "random_plant")
	if bad_problems.is_empty():
		_fail("bad options was accepted")
	var sealed: Dictionary = good.duplicate(true)
	var doors: Array = []
	doors.resize(22)
	doors.fill(0)
	sealed["doors"] = doors
	sealed["rows"] = rows
	var door_problems: Array = RoomFile.check_pool_room(sealed, "random_plant")
	if door_problems.is_empty():
		_fail("door mismatch was accepted")
	var back: Dictionary = good.duplicate(true)
	back["options"] = {"tip": "back"}
	if RoomFile.check_pool_room(back, "random_plant").is_empty():
		_fail("tip back was accepted on plant")


func _draw() -> int:
	LandGen.keep_seed = true
	for i in TRIES:
		seed(1000 + i)
		var built: Dictionary = LandGen.build("random_plant")
		if str(built.get("error", "")) != "":
			_fail("build %s" % built.error)
			return -1
		var hit := false
		for cell_v in built.cells.values():
			var name := str((cell_v as Dictionary).get("name", ""))
			if name == "pool_probe_bad":
				_fail("bad room was drawn")
				return -1
			if name == PROBE:
				hit = true
		if hit:
			return i
	_fail("probe missing after %d tries" % TRIES)
	return -1


func _plant() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLANT))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _blank() -> Array:
	var line := ".".repeat(47)
	var rows: Array = []
	for _i in 25:
		rows.append(line)
	return rows


func _fail(msg: String) -> void:
	_bad = true
	print("POOL_FAIL ", msg)
	quit(1)
