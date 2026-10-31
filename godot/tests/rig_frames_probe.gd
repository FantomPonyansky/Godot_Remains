extends Node2D

## Still frames of one unit as the game draws it, for a
## frame-by-frame match against OTHER (tmp/other_frames.gd uses the same layout).
## Args: unit=bloodwing rows="fly:0,1,2,3,4,5;die:0,4,8,12,16,19" zoom=2
## Saves tmp/shots/frames_<rig|sheet>.png. Layout in 1280x720 base pixels: column i at
## x 110 + 200 i, row r at y 300 + 340 r.

func _ready() -> void:
	var unit := "bloodwing"
	var rows := "fly:0,1,2"
	var zoom := 2.0
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			match kv[0]:
				"unit": unit = kv[1]
				"rows": rows = kv[1]
				"zoom": zoom = float(kv[1])
	var bg := ColorRect.new()
	bg.color = Color(0.32, 0.34, 0.36)
	bg.size = Vector2(8192, 8192)
	bg.position = -bg.size * 0.5
	add_child(bg)
	# Zoom through a camera as in game: filters (blur) are sized in world pixels.
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE * zoom
	add_child(cam)
	cam.make_current()
	var half := Vector2(640, 360)
	var poses: Array = []
	var r := 0
	for spec in rows.split(";", false):
		var parts := spec.split(":")
		var frames := parts[1].split(",", false)
		for i in frames.size():
			var node := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Node2D
			node.set_meta("unit_id", unit)
			var holder := Node2D.new()
			holder.position = (Vector2(110 + 200 * i, 300 + 340 * r) - half) / zoom
			add_child(holder)
			holder.add_child(node)
			node.set_physics_process(false)
			node.set_process(false)
			poses.append([node.get("anim"), parts[0], int(frames[i])])
		r += 1
	await get_tree().process_frame
	for p in poses:
		var spr := p[0] as AnimatedSprite2D
		spr.play(p[1])
		spr.pause()
		spr.frame = p[2]
	for i in 10:
		await get_tree().process_frame
	var tag := "rig"
	var dir := ProjectSettings.globalize_path("res://").path_join("../tmp/shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("frames_%s.png" % tag))
	get_tree().quit()
