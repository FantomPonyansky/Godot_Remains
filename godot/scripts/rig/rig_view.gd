class_name RigView
extends Node2D
## A Flash unit rig converted by OTHER's tools (tools/import_rig.py): bone nodes under
## `osn/body` holding part sprites, and an AnimationLibrary of per-bone transform and
## visibility tracks. Part textures are bound at load from the art and symbol data.
## Covers bone parts and bitmap frames; nested graphic symbols are not handled yet.
##
## In game a rig `follow`s a unit's AnimatedSprite2D, which keeps the clip names and frame
## counts of the old sheet but no pixels: the rig shows the sprite's clip at its frame and
## facing, and inherits its transform, modulate and visibility as a child.

const FPS := 30.0
const BLUR := preload("res://assets/shaders/rig_blur.gdshader")
const GLOW := preload("res://assets/shaders/rig_glow.gdshader")
const MASKED := preload("res://assets/rigs/shaders/color_transform_masked.gdshader")

var anim_player: AnimationPlayer
## art_fx library filters: {sprite, base, fx, source, frames}; only BlurFilter is drawn.
var _filters: Array[Dictionary] = []
var _follow: AnimatedSprite2D
var _clip_map := {}
var _osn := {}
## Nested symbol instances under the bones: {node, bone, vis_lib, ranges}. Shown while
## their bone shows `vis_lib` at a frame in `ranges` (pairs, 0-based).
var _nested: Array[Dictionary] = []
## Bone -> frame of its library's own timeline now shown (movie clip libraries only).
var _bone_frame := {}
var _lib_frames := {}
var _lib_stops := {}
## Clips OTHER split at a frame: base clip -> [[start frame, segment clip], ...] ascending.
var _segments := {}
## Unit code control (Flash `gotoAndStop` / `gotoAndPlay` / `rotation` on a part): node ->
## held frame, node -> [start frame, clock at start], node -> rotation kept over seeks.
var _held := {}
var _played := {}
var _rot_override := {}
var _clock := 0.0
var _attachments: Array[Node] = []
var _clip_anim := ""
var _clip_started := 0.0
## art_fx blend mirrors: {src, dst, chain}; one viewport copy before them while one shows.
var _mirrors: Array[Dictionary] = []
var _blend_copy: BackBufferCopy
var _shown := ""

var _art_dir := ""
var _png_meta := {}
var _index := {}
var _symbols := {}
var _bones := {}
var _bone_lib := {}
var _body: Node2D
var _bone_order := ""
var _data_dir := ""
## Per clip: method keys [time, method, args] sorted by time (seek does not fire them).
var _method_keys := {}
## osn frame label -> rig clip (`state_machine.json`, e.g. msp `walk` -> `msp3`).
var _states := {}
## Flash masks drawn by `color_transform_masked`: per clipped sprite {sprite, mat, shown}.
## Symbol masks (`is_masked` under a `mask_clip`) add {clip, owner, part}: the aperture of the
## owner's frame. Timeline masks (index `timeline_masks`): {source, keyframes, sprites}.
var _masks: Array[Dictionary] = []
var _tl_masks: Array[Dictionary] = []
var _mask_keys := {}
var _open_mask: ImageTexture
var _now_clip := ""
var _now_frame := 0


func _ready() -> void:
	_art_dir = str(get_meta("art_dir", ""))
	_data_dir = str(get_meta("data_dir", ""))
	_png_meta = _json(_art_dir + "png_metadata.json")
	_index = _json(_data_dir + "index.json")
	var sm_path := _data_dir + "state_machine.json"
	var sm: Variant = JSON.parse_string(FileAccess.get_file_as_string(sm_path)) if FileAccess.file_exists(sm_path) else null
	for st in (sm if sm is Array else []):
		_states[str(st.get("label", ""))] = str(st.get("animation", ""))
	var osn := get_node_or_null("osn")
	_body = osn.get_node_or_null("body") if osn else null
	for bone: Dictionary in _json(_data_dir + "hierarchy.json").get("bones", []):
		# Library folders ("Bd/T01_Bd_01") are not in the symbol file names.
		_bone_lib[str(bone.get("node_name", ""))] = str(bone.get("library_item", "")).get_file()
	if _body:
		for bone: Node in _body.get_children():
			_bones[bone.name] = bone
			_bind_bone(bone, str(_bone_lib.get(str(bone.name), "")))
			_collect_nested(bone, bone)
	for child in get_children():
		if child.has_meta("attachment"):
			_bind_bone(child, str(child.get_meta("library", "")))
			_collect_nested(child, child)
			_attachments.append(child)
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	anim_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	var lib: AnimationLibrary = load(str(get_meta("anim_library", ""))) as AnimationLibrary
	anim_player.add_animation_library("", lib if lib else AnimationLibrary.new())
	(osn if osn else self).add_child(anim_player)
	var seg_re := RegEx.create_from_string("^(.+)_f(\\d+)$")
	for a_name in anim_player.get_animation_list():
		var m := seg_re.search(a_name)
		if m and anim_player.has_animation(m.get_string(1)):
			(_segments.get_or_add(m.get_string(1), []) as Array).append([int(m.get_string(2)), a_name])
	for base in _segments:
		(_segments[base] as Array).sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	# Parts are rasterised above display size: linear taps averaged over the pixel footprint.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for spr in find_children("*", "Sprite2D", true, false):
		var mat := (spr as Sprite2D).material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("footprint", 1.0)
	_setup_masks()
	_read_art_fx()
	var idle := idle_clip()
	if idle != "":
		play(idle)


## A root child the unit code drives (Flash `vis.<name>`, e.g. the drone's `dis` discharge).
func attachment(attach_name: String) -> Node2D:
	for child in get_children():
		if str(child.get_meta("attachment", "")) == attach_name:
			return child as Node2D
	return null


## A body part by its path under `osn/body` (Flash `vis.osn.<path>`, e.g. "puha").
func part(path: String) -> Node2D:
	return _body.get_node_or_null(path) as Node2D if _body else null


## `gotoAndStop(frame + 1)` on the part's own timeline.
func hold(path: String, frame: int) -> void:
	var node := part(path)
	if node:
		_played.erase(node)
		_held[node] = frame


## `gotoAndPlay(frame + 1)` on every nested clip directly under the part (Flash
## `vis.osn.puha.puha`: the one shown is the instance the code reaches); it plays to a
## `stop()` frame.
func play_children(path: String, frame: int) -> void:
	var node := part(path)
	if node == null:
		return
	for child in node.get_children():
		if child.has_meta("library") and not child is Sprite2D:
			_held.erase(child)
			_played[child] = [frame, _clock]


## The part's rotation set by the unit code; timeline seeks keep it.
func set_part_rotation(path: String, radians: float) -> void:
	var node := part(path)
	if node:
		_rot_override[node] = radians
		node.rotation = radians


func clips() -> PackedStringArray:
	return anim_player.get_animation_list() if anim_player else PackedStringArray()


func idle_clip() -> String:
	var idle := str(get_meta("idle_animation", ""))
	return idle if anim_player.has_animation(idle) else ""


func play(clip: String) -> void:
	_apply_bone_order(clip)
	anim_player.play(clip)


## Drive this rig from `spr` (its parent): `clip_map` maps sprite clips to rig clips; a clip
## with no entry and no rig clip of that name shows the idle clip.
## `osn` (sprite clip -> 1-based osn frame, the sheet manifest's "osn"): a clip with no rig
## clip of its name holds that frame of the idle timeline, and the sprite frame is the clock
## of the nested movie clips under it, as the sheet export rendered it.
func follow(spr: AnimatedSprite2D, clip_map: Dictionary = {}, osn: Dictionary = {}) -> void:
	_follow = spr
	_clip_map = clip_map
	_osn = osn
	if anim_player == null:
		ready.connect(follow.bind(spr, clip_map, osn), CONNECT_ONE_SHOT)
		return
	anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_sync()


func _process(delta: float) -> void:
	_clock += delta * FPS
	if _follow:
		if _follow.animation != _clip_anim:
			_clip_anim = _follow.animation
			_clip_started = _clock
		_sync()
		# A one-frame sprite clip has no clock: its nested clips run on time.
		var still := _follow.sprite_frames == null \
				or _follow.sprite_frames.get_frame_count(_follow.animation) <= 1
		_update_nested(int(_clock - _clip_started) if still else _follow.frame)
	elif not _filters.is_empty() and anim_player.is_playing():
		_apply_filters(anim_player.current_animation, roundi(anim_player.current_animation_position * FPS))
	if not _mirrors.is_empty():
		_update_mirrors()
	if not _masks.is_empty() or not _tl_masks.is_empty():
		_update_masks()


func _sync() -> void:
	var clip := str(_clip_map.get(_follow.animation, _follow.animation))
	if not anim_player.has_animation(clip):
		clip = str(_states.get(clip, "body_" + clip))
	var frame := _follow.frame
	if not anim_player.has_animation(clip):
		clip = idle_clip()
		if _osn.has(_follow.animation):
			# Split timelines play the osn range; a whole one holds osn under nested clips.
			frame = int(_osn[_follow.animation]) - 1 + (_follow.frame if _segments.has(clip) else 0)
	if clip == "":
		return
	var first := anim_player.get_animation(clip)
	if first != null and first.has_meta("next"):
		# Flash frame-script chain (trot -> trot_trot): a playing sprite runs it on time
		# since the clip began, so the sheet's shorter loop does not restart it.
		if _follow.is_playing():
			frame = int(_clock - _clip_started)
		for _i in 4:
			var cur_a := anim_player.get_animation(clip)
			var info: Dictionary = cur_a.get_meta("next", {})
			var nxt := str(info.get("animation", ""))
			var n := maxi(1, roundi(cur_a.length * FPS))
			if frame < n or nxt == "" or not anim_player.has_animation(nxt):
				break
			frame = 0 if str(info.get("mode", "play")) == "hold" else frame - n
			clip = nxt
	var seg_start := 0
	for seg: Array in _segments.get(clip, []):
		if seg[0] <= frame:
			seg_start = seg[0]
	if seg_start > 0:
		clip = "%s_f%d" % [clip, seg_start]
		frame -= seg_start
	scale.x = -absf(scale.x) if _follow.flip_h else absf(scale.x)
	_now_clip = clip
	_now_frame = frame
	var key := "%s:%d:%d" % [clip, frame, _follow.frame]
	if key == _shown:
		return
	_shown = key
	if anim_player.current_animation != clip:
		play(clip)
	var a := anim_player.get_animation(clip)
	var t := float(frame) / FPS
	t = fmod(t, a.length) if a.loop_mode != Animation.LOOP_NONE else minf(t, a.length)
	anim_player.seek(t, true)
	var libs: Dictionary = a.get_meta("initial_libs", {})
	for bone_name in libs:
		_swap_bone_lib(str(bone_name), str(libs[bone_name]))
	for k in _keys_of(clip, a):
		if k[0] > t + 0.0005:
			break
		callv(k[1], k[2])
	for node: Node2D in _rot_override:
		node.rotation = _rot_override[node]
	_apply_filters(clip, roundi(t * FPS))


func _keys_of(clip: String, a: Animation) -> Array:
	if _method_keys.has(clip):
		return _method_keys[clip]
	var keys := []
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_METHOD:
			continue
		for k in a.track_get_key_count(i):
			var m := str(a.method_track_get_name(i, k))
			if has_method(m):
				keys.append([a.track_get_key_time(i, k), m, a.method_track_get_params(i, k)])
	keys.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	_method_keys[clip] = keys
	return keys


## Nested instances (`metadata/library`): a container holds artwork sprites of its library,
## a leaf Sprite2D is the library's one bitmap. Bound once at their library's frame 0.
func _collect_nested(node: Node, bone: Node) -> void:
	for child in node.get_children():
		if _is_mask_clip(child):
			_collect_nested(child, bone)
			continue
		if not child.has_meta("library"):
			continue
		var lib := str(child.get_meta("library"))
		if child is Sprite2D and not child.has_meta("artwork_layer"):
			var svg: Dictionary = _symbol(lib).get("svg_files", {})
			if not svg.is_empty():
				_apply_texture(child, str(svg.get("0", svg.values()[0])).replace(".svg", ""))
		else:
			_bind_bone(child, lib)
			_collect_nested(child, bone)
		var ranges := PackedInt32Array(child.get_meta("frame_ranges", PackedInt32Array()))
		var vis_lib := str(child.get_meta("vis_lib", ""))
		_nested.append({"node": child, "bone": bone, "vis_lib": vis_lib, "ranges": ranges,
				"graphic": _graphic_spec(vis_lib, lib, int(child.get_meta("layer_index", -1))),
				"ft": _frame_transforms(child), "base": (child as Node2D).transform})


## Per-frame transforms of a nested instance in its container (keyframes and baked tweens).
static func _frame_transforms(node: Node) -> Dictionary:
	var out := {}
	if not node.has_meta("frame_transforms"):
		return out
	var parsed: Variant = JSON.parse_string(str(node.get_meta("frame_transforms")))
	if parsed is Dictionary:
		for f: String in parsed:
			var t: Dictionary = parsed[f]
			out[int(f)] = Transform2D(float(t["rot"]), Vector2(float(t["sx"]), float(t["sy"])),
					float(t["skew"]), Vector2(float(t["tx"]), float(t["ty"])))
	return out


## The container's frame `f` places a nested instance: that frame's transform, else its
## keyframe's, else the first keyframe's (OTHER rig_base `_apply_nested_frame_transform`).
static func _place_nested(e: Dictionary, f: int) -> void:
	var ft: Dictionary = e["ft"]
	var key := f
	if not ft.has(key):
		var r: PackedInt32Array = e["ranges"]
		for i in range(0, r.size() - 1, 2):
			if r[i] <= f and f <= r[i + 1]:
				key = r[i]
				break
	(e["node"] as Node2D).transform = ft.get(key, e["base"])


## A `mask_clip` holds a symbol's masked layers in that symbol's space; it is no instance.
static func _is_mask_clip(node: Node) -> bool:
	return node.has_meta("mask_part") and not node.has_meta("library")


## The symbol instance whose timeline shows `node`.
static func _holder(node: Node) -> Node:
	var p := node.get_parent()
	return p.get_parent() if p != null and _is_mask_clip(p) else p


## A graphic symbol instance (symbol `children[]` with `graphic`): its frame follows the
## frame its container shows, from the keyframe's first frame and loop mode.
func _graphic_spec(parent_lib: String, lib: String, layer: int) -> Dictionary:
	if parent_lib == "":
		return {}
	for c: Dictionary in _symbol(parent_lib).get("children", []):
		if str(c.get("library", "")) == lib and int(c.get("layer_index", -1)) == layer and c.get("graphic", false):
			return {"loop": str(c.get("loop", "loop")), "ff": int(c.get("first_frame", 0)),
					"keys": c.get("graphic_keys", {})}
	return {}


## Flash graphic playback (OTHER rig_base `_graphic_child_frame`), 0-based frames.
func _graphic_frame(e: Dictionary, parent_frame: int, total: int) -> int:
	var kf := -1
	var r: PackedInt32Array = e["ranges"]
	for i in range(0, r.size() - 1, 2):
		if r[i] <= parent_frame and parent_frame <= r[i + 1]:
			kf = r[i]
			break
	var g: Dictionary = e["graphic"]
	if kf < 0 or total <= 1:
		return 0
	var ff := int(g["ff"])
	var loop := str(g["loop"])
	if g["keys"].has(str(kf)):
		ff = int(g["keys"][str(kf)][0])
		loop = str(g["keys"][str(kf)][1])
	if loop == "single frame":
		return clampi(ff, 0, total - 1)
	var d := ff + parent_frame - kf
	return clampi(d, 0, total - 1) if loop == "play once" else posmod(d, total)


func _symbol(lib: String) -> Dictionary:
	if not _symbols.has(lib):
		_symbols[lib] = _json(_data_dir + "symbols/%s.json" % lib)
	return _symbols[lib]


## Frames of a library's own timeline (1 for a still symbol).
func _frames_of(lib: String) -> int:
	if _lib_frames.has(lib):
		return _lib_frames[lib]
	var sym := _symbol(lib)
	var n := int(sym.get("timeline", {}).get("frames", 0))
	if n <= 0:
		for al: Dictionary in sym.get("artwork_layers", []):
			for f in al.get("element_svg_files", {}):
				n = maxi(n, int(f) + 1)
	_lib_frames[lib] = maxi(n, 1)
	return _lib_frames[lib]


## Frames of a library's timeline with a `stop()` script.
func _stops_of(lib: String) -> Dictionary:
	if not _lib_stops.has(lib):
		var stops := {}
		var scripts: Dictionary = _symbol(lib).get("timeline", {}).get("scripts", {})
		for f in scripts:
			if "stop()" in str(scripts[f]):
				stops[int(f)] = true
		_lib_stops[lib] = stops
	return _lib_stops[lib]


## Where a movie clip of `lib` is after `elapsed` frames from `from`, looping, halting on
## a `stop()` frame.
func _run(lib: String, from: int, elapsed: int) -> int:
	var n := _frames_of(lib)
	var stops := _stops_of(lib)
	if stops.is_empty():
		return (from + elapsed) % n
	var f := from % n
	for i in mini(elapsed, n):
		if stops.has(f):
			return f
		f = (f + 1) % n
	return f


## Frame of a movie clip node: held or played by the unit code, else running from frame 0
## on `tick`, the frames since the sprite clip began.
func _clip_frame(node: Node, lib: String, tick: int) -> int:
	var n := _frames_of(lib)
	if _held.has(node):
		return clampi(int(_held[node]), 0, n - 1)
	if _played.has(node):
		var p: Array = _played[node]
		return _run(lib, int(p[0]), int(_clock - float(p[1])))
	return _run(lib, 0, tick)


func _step_clip(node: Node, lib: String, tick: int) -> void:
	var f := _clip_frame(node, lib, tick)
	if _bone_frame.get(node, -1) == f:
		return
	_bone_frame[node] = f
	_bind_bone(node, lib, false, f)
	# The one frame script the rigs carry besides stop() (megadron `dronDis2`).
	var script := str(_symbol(lib).get("timeline", {}).get("scripts", {}).get(str(f), ""))
	if "rotation=Math.random()*360" in script and node is Node2D:
		(node as Node2D).rotation = randf() * TAU


## Movie clip libraries on the bones, attachments and nested containers play their own timeline;
## nested instances show inside their parent's frame ranges.
func _update_nested(tick: int) -> void:
	for bone_name in _bones:
		var lib := str(_bone_lib.get(str(bone_name), ""))
		var n := _frames_of(lib) if lib != "" else 1
		var bone: Node = _bones[bone_name]
		if n <= 1:
			_bone_frame.erase(bone)
			continue
		_step_clip(bone, lib, tick)
	for node in _attachments:
		var lib := str(node.get_meta("library", ""))
		if lib != "" and _frames_of(lib) > 1:
			_step_clip(node, lib, tick)
	for e in _nested:
		var node: Node = e["node"]
		if node is Sprite2D or not e["graphic"].is_empty():
			continue
		var lib := str(node.get_meta("library", ""))
		if _frames_of(lib) > 1:
			_step_clip(node, lib, tick)
	# Containers come after their children in `_nested`: walk back so a graphic reads the
	# frame its parent shows this tick.
	for i in range(_nested.size() - 1, -1, -1):
		var e: Dictionary = _nested[i]
		var node: Node = e["node"]
		if node is Sprite2D or e["graphic"].is_empty():
			continue
		var lib := str(node.get_meta("library", ""))
		var f := _graphic_frame(e, int(_bone_frame.get(_holder(node), 0)), _frames_of(lib))
		if _bone_frame.get(node, -1) != f:
			_bone_frame[node] = f
			_bind_bone(node, lib, false, f)
	for e in _nested:
		var bone: Node = e["bone"]
		var node: CanvasItem = e["node"]
		var parent: Node = _holder(node)
		var parent_lib := str(_bone_lib.get(str(bone.name), bone.get_meta("library", ""))) if parent == bone \
				else str(parent.get_meta("library", ""))
		var f: int = _bone_frame.get(parent, 0)
		var on: bool = e["vis_lib"] == "" or e["vis_lib"] == parent_lib
		if on and not (e["ranges"] as PackedInt32Array).is_empty():
			on = false
			var r: PackedInt32Array = e["ranges"]
			for i in range(0, r.size() - 1, 2):
				if r[i] <= f and f <= r[i + 1]:
					on = true
					break
		node.visible = on
		if on and not (e["ft"] as Dictionary).is_empty():
			_place_nested(e, f)


## Method key: a bone shows another library mid-clip (OTHER rig_base `_swap_bone_lib`).
func _swap_bone_lib(bone_name: String, lib: String) -> void:
	if _bone_lib.get(bone_name, "") == lib:
		return
	var bone: Node = _bones.get(StringName(bone_name))
	if bone == null:
		return
	_bone_lib[bone_name] = lib
	_bone_frame.erase(bone)
	_bind_bone(bone, lib, true)


## OTHER's `art_fx` node: per-sprite Flash filters shown on some frames of a source clip.
func _read_art_fx() -> void:
	var fx := get_node_or_null("art_fx")
	if fx == null:
		return
	for m: Dictionary in fx.get_meta("mirrors", []):
		var src := get_node_or_null(str(m.get("source", ""))) as Sprite2D
		var dst := fx.get_node_or_null(str(m.get("mirror", ""))) as Sprite2D
		if src == null or dst == null:
			push_warning("rig_view: %s mirror %s unresolved" % [name, m.get("source", "")])
			continue
		var chain: Array[CanvasItem] = []
		var n := src.get_parent()
		while n != null and n != self:
			if n is CanvasItem:
				chain.append(n)
			n = n.get_parent()
		src.self_modulate.a = 0.0
		dst.visible = false
		_mirrors.append({"src": src, "dst": dst, "chain": chain})
	if not _mirrors.is_empty():
		_blend_copy = BackBufferCopy.new()
		_blend_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		_blend_copy.visible = false
		fx.add_child(_blend_copy)
		fx.move_child(_blend_copy, 0)
	for f: Dictionary in fx.get_meta("filters", []):
		var spr := get_node_or_null(str(f.get("sprite", ""))) as Sprite2D
		if spr == null:
			continue
		var bx := 0.0
		var by := 0.0
		for flt: Dictionary in f.get("filters", []):
			if str(flt.get("element", "")) == "BlurFilter":
				bx = maxf(bx, float(flt.get("blurX", 0)))
				by = maxf(by, float(flt.get("blurY", 0)))
			elif str(flt.get("element", "")) == "GlowFilter":
				var glow := ShaderMaterial.new()
				glow.shader = GLOW
				var base := spr.material as ShaderMaterial
				if base:
					for p in ["ct_multiply", "ct_offset", "ct_brightness"]:
						if base.get_shader_parameter(p) != null:
							glow.set_shader_parameter(p, base.get_shader_parameter(p))
				glow.set_shader_parameter("blur_x", float(flt.get("blurX", 4)))
				glow.set_shader_parameter("blur_y", float(flt.get("blurY", 4)))
				glow.set_shader_parameter("glow_color", Color(str(flt.get("color", "#FF0000"))))
				glow.set_shader_parameter("strength", float(flt.get("strength", 1)))
				glow.set_shader_parameter("screen", str(f.get("blend", "")) == "screen")
				_filters.append({"sprite": spr, "base": spr.material, "fx": glow,
					"source": str(f.get("source", "")), "frames": f.get("frames", [])})
			else:
				push_warning("rig_view: %s %s not drawn" % [name, flt.get("element", "")])
		if bx <= 1.0 and by <= 1.0:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = BLUR
		mat.set_shader_parameter("blur_x", bx)
		mat.set_shader_parameter("blur_y", by)
		_filters.append({"sprite": spr, "base": spr.material, "fx": mat,
			"source": str(f.get("source", "")), "frames": f.get("frames", [])})


## A blended leaf inside the body CanvasGroup would blend with the group's buffer, not the
## scene: it stays in place at alpha 0 and its art_fx mirror (blend shader, outside the group)
## draws it every frame (OTHER rig_art_fx.gd, without its filter-stack case).
func _update_mirrors() -> void:
	var shown := 0
	for m in _mirrors:
		var src: Sprite2D = m["src"]
		var dst: Sprite2D = m["dst"]
		var vis := src.is_visible_in_tree() and src.texture != null
		dst.visible = vis
		if not vis:
			continue
		shown += 1
		dst.texture = src.texture
		dst.centered = src.centered
		dst.offset = src.offset
		dst.flip_h = src.flip_h
		dst.flip_v = src.flip_v
		dst.region_enabled = src.region_enabled
		dst.region_rect = src.region_rect
		dst.global_transform = src.global_transform
		var mod := Color(src.self_modulate.r, src.self_modulate.g, src.self_modulate.b, 1.0) * src.modulate
		for c: CanvasItem in m["chain"]:
			mod *= c.modulate
		dst.modulate = mod
		var sm := src.material as ShaderMaterial
		var dm := dst.material as ShaderMaterial
		if sm and dm:
			for p in ["ct_multiply", "ct_offset", "ct_brightness"]:
				var v: Variant = sm.get_shader_parameter(p)
				if v != null:
					dm.set_shader_parameter(p, v)
	if _blend_copy:
		_blend_copy.visible = shown > 0


## Method key on a Flash `stop()` frame: the hold is the clip's end (the sprite clip's loop flag).
func _on_frame_stop(_frame: int) -> void:
	pass


func _apply_filters(clip: String, frame: int) -> void:
	for f in _filters:
		var on: bool = f["source"] == "" or f["source"] == clip
		if on and not (f["frames"] as Array).is_empty():
			on = false
			for r in f["frames"]:
				if frame >= int(r[0]) and frame <= int(r[1]):
					on = true
					break
		(f["sprite"] as Sprite2D).material = f["fx"] if on else f["base"]


func _bind_bone(bone: Node, lib: String, swapped := false, frame := 0) -> void:
	var r := float(_index.get("precomputed", {}).get("library_scales", {}).get(lib, 0.0))
	var parts := bone.get_children()
	for c in bone.get_children():
		if _is_mask_clip(c):
			parts.append_array(c.get_children())
	for spr in parts:
		if not spr is Sprite2D:
			continue
		if spr.has_meta("bitmap"):
			_apply_texture(spr, str(spr.get_meta("bitmap")))
			continue
		if lib == "" or not spr.has_meta("artwork_layer"):
			continue
		if swapped and r > 0.0:
			spr.scale = Vector2.ONE / r
		spr.visible = true
		var layer := int(str(spr.get_meta("artwork_layer")))
		var elem := int(str(spr.get_meta("element_index", 0)))
		var found := false
		for al: Dictionary in _symbol(lib).get("artwork_layers", []):
			if int(al.get("layer_index", -1)) != layer:
				continue
			found = true
			var by_frame: Dictionary = al.get("element_svg_files", {})
			if by_frame.is_empty():
				break
			# A movie clip frame with no key has nothing on this layer.
			var files: Array = by_frame.get(str(frame), []) if frame > 0 or _frames_of(lib) > 1 \
					else by_frame.get("0", by_frame.values()[0])
			if elem < files.size():
				_apply_texture(spr, str(files[elem]).replace(".svg", ""))
			else:
				spr.visible = false
			break
		if not found:
			spr.visible = false


func _apply_texture(spr: Sprite2D, tex_name: String) -> void:
	var path := _art_dir + tex_name + ".png"
	if not ResourceLoader.exists(path):
		push_warning("rig_view: missing %s" % path)
		return
	spr.texture = load(path)
	var meta: Dictionary = _png_meta.get(tex_name + ".png", {})
	if not meta.is_empty():
		# The sprite carries scale 1/R; the view-box origin is in raster pixels.
		var r := float(meta.get("scale", 1.0))
		spr.offset = Vector2(float(meta["vx"]), float(meta["vy"])) * r


## Method key at t=0 of every clip: Flash depth order, back to front, as sibling order.
func _apply_bone_order(clip: String) -> void:
	if _bone_order == clip or _body == null:
		return
	_bone_order = clip
	var order: Array = _index.get("precomputed", {}).get("bone_orders", {}).get(clip, [])
	var idx := 0
	for bone_name in order:
		var node: Node = _bones.get(StringName(str(bone_name)))
		if node == null:
			continue
		if node.get_index() != idx:
			_body.move_child(node, idx)
		idx += 1


func _setup_masks() -> void:
	for spr: Sprite2D in find_children("*", "Sprite2D", true, false):
		if not spr.has_meta("is_masked") or not spr.material is ShaderMaterial:
			continue
		var clip := spr.get_parent()
		while clip != null and not _is_mask_clip(clip):
			clip = clip.get_parent()
		if clip != null:
			spr.material = spr.material.duplicate()
			_masks.append({"sprite": spr, "mat": spr.material, "shown": "?", "clip": clip,
					"owner": clip.get_parent(), "part": str(spr.get_meta("mask_part"))})
	# A mask layer on a clip's own timeline clips its bones on the frames it has a shape.
	var tm: Dictionary = _index.get("timeline_masks", {})
	for source: String in tm:
		for m: Dictionary in tm[source]:
			var sprites: Array[Dictionary] = []
			for bone_name in m.get("masked_bones", []):
				var bone: Node = _bones.get(StringName(str(bone_name)))
				if bone == null:
					continue
				for spr: Sprite2D in bone.find_children("*", "Sprite2D", true, false):
					var old := spr.material as ShaderMaterial
					if old == null or old.shader == null or not old.shader.resource_path.ends_with("/color_transform.gdshader"):
						continue
					var mat := ShaderMaterial.new()
					mat.shader = MASKED
					for p in ["ct_multiply", "ct_offset", "ct_brightness", "footprint"]:
						var v: Variant = old.get_shader_parameter(p)
						if v != null:
							mat.set_shader_parameter(p, v)
					spr.material = mat
					sprites.append({"sprite": spr, "mat": mat, "shown": "?"})
			_tl_masks.append({"source": source, "keyframes": m.get("keyframes", []), "sprites": sprites})


## Mask rasters of a symbol by the frame they start on: `<part>_mask`, `<part>_mask_f<k>`.
func _mask_frames(part: String) -> Array:
	if not _mask_keys.has(part):
		var keys := []
		var re := RegEx.create_from_string("^%s_mask(?:_f(\\d+))?\\.png$" % part)
		for k in _png_meta:
			var m := re.search(str(k))
			if m:
				keys.append([int(m.get_string(1)) if m.get_string(1) != "" else 0, str(k).get_basename()])
		keys.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		_mask_keys[part] = keys
	return _mask_keys[part]


func _update_masks() -> void:
	for m in _masks:
		var spr: Sprite2D = m["sprite"]
		if not spr.is_visible_in_tree():
			continue
		var f: int = _bone_frame.get(m["owner"], 0)
		var tex_name := ""
		for k: Array in _mask_frames(m["part"]):
			if k[0] <= f:
				tex_name = k[1]
		_clip_sprite(m, tex_name, (m["clip"] as Node2D).get_global_transform().affine_inverse() * spr.get_global_transform())
	if _tl_masks.is_empty() or _body == null:
		return
	var clip := _now_clip if _follow else str(anim_player.current_animation)
	var frame := _now_frame if _follow else roundi(anim_player.current_animation_position * FPS)
	var source := clip
	if anim_player.has_animation(clip):
		var a := anim_player.get_animation(clip)
		var n := maxi(1, roundi(a.length * FPS))
		frame = posmod(frame, n) if a.loop_mode != Animation.LOOP_NONE else mini(frame, n - 1)
		source = str(a.get_meta("source", clip))
		frame += int(a.get_meta("frame_start", 0))
	var inv := _body.get_global_transform().affine_inverse()
	for e in _tl_masks:
		var tex_name := ""
		if e["source"] == source:
			for kf: Array in e["keyframes"]:
				if int(kf[0]) <= frame and frame <= int(kf[1]):
					tex_name = str(kf[2])
					break
		for it: Dictionary in e["sprites"]:
			_clip_sprite(it, tex_name, inv * (it["sprite"] as Node2D).get_global_transform())


## The sprite draws only inside mask raster `tex_name` (view box in the mask's space); `xf`
## takes the sprite into that space. No raster: nothing is clipped.
func _clip_sprite(it: Dictionary, tex_name: String, xf: Transform2D) -> void:
	var spr: Sprite2D = it["sprite"]
	var mat: ShaderMaterial = it["mat"]
	var meta: Dictionary = _png_meta.get(tex_name + ".png", {})
	if meta.is_empty() or spr.texture == null:
		if it["shown"] != "":
			it["shown"] = ""
			if _open_mask == null:
				var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
				img.fill(Color.WHITE)
				_open_mask = ImageTexture.create_from_image(img)
			mat.set_shader_parameter("mask_texture", _open_mask)
			mat.set_shader_parameter("mask_uv_xform", Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO))
			mat.set_shader_parameter("mask_uv_offset", Vector2(0.5, 0.5))
		return
	if it["shown"] != tex_name:
		it["shown"] = tex_name
		mat.set_shader_parameter("mask_texture", load(_art_dir + tex_name + ".png"))
	var origin := Vector2(float(meta["vx"]), float(meta["vy"]))
	var extent := Vector2(float(meta["vw"]), float(meta["vh"]))
	var size := spr.texture.get_size()
	mat.set_shader_parameter("mask_uv_xform", Transform2D(xf.x * size.x / extent, xf.y * size.y / extent, Vector2.ZERO))
	mat.set_shader_parameter("mask_uv_offset", (xf * spr.offset - origin) / extent)


## True when `node` is a part inside a rig.
static func owns(node: Node) -> bool:
	var at := node.get_parent() if node else null
	while at != null:
		if at is RigView:
			return true
		at = at.get_parent()
	return false


static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
