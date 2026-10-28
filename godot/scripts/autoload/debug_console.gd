extends CanvasLayer

## Tilde toggles the console and freezes gameplay input while it is open.
## Esc stays the pause key, so it does not close the console.

const _Commands := preload("res://scripts/debug_commands.gd")
## Lines from --cmd that travel. The rest of the queue waits for the next land.
const _TRAVEL: PackedStringArray = ["land", "quiet", "trial", "boss", "surfend", "arena"]
const _QUEUE_SETTLE := 1.0
const _QUEUE_TIMEOUT := 20.0

var selected: Node

var _commands
var _open := false
var _restore_paused := false
var _held_player: Node
var _restore_physics := false
var _touched_player := false
var _panel: PanelContainer
var _picked: Label
var _log_label: RichTextLabel
var _line: LineEdit
var _history: PackedStringArray = []
var _ring: Line2D
var _boot := ""
var _land := ""
var _room := ""
var _queue: PackedStringArray = []
var _queue_wait := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30


func _ready() -> void:
	_commands = _Commands.new()
	_build_ui()
	_log("~ opens and closes this console.")
	_refresh_picked()
	_read_launch_args()


## --boot=new|cont|slot=N skips the main menu once. --cmd="a; b" runs those
## console lines after the first land loads (verify/ kit).
func _read_launch_args() -> void:
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--boot="):
			_boot = arg.trim_prefix("--boot=")
		elif arg.begins_with("--land="):
			_land = arg.trim_prefix("--land=")
		elif arg.begins_with("--room="):
			_room = arg.trim_prefix("--room=")
		elif arg.begins_with("--cmd="):
			for part in arg.trim_prefix("--cmd=").split(";", false):
				if part.strip_edges() != "":
					_queue.append(part.strip_edges())
	if not _queue.is_empty():
		# Travel is a later autoload.
		(func() -> void: Travel.land_entered.connect(_on_queue_land.unbind(1))).call_deferred()


## The main menu asks once; an empty answer means show the menu.
func take_boot() -> String:
	var boot := _boot
	_boot = ""
	return boot


## --land=<id>[:room_x:room_y]: game.tscn opens on that land, once.
func take_land() -> String:
	var land := _land
	_land = ""
	return land


## --room=<rooms file>:<room name>: that room alone as its own test land, once.
func take_room() -> String:
	var room := _room
	_room = ""
	return room


func _on_queue_land() -> void:
	print("cmd> in land %s" % Travel.cur_land_id)
	_queue_wait += 1
	var token := _queue_wait
	await get_tree().create_timer(_QUEUE_SETTLE, true).timeout
	if token == _queue_wait:
		_run_queue()


func _run_queue() -> void:
	while not _queue.is_empty():
		var line := _queue[0]
		_queue.remove_at(0)
		var result := str(_commands.run(self, line))
		_log("> " + line)
		if result != "":
			_log(result)
		print("cmd> %s | %s" % [line, result.replace("\n", " / ")])
		var words: PackedStringArray = _commands.tokenize(line)
		if not words.is_empty() and _TRAVEL.has(words[0].to_lower()):
			_queue_wait += 1
			var token := _queue_wait
			await get_tree().create_timer(_QUEUE_TIMEOUT, true).timeout
			if token == _queue_wait and not _queue.is_empty():
				print("cmd> no land after '%s', running the rest here" % line)
				_run_queue()
			return


func _input(event: InputEvent) -> void:
	if _is_tilde(event):
		if _open:
			_close_console()
		else:
			_open_console()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	if _is_escape(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
			return
		if _over_panel(button.position):
			return
		_click_select(_screen_to_world(button.position))
		get_viewport().set_input_as_handled()


func live_selection() -> Node:
	if selected != null and not is_instance_valid(selected):
		selected = null
		_ring = null
		_refresh_picked()
	return selected


func clear_selection() -> void:
	if selected != null and is_instance_valid(selected) and selected.tree_exiting.is_connected(_on_selected_gone):
		selected.tree_exiting.disconnect(_on_selected_gone)
	if _ring != null and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null
	selected = null
	_refresh_picked()


func describe(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return "nothing selected"
	return "%s    %s" % [object_title(node), str(node.get_path())]


func object_title(node: Node) -> String:
	var title := str(node.name)
	var id := object_id(node)
	var kind := object_kind(node)
	if id != "" and id != title:
		title = "%s (%s)" % [title, id]
	if kind != "":
		title = "%s [%s]" % [title, kind]
	return title


func object_id(node: Node) -> String:
	if node.is_in_group("pickups") and "item_id" in node and str(node.get("item_id")) != "":
		return str(node.get("item_id"))
	for key in ["unit_id", "door_id", "id"]:
		if node.has_meta(key) and str(node.get_meta(key)) != "":
			return str(node.get_meta(key))
	return ""


func object_kind(node: Node) -> String:
	if node.is_in_group("player"):
		return "player"
	if node.is_in_group("enemies") or node.is_in_group("allies"):
		return "enemy"
	if node.is_in_group("player_bullets") or node.is_in_group("enemy_bullets"):
		return "projectile"
	if node.is_in_group("pickups"):
		return "pickup"
	var id := object_id(node)
	if id.begins_with("term") or id == "alarm" or id == "robocell" or id == "elpanel":
		return "terminal"
	if node.has_meta("door_id") or node.has_meta("door_open"):
		return "door"
	if node.has_meta("cont") or node.has_meta("items"):
		return "container"
	return ""


func _open_console() -> void:
	if _open:
		return
	_open = true
	_panel.visible = true
	# Freeze the tree so held keys do not move, shoot, or use objects while typing.
	# The player's own check looks at Input, which stays live if only the GUI has focus.
	_restore_paused = get_tree().paused
	get_tree().paused = true
	_hold_player()
	_line.call_deferred("grab_focus")


func _close_console() -> void:
	if not _open:
		return
	_open = false
	_panel.visible = false
	_release_player()
	get_tree().paused = _restore_paused
	_line.release_focus()
	get_viewport().gui_release_focus()
	if _restore_paused:
		var menu := get_tree().root.find_child("PauseMenu", true, false)
		if menu != null and menu.has_method("focus_menu"):
			menu.call_deferred("focus_menu")


func _hold_player() -> void:
	_touched_player = false
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_held_player = player
	_restore_physics = player.is_physics_processing()
	_touched_player = true
	player.set_physics_process(false)


func _release_player() -> void:
	if not _touched_player:
		return
	_touched_player = false
	if _held_player != null and is_instance_valid(_held_player):
		_held_player.set_physics_process(_restore_physics)
	_held_player = null


func _on_submit(text: String) -> void:
	var line := text.strip_edges()
	_line.text = ""
	_line.call_deferred("grab_focus")
	if line == "":
		return
	_log("> " + line)
	var result := str(_commands.run(self, line))
	if result != "":
		_log(result)


func _click_select(world: Vector2) -> void:
	var hit := _top_at(world)
	if hit == null:
		return
	if hit == live_selection():
		clear_selection()
		_log("cleared")
		return
	_choose(hit)
	_log("selected %s" % describe(hit))


func _choose(node: Node) -> void:
	clear_selection()
	selected = node
	if not node.tree_exiting.is_connected(_on_selected_gone):
		node.tree_exiting.connect(_on_selected_gone)
	_add_ring(node)
	_refresh_picked()


func _on_selected_gone() -> void:
	selected = null
	_ring = null
	_refresh_picked()


func _top_at(world: Vector2) -> Node:
	var hits: Array = []
	var seen := {}
	_physics_hits(world, hits, seen)
	var scene := get_tree().current_scene
	if scene != null:
		_walk(scene, world, hits, seen)
	if hits.is_empty():
		return null
	var best: Node = hits[0]
	for i in range(1, hits.size()):
		var other: Node = hits[i]
		if _is_above(other, best):
			best = other
	return best


func _physics_hits(world: Vector2, hits: Array, seen: Dictionary) -> void:
	var viewport := get_viewport()
	if viewport == null or viewport.world_2d == null:
		return
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0x7fffffff
	var found: Array = viewport.world_2d.direct_space_state.intersect_point(query, 64)
	for row in found:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var collider: Variant = (row as Dictionary).get("collider")
		if not collider is Node:
			continue
		var pick := _selectable_from(collider as Node)
		if pick != null and _remember(pick, seen):
			hits.append(pick)


func _walk(node: Node, world: Vector2, hits: Array, seen: Dictionary) -> void:
	if node is Node2D and object_kind(node) != "":
		if _remember(node, seen) and _contains(node as Node2D, world):
			hits.append(node)
	for child in node.get_children():
		_walk(child, world, hits, seen)


func _remember(node: Node, seen: Dictionary) -> bool:
	var id := node.get_instance_id()
	if seen.has(id):
		return false
	seen[id] = true
	return true


func _selectable_from(node: Node) -> Node:
	var cur := node
	while cur != null:
		if object_kind(cur) != "":
			return cur
		cur = cur.get_parent()
	return null


func _contains(body: Node2D, world: Vector2) -> bool:
	var shapes := 0
	for child in body.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			shapes += 1
			if _shape_has(child as CollisionShape2D, world):
				return true
	if shapes > 0:
		return false
	return _meta_rect(body, world)


func _shape_has(shape_node: CollisionShape2D, world: Vector2) -> bool:
	var shape := shape_node.shape
	var point := shape_node.to_local(world)
	if shape is RectangleShape2D:
		var size := (shape as RectangleShape2D).size
		return Rect2(-size * 0.5, size).has_point(point)
	if shape is CircleShape2D:
		return point.length() <= (shape as CircleShape2D).radius
	if shape is CapsuleShape2D:
		var cap := shape as CapsuleShape2D
		return absf(point.x) <= cap.radius and absf(point.y) <= cap.height * 0.5 + cap.radius
	return false


func _meta_rect(body: Node2D, world: Vector2) -> bool:
	var local := body.to_local(world)
	if body.has_meta("door_w"):
		var size := Vector2(float(body.get_meta("door_w")), float(body.get_meta("door_h", 40.0)))
		return Rect2(Vector2.ZERO, size).has_point(local)
	if body.has_meta("size") and body.get_meta("size") is Vector2:
		return Rect2(Vector2.ZERO, body.get_meta("size")).has_point(local)
	return false


func _is_above(a: Node, b: Node) -> bool:
	var za := _effective_z(a)
	var zb := _effective_z(b)
	if za != zb:
		return za > zb
	var ac := _root_chain(a)
	var bc := _root_chain(b)
	var count := mini(ac.size(), bc.size())
	for i in count:
		if ac[i] == bc[i]:
			continue
		return ac[i].get_index() > bc[i].get_index()
	return ac.size() > bc.size()


func _effective_z(node: Node) -> int:
	var total := 0
	var cur := node
	while cur is CanvasItem:
		var item := cur as CanvasItem
		total += item.z_index
		if not item.z_as_relative:
			break
		cur = cur.get_parent()
	return total


func _root_chain(node: Node) -> Array:
	var chain: Array = []
	var cur := node
	while cur != null:
		chain.append(cur)
		cur = cur.get_parent()
	chain.reverse()
	return chain


func _add_ring(node: Node) -> void:
	if not node is Node2D:
		return
	var body := node as Node2D
	var rect := _bounds(body)
	var line := Line2D.new()
	line.name = "DebugSelectRing"
	# Wider than a melee swing line, so weapon-wear does not treat the outline as a hit.
	line.width = 3.0
	line.default_color = Color(1.0, 0.86, 0.25, 0.95)
	line.z_index = 50
	var origin := rect.position
	var size := rect.size
	line.points = PackedVector2Array([
		origin,
		origin + Vector2(size.x, 0.0),
		origin + size,
		origin + Vector2(0.0, size.y),
		origin,
	])
	body.add_child(line)
	_ring = line


func _bounds(body: Node2D) -> Rect2:
	var merged := Rect2()
	var any := false
	for child in body.get_children():
		if not child is CollisionShape2D:
			continue
		var shape_node := child as CollisionShape2D
		var shape := shape_node.shape
		var local := Rect2()
		var ok := false
		if shape is RectangleShape2D:
			var size := (shape as RectangleShape2D).size
			local = Rect2(-size * 0.5, size)
			ok = true
		elif shape is CircleShape2D:
			var radius := (shape as CircleShape2D).radius
			local = Rect2(-radius, -radius, radius * 2.0, radius * 2.0)
			ok = true
		if not ok:
			continue
		var piece := Rect2(shape_node.position + local.position, local.size)
		merged = piece if not any else merged.merge(piece)
		any = true
	if any:
		return merged
	if body.has_meta("size") and body.get_meta("size") is Vector2:
		return Rect2(Vector2.ZERO, body.get_meta("size"))
	if body.has_meta("door_w"):
		return Rect2(Vector2.ZERO, Vector2(float(body.get_meta("door_w")), float(body.get_meta("door_h", 40.0))))
	return Rect2(-16, -16, 32, 32)


func _refresh_picked() -> void:
	if _picked == null:
		return
	var node := selected if selected != null and is_instance_valid(selected) else null
	if node == null:
		_picked.text = "selected: none"
	else:
		_picked.text = "selected: %s" % object_title(node)


func _log(text: String) -> void:
	for part in text.split("\n"):
		_history.append(part)
	while _history.size() > 400:
		_history.remove_at(0)
	if _log_label == null:
		return
	_log_label.text = "\n".join(_history)
	_log_label.scroll_to_line(_history.size())


func _over_panel(screen: Vector2) -> bool:
	return _panel != null and _panel.visible and _panel.get_global_rect().has_point(screen)


func _screen_to_world(screen: Vector2) -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		return cam.get_canvas_transform().affine_inverse() * screen
	return get_viewport().get_canvas_transform().affine_inverse() * screen


func _is_tilde(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return false
	# quoteleft is the `~ key on a US keyboard and ё on the same physical key.
	if key.physical_keycode == KEY_QUOTELEFT or key.keycode == KEY_QUOTELEFT:
		return true
	if key.physical_keycode == 0 and key.unicode in [96, 126, 1025, 1105]:
		return true
	return false


func _is_escape(event: InputEvent) -> bool:
	if event.is_action("pause") or event.is_action("ui_cancel"):
		return true
	if event is InputEventKey and (event as InputEventKey).pressed:
		var key := event as InputEventKey
		return key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE
	return false


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 8.0
	_panel.offset_right = -8.0
	_panel.offset_top = -228.0
	_panel.offset_bottom = -8.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.03, 0.94)
	style.border_color = Color(0.35, 0.62, 0.34, 1.0)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)

	_picked = Label.new()
	_picked.text = "selected: none"
	_picked.add_theme_font_size_override("font_size", 16)
	_picked.add_theme_color_override("font_color", Color(1.0, 0.86, 0.4))
	box.add_child(_picked)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = false
	_log_label.scroll_active = true
	_log_label.scroll_following = true
	_log_label.selection_enabled = true
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_label.add_theme_font_size_override("normal_font_size", 16)
	_log_label.add_theme_color_override("default_color", Color(0.76, 0.93, 0.72))
	box.add_child(_log_label)

	_line = LineEdit.new()
	_line.placeholder_text = "help"
	_line.clear_button_enabled = false
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line.add_theme_font_size_override("font_size", 16)
	_line.add_theme_color_override("font_color", Color(0.9, 1.0, 0.88))
	_line.text_submitted.connect(_on_submit)
	box.add_child(_line)
