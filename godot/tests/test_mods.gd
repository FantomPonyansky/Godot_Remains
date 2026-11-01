extends Node

## Sandbox mods: an id override, an added row, a remove, a bad mod skipped
## whole, an art take_over_path, and the save-mismatch warning.
## Prints CHECK mods: ok N fail M. Mod failures are log lines, not push_error.

const DataLib = preload("res://scripts/data_lib.gd")
const Mods = preload("res://scripts/mod_loader.gd")
const RoomFile = preload("res://scripts/map/room_file.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const UserDir = preload("res://scripts/user_dir.gd")
const WEAPONS := "res://assets/data/weapons.json"
const ENEMIES := "res://assets/data/enemies.json"
const ARROW := "res://assets/ui/cursor/arrow.png"
const WeaponVis = preload("res://scripts/weapon_vis.gd")
const PlayerRigPort = preload("res://scripts/rig/player_rig_port.gd")
const PLAYER_RIG := "res://assets/rigs/player/player_rig.tscn"
## Resolved when this script loads, before _ready writes the mod file.
const _ARROW := preload("res://assets/ui/cursor/arrow.png")

var _ok := 0
var _fail_n := 0


func _ready() -> void:
	_write_mods()
	Mods.rescan()
	_check_data()
	_check_art()
	_check_weapon_art()
	_check_armor()
	_check_text()
	_check_rooms()
	_check_saves()
	_check_commands()
	print("CHECK mods: ok %d fail %d" % [_ok, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
	else:
		_fail_n += 1
		print("FAIL ", msg)


func _write_mods() -> void:
	var root := UserDir.mods()
	_json(root.path_join("bad/mod.json"), {
		"id": "bad", "name": "Bad", "version": "0.1.0", "enabled": true,
	})
	_json(root.path_join("bad/data/weapons.json"), {
		"weapons": [{"id": "bad_gun", "damage": 1}],
	})
	_json(root.path_join("bad/data/enemies.json"), {
		"units": {"should_not_appear": {"name": "should_not_appear", "hp": 1}},
	})
	_json(root.path_join("bad/rooms/rooms_badprobe.json"), {
		"file": "rooms_badprobe", "rooms": [{"name": "mod_room_bad"}],
	})
	_json(root.path_join("broken_json/mod.json"), {
		"id": "broken_json", "name": "Broken", "version": "0.0.0", "enabled": true,
	})
	_text(root.path_join("broken_json/data/weapons.json"), "{")
	_json(root.path_join("broken_json/data/enemies.json"), {
		"units": {"json_ghost": {"name": "json_ghost", "hp": 1}},
	})
	_json(root.path_join("good/mod.json"), {
		"id": "good", "name": "Sample arsenal", "version": "1.0.0",
		"after": ["bad"], "description": "One weapon tweak and one enemy tweak.",
	})
	_json(root.path_join("good/data/weapons.json"), {
		"weapons": [
			{"id": "armature", "damage": 40},
			{"id": "mod_stick", "name": "Mod stick", "kind": "melee", "damage": 5},
		],
		"remove": ["bat"],
	})
	_json(root.path_join("good/data/enemies.json"), {
		"units": {
			"bloat1": {"hp": 99},
			"mod_mite": {"name": "mod_mite", "hp": 1},
			"remove": ["bloodwing"],
		},
	})
	_json(root.path_join("good/rooms/rooms_goodprobe.json"), {
		"file": "rooms_goodprobe", "rooms": [{"name": "mod_room_ok"}],
	})
	_json(root.path_join("better/mod.json"), {
		"id": "better", "name": "Later arsenal", "version": "1.1.0",
		"after": ["good"], "enabled": true,
	})
	_json(root.path_join("better/data/weapons.json"), {
		"weapons": [{"id": "armature", "damage": 77}],
	})
	_json(root.path_join("silent/mod.json"), {
		"id": "silent", "name": "Silent", "version": "0.0.1", "enabled": false,
	})
	_json(root.path_join("silent/data/weapons.json"), {
		"weapons": [{"id": "armature", "damage": 1}],
	})
	_json(root.path_join("rooms/rooms_looseprobe.json"), {
		"file": "rooms_looseprobe", "rooms": [{"name": "loose_probe"}],
	})
	_json(root.path_join("good/assets/sprites/weapons/held/manifest.json"), {
		"clips": {"vismodstick": {"anchor": [3, 2], "emit": [20, 1], "file": "vismodstick.png", "png": [24, 4]}},
		"ids": {"mod_stick": "vismodstick"},
	})
	_json(root.path_join("good/data/armor_art.json"), {
		"mod_suit": {"base": "assault", "hide_mane": true},
	})
	_json(root.path_join("good/data/item_text.json"), {
		"mod_stick": {"name": {"en": "Mod stick EN", "ru": "Мод-палка"}, "desc": {"en": "Mod stick text"}},
	})
	_png(root.path_join("good/assets/ui/cursor/arrow.png"), 2, 2)
	_png(root.path_join("good/assets/sprites/weapons/held/vismodstick.png"), 24, 4)
	_png(root.path_join("good/assets/rigs/player/art/korpus_mod_suit_L1_S0.png"), 3, 3)


func _png(path: String, w: int, h: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 0, 0, 1))
	_check(image.save_png(path) == OK, "save mod png " + path.get_file())


func _check_data() -> void:
	var disk: Dictionary = _disk_weapon("armature")
	var weapons: Dictionary = DataLib.by_id(WEAPONS)
	var arm: Dictionary = weapons.get("armature", {})
	_check(int(disk.get("damage", -1)) != 77, "built-in weapon file changed")
	_check(str(arm.get("name", "")) == str(disk.get("name", "")), "armature name kept")
	_check(int(arm.get("damage", -1)) == 77, "later mod damage %s" % str(arm.get("damage", "")))
	_check(arm.get("damage") is float, "mod number is a float like built-in JSON")
	_check(arm.is_read_only() and weapons.is_read_only(), "by_id view and rows read-only")
	_check(weapons.has("mod_stick"), "added weapon")
	_check(str(weapons.get("mod_stick", {}).get("kind", "")) == "melee", "mod_stick kind")
	_check(not weapons.has("bat"), "removed bat")
	_check(not weapons.has("bad_gun"), "bad weapon skipped")
	var loaded: Variant = DataLib.load(WEAPONS)
	_check(loaded is Dictionary and (loaded as Dictionary).is_read_only(), "weapons read-only")
	var copy: Dictionary = DataLib.copy(WEAPONS)
	copy["tick_rate"] = -1
	_check(int((DataLib.load(WEAPONS) as Dictionary).get("tick_rate", 0)) != -1, "copy stayed off the cache")
	var units: Dictionary = DataLib.by_id(ENEMIES)
	_check(int(units.get("bloat1", {}).get("hp", -1)) == 99, "bloat1 hp")
	_check(str(units.get("bloat1", {}).get("name", "")) == "bloat1", "bloat1 name kept")
	_check(units.has("mod_mite"), "added enemy")
	_check(not units.has("bloodwing"), "removed bloodwing")
	_check(not units.has("remove"), "remove key leaked")
	_check(not units.has("should_not_appear"), "bad mod enemy skipped")
	_check(not units.has("json_ghost"), "broken json enemy skipped")
	var skip_bad := 0
	var skip_json := 0
	var dup := 0
	var merged_w := 0
	var merged_e := 0
	for line in DataLib.notes():
		if line.begins_with("ModLoader: skip bad:"):
			skip_bad += 1
		elif line.begins_with("ModLoader: skip broken_json:"):
			skip_json += 1
		elif line.contains("duplicate id armature") and line.contains("good then better"):
			dup += 1
		elif line.begins_with("DataLib: merged " + WEAPONS):
			merged_w += 1
			_check(line.contains("mod_stick"), "merged weapon ids")
		elif line.begins_with("DataLib: merged " + ENEMIES):
			merged_e += 1
			_check(line.contains("mod_mite"), "merged enemy ids")
	_check(skip_bad == 1, "bad skip lines %d" % skip_bad)
	_check(skip_json == 1, "json skip lines %d" % skip_json)
	_check(dup == 1, "duplicate lines %d" % dup)
	_check(merged_w == 1, "weapon merge logs %d" % merged_w)
	_check(merged_e == 1, "enemy merge logs %d" % merged_e)
	var order: Array = []
	var silent_off := false
	for mod_v in Mods.catalog():
		var mod: Dictionary = mod_v
		order.append(str(mod.get("id", "")))
		if str(mod.get("id", "")) == "silent":
			silent_off = not bool(mod.get("enabled", true))
	_check(order.find("rooms") == 0, "loose rooms first %s" % str(order))
	_check(order.find("good") >= 0 and order.find("good") < order.find("better"), "after order %s" % str(order))
	_check(silent_off, "silent disabled")
	var stamp: Array = []
	for row_v in Mods.applied():
		var row: Dictionary = row_v
		stamp.append("%s@%s" % [str(row.get("id", "")), str(row.get("version", ""))])
	_check(stamp == ["rooms@", "good@1.0.0", "better@1.1.0"], "applied %s" % str(stamp))


func _check_art() -> void:
	var disk := Image.load_from_file(ProjectSettings.globalize_path(ARROW))
	_check(disk != null and disk.get_width() != 2, "built-in png replaced on disk")
	_check(_ARROW.get_width() != 2, "preload kept the imported texture")
	var live: Variant = load(ARROW)
	_check(live != _ARROW, "load() still the preload")
	_check(live is Texture2D and (live as Texture2D).get_width() == 2, "override size %s" % (live.get_class() if live is Object else "null"))
	var image: Image = (live as Texture2D).get_image() if live is Texture2D else null
	_check(image != null and image.get_pixel(0, 0).r > 0.9 and image.get_pixel(0, 0).g < 0.1, "override pixel")


func _check_weapon_art() -> void:
	WeaponVis._loaded = false
	WeaponVis._data = {}
	_check(WeaponVis.has_art("mod_stick"), "mod weapon clip")
	_check(WeaponVis.anchor("mod_stick") == Vector2(3, 2), "mod grip %s" % str(WeaponVis.anchor("mod_stick")))
	_check(WeaponVis.emit("mod_stick") == Vector2(20, 1), "mod muzzle %s" % str(WeaponVis.emit("mod_stick")))
	var tex := WeaponVis.texture("mod_stick")
	_check(tex != null and tex.get_width() == 24, "mod weapon png")
	_check(WeaponVis.anchor("armature") == Vector2(9.3, 1.45), "built-in grip kept")


func _check_armor() -> void:
	RigBase._armor_art_loaded = false
	_check(RigBase.armor_base("mod_suit") == "assault", "mod armour base")
	_check(RigBase.armor_base("assault") == "assault", "built-in armour base")
	var rig: Node = load(PLAYER_RIG).instantiate()
	rig.set_script(PlayerRigPort)
	add_child(rig)
	rig.call("set_armor", "mod_suit")
	var found := false
	for node in rig.find_children("*", "Sprite2D", true, false):
		var spr := node as Sprite2D
		if spr.texture != null and spr.texture.get_width() == 3 and spr.texture.get_height() == 3:
			found = true
	_check(found, "mod armour png on the rig")
	var bones: Dictionary = rig.get("_bones")
	_check(bones.has("mane") and not (bones["mane"] as CanvasItem).visible, "mod armour hides the mane")
	rig.call("set_armor", "assault")
	_check((bones["mane"] as CanvasItem).visible, "assault shows the mane")
	rig.queue_free()


func _check_text() -> void:
	OriginalLines._mod_text_loaded = false
	var lang := OriginalLines.language()
	_check(OriginalLines.name_of("mod_stick") == ("Мод-палка" if lang == "ru" else "Mod stick EN"), "mod item name")
	_check(OriginalLines.desc_of("mod_stick") == "Mod stick text", "mod desc falls back to en")
	_check(OriginalLines.name_of("armature") != "Mod stick EN", "built-in name kept")


func _check_rooms() -> void:
	RoomFile.drop_cache()
	var good: Dictionary = RoomFile.load_doc("rooms_goodprobe")
	var rooms: Array = good.get("rooms", [])
	_check(not rooms.is_empty() and str(rooms[0].get("name", "")) == "mod_room_ok", "mod room")
	_check(RoomFile.load_doc("rooms_badprobe").is_empty(), "bad mod room skipped")
	_check(RoomFile.file_names().has("rooms_goodprobe"), "good room listed")
	_check(not RoomFile.file_names().has("rooms_badprobe"), "bad room listed")
	_check(RoomFile.has_mod("rooms_looseprobe") and RoomFile.mod_enabled("rooms_looseprobe"), "loose file on")
	var loose: Dictionary = RoomFile.load_doc("rooms_looseprobe")
	_check(str(loose.get("rooms", [{}])[0].get("name", "")) == "loose_probe", "loose room")
	RoomFile.set_mod_enabled("rooms_looseprobe", false)
	RoomFile.drop_cache()
	_check(RoomFile.load_doc("rooms_looseprobe").is_empty(), "loose file disabled")
	RoomFile.set_mod_enabled("rooms_looseprobe", true)
	RoomFile.drop_cache()
	_check(not RoomFile.load_doc("rooms_looseprobe").is_empty(), "loose file enabled again")


func _check_commands() -> void:
	var cmd: Variant = LocalInput.PlayerCommand.new()
	cmd.held = {&"jump": true}
	cmd.strength = {&"move_right": 1.0}
	LocalInput.set_command(99, cmd)
	_check(LocalInput.held(&"jump", 99), "remote command held")
	_check(LocalInput.axis(&"move_left", &"move_right", 99) == 1.0, "remote command axis")
	_check(not LocalInput.held(&"jump"), "local command apart from remote")
	_check(not LocalInput.held(&"jump", 98), "player without command is idle")
	LocalInput.drop_command(99)
	_check(not LocalInput.held(&"jump", 99), "dropped command")
	Sim.set_paused(true, &"pipbuck")
	_check(Sim.paused() and Sim.busy(), "single player screen pauses and marks busy")
	Sim.set_paused(false, &"pipbuck")
	Sim.pause_world = false
	Sim.set_paused(true, &"pipbuck", 7)
	_check(not Sim.paused() and Sim.busy(7) and not Sim.busy(), "world keeps running for a busy player")
	Sim.set_paused(true, &"console")
	_check(Sim.paused(), "non-player reason still pauses")
	Sim.set_paused(false, &"console")
	Sim.set_paused(false, &"pipbuck", 7)
	Sim.pause_world = true
	_check(not Sim.paused() and not Sim.busy(7), "busy cleared")
	var node := Node.new()
	_check(Entity.has_authority(node), "node without field has authority")
	node.free()
	_check_world_ops()
	_check_grid()
	_check_addresses()
	_check_cell_records()


func _cells_digest(built: Dictionary) -> String:
	var out := {}
	for at_v in built.get("cells", {}):
		var cell: Dictionary = built.cells[at_v]
		out[str(at_v)] = [cell.name, cell.mirror, cell.ramka, cell.setdoor, str(cell.xp), cell.water, cell.enemy_type, str(cell.open)]
	return JSON.stringify(out, "", true)


func _check_cell_records() -> void:
	var gen := preload("res://scripts/map/land_gen.gd")
	var id := "random_sewer"
	WorldState.forget_land(id)
	WorldState.begin_build(id)
	var first := gen.build(id)
	WorldState.end_build(id)
	_check(str(first.get("error", "")) == "", "generated land plans")
	_check(WorldState.build_cells(id).size() == int(first.width) * int(first.height), "first plan keeps a record per cell")
	var digest := _cells_digest(first)
	WorldState.begin_build(id)
	var again := gen.build(id)
	WorldState.end_build(id)
	_check(_cells_digest(again) == digest, "rebuild matches the first plan")
	WorldState._build_info(id)["seed"] = 12345
	WorldState.begin_build(id)
	var replay := gen.build(id)
	WorldState.end_build(id)
	_check(_cells_digest(replay) == digest, "cell records replay without the seed")
	WorldState.begin_build(id, 1)
	var next := gen.build(id)
	WorldState.end_build(id)
	_check(not WorldState.build_cells(id, 1).is_empty() and int(WorldState.chunk_info(id, 1).seed) != int(WorldState.chunk_info(id).seed), "a chained chunk keeps its own seed and records")
	_check(_cells_digest(next) != digest and _cells_digest(replay) == digest, "a chained chunk plans its own layout")
	_check(Travel.land_stage(id, 2) == Travel.land_stage(id) + 2, "chunk distance adds to landStage")
	_check(not Travel.chain_lands, "chaining is off by default")
	var a := gen.cell_rng(7, 2, 1)
	var b := gen.cell_rng(7, 2, 1)
	var c := gen.cell_rng(7, 3, 1)
	_check(a.randf() == b.randf() and a.randf() != c.randf(), "cell streams depend on the cell only")
	WorldState.forget_land(id)


func _check_addresses() -> void:
	var addr := preload("res://scripts/map/room_address.gd")
	var land := Node.new()
	var rooms := [
		{"lx": 0, "ly": 0, "z": 0, "x": 0, "y": 0},
		{"lx": 1, "ly": 0, "z": 0, "x": 1, "y": 0},
		{"lx": 0, "ly": 0, "z": 1, "x": 0, "y": 3},
		{"lx": 1, "ly": 0, "z": 1, "x": 1, "y": 3},
		{"lx": 2, "ly": 0, "z": 0, "x": 0, "y": 5, "sky_block": true, "sky_of": Vector2i(2, 0)},
		{"lx": -1001, "ly": -1000, "z": 0, "x": 1, "y": 5, "sky_part": true, "sky_of": Vector2i(2, 0), "sky_i": 1, "sky_j": 0},
		{"lx": 0, "ly": 0, "z": 0, "x": 0, "y": 7, "prob": "test"},
	]
	addr.stamp(land, rooms)
	_check(addr.at(land, Vector2i(0, 0)) == "0:0:0:main", "main address")
	_check(addr.layer_at(land, Vector2i(1, 3)) == addr.BACK, "back layer")
	_check(addr.layer_at(land, Vector2i(1, 5)) == addr.SKY, "sky part layer")
	_check(addr.layer_at(land, Vector2i(0, 7)) == addr.TRIAL, "trial layer")
	_check(addr.cell_of(land, "0:1:0:back") == Vector2i(1, 3), "address to cell")
	_check(addr.twin(land, Vector2i(1, 0)) == Vector2i(1, 3), "back twin of main")
	_check(addr.twin(land, Vector2i(0, 3)) == Vector2i(0, 0), "main twin of back")
	_check(addr.group_at(land, Vector2i(0, 5)) == addr.group_at(land, Vector2i(1, 5)), "sky block one group")
	_check(addr.group_at(land, Vector2i(0, 3)) != addr.group_at(land, Vector2i(1, 3)), "back rooms apart")
	_check(addr.at(land, Vector2i(9, 9)) == "", "no room no address")
	var keys: Dictionary = preload("res://scripts/fog.gd")._cell_keys(land, {"0:1:0:back": "a", "2,3": "b", "0:9:9:main": "c"})
	_check(keys == {"1,3": "a", "2,3": "b"}, "fog keys by address load back to cells")
	land.free()


func _script(source: String) -> GDScript:
	var gs := GDScript.new()
	gs.source_code = source
	gs.reload()
	return gs


func _check_grid() -> void:
	var grid := preload("res://scripts/map/room_grid.gd")
	var flow_script := preload("res://scripts/map/water_flow.gd")
	var rows: Array = []
	for j in 25:
		rows.append("")
	var env := {"water": 20, grid.WATER: grid.build_water(rows, 20), "rows": rows}
	_check(grid.wet(env, 0, 20) and not grid.wet(env, 0, 19), "water below the level")
	grid.set_water(env, 5, 5, grid.FULL)
	_check(grid.wet(env, 5, 5) and not grid.is_built_water(env, 5, 5, grid.FULL), "water write keeps the built copy")
	_check(grid.reset_water(env) and not grid.wet(env, 5, 5), "reset to built water")
	grid.add_gas(env, 1, 1, 200)
	grid.add_gas(env, 1, 1, 200)
	_check(grid.gas(env, 1, 1) == grid.FULL and grid.gas(env, 2, 1) == 0, "gas density caps")
	var disk_env := {}
	var envs := {Vector2i.ZERO: disk_env}
	grid.add_gas_disk(envs, Vector2(400, 400), 200.0, 10.0)
	var peak := grid.gas(disk_env, 9, 9)
	_check(peak > grid.gas(disk_env, 12, 9) and grid.gas(disk_env, 16, 9) == 0, "source gas fades with distance")
	grid.add_gas_disk(envs, Vector2(400, 400), 200.0, 10.0, -1)
	_check(grid.gas(disk_env, 9, 9) == 0, "source gas taken back")
	_check(grid.room_gas(2.0)[0] == 8 and grid.room_gas(0.0).is_empty(), "room rad gas")
	var host := Node2D.new()
	host.set_meta("room_env", {Vector2i.ZERO: env})
	var solids := Node.new()
	solids.name = "Solids"
	var wall := Node.new()
	wall.set_script(_script("extends Node\nfunc cell_rects(_a: Rect2) -> Array:\n\treturn [[Rect2(0, 0, 40, 40), true], [Rect2(40, 0, 40, 40), false]]\n"))
	solids.add_child(wall)
	host.add_child(solids)
	var props := Node.new()
	props.set_script(_script("extends Node\nvar _doors: Array = []\nvar flags := {}\nfunc flag(k: String, d: Variant = null) -> Variant:\n\treturn flags.get(k, d)\nfunc set_flag(k: String, v: Variant) -> void:\n\tflags[k] = v\n"))
	props.add_to_group("land_props")
	host.add_child(props)
	var door := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	box.size = Vector2(40, 80)
	shape.shape = box
	shape.position = Vector2(20, 40)
	door.add_child(shape)
	door.position = Vector2(400, 0)
	door.set_meta("door_w", 40.0)
	door.set_meta("door_h", 80.0)
	props.add_child(door)
	props.get("_doors").append(door)
	add_child(host)
	_check(grid.solid(env, host, props, Vector2i.ZERO, 0, 0) == grid.SOLID, "live wall cell solid")
	_check(grid.solid(env, host, props, Vector2i.ZERO, 1, 0) == grid.WALL_OPEN, "broken wall cell open")
	_check(grid.solid(env, host, props, Vector2i.ZERO, 2, 0) == grid.FREE, "free cell")
	_check(grid.solid(env, host, props, Vector2i.ZERO, 10, 1) == grid.SOLID, "closed door solid")
	door.collision_layer = 0
	shape.disabled = true
	flow_script.forget_solids(host)
	_check(grid.solid(env, host, props, Vector2i.ZERO, 10, 1) == grid.FREE, "open door refilled free")
	flow_script._write(env, Vector2i(20, 5), 1)
	flow_script._write(env, Vector2i(21, 5), 1)
	var flow: Node = flow_script.of(props)
	flow.call("enqueue", Vector2i(20, 5))
	flow.call("_recalc")
	_check(not grid.wet(env, 21, 5) and (props.get("flags") as Dictionary).has("water"), "water drains through the grid and is saved")
	flow_script._write(env, Vector2i(11, 1), 1)
	flow_script._write(env, Vector2i(10, 1), 1)
	flow_script.door_opened(props, door)
	flow.call("_recalc")
	_check(not grid.wet(env, 11, 1), "opened door wakes the water")
	host.free()


func _check_world_ops() -> void:
	var seen: Array = []
	var log_op := func(op: StringName, args: Array) -> void: seen.append([op, args])
	WorldOps.applied.connect(log_op)
	var before: Variant = Travel.trigger("wops_probe")
	WorldOps.set_trigger("wops_probe", 3)
	_check(Travel.trigger("wops_probe") == 3, "set_trigger reaches Travel")
	_check(seen.size() == 1 and seen[0][0] == &"set_trigger", "applied signal")
	var asked: Array = []
	var log_req := func(op: StringName, args: Array) -> void: asked.append(op)
	WorldOps.requested.connect(log_req)
	WorldOps.authority = false
	WorldOps.set_trigger("wops_probe", 4)
	WorldOps.authority = true
	_check(Travel.trigger("wops_probe") == 3 and asked == [&"set_trigger"], "client call is only requested")
	var drop := Node.new()
	add_child(drop)
	Entity.claim(drop, &"prop")
	_check(Entity.node_of(Entity.eid_of(drop)) == drop, "eid lookup")
	drop.free()
	var who: Array = []
	WorldOps.handle(&"probe", func() -> void: who.append(WorldOps.actor))
	WorldOps._run(&"probe", [], 7)
	_check(who == [7] and WorldOps.actor == 0, "handler sees the acting player")
	_check(Run.character(7) != Run.character() and Run.character(7) == Run.character(7), "second player character")
	WorldOps.applied.disconnect(log_op)
	WorldOps.requested.disconnect(log_req)
	if before == null:
		Travel.triggers.erase("wops_probe")
	else:
		Travel.triggers["wops_probe"] = before


func _check_saves() -> void:
	_slot(null)
	_check(not Mods.slot_mods_differ(1), "old save without mods key")
	_check(not Mods.slot_mods_differ(2), "missing slot")
	_slot([{"id": "nope", "version": "9"}])
	_check(Mods.slot_mods_differ(1), "different mod set warns")
	_slot(Mods.applied())
	_check(not Mods.slot_mods_differ(1), "same mod set")
	var world := get_node("/root/WorldState")
	_check(bool(world.call("apply_run", {"version": 1, "providers": {}})), "run version 1 loads")
	var doc: Dictionary = world.call("run_document")
	_check(int(doc.get("version", 0)) == 2, "run version %s" % str(doc.get("version", 0)))
	var providers: Dictionary = doc.get("providers", {})
	_check(providers.has("mods"), "mods provider")
	var blob: Dictionary = providers.get("mods", {})
	_check(blob.get("active", null) is Array, "mods active list")
	var chars: Dictionary = (world.call("character_document") as Dictionary).get("providers", {})
	_check(chars.has("favorites") and not providers.has("favorites"), "favorites in character document")
	var fav: Variant = chars.get("favorites")
	world.call("apply_run", {"version": 2, "providers": {"favorites": fav}})
	var moved: Dictionary = (world.call("character_document") as Dictionary).get("providers", {})
	_check(moved.get("favorites") == fav, "format 3 favorites migrate to character")
	var run_after: Dictionary = (world.call("run_document") as Dictionary).get("providers", {})
	_check(not run_after.has("favorites"), "run document drops character ids")


func _slot(active) -> void:
	var dir := SaveSlots.dir_of(1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var body := {"version": 2, "providers": {}}
	if active != null:
		body["providers"] = {"mods": {"version": 1, "active": active}}
	_text(dir.path_join("run.json"), JSON.stringify(body))


func _disk_weapon(id: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(WEAPONS))
	if data is not Dictionary:
		return {}
	for row_v in (data as Dictionary).get("weapons", []):
		if row_v is Dictionary and str((row_v as Dictionary).get("id", "")) == id:
			return row_v
	return {}


func _json(path: String, body: Variant) -> void:
	_text(path, JSON.stringify(body, "\t"))


func _text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "write " + path)
		return
	file.store_string(text)
	file.close()
