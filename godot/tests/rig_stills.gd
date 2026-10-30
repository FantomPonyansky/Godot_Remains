extends SceneTree

## Room editor stills of rigged units (PropArt): each unit as the game draws it, stay
## frame 0, cropped, to assets/sprites/rig_stills/<id>.png with the Flash origin in
## manifest.json. Not headless. Args after --: units=turret1,ttur (default: every rigged unit).

const OUT := "res://assets/sprites/rig_stills/"
const SIZE := Vector2i(1024, 1024)
const ORIGIN := Vector2(512, 700)


func _initialize() -> void:
	var enemy_script: GDScript = load("res://scripts/enemy.gd")
	var ids: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("units="):
			ids = Array(a.substr(6).split(",", false))
	if ids.is_empty():
		var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/enemies.json"))
		for id in (table.get("units", {}) as Dictionary).keys():
			if enemy_script.rig_path(str(id)) != "":
				ids.append(str(id))
	var holder := Node2D.new()
	get_root().add_child(holder)
	current_scene = holder
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(vp)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var man_path := ProjectSettings.globalize_path(OUT + "manifest.json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(man_path)) if FileAccess.file_exists(man_path) else null
	var manifest: Dictionary = parsed if parsed is Dictionary else {}
	for id: String in ids:
		var node := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Node2D
		node.set_meta("unit_id", id)
		if id == "ttur":
			node.set_meta("tr", 1)
		node.position = ORIGIN
		vp.add_child(node)
		node.set_physics_process(false)
		node.set_process(false)
		await process_frame
		var spr := node.get("anim") as AnimatedSprite2D
		if spr != null and spr.sprite_frames != null and spr.sprite_frames.has_animation("stay"):
			spr.play("stay")
			spr.pause()
			spr.frame = 0
		var brain: Object = node.get("_brain")
		for i in 8:
			# Gun vis and turret parts are placed by animate.
			if brain != null:
				brain.call("animate")
				if spr != null and spr.sprite_frames != null and spr.sprite_frames.has_animation("stay"):
					spr.play("stay")
					spr.pause()
					spr.frame = 0
			await process_frame
		var img := vp.get_texture().get_image()
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			img.get_region(used).save_png(ProjectSettings.globalize_path(OUT + id + ".png"))
			manifest[id] = {"anchor": [ORIGIN.x - used.position.x, ORIGIN.y - used.position.y]}
			print("still ", id, " ", used.size)
		else:
			print("still ", id, " empty")
		node.queue_free()
		await process_frame
	var f := FileAccess.open(man_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, " ", true))
	f.close()
	quit()
