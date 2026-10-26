extends RefCounted

## Breadcrumbs for the exit to the main menu (tester crash). Armed by every
## path that changes to main_menu.tscn; logs each step, every node leaving the
## tree, when the old scene is gone, and the first frames of the menu. Lines go
## through print, so the exe-local log (user_dir.gd) flushes each one.

const MENU_FRAMES := 20

static var _armed := false
static var _frames := 0
static var _removed := 0
static var _t0 := 0


static func step(what: String) -> void:
	print("[exit %dms] %s" % [Time.get_ticks_msec() - _t0, what])


static func arm(tree: SceneTree, source: String) -> void:
	if _armed:
		step("arm again from %s" % source)
		return
	_armed = true
	_frames = 0
	_removed = 0
	_t0 = Time.get_ticks_msec()
	var scene := tree.current_scene
	step("armed by %s, scene=%s nodes=%d static_mem=%d" % [source, scene.name if scene else "-", tree.get_node_count(), OS.get_static_memory_usage()])
	tree.node_removed.connect(_on_removed)
	tree.scene_changed.connect(_on_scene_changed.bind(tree))
	if scene != null:
		scene.tree_exiting.connect(func() -> void: step("old scene tree_exiting"))
		scene.tree_exited.connect(func() -> void: step("old scene tree_exited (%d nodes removed)" % _removed))


static func _on_removed(node: Node) -> void:
	_removed += 1
	var script: Script = node.get_script()
	var path := str(node.get_path()) if node.is_inside_tree() else str(node.name)
	if script != null:
		step("rm %s %s (%s)" % [node.get_class(), path, script.resource_path.get_file()])
	else:
		step("rm %s %s" % [node.get_class(), path])


static func _on_scene_changed(tree: SceneTree) -> void:
	var scene := tree.current_scene
	step("scene_changed -> %s, nodes=%d" % [scene.name if scene else "-", tree.get_node_count()])
	if tree.node_removed.is_connected(_on_removed):
		tree.node_removed.disconnect(_on_removed)
	tree.process_frame.connect(_on_frame.bind(tree))


static func _on_frame(tree: SceneTree) -> void:
	_frames += 1
	step("menu frame %d" % _frames)
	if _frames >= MENU_FRAMES:
		tree.process_frame.disconnect(_on_frame)
		if tree.scene_changed.is_connected(_on_scene_changed):
			tree.scene_changed.disconnect(_on_scene_changed)
		step("trace done")
		_armed = false
