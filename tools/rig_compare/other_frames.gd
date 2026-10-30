extends SceneTree

## Run in OTHER's project: its rig_base draws the rig_frames_probe layout (1280x720 base,
## unscaled window). Args after --: unit=bloodwing rows="fly:0,1,2" zoom=2 (clip x -> x or body_x)
## Saves D:/Games/FoE Remains Port/tmp/shots/frames_other.png.

func _initialize() -> void:
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
	bg.size = Vector2(4096, 4096)
	root.add_child(bg)
	var poses: Array = []
	var r := 0
	for spec in rows.split(";", false):
		var parts := spec.split(":")
		var frames := parts[1].split(",", false)
		for i in frames.size():
			var holder := Node2D.new()
			holder.position = Vector2(110 + 200 * i, 300 + 340 * r)
			holder.scale = Vector2.ONE * zoom
			root.add_child(holder)
			var rig: Node = load("res://scenes/rigs/%s.tscn" % unit).instantiate()
			holder.add_child(rig)
			poses.append([rig, parts[0], int(frames[i])])
		r += 1
	await process_frame
	for p in poses:
		var rig: Node = p[0]
		var ap := rig.get("_anim_player") as AnimationPlayer
		var clip: String = p[1] if ap.has_animation(p[1]) else "body_" + p[1]
		if not ap.has_animation(clip):
			var states: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/rigs/%s/state_machine.json" % unit))
			for st in (states if states is Array else []):
				if str(st.get("label", "")) == p[1]:
					clip = str(st.get("animation", ""))
			if not ap.has_animation(clip):
				clip = str(rig.get_meta("idle_animation", ""))
		rig.call("play_from_frame", clip, p[2])
		ap.pause()
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png("D:/Games/FoE Remains Port/tmp/shots/frames_other.png")
	quit()
