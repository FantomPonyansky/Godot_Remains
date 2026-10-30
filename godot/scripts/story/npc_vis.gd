extends RefCounted

## NPC sheets exported from pfe.swf (visual<Vis>, visualCaptive layers,
## visNPCIco) by extracted_swf/export_story_art.py: manifest.json uses the
## unit-sheet format (sheet, cell, anchor, cols, clips {frames, loop}).

const DIR := "res://assets/sprites/npcs/"
const FPS := 30.0
const RIGS := "res://assets/rigs/scenes/"
## Rigs whose converted saddlebag sits behind and below the body (OTHER's too): sheets.
const SHEET_ONLY := ["vendor", "doctor", "vendorarmor", "vendorexpl", "vendorweapon"]

static var _manifest: Dictionary = {}
static var _loaded := false
static var _frames: Dictionary = {}


static func drop_cache() -> void:
	_frames.clear()


static func entry(key: String) -> Dictionary:
	if not _loaded:
		_loaded = true
		var path := DIR + "manifest.json"
		if FileAccess.file_exists(path):
			var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if v is Dictionary:
				_manifest = v
	return _manifest.get(key, {})


static func has(key: String) -> bool:
	return not entry(key).is_empty()


## One AnimatedSprite2D whose origin is the symbol origin (the unit's feet). With an OTHER
## rig its frames are blank (the sheet's clips and frame counts) and the rig follows it.
static func sprite(key: String) -> AnimatedSprite2D:
	var e := entry(key)
	if e.is_empty():
		return null
	var rig_path := RIGS + key + ".tscn"
	if not key in SHEET_ONLY and ResourceLoader.exists(rig_path):
		var ghost := AnimatedSprite2D.new()
		ghost.sprite_frames = _ghost(key, e)
		var rig := (load(rig_path) as PackedScene).instantiate()
		ghost.add_child(rig)
		rig.call("follow", ghost, {}, {})
		return ghost
	var frames: SpriteFrames = _frames.get(key)
	if frames == null:
		var tex := ResourceLoader.load(DIR + str(e.sheet)) as Texture2D
		if tex == null:
			return null
		frames = _build(tex, e)
		_frames[key] = frames
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.centered = false
	var anchor: Array = e.get("anchor", [0, 0])
	spr.offset = -Vector2(float(anchor[0]), float(anchor[1]))
	return spr


static func _ghost(key: String, e: Dictionary) -> SpriteFrames:
	var cache_key := "rig:" + key
	if _frames.has(cache_key):
		return _frames[cache_key]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for clip in (e.get("clips", {}) as Dictionary):
		var data: Dictionary = e.clips[clip]
		frames.add_animation(clip)
		frames.set_animation_speed(clip, FPS)
		frames.set_animation_loop(clip, bool(data.get("loop", false)))
		for _i in (data.get("frames", []) as Array).size():
			frames.add_frame(clip, null)
	_frames[cache_key] = frames
	return frames


static func _build(tex: Texture2D, e: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var cw := int(e.cell[0])
	var ch := int(e.cell[1])
	var cols := maxi(1, int(e.get("cols", 1)))
	var cache := {}
	for clip in (e.get("clips", {}) as Dictionary):
		var data: Dictionary = e.clips[clip]
		frames.add_animation(clip)
		frames.set_animation_speed(clip, FPS)
		frames.set_animation_loop(clip, bool(data.get("loop", false)))
		for idx_v in data.get("frames", []):
			var idx := int(idx_v)
			var at: AtlasTexture = cache.get(idx)
			if at == null:
				at = AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2((idx % cols) * cw, (idx / cols) * ch, cw, ch)
				cache[idx] = at
			frames.add_frame(clip, at)
	return frames


## Frame n (0-based) of a single-clip sheet as a still.
static func still(key: String, clip: String, n: int) -> AnimatedSprite2D:
	var spr := sprite(key)
	if spr == null:
		return null
	if spr.sprite_frames.has_animation(clip):
		spr.animation = clip
		spr.frame = clampi(n, 0, spr.sprite_frames.get_frame_count(clip) - 1)
	spr.pause()
	return spr
