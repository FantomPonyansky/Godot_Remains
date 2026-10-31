extends Node

## In-game rig check: opens game.tscn (pass --land=<id> and --cmd="god 1" after --), puts the
## units in a row in front of the player and saves tmp/shots/rig_game_<rig|sheet>_<n>.png,
## one per second, then quits. Args: units=bloat1,bloat10 wait=8 shots=3


class Runner extends Node:
	var units := PackedStringArray(["bloat1", "bloat10", "bloat7"])
	var wait := 8.0
	var shots := 3

	func _ready() -> void:
		await get_tree().create_timer(wait).timeout
		var tree := get_tree()
		var who := tree.get_first_node_in_group("player") as Node2D
		if who == null:
			print("RIG_PROBE no player")
			tree.quit()
			return
		var packed := load("res://scenes/enemy.tscn") as PackedScene
		var facing := 1.0 if float(who.get("facing")) >= 0.0 else -1.0
		var spawned: Array[Node2D] = []
		for i in units.size():
			var node := packed.instantiate() as Node2D
			spawned.append(node)
			node.set_meta("unit_id", units[i])
			var at := who.global_position + Vector2(facing * (90.0 + 80.0 * i), -40.0)
			node.position = at
			tree.current_scene.add_child(node)
			node.global_position = at
			var spr := node.get("anim") as AnimatedSprite2D
			print("RIG_PROBE ", units[i], " rig=", node.get("rig") != null, " clips=", spr.sprite_frames.get_animation_names() if spr.sprite_frames else [])
		var dir := ProjectSettings.globalize_path("res://").path_join("../tmp/shots")
		DirAccess.make_dir_recursive_absolute(dir)
		var tag := "rig"
		var attach := ""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("attach="):
				attach = a.trim_prefix("attach=")
		if attach != "":
			var seen := 0
			var shot := false
			for t in 180:
				await tree.physics_frame
				for n in spawned:
					var r: RigView = n.get("rig")
					var at: Node2D = r.attachment(attach) if r else null
					if at and at.is_visible_in_tree():
						seen += 1
						if not shot:
							shot = true
							tree.root.get_texture().get_image().save_png(dir.path_join("rig_attach_%s.png" % attach))
			print("RIG_PROBE attach ", attach, " visible ticks=", seen)
			tree.quit()
			return
		if OS.get_cmdline_user_args().has("fx"):
			await _fx(tree, who, spawned, dir.path_join("rig_fx_%s_" % tag))
			tree.quit()
			return
		for n in shots:
			await tree.create_timer(1.0).timeout
			tree.root.get_texture().get_image().save_png(dir.path_join("rig_game_%s_%d.png" % [tag, n]))
		print("RIG_PROBE done")
		tree.quit()

	## fx: telekinesis glow, SATS (hover on the first unit), fog last-seen ghost 110 px above.
	func _fx(tree: SceneTree, who: Node2D, spawned: Array[Node2D], out: String) -> void:
		await tree.create_timer(1.0).timeout
		for n in spawned:
			n.set_physics_process(false)
			(load("res://scripts/magic_aura.gd") as GDScript).call("attach", n)
		await tree.create_timer(0.5).timeout
		tree.root.get_texture().get_image().save_png(out + "aura.png")
		for n in spawned:
			(load("res://scripts/magic_aura.gd") as GDScript).call("clear", n)
		var bags := tree.root.get_node("/root/Inventory")
		bags.call("add", "p10mm", 1)
		bags.call("add", "p10", 200)
		print("RIG_PROBE equip=", bags.call("equip", "p10mm"))
		await tree.create_timer(0.5).timeout
		var sats: Node = who.get("sats")
		sats.call("_set_active", true)
		await tree.create_timer(0.5).timeout
		var rows: Array = sats.get("units")
		print("RIG_PROBE sats units=", rows.size())
		for row in rows:
			for g in row.get("glows", []):
				(g as CanvasItem).visible = true
		await tree.create_timer(0.3).timeout
		tree.root.get_texture().get_image().save_png(out + "sats.png")
		sats.call("_set_active", false)
		await tree.create_timer(0.3).timeout
		var sight: Object = null
		for f in tree.current_scene.find_children("*", "", true, false):
			if f.get("_sight") != null:
				sight = f.get("_sight")
				break
		if sight == null:
			print("RIG_PROBE no fog sight")
			return
		var ghosts := Node2D.new()
		tree.current_scene.add_child(ghosts)
		sight.set("_ghosts", ghosts)
		for n in spawned:
			var items: Array = []
			sight.call("_collect", n, items, 0)
			var parts: Array = []
			for it in items:
				var p: Dictionary = sight.call("_part_of", it)
				if not p.is_empty():
					parts.append(p)
			print("RIG_PROBE ghost ", n.get_meta("unit_id"), " parts=", parts.size())
			var g: Node2D = sight.get_script().make_ghost(ghosts, parts, n.global_position, "")
			g.position.y -= 110.0
		await tree.create_timer(0.3).timeout
		tree.root.get_texture().get_image().save_png(out + "ghost.png")


func _ready() -> void:
	var r := Runner.new()
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			match kv[0]:
				"units": r.units = kv[1].split(",", false)
				"wait": r.wait = float(kv[1])
				"shots": r.shots = int(kv[1])
	get_tree().root.add_child.call_deferred(r)
	get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")
