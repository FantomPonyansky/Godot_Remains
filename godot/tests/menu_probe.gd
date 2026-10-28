extends Node

## Windowed main menu shot to tmp/shots/menu.png. Args: [seconds] [call=<method>]
## call= runs a main_menu method (e.g. _open_about) halfway through the wait.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var wait := float(args[0]) if args.size() > 0 and args[0].is_valid_float() else 8.0
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(wait * 0.5).timeout
	for a in args:
		if a.begins_with("call="):
			menu.call(a.substr(5))
		elif a == "controls":
			ControlsUI.open()
			await get_tree().process_frame
			await get_tree().process_frame
			for sc in ControlsUI.find_children("*", "ScrollContainer", true, false):
				(sc as ScrollContainer).scroll_vertical = 100000
	await get_tree().create_timer(wait * 0.5).timeout
	var dir := ProjectSettings.globalize_path("res://").path_join("../tmp/shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("menu.png"))
	get_tree().quit()
