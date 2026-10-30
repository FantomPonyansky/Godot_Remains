extends Node2D

## Visual animation test: each unit is shown twice, as the game draws it (left, a frozen
## enemy.tscn: its rig) and OTHER's rig alone (right, RigView
## from assets/rigs), each cycling through every clip it has, holding each `hold` seconds.
## Args: unit=bloat1[,bloat10,...] hold=5 zoom=2 shot=<seconds> (save tmp/shots/anim_probe.png, quit)
## Keys: Right / Left next / previous clip, Space pause, Up / Down zoom.

const RIG_DIR := "res://assets/rigs/scenes/%s.tscn"

var _hold := 5.0
var _zoom := 2.0
var _paused := false
var _views: Array[Dictionary] = []
var _root: Node2D


func _ready() -> void:
	var units := PackedStringArray(["bloat1"])
	var shot := -1.0
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"unit": units = kv[1].split(",", false)
			"hold": _hold = float(kv[1])
			"zoom": _zoom = float(kv[1])
			"shot": shot = float(kv[1])
	var bg := ColorRect.new()
	bg.color = Color(0.32, 0.34, 0.36)
	bg.size = Vector2(4096, 4096)
	bg.show_behind_parent = true
	add_child(bg)
	_root = Node2D.new()
	add_child(_root)
	for row in units.size():
		var unit := units[row]
		_add_view(unit, "ours", _make_ours(unit), row, 0)
		_add_view(unit, "rig", _make_rig(unit), row, 1)
	_layout()
	queue_redraw()
	if shot >= 0.0:
		await get_tree().create_timer(shot).timeout
		var dir := ProjectSettings.globalize_path("res://").path_join("../tmp/shots")
		DirAccess.make_dir_recursive_absolute(dir)
		get_viewport().get_texture().get_image().save_png(dir.path_join("anim_probe.png"))
		get_tree().quit()


func _make_ours(unit: String) -> Dictionary:
	var node := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Node2D
	node.set_meta("unit_id", unit)
	var holder := Node2D.new()
	_root.add_child(holder)
	holder.add_child(node)
	# The body stays put; only its sprite keeps animating.
	node.set_physics_process(false)
	node.set_process(false)
	var spr := node.get("anim") as AnimatedSprite2D
	var names := PackedStringArray()
	if spr and spr.sprite_frames:
		names = spr.sprite_frames.get_animation_names()
		names.sort()
	return {"holder": holder, "names": names,
		"play": func(clip: String) -> void: spr.play(clip)}


func _make_rig(unit: String) -> Dictionary:
	var holder := Node2D.new()
	_root.add_child(holder)
	var path := RIG_DIR % unit
	if not ResourceLoader.exists(path):
		return {"holder": holder, "names": PackedStringArray(), "play": func(_c: String) -> void: pass}
	var rig := (load(path) as PackedScene).instantiate() as RigView
	holder.add_child(rig)
	return {"holder": holder, "names": rig.clips(),
		"play": func(clip: String) -> void: rig.play(clip)}


func _add_view(unit: String, kind: String, v: Dictionary, row: int, col: int) -> void:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	v.merge({"unit": unit, "kind": kind, "row": row, "col": col, "label": label, "i": 0, "t": 0.0})
	_views.append(v)
	_show(v)


func _layout() -> void:
	var rows := 1
	for v in _views:
		rows = maxi(rows, int(v["row"]) + 1)
	var cell := get_viewport_rect().size / Vector2(2, rows)
	for v in _views:
		var origin := Vector2(v["col"] * cell.x, v["row"] * cell.y)
		(v["holder"] as Node2D).position = origin + cell * Vector2(0.5, 0.6)
		(v["holder"] as Node2D).scale = Vector2.ONE * _zoom
		(v["label"] as Label).position = origin + Vector2(8, 6)


## Unit origin (the feet / body anchor) of every view.
func _draw() -> void:
	for v in _views:
		var p := (v["holder"] as Node2D).position
		draw_line(p - Vector2(10, 0), p + Vector2(10, 0), Color(1, 0.3, 0.3), 1.0)
		draw_line(p - Vector2(0, 10), p + Vector2(0, 10), Color(1, 0.3, 0.3), 1.0)


func _show(v: Dictionary) -> void:
	var names: PackedStringArray = v["names"]
	var head := "%s  [%s]" % [v["unit"], v["kind"]]
	if names.is_empty():
		(v["label"] as Label).text = head + "\n(no clips)"
		return
	var clip := names[v["i"]]
	(v["play"] as Callable).call(clip)
	(v["label"] as Label).text = "%s\n%d/%d  %s" % [head, v["i"] + 1, names.size(), clip]


func _step(dir: int) -> void:
	for v in _views:
		var n: int = (v["names"] as PackedStringArray).size()
		if n > 0:
			v["i"] = posmod(v["i"] + dir, n)
			v["t"] = 0.0
			_show(v)


func _process(delta: float) -> void:
	if _paused:
		return
	for v in _views:
		var n: int = (v["names"] as PackedStringArray).size()
		v["t"] += delta
		if n > 1 and v["t"] >= _hold:
			v["t"] = 0.0
			v["i"] = (v["i"] + 1) % n
			_show(v)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_RIGHT: _step(1)
		KEY_LEFT: _step(-1)
		KEY_SPACE: _paused = not _paused
		KEY_UP:
			_zoom += 1.0
			_layout()
		KEY_DOWN:
			_zoom = maxf(1.0, _zoom - 1.0)
			_layout()
