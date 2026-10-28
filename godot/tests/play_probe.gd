extends Node

## Windowed probe: start an editor one-room play-test, screenshot, quit.
## godot --path godot res://tests/play_probe.tscn -- file room seconds out.png


class Shot extends Node:
	var wait := 6.0
	var out := ""
	var again: Callable
	var _t := 0.0
	var _step := 0
	var burst := false
	var _shots := 0

	func _process(delta: float) -> void:
		_t += delta
		if again.is_valid() and _step == 0 and _t > 5.0:
			_step = 1
			var ev := InputEventAction.new()
			ev.action = "pause"
			ev.pressed = true
			Input.parse_input_event(ev)
			print("PROBE_ESC")
		elif again.is_valid() and _step == 1 and _t > 9.0:
			_step = 2
			print("PROBE_AGAIN scene=", get_tree().current_scene.scene_file_path, " paused=", get_tree().paused)
			again.call()
		if _step == 0 and _t > 4.0 and OS.get_cmdline_user_args().has("layerpop"):
			_step = 3
			var pop = get_tree().current_scene.get("_layer_pop")
			if pop is PopupMenu:
				(pop as PopupMenu).popup(Rect2i(800, 60, 220, 300))
		if OS.get_cmdline_user_args().has("drag") and _step == 0 and _t > wait - 2.0:
			_step = 4
			_drag_test()
		if burst and int(_t) > _shots and _t < wait:
			_shots = int(_t)
			get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%02d.png" % _shots))
		if _t < wait:
			return
		get_viewport().get_texture().get_image().save_png(out)
		print("PROBE_SHOT ", out)
		get_tree().quit()

	func _cam() -> Camera2D:
		var scene := get_tree().current_scene
		return scene.get_node_or_null("Player/Camera2D") as Camera2D if scene else null

	func _drag_test() -> void:
		var cam := _cam()
		var scene := get_tree().current_scene
		print("PROBE_DRAG scene=", scene.scene_file_path if scene else "", " preview=", scene.get_node_or_null("EditorPreview") != null if scene else false, " cam=", cam.global_position if cam else null, " screen=", cam.get_screen_center_position() if cam else null)
		for n in scene.get_children():
			if n.has_method("world_position"):
				print("PROBE_DRAG marker before=", n.get("screen_pos"))
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = Vector2(500, 300)
		Input.warp_mouse(down.position)
		await get_tree().process_frame
		Input.parse_input_event(down)
		for i in 10:
			Input.warp_mouse(Vector2(500 - 30 * (i + 1), 300))
			await get_tree().process_frame
			await get_tree().process_frame
		var up := down.duplicate() as InputEventMouseButton
		up.pressed = false
		Input.parse_input_event(up)
		await get_tree().create_timer(0.5, true, false, true).timeout
		var aim: Node = null
		for n in scene.get_children():
			if n.has_method("world_position"):
				aim = n
		print("PROBE_DRAG after cam=", cam.global_position if cam else null, " screen=", cam.get_screen_center_position() if cam else null, " marker=", aim.get("screen_pos") if aim else null)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var file := args[0] if args.size() > 0 else "rooms_comm"
	var room := args[1] if args.size() > 1 else "room_1_0"
	var shot := Shot.new()
	shot.process_mode = Node.PROCESS_MODE_ALWAYS
	shot.wait = float(args[2]) if args.size() > 2 else 6.0
	shot.out = ProjectSettings.globalize_path("res://../tmp/play_probe.png")
	get_tree().root.add_child.call_deferred(shot)
	var doc: Dictionary = load("res://scripts/map/room_file.gd").load_doc(file)
	if room == "EMPTY":
		var parts := PackedStringArray()
		parts.resize(48)
		parts.fill("_")
		var rows: Array = []
		for _y in 25:
			rows.append(".".join(parts))
		room = "room_0_0"
		doc = {"file": file, "source": "mod", "placed": true, "rooms": [{"name": room, "x": 0, "y": 0, "rows": rows, "objs": []}]}
	if room == "*" and not (doc.get("rooms", []) as Array).is_empty():
		room = str(doc.rooms[0].get("name", ""))
		print("PROBE_ROOM ", room, " placed=", doc.get("placed", false))
	var as_name := args[3] if args.size() > 3 else file
	if as_name != file:
		doc = doc.duplicate(true)
		doc["file"] = as_name
		doc["source"] = "mod"
	if args.size() > 4 and args[4] == "editor":
		load("res://scripts/editor/editor_play.gd")._back = {"file": file, "room": room, "view": {"tex": true}}
		get_tree().change_scene_to_file.call_deferred("res://scenes/room_editor.tscn")
		return
	if args.size() > 4 and args[4].begins_with("preview"):
		var go: Callable = load("res://scripts/editor/editor_preview.gd").start.bind(doc, as_name, room, false)
		if args[4] == "preview2":
			shot.again = go
		go.call_deferred()
		return
	shot.burst = OS.get_cmdline_user_args().has("burst")
	load("res://scripts/editor/editor_play.gd").start(as_name, room, true, doc)
	Travel.enter_game.call_deferred()
