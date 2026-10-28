extends Node

## Windowed PipBuck shot to tmp/shots/pip.png. Args: [page] [sub] [skill points] [perk ids, comma-separated].
## Skills page: places 3 pending points on the first skill. Any page: focuses the first row.
## Arg "nomed" anywhere sets the nomed trigger (medical module not yet repaired).
## "give=id:n,id:n" adds items; "focus=N" focuses row N instead of the last.
## "game" boots game.tscn first (local map needs a land); "mapall" also lights every tile.
## "perkpick" opens the perk choice at level 12 with one point.
## "pet" calls the phoenix at half health (no unit spawned).
## "switch=page:sub" opens a second page before the shot; "refill" rebuilds the list once.
## "save" writes slot 1 first (Menu / Load info and preview).

var _quests := 0


## Story.add_quest for the first N quests.json ids; again after game.tscn resets the story.
func _add_quests() -> void:
	if _quests <= 0:
		return
	var defs: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/story/quests.json"))
	var ids: Array = (defs as Dictionary).keys() if defs is Dictionary else []
	if defs is Array:
		for d: Variant in defs:
			if d is Dictionary and (d as Dictionary).has("id"):
				ids.append(str(d.id))
	var n := 0
	for qid: Variant in ids:
		if n >= _quests or str(qid).begins_with("_"):
			continue
		if Story.add_quest(str(qid), {}, false, false, false) != null:
			n += 1
	print("PROBE_QUESTS added=%d list=%d" % [n, Story.quest_list().size()])


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("nomed"):
		Travel.triggers["nomed"] = 1
		args.erase("nomed")
	var focus := -1
	for a in args.duplicate():
		if a.begins_with("wear="):
			Inventory.add(a.substr(5), 1)
			Inventory.wear(a.substr(5))
			args.erase(a)
		elif a.begins_with("give="):
			for pair in a.substr(5).split(","):
				var kv := pair.split(":")
				Inventory.add(kv[0], int(kv[1]) if kv.size() > 1 else 1)
			args.erase(a)
		elif a.begins_with("quests="):
			_quests = int(a.substr(7))
			_add_quests()
			args.erase(a)
		elif a.begins_with("focus="):
			focus = int(a.substr(6))
			args.erase(a)
	if args.has("save"):
		SaveSlots.save(1)
		args.erase("save")
	var page := int(args[0]) if args.size() > 0 and args[0].is_valid_int() else 1
	var sub := int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 1
	if args.size() > 2 and args[2].is_valid_int():
		Progression.skill_points = int(args[2])
	if args.size() > 3 and not args[3].begins_with("--"):
		for id in args[3].split(","):
			Progression._perks[id] = 1
	if OS.get_cmdline_user_args().has("game"):
		var game: Node = load("res://scenes/game.tscn").instantiate()
		get_tree().root.add_child.call_deferred(game)
		await get_tree().create_timer(6.0).timeout
		get_tree().current_scene = game
		var fog := game.get_node_or_null("Fog")
		if OS.get_cmdline_user_args().has("mapall") and fog != null and fog.get("_state") != null:
			fog._state.vis.fill(1.0)
		_add_quests()
		var hud := get_tree().get_first_node_in_group("hud")
		if OS.get_cmdline_user_args().has("log") and hud != null:
			for id in ["itsEmpty", "noPoss", "unLock", "overMass", "usedSpell"]:
				hud.info_line(OriginalLines.info(id, "X"))
			hud.info_line("Port notice")
		for n in game.find_children("*", "", true, false):
			if n.has_method("open_pipbuck_at"):
				n.open_pipbuck_at(page, sub + 1)
				break
		await get_tree().create_timer(2.0).timeout
		for a in OS.get_cmdline_user_args():
			if a.begins_with("switch="):
				var gp: Node = null
				for n in get_tree().root.find_children("*", "", true, false):
					if n.has_method("_fill_quests") and n.is_visible_in_tree():
						gp = n
						break
				if gp != null:
					var ps := a.substr(7).split(":")
					gp.open_at(int(ps[0]), int(ps[1]))
					await get_tree().create_timer(1.0).timeout
					var vb: ScrollBar = gp._scroll.get_v_scroll_bar()
					print("PROBE_SCROLL_W ", gp._scroll.size.x, " list ", gp._list.size.x, " vbar ", vb.visible, " ", vb.max_value, " ", vb.page, " ", vb.position, vb.size, " rows ", gp._rows.size(), " listh ", gp._list.size.y)
		var shot := ProjectSettings.globalize_path("res://").path_join("../tmp/shots")
		DirAccess.make_dir_recursive_absolute(shot)
		get_viewport().get_texture().get_image().save_png(shot.path_join("pip.png"))
		get_tree().quit()
		return
	var pip: Node = load("res://scenes/pipbuck.tscn").instantiate()
	if OS.get_cmdline_user_args().has("pet"):
		Pets.current = "phoenix"
		Pets.proc["phoenix"] = 0.5
	if OS.get_cmdline_user_args().has("perkpick"):
		Progression.perk_points = 1
		Progression.level = 12
		pip._choosing = true
	pip.open_at(page, sub)
	add_child(pip)
	await get_tree().create_timer(1.0).timeout
	if page == 1 and sub == 1 and not pip._rows.is_empty():
		for i in 3:
			pip._on_row_primary(pip._rows[0])
		await get_tree().process_frame
	if not pip._rows.is_empty():
		pip._rows[clampi(focus, 0, pip._rows.size() - 1) if focus >= 0 else pip._rows.size() - 1].grab_focus()
	await get_tree().create_timer(1.0).timeout
	if OS.get_cmdline_user_args().has("rapid"):
		pip.open_at(3, 2)
		pip.open_at(3, 1)
		await get_tree().create_timer(0.5).timeout
		print("PROBE_RAPID ", pip._scroll.size.x)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("switch="):
			var ps := a.substr(7).split(":")
			pip.open_at(int(ps[0]), int(ps[1]))
			await get_tree().create_timer(0.5).timeout
			if not pip._rows.is_empty():
				pip._rows[0].grab_focus()
			await get_tree().create_timer(0.5).timeout
			print("PROBE_SCROLL_W ", pip._scroll.size.x, " list ", pip._list.size.x)
	if OS.get_cmdline_user_args().has("act"):
		var row0: Object = pip._rows[0]
		var f: int = pip._focused_row_index()
		print("PROBE_ACT before scroll=", pip._scroll.scroll_vertical, " focus=", f)
		pip._on_row_primary(pip._rows[f])
		await get_tree().create_timer(0.5).timeout
		print("PROBE_ACT after scroll=", pip._scroll.scroll_vertical, " focus=", pip._focused_row_index(), " same_rows=", is_instance_valid(row0) and pip._rows.has(row0))
	if OS.get_cmdline_user_args().has("refill"):
		print("PROBE_SCROLL before=", pip._scroll.scroll_vertical)
		pip._fill()
		await get_tree().create_timer(0.5).timeout
		print("PROBE_SCROLL after=", pip._scroll.scroll_vertical)
	var dir := ProjectSettings.globalize_path("res://").path_join("../tmp/shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("pip.png"))
	get_tree().quit()
