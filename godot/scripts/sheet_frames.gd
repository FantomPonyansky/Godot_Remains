class_name SheetFrames
extends RefCounted

## Build SpriteFrames from a grid atlas. `clips` maps anim name -> Array of
## [col, row] cells (or a flat list of Vector2i).


static func build(
	texture: Texture2D,
	frame_w: int,
	frame_h: int,
	clips: Dictionary,
	speeds: Dictionary = {},
	loops: Dictionary = {}
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	# Remove default empty animation Godot may expect us to replace.
	if frames.has_animation("default"):
		frames.remove_animation("default")

	for anim_name in clips.keys():
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(speeds.get(anim_name, 10.0)))
		frames.set_animation_loop(anim_name, bool(loops.get(anim_name, true)))
		for cell in clips[anim_name]:
			var col: int
			var row: int
			if cell is Vector2i:
				col = cell.x
				row = cell.y
			else:
				col = int(cell[0])
				row = int(cell[1])
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
			atlas.filter_clip = true
			frames.add_frame(anim_name, atlas)
	return frames


static func row_clip(row: int, count: int, start_col: int = 0) -> Array:
	var out: Array = []
	for i in count:
		out.append(Vector2i(start_col + i, row))
	return out


static func raider_frames(texture: Texture2D) -> SpriteFrames:
	return build(
		texture,
		120,
		120,
		{
			"idle": [Vector2i(0, 0)],
			"crouch": [Vector2i(1, 0)],
			"walk": row_clip(1, 17),
			"run": row_clip(2, 8),
			"jump": [Vector2i(1, 0)],
			"fall": [Vector2i(0, 0)],
			"climb": row_clip(1, 8),
			"levitate": [Vector2i(0, 0)],
		},
		{"idle": 4.0, "walk": 11.0, "run": 13.0, "climb": 10.0},
		{"jump": false, "fall": false, "crouch": false}
	)
