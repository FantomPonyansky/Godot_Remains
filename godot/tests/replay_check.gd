extends Node

## Seeded replay (ARCHITECTURE_PLAN R0.3, TODO 6.1). Plays the same scripted
## input twice from the same seed in begin and compares a state hash every
## HASH_EVERY physics ticks: the player (position, velocity, health, magic) and
## the enemies of the land (position, health). Run with --fixed-fps 60 so both
## runs get the same frame pacing.
## Gameplay draws use Rng streams seeded from WorldState.fixed_seed and the
## land id. EXPECT_SAME: begin, surf and the arena all matched on 2026-10-31.
## User args: land=<id> (default begin) or room=<rooms_file>:<room> (editor
## test land). golden=<path>: missing file receives run 1 (one line per hash:
## tick, player, enemies); an existing file is compared to run 1 and each
## mismatch counts as a failure. Prints `CHECK replay: ok N fail M xfail K`.

const SEED := 20261031
const HASH_EVERY := 30
const EXPECT_SAME := true
const TIMEOUT_S := 240.0
## [ticks, actions held]
const SCRIPT := [
	[90, ["move_right"]],
	[6, ["move_right", "jump"]],
	[60, ["move_right"]],
	[60, ["move_left"]],
	[60, ["move_right", "sprint"]],
	[30, []],
	[60, ["move_left", "sprint"]],
	[30, []],
]


class Runner extends Node:
	var tree: SceneTree
	var _held: Array = []
	var _golden := ""

	func _ready() -> void:
		tree = get_tree()
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("golden="):
				_golden = arg.trim_prefix("golden=")
		tree.create_timer(TIMEOUT_S, true, false, true).timeout.connect(func() -> void:
			print("CHECK replay: ok 0 fail 1 (timeout)")
			tree.quit(1))
		var a: Array = await _play()
		var b: Array = await _play()
		if a.is_empty() or b.is_empty():
			print("CHECK replay: ok 0 fail 1 (no player)")
			tree.quit(1)
			return
		var same := 0
		var first := -1
		for i in mini(a.size(), b.size()):
			if a[i] == b[i]:
				same += 1
			elif first < 0:
				first = i
		var drift := a.size() - same
		var player_same := 0
		for i in mini(a.size(), b.size()):
			if a[i].player == b[i].player:
				player_same += 1
		print("replay: %d hashes, player same %d, all same %d" % [a.size(), player_same, same])
		if first >= 0:
			var part := "player" if a[first].player != b[first].player else "enemies"
			print("DRIFT from tick %d (%s)" % [first * HASH_EVERY, part])
			print("  run 1 ", str(a[first][part]).left(160))
			print("  run 2 ", str(b[first][part]).left(160))
		var golden_fail := _golden_check(a)
		var fail := drift + golden_fail
		if EXPECT_SAME:
			print("CHECK replay: ok %d fail %d" % [same, fail])
		else:
			print("CHECK replay: ok %d fail %d xfail %d" % [same, golden_fail, drift])
		tree.quit(1 if (EXPECT_SAME and fail > 0) or golden_fail > 0 else 0)

	## Run 1 against golden=<path>. A missing file is written and is not a failure.
	func _golden_check(rows: Array) -> int:
		if _golden == "":
			return 0
		if not FileAccess.file_exists(_golden):
			var out := FileAccess.open(_golden, FileAccess.WRITE)
			if out == null:
				print("GOLDEN write failed %s" % _golden)
				return 1
			for i in rows.size():
				var row: Dictionary = rows[i]
				out.store_line("%d\t%s\t%s" % [i * HASH_EVERY, row.player, row.enemies])
			out.close()
			print("GOLDEN wrote %s (%d)" % [_golden, rows.size()])
			return 0
		var lines := FileAccess.get_file_as_string(_golden).split("\n", false)
		var bad := absi(rows.size() - lines.size())
		var told := false
		var n := mini(rows.size(), lines.size())
		for i in n:
			var row: Dictionary = rows[i]
			var got := "%d\t%s\t%s" % [i * HASH_EVERY, row.player, row.enemies]
			if got == lines[i]:
				continue
			bad += 1
			if told:
				continue
			told = true
			var parts := lines[i].split("\t", false, 2)
			var part := "line"
			if parts.size() >= 3:
				part = "player" if parts[1] != str(row.player) else "enemies"
			var shown: String = got
			if part == "player":
				shown = str(row.player)
			elif part == "enemies":
				shown = str(row.enemies)
			print("GOLDEN mismatch tick %d (%s)" % [i * HASH_EVERY, part])
			print("  run 1 ", shown.left(160))
			print("  file  ", (parts[part_index(part)] if parts.size() >= 3 else lines[i]).left(160))
		if rows.size() != lines.size() and not told:
			print("GOLDEN mismatch count run %d file %d" % [rows.size(), lines.size()])
		print("GOLDEN %s mismatches %d" % [_golden, bad])
		return bad

	func part_index(part: String) -> int:
		return 1 if part == "player" else 2

	func _play() -> Array:
		var land := ""
		var room := ""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("land="):
				land = arg.trim_prefix("land=")
			elif arg.begins_with("room="):
				room = arg.trim_prefix("room=")
		WorldState.fixed_seed = SEED
		GameState.reset_run()
		preload("res://scripts/intro_screen.gd").pending = false
		if room != "":
			var r := room.split(":")
			preload("res://scripts/editor/editor_play.gd").start(r[0], r[1], true)
		elif land != "" and land != "begin":
			DebugConsole._land = land
		tree.change_scene_to_file("res://scenes/game.tscn")
		if not await _settle():
			return []
		var hashes: Array = []
		var tick := 0
		for step in SCRIPT:
			_hold(step[1])
			for i in int(step[0]):
				await tree.physics_frame
				if tick % HASH_EVERY == 0:
					hashes.append(_state())
				tick += 1
		_hold([])
		return hashes

	func _hold(actions: Array) -> void:
		for a in _held:
			if not a in actions:
				Input.action_release(a)
		for a in actions:
			if not a in _held:
				Input.action_press(a)
		_held = actions.duplicate()

	func _settle() -> bool:
		var ready_frames := 0
		for i in 3000:
			await tree.physics_frame
			var ready := tree.get_first_node_in_group("player") != null \
				and tree.get_first_node_in_group("active_land") != null and not WorldState.resuming()
			ready_frames = ready_frames + 1 if ready else 0
			if ready_frames >= 60:
				return true
		return false

	func _state() -> Dictionary:
		var p := tree.get_first_node_in_group("player") as CharacterBody2D
		var player := "%.2f,%.2f v%.2f,%.2f h%.2f m%.2f" % [p.global_position.x, p.global_position.y,
			p.velocity.x, p.velocity.y, GameState.health, GameState.magic]
		var rows: Array = []
		for e in tree.get_nodes_in_group("enemies"):
			var n := e as Node2D
			if n != null and is_instance_valid(n):
				rows.append("%.1f,%.1f h%s" % [n.global_position.x, n.global_position.y, str(n.get("hp"))])
		rows.sort()
		return {"player": player, "enemies": ",".join(rows)}


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())
