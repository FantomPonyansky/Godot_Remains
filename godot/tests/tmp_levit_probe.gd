extends Node

## Self-levitation start: holds jump, forces _levitating, saves the first 8 frames around the player to tmp/shots/levit.png.
## Pass --land=begin after --.


class Runner extends Node:
	func _ready() -> void:
		await get_tree().create_timer(12.0).timeout
		var who := get_tree().get_first_node_in_group("player") as Node2D
		Input.action_press("jump")
		await get_tree().create_timer(0.35).timeout
		who.set("_levitating", true)
		var cells: Array[Image] = []
		for i in 8:
			await RenderingServer.frame_post_draw
			var img := get_tree().root.get_texture().get_image()
			var k := Vector2(img.get_size()) / get_tree().root.get_visible_rect().size
			var at := who.get_global_transform_with_canvas().origin * k
			cells.append(img.get_region(Rect2i(Vector2i(at) - Vector2i(80, 130), Vector2i(160, 160))))
		var out := Image.create(160 * cells.size(), 160, false, cells[0].get_format())
		for i in cells.size():
			out.blit_rect(cells[i], Rect2i(0, 0, 160, 160), Vector2i(160 * i, 0))
		out.save_png(ProjectSettings.globalize_path("res://").path_join("../tmp/shots/levit.png"))
		get_tree().quit()


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")
