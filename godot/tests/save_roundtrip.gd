extends Node

## Save round trip (ARCHITECTURE_PLAN R0.2, TODO 6.3). Starts a new run in begin,
## scripts a state, saves slot 9, changes every part of that state, loads slot 9
## the way the main menu does and compares the live state with the saved one.
## Prints `CHECK save_roundtrip: ok N fail M` plus one `DIFF` line per mismatch.
## Reopened save gaps print as `XFAIL` and do not count as failures.
## Run with --user-dir=<sandbox> after --; land=<id> starts there instead of begin.

const SLOT := 9
const _UserDir := preload("res://scripts/user_dir.gd")
const SaveSlots := preload("res://scripts/save_slots.gd")
const Registry := preload("res://scripts/map/land_registry.gd")
## Reopened save gaps. Empty after the format-3 run document (TODO 1.9).
const KNOWN_GAPS: PackedStringArray = []
## Units walk and props settle while the land runs after the save and after the
## load: unit positions are skipped, props may move this far. Fog keeps
## revealing around the player: this share of a room mask may differ.
## The random vendor keeps id / kol / variant only (Vendor.as), the rest rerolls.
const POS_TOLERANCE := 8.0
const FOG_TOLERANCE := 0.05
const TIMEOUT_S := 150.0


class Runner extends Node:
	var tree: SceneTree
	var leaves := 0
	var land := "begin"
	var _cps: Array = []
	var _crate: Node = null

	func _ready() -> void:
		tree = get_tree()
		tree.create_timer(TIMEOUT_S, true, false, true).timeout.connect(func() -> void:
			print("CHECK save_roundtrip: ok 0 fail 1 (timeout)")
			tree.quit(1))
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("land="):
				land = arg.trim_prefix("land=")
		GameState.reset_run()
		preload("res://scripts/intro_screen.gd").pending = false
		if land != "begin":
			DebugConsole._land = land
		tree.change_scene_to_file("res://scenes/game.tscn")
		if not await _settle():
			return _finish({}, ["no player after new game"])
		print("save_roundtrip: land %s, %s" % [land, _script_state()])
		await _frames(60)
		var cycle_diffs: Array = []
		if str(Registry.land(land).get("tip", "")) == "rnd":
			cycle_diffs = await _cycle_room()
		var saved := _digest()
		if not SaveSlots.save(SLOT):
			return _finish({}, ["SaveSlots.save failed"])
		_mutate()
		await _frames(30)
		var changed := _digest()
		var unchanged: Array = []
		for key in ["files/inventory.cfg", "files/progression.cfg", "files/pets.cfg", "game/health", "game/score", "vendor_money", "room", "world/providers/story"]:
			if _at(saved, key) == _at(changed, key):
				unchanged.append(key)
		if not unchanged.is_empty():
			return _finish({}, ["mutation did not change: " + ", ".join(unchanged)])
		SaveSlots.request_load(SLOT)
		tree.change_scene_to_file("res://scenes/game.tscn")
		if not await _settle():
			return _finish({}, ["no player after load"])
		await _frames(30)
		var loaded := _digest()
		var diffs: Array = cycle_diffs
		if str(Registry.land(land).get("tip", "")) == "rnd":
			# A save in a generated land resumes in the camp (WorldState._tick_resume):
			# the arrival there changes travel, notes and the camp land; the rest must match.
			if str(loaded.world.get("land", "")) != Travel.base_id:
				diffs.append("world/land: %s, expected the camp %s" % [loaded.world.get("land", ""), Travel.base_id])
			for d in [saved, loaded]:
				d.erase("room")
				d.erase("pos")
				d.world.erase("land")
				d.world.erase("room")
				d.world.providers.erase("travel")
				(d.world.providers.story as Dictionary).erase("notes")
				(d.world.lands as Dictionary).erase(Travel.base_id)
		_compare("", saved, loaded, diffs)
		if saved.has("pos") and (saved.pos as Vector2).distance_to(loaded.pos) > POS_TOLERANCE:
			diffs.append("pos %s -> %s" % [saved.pos, loaded.pos])
		_finish(saved, diffs)

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
		print("settle: scene %s player %s land %s resuming %s" % [tree.current_scene.name if tree.current_scene else "-",
			tree.get_first_node_in_group("player") != null, tree.get_first_node_in_group("active_land") != null, WorldState.resuming()])
		return false

	## R5.3: a far room with actors unloads (actors into memory, collision
	## meshed without it) and loads back; memory and collision must match.
	func _cycle_room() -> Array:
		var out: Array = []
		var land_node := tree.get_first_node_in_group("active_land")
		var props := land_node.get_node("Actors")
		var memory: Variant = props.get("_memory")
		var nodes := preload("res://scripts/map/room_nodes.gd")
		var here := Vector2i((_player().global_position / Vector2(1920.0, 1000.0)).floor())
		var stream := land_node.get_node_or_null("RoomStream")
		if stream == null:
			out.append("cycle: generated land has no RoomStream")
		else:
			var parked: Dictionary = stream.get("_out")
			if parked.is_empty():
				out.append("cycle: streaming left every room loaded")
			for cell_v in parked:
				if maxi(absi(cell_v.x - here.x), absi(cell_v.y - here.y)) <= stream.LOAD_REACH:
					out.append("cycle: room %s near the player is unloaded" % cell_v)
			print("save_roundtrip: streaming parked %d rooms, %d actors" % [parked.size(), stream.unloaded_total])
			stream.paused = true
			for cell_v in parked.keys():
				props.reload_room(cell_v)
			parked.clear()
		var best := Vector2i(-99, -99)
		var best_n := 0
		for cell_v in land_node.get_meta("room_addr", {}):
			var cell: Vector2i = cell_v
			if maxi(absi(cell.x - here.x), absi(cell.y - here.y)) < 2:
				continue
			props.call("_spawn_room", "%d,%d" % [cell.x, cell.y])
			var n := 0
			for wid in memory._nodes:
				var node: Variant = memory._nodes[wid]
				if is_instance_valid(node) and memory._in_room(node, cell):
					n += 1
			if n > best_n:
				best = cell
				best_n = n
		if best_n == 0:
			return ["cycle: no far room with actors"]
		await _frames(5)
		var before := _cycle_digest(memory)
		var tiles_before := _collision_tiles(land_node)
		var left: int = props.unload_room(best)
		land_node.set_loaded(best, false)
		land_node.remesh([best])
		for node in nodes.nodes_of(land_node, best):
			if str(node.get_parent().name) in land_node.COLLISION_ROOTS:
				out.append("cycle: collision left in unloaded room %s" % best)
				break
		if left < best_n:
			out.append("cycle: %d of %d actors left room %s" % [left, best_n, best])
		_compare("cycle_parked", before, _cycle_digest(memory), out)
		land_node.set_loaded(best, true)
		land_node.remesh([best])
		props.reload_room(best)
		props.call("_spawn_room", "%d,%d" % [best.x, best.y])
		await _frames(5)
		_compare("cycle", before, _cycle_digest(memory), out)
		if _collision_tiles(land_node) != tiles_before:
			out.append("cycle: collision tiles differ after remesh of %s" % best)
		print("save_roundtrip: cycled room %s with %d actors" % [best, best_n])
		if stream != null:
			stream.paused = false
			stream.tick()
			await _frames(5)
			var parked: Dictionary = stream.get("_out")
			if not parked.is_empty():
				var away: Vector2i = parked.keys()[0]
				var home := _player().global_position
				var waiting := 0
				for wid in memory._parked:
					var row: Dictionary = memory._rows.get(wid, {})
					var room: Array = row.get("room", [0, 0])
					if Vector2i(int(room[0]), int(room[1])) == away:
						waiting += 1
				_player().global_position = Vector2(away) * Vector2(1920.0, 1000.0) + Vector2(960.0, 500.0)
				stream.tick()
				await _frames(10)
				var live := 0
				for wid in memory._nodes:
					var node: Variant = memory._nodes[wid]
					if is_instance_valid(node) and memory._in_room(node, away):
						live += 1
				if stream.is_out(away) or (waiting > 0 and live == 0):
					out.append("cycle: room %s did not come back when the player went there (%d rows, %d live)" % [away, waiting, live])
				print("save_roundtrip: streamed into room %s, %d live" % [away, live])
				_player().global_position = home
				_player().call("reset_physics_interpolation")
				stream.tick()
				await _frames(10)
		return out

	func _cycle_digest(memory: Variant) -> Dictionary:
		var cap: Dictionary = memory.capture()
		var drops: Array = []
		for d in cap.get("drops", []):
			drops.append(JSON.stringify(d))
		drops.sort()
		return {"ents": cap.ents, "doors": cap.doors, "broken": cap.broken, "drops": drops, "extra": cap.extra, "xp_left": cap.xp_left}

	func _collision_tiles(land_node: Node) -> Dictionary:
		var out := {}
		for root_name in land_node.COLLISION_ROOTS:
			var root := land_node.get_node_or_null(str(root_name))
			if root == null:
				continue
			for body in root.get_children():
				var span: Rect2i = body.get_meta("tiles", Rect2i())
				for x in range(span.position.x, span.end.x):
					for y in range(span.position.y, span.end.y):
						out["%s %d,%d" % [root_name, x, y]] = true
		return out

	func _frames(n: int) -> void:
		for i in n:
			await tree.physics_frame

	func _player() -> Node2D:
		return tree.get_first_node_in_group("player") as Node2D

	func _script_state() -> String:
		var suit := ""
		for id in Condition._armors:
			if str(id) != Inventory.PIP_ID:
				suit = str(id)
				break
		Inventory.add(suit, 1)
		var worn := Inventory.wear(suit)
		Story.add_quest("storyContact", {}, false, false, false)
		Story.rep = 7
		var land_node := tree.get_first_node_in_group("active_land")
		for cp in tree.get_nodes_in_group("checkpoints"):
			if land_node.is_ancestor_of(cp):
				_cps.append(cp)
		if not _cps.is_empty():
			_cps[0].activate()
		for n in tree.get_nodes_in_group("floor_box"):
			if land_node.is_ancestor_of(n) and n.has_meta("cont"):
				_crate = n
				break
		if _crate:
			preload("res://scripts/prop_state.gd").put(_crate, "box_hp", 3.0)
		Inventory.add("p10mm", 1)
		Inventory.add("p10", 50)
		Inventory.equip("p10mm")
		Inventory.add("money", 123)
		Progression.add_xp(500)
		Progression.add_skill_point(2)
		GameState.health = maxi(1, GameState.health - 7)
		GameState.score = 42
		Pets.proc["owl"] = 0.5
		Vendors.get_state()
		for vid in Vendors.vendors:
			Vendors.vendors[vid].money = 777
		var p := _player()
		p.global_position += Vector2(160, -40)
		return "suit %s worn %s, checkpoints %d, crate %s" % [suit, worn, _cps.size(), _crate != null]

	func _mutate() -> void:
		Inventory.add("money", 900)
		Inventory.add("p10", 7)
		Progression.add_xp(3000)
		GameState.health = maxi(1, GameState.health - 5)
		GameState.score = 99
		Pets.proc["owl"] = 0.9
		Pets._save()
		Inventory.wear(Inventory.PIP_ID)
		Story.add_quest("storyFind", {}, false, false, false)
		Story.rep = 1
		if _cps.size() >= 2:
			_cps[1].activate()
		if _crate:
			preload("res://scripts/prop_state.gd").put(_crate, "box_hp", 1.0)
		for vid in Vendors.vendors:
			Vendors.vendors[vid].money = 1
		var p := _player()
		p.global_position += Vector2(2000, 0)
		p.call("reset_physics_interpolation")

	func _digest() -> Dictionary:
		SaveSlots._flush_autoloads()
		Pets._save()
		var files := {}
		for f in Array(SaveSlots.RUN_FILES) + ["pets.cfg"]:
			files[f] = _cfg(_UserDir.run(f))
		var money := {}
		for vid in Vendors.vendors:
			money[vid] = int(Vendors.vendors[vid].money)
		var world := WorldState.to_save()
		var p := _player()
		var at := p.global_position if p else Vector2.ZERO
		world.erase("pos")
		return {
			"files": files,
			"game": {"health": GameState.health, "magic": GameState.magic, "score": GameState.score, "ammo": GameState.ammo},
			"vendor_money": money,
			"world": world,
			"character": WorldState.character_document(),
			"room": [floori(at.x / 1920.0), floori(at.y / 1000.0)],
			"pos": at,
		}

	func _cfg(path: String) -> Dictionary:
		var cfg := ConfigFile.new()
		if cfg.load(path) != OK:
			return {}
		var out := {}
		for s in cfg.get_sections():
			for k in cfg.get_section_keys(s):
				out["%s/%s" % [s, k]] = cfg.get_value(s, k)
		return out

	func _at(d: Dictionary, path: String) -> Variant:
		var v: Variant = d
		for part in path.split("/"):
			if not v is Dictionary or not (v as Dictionary).has(part):
				return null
			v = v[part]
		return v

	func _compare(path: String, a: Variant, b: Variant, out: Array) -> void:
		if not (a is Dictionary or a is Array):
			leaves += 1
		if path == "pos" or (path.contains("/ents/unit|") and path.contains("/pos")):
			return
		if path.contains("/ents/") and path.contains("/pos[") and typeof(a) == TYPE_FLOAT and typeof(b) == TYPE_FLOAT:
			if absf(a - b) <= POS_TOLERANCE:
				return
		if path.begins_with("world/providers/vendors/random[") and not (path.ends_with("/id") or path.ends_with("/kol") or path.ends_with("/variant")):
			return
		if a is String and b is String and a.length() == b.length() and a != b:
			var n := 0
			for i in a.length():
				if a[i] != b[i]:
					n += 1
			if path.contains("/fog/") and n <= a.length() * FOG_TOLERANCE:
				return
			out.append("%s: %d of %d chars differ" % [path, n, a.length()])
			return
		if a is Dictionary and b is Dictionary:
			for k in a:
				_compare(path + "/" + str(k) if path != "" else str(k), a[k], (b as Dictionary).get(k), out)
			for k in b:
				if not (a as Dictionary).has(k):
					out.append("%s/%s only after load" % [path, k])
			return
		if a is Array and b is Array and a.size() == b.size():
			for i in a.size():
				_compare("%s[%d]" % [path, i], a[i], b[i], out)
			return
		if typeof(a) in [TYPE_FLOAT, TYPE_INT] and typeof(b) in [TYPE_FLOAT, TYPE_INT]:
			if absf(float(a) - float(b)) <= 0.001:
				return
		elif a == b:
			return
		out.append("%s: %s -> %s" % [path, str(a).left(80), str(b).left(80)])

	func _finish(saved: Dictionary, diffs: Array) -> void:
		var fail := 0
		var xfail := 0
		var per_gap := {}
		for d in diffs:
			var gap_hit := ""
			for gap in KNOWN_GAPS:
				if str(d).begins_with(gap):
					gap_hit = gap
			if gap_hit != "":
				xfail += 1
				if not per_gap.has(gap_hit):
					print("XFAIL ", d)
				per_gap[gap_hit] = int(per_gap.get(gap_hit, 0)) + 1
			else:
				fail += 1
				print("DIFF ", d)
		for gap in per_gap:
			if per_gap[gap] > 1:
				print("XFAIL %s: %d values" % [gap, per_gap[gap]])
		var ok := maxi(0, leaves - fail - xfail)
		print("CHECK save_roundtrip: ok %d fail %d xfail %d" % [ok, fail, xfail])
		tree.quit(1 if fail > 0 or saved.is_empty() else 0)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())
