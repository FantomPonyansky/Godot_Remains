extends Node

## Loads a format-2 slot (cfg files + world.json v2) and checks the run still
## comes back: inventory, worn suit, level, xp, land and health.
## `src=` is the fixture directory (user arg). Prints `CHECK save_migrate: ok N fail M`.

const SLOT := 8
const SaveSlots := preload("res://scripts/save_slots.gd")
const TIMEOUT_S := 150.0


class Runner extends Node:
	var tree: SceneTree
	var src := ""
	var leaves := 0
	var fails: Array[String] = []

	func _ready() -> void:
		tree = get_tree()
		tree.create_timer(TIMEOUT_S, true, false, true).timeout.connect(func() -> void:
			print("CHECK save_migrate: ok 0 fail 1 (timeout)")
			tree.quit(1))
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("src="):
				src = arg.trim_prefix("src=")
		preload("res://scripts/intro_screen.gd").pending = false
		if not _install():
			return _finish()
		SaveSlots.request_load(SLOT)
		tree.change_scene_to_file("res://scenes/game.tscn")
		if not await _settle():
			fails.append("no player after load")
			return _finish()
		await _frames(30)
		_check()
		_finish()

	func _install() -> bool:
		var from := src.replace("\\", "/").trim_suffix("/")
		if from == "":
			fails.append("missing src=")
			return false
		var dest := SaveSlots.dir_of(SLOT)
		DirAccess.make_dir_recursive_absolute(dest)
		var rd := DirAccess.open(from)
		if rd == null:
			fails.append("cannot open %s" % from)
			return false
		for file in rd.get_files():
			var err := DirAccess.copy_absolute(from + "/" + file, dest + file)
			if err != OK:
				fails.append("copy %s err %s" % [file, err])
				return false
		var row := SaveSlots.info(SLOT)
		if int(row.get("format", 1)) != 2:
			fails.append("fixture format %s" % str(row.get("format", "?")))
			return false
		return true

	func _check() -> void:
		var dir := SaveSlots.dir_of(SLOT)
		var row := SaveSlots.info(SLOT)
		var bags := _cfg(dir + "inventory.cfg")
		var prog := _cfg(dir + "progression.cfg")
		_eq("land", str(row.get("land", "")), Travel.cur_land_id)
		_eq("health", int(row.get("health", -1)), GameState.health)
		_eq("level", int(prog.get("run/level", -1)), Progression.level)
		_eq("xp", int(prog.get("run/xp", -1)), Progression.xp)
		_eq("worn", str(bags.get("gear/worn", "")), Inventory.worn)
		for key in bags:
			if not str(key).begins_with("items/"):
				continue
			var id := str(key).trim_prefix("items/")
			_eq("item " + id, int(bags[key]), Inventory.count(id))

	func _eq(label: String, want: Variant, got: Variant) -> void:
		leaves += 1
		if want != got:
			fails.append("%s: %s -> %s" % [label, str(want), str(got)])

	func _cfg(path: String) -> Dictionary:
		var cfg := ConfigFile.new()
		var out := {}
		if cfg.load(path) != OK:
			fails.append("unreadable " + path)
			return out
		for section in cfg.get_sections():
			for key in cfg.get_section_keys(section):
				out["%s/%s" % [section, key]] = cfg.get_value(section, key)
		return out

	func _settle() -> bool:
		var until := Time.get_ticks_msec() + 60000
		var ready_frames := 0
		while Time.get_ticks_msec() < until:
			await tree.physics_frame
			var ready := tree.get_first_node_in_group("player") != null \
				and tree.get_first_node_in_group("active_land") != null and not WorldState.resuming()
			ready_frames = ready_frames + 1 if ready else 0
			if ready_frames >= 60:
				return true
		return false

	func _frames(n: int) -> void:
		for _i in n:
			await tree.physics_frame

	func _finish() -> void:
		for d in fails:
			print("DIFF ", d)
		var fail := fails.size()
		print("CHECK save_migrate: ok %d fail %d" % [maxi(0, leaves - fail), fail])
		tree.quit(1 if fail > 0 else 0)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())
