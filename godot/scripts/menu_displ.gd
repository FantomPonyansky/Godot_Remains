class_name MenuDispl
extends Node

## Displ.as: the main-menu background animation. visMainMenu.pipka (eye blink,
## mane and tail waving through a DisplacementMapFilter, the levitated pistol
## bobbing, the magic rings turning) and visMainMenu.groza (a lightning flash
## at a random point of the sky). Parts come from extracted_swf/export_menu_anim.py
## + tools/pack_menu_anim.gd, positioned in visMainMenu coordinates.

const DIR := "res://assets/ui/menu/anim/"
const SCREEN_MUL := preload("res://assets/shaders/menu_screen_mul.gdshader")
const SCREEN_ADD := preload("res://assets/shaders/menu_screen_add.gdshader")
const OVERLAY := preload("res://assets/shaders/menu_overlay.gdshader")
const DISPLACE := preload("res://assets/shaders/menu_displace.gdshader")
const TICK := 1.0 / 30.0
const PIPKA_AT := Vector2(670.0, 360.0)
## displMatrix: target - displ1 in pipka.
const STAMP_AT := Vector2(164.0, 159.95)
const WAV_KOL := 10
const DIS_X := 200.0
const DIS_Y := 250.0
const SPD := 1.0
## anim_horn / anim_pistol aura (inner knockout GlowFilter, then BlurFilter), screen-blended.
## Horn: blur 8, strength 0.86. Pistol: blur 20, strength 0.54. Both #00FF00, alpha 1, quality 1,
## then blur 4 quality 3. Pistol bitmap colour offset is green +20.
const HORN_GLOW_BLUR := 8.0
const HORN_GLOW_STRENGTH := 0.86
const PISTOL_GLOW_BLUR := 20.0
const PISTOL_GLOW_STRENGTH := 0.54
const AURA_BLUR := 4.0
const AURA_BLUR_Q := 3
const GLOW_PAD := 20
const PISTOL_GREEN := 20.0 / 255.0
## iskr_* : 30 frames held, then 20 frames of scale and alpha (the shape tween).
const SPARK_SCALES: Array[float] = [1.0, 0.9783, 0.9566, 0.9349, 0.9132, 0.8915, 0.8698, 0.8481, 0.8264, 0.8047, 0.783, 0.7613, 0.7396, 0.7179, 0.6962, 0.6745, 0.6528, 0.6311, 0.6094, 0.5877, 0.566]
const SPARK_ALPHAS: Array[float] = [1.0, 0.9516, 0.9031, 0.8547, 0.8063, 0.7578, 0.7094, 0.6609, 0.6125, 0.5641, 0.5156, 0.4672, 0.4188, 0.3703, 0.3219, 0.2734, 0.225, 0.1766, 0.1281, 0.0797, 0.0312]

var playing := true
var _info: Dictionary = {}
var _acc := 0.0
var _t_anim := 0
var _t_klip := 60
var _t_groza := 120
var _frame := 0
var _blink := 0
var _eye: Sprite2D
var _pistol: Node2D
var _pistol_at := Vector2(-19.0, 86.05)
var _rings: Array = []
var _spark_states: Array = []
var _wavs: Array[Sprite2D] = []
var _map: SubViewport
var _map_fill: ColorRect
var _groza: Node2D
var _tuchi: Node2D
var _moln: Sprite2D
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "anim.json"))
	_info = raw if raw is Dictionary else {}
	_rng.randomize()


func has_parts() -> bool:
	return not _info.is_empty()


## The lightning layer, between the sky (shape 411) and the city (425).
func make_groza() -> Node2D:
	_groza = Node2D.new()
	_groza.name = "Groza"
	_groza.visible = false
	var sky := _sprite("groza_sky")
	sky.position = Vector2(0.0, -76.0)
	var overlay := ShaderMaterial.new()
	overlay.shader = OVERLAY
	sky.material = overlay
	_groza.add_child(sky)
	var mask: Dictionary = _info["groza_sky"]
	_tuchi = _screen("tuchi", {"use_mask": true, "mask_tex": _tex("groza_sky"),
		"mask_scale": Vector2(1.0, 0.883), "mask_origin": _vec(mask["origin"]),
		"mask_size": Vector2(float(mask["w"]), float(mask["h"]))})
	_tuchi.position = Vector2(-200.0, -200.0)
	_set_screen(_tuchi, "mask_pos", Vector2(0.0, -57.0) - _tuchi.position)
	_groza.add_child(_tuchi)
	var holder := Node2D.new()
	holder.position = Vector2(-5.8, -15.75)
	holder.scale = Vector2(1.0, 0.391)
	_groza.add_child(holder)
	_moln = _screen("moln", {"use_glow": true, "glow_color": Color("ff6600"), "glow_radius": 8.0, "glow_strength": 2.0})
	holder.add_child(_moln)
	return _groza


## The pony's moving parts, over the city art.
func make_pipka() -> Node2D:
	var pipka := Node2D.new()
	pipka.name = "Pipka"
	pipka.position = PIPKA_AT
	_map = _make_map()
	pipka.add_child(_map)
	_eye = _sprite("eye")
	_eye.position = Vector2(77.5, 97.5)
	pipka.add_child(_eye)
	# Hair is displaced in off-screen viewports, then blitted as plain sprites.
	# A ShaderMaterial on the menu sprites drew in a later pass and hid the horn.
	pipka.add_child(_hair_blit("displ1", Vector2(10.0, 15.0)))
	pipka.add_child(_hair_blit("displ2", Vector2(0.0, 5.0)))
	var horn_body := _sprite("horn_body")
	horn_body.position = Vector2(32.0, 40.0)
	pipka.add_child(horn_body)
	var horn := Node2D.new()
	horn.name = "horn"
	horn.position = Vector2(52.0, 55.05)
	pipka.add_child(horn)
	_add_aura(horn, "aura_horn", Vector2i(42, 33), Vector2(-21.0, -16.05), HORN_GLOW_BLUR, HORN_GLOW_STRENGTH)
	_add_magic(horn, "horn_glow", 0.58, 90.0, 0.67)
	_add_sparks(horn, 4, 36.0, 18.0, 15.0, 8.0)
	pipka.add_child(_sprite("ear"))
	_pistol = _sprite("pistol")
	_pistol.position = _pistol_at
	# The bob is under 1 px/s: nearest filtering snaps it to whole-pixel steps.
	_pistol.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_tint_green(_pistol)
	pipka.add_child(_pistol)
	_add_aura(_pistol, "aura_pistol", Vector2i(47, 84), Vector2(-24.0, -37.05), PISTOL_GLOW_BLUR, PISTOL_GLOW_STRENGTH)
	_add_magic(_pistol, "pistol_glow", 1.0, 0.0, 1.0)
	_add_magic(_pistol, "pistol_glow2", 1.0, 90.0, 0.67)
	_add_sparks(_pistol, 7, 30.0, 15.0, 80.0, 40.0)
	_present()
	return pipka


func _process(delta: float) -> void:
	_acc = minf(_acc + delta, TICK * 4.0)
	while _acc >= TICK:
		_acc -= TICK
		_timelines()
		if playing:
			_anim()
	if playing:
		_wav_move(delta)
	_present()


## MovieClip timelines run whether or not Displ.anim does.
func _timelines() -> void:
	_frame += 1
	for st in _spark_states:
		st["frame"] = int(st["frame"]) + 1
		if int(st["frame"]) > 50:
			_reroll_spark(st)
	if _blink > 0:
		_blink = (_blink + 1) % _eye.hframes
		_eye.frame = _blink


func _anim() -> void:
	_t_anim += 1
	_t_klip -= 1
	if _t_klip <= 0:
		if _blink == 0 and _eye.hframes > 1:
			_blink = 1
			_eye.frame = 1
		_t_klip = _rng.randi_range(60, 169)
	if _groza != null:
		_storm()


## visWav drifts every display frame (not only on the 30 Hz tick) so the
## displacement map has in-between stamps. Distances stay SPD pixels / tick.
func _wav_move(delta: float) -> void:
	var ticks := delta / TICK
	for i in _wavs.size():
		var v := _wavs[i]
		var step := (SPD + i / 2.0) * ticks
		var pos := v.position + Vector2(-step, step * 0.3)
		if pos.x < -DIS_X * 2.0:
			pos.x = DIS_X
			v.scale = Vector2(_rng.randf_range(2.0, 3.0), 3.0)
			v.modulate.a = _rng.randf_range(0.5, 1.0)
		if pos.y > DIS_Y:
			pos.y = -DIS_Y
		v.position = pos


## Gun bob, ring spin and spark fade. The 30 Hz tick owns the values; the fraction
## of the current tick is interpolated so a 60 Hz window does not step.
func _present() -> void:
	var frac := clampf(_acc / TICK, 0.0, 1.0)
	var t := float(_t_anim) + (frac if playing else 0.0)
	if _pistol != null:
		_pistol.position = _pistol_at + Vector2(sin(t / 100.0) * 2.0, -(cos(t / 100.0) - 1.0) * 8.0)
	for ring: Array in _rings:
		var angle := deg_to_rad(float(ring[1]) + t * float(ring[2]))
		for mat: ShaderMaterial in ring[0]:
			mat.set_shader_parameter("ring_angle", angle)
	for st in _spark_states:
		var frame := int(st["frame"])
		var k := 0 if frame <= 30 else frame - 30
		var k2 := k if frame >= 50 else (0 if frame + 1 <= 30 else frame + 1 - 30)
		var sc := lerpf(SPARK_SCALES[k], SPARK_SCALES[k2], frac) * float(st["base"])
		var root: Node2D = st["root"]
		root.scale = Vector2(sc, sc)
		root.modulate.a = lerpf(SPARK_ALPHAS[k], SPARK_ALPHAS[k2], frac)


func _storm() -> void:
	_t_groza -= 1
	if _t_groza == 0:
		_groza.position = Vector2(_rng.randf_range(0.0, 1800.0), _rng.randf_range(0.0, 350.0))
		var k := 1.0 - _groza.position.y / 800.0
		_groza.scale = Vector2(k, k)
		_moln.rotation_degrees = _rng.randf_range(0.0, 360.0)
		_moln.frame = _rng.randi_range(0, _moln.hframes - 1)
		(_moln.get_child(0) as Sprite2D).frame = _moln.frame
		_groza.modulate.a = 1.0
		_groza.visible = true
		_tuchi.position = Vector2(_rng.randf_range(-600.0, -200.0), _rng.randf_range(-500.0, -200.0))
		_set_screen(_tuchi, "mask_pos", Vector2(0.0, -57.0) - _tuchi.position)
	elif _t_groza < 0:
		_groza.modulate.a = minf(1.0, _rng.randf_range(0.0, 0.5) + _t_groza / 12.0 + 0.7)
		if _t_groza < -6 and _rng.randf() < 0.1:
			_t_groza = -100
	if _t_groza < -30:
		_t_groza = _rng.randi_range(100, 300)
		_groza.visible = false


## displBmpd: 240x300, drawn each tick from displStamp (displVolna, ten visWav
## drifting left and down, visSerost on top) through displMatrix.
func _make_map() -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(240, 300)
	view.disable_3d = true
	view.transparent_bg = true
	view.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	_map_fill = ColorRect.new()
	_map_fill.color = Color8(0x7F, 0x7F, 0x7F)
	_map_fill.size = Vector2(240, 300)
	_map_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(_map_fill)
	if not RenderingServer.frame_post_draw.is_connected(_retire_map_fill):
		RenderingServer.frame_post_draw.connect(_retire_map_fill, CONNECT_ONE_SHOT)
	var stamp := Node2D.new()
	stamp.position = STAMP_AT
	view.add_child(stamp)
	stamp.add_child(_sprite("volna"))
	for i in WAV_KOL:
		var v := _sprite("wav")
		v.position = Vector2(_rng.randf_range(-DIS_X, DIS_X), _rng.randf_range(-DIS_Y, DIS_Y))
		v.scale = Vector2(_rng.randf_range(2.0, 3.0), 3.0)
		stamp.add_child(v)
		_wavs.append(v)
	stamp.add_child(_sprite("serost"))
	return view


## Displace off-screen and return a plain sprite of the result, so the horn
## (no material) can draw on top in tree order.
func _hair_blit(id: String, scale_xy: Vector2) -> Sprite2D:
	var view := SubViewport.new()
	view.size = Vector2i(240, 300)
	view.disable_3d = true
	view.transparent_bg = true
	view.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.gui_disable_input = true
	view.add_child(_displaced(id, scale_xy))
	var s := Sprite2D.new()
	s.name = id
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.add_child(view)
	s.texture = view.get_texture()
	return s


func _displaced(id: String, scale_xy: Vector2) -> Sprite2D:
	var s := _sprite(id)
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(DIR + id + ".png")) == OK:
		s.texture = ImageTexture.create_from_image(img)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = DISPLACE
	mat.render_priority = -8
	mat.set_shader_parameter("src_tex", s.texture)
	mat.set_shader_parameter("map_tex", _map.get_texture())
	mat.set_shader_parameter("scale", scale_xy)
	var info: Dictionary = _info.get(id, {})
	mat.set_shader_parameter("src_size", Vector2(float(info.get("w", 240)), float(info.get("h", 300))))
	s.material = mat
	return s


## part.magic (screen) with magic.krug (multiply) turning at base + t * speed degrees.
func _add_magic(parent: Node2D, id: String, ring_scale: float, base: float, speed: float) -> void:
	var krug: Dictionary = _info["krug"]
	var glow := _screen(id, {"use_ring": true, "ring_tex": _tex("krug"), "ring_origin": _vec(krug["origin"]),
		"ring_size": Vector2(float(krug["w"]), float(krug["h"])), "ring_scale": ring_scale})
	parent.add_child(glow)
	_rings.append([_materials(glow), base, speed])


func _add_sparks(parent: Node2D, count: int, w: float, xo: float, h: float, yo: float) -> void:
	for _i in count:
		var root := Node2D.new()
		root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var pic := _screen("spark", {})
		pic.position = Vector2(0.0, -0.1)
		pic.scale = Vector2(0.5, 0.5)
		root.add_child(pic)
		parent.add_child(root)
		var st := {"root": root, "frame": 1, "base": 1.0, "w": w, "xo": xo, "h": h, "yo": yo}
		_spark_states.append(st)
		_reroll_spark(st)


## iskr frame-1 script: random position and scale, then a random frame of the 50.
func _reroll_spark(st: Dictionary) -> void:
	var root: Node2D = st["root"]
	root.position = Vector2(_rng.randf() * float(st["w"]) - float(st["xo"]), _rng.randf() * float(st["h"]) - float(st["yo"]))
	st["base"] = _rng.randf() * 0.8 + 0.2
	st["frame"] = _rng.randi_range(1, 50)


## Aura bitmap (exported at 2x) through the inner-knockout glow and the follow-up blur.
func _add_aura(parent: Node2D, id: String, display: Vector2i, at: Vector2, blur: float, strength: float) -> void:
	var img := Image.new()
	if img.load(DIR + id + ".png") != OK:
		return
	img.resize(display.x, display.y, Image.INTERPOLATE_BILINEAR)
	var baked := _glow_image(img, blur, strength)
	var spr := _screen_tex(ImageTexture.create_from_image(baked))
	spr.position = at - Vector2(GLOW_PAD, GLOW_PAD)
	parent.add_child(spr)


func _glow_image(src: Image, blur: float, strength: float) -> Image:
	var pad := GLOW_PAD
	var w := src.get_width() + pad * 2
	var h := src.get_height() + pad * 2
	var n := w * h
	var alpha := PackedFloat32Array()
	alpha.resize(n)
	for y in src.get_height():
		for x in src.get_width():
			alpha[(y + pad) * w + x + pad] = src.get_pixel(x, y).a
	var inv := PackedFloat32Array()
	inv.resize(n)
	for i in n:
		inv[i] = 1.0 - alpha[i]
	var ker := _box_kernel(blur)
	var g := _blur_axis(_blur_axis(inv, w, h, true, ker, 1.0), w, h, false, ker, 1.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var v := g[i] * strength
		var ga := (1.0 if v >= 1.0 else (v if v > 0.0 else 0.0)) * alpha[i]
		out[i] = ga
	var soft := _box_kernel(AURA_BLUR)
	for _q in AURA_BLUR_Q:
		out = _blur_axis(_blur_axis(out, w, h, true, soft, 0.0), w, h, false, soft, 0.0)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var a := clampf(out[y * w + x], 0.0, 1.0)
			img.set_pixel(x, y, Color(0.0, 1.0, 0.0, a))
	return img


func _box_kernel(bw: float) -> PackedFloat32Array:
	var r := (bw - 1.0) * 0.5
	var n := int(floor(r))
	var frac := r - float(n)
	var k := PackedFloat32Array()
	if frac > 0.0001:
		k.append(frac / bw)
	for _i in 2 * n + 1:
		k.append(1.0 / bw)
	if frac > 0.0001:
		k.append(frac / bw)
	return k


func _blur_axis(src: PackedFloat32Array, w: int, h: int, horizontal: bool, kernel: PackedFloat32Array, pad: float) -> PackedFloat32Array:
	var dst := PackedFloat32Array()
	dst.resize(src.size())
	var center := kernel.size() >> 1
	for y in h:
		for x in w:
			var acc := 0.0
			for i in kernel.size():
				var ox := x
				var oy := y
				var d := i - center
				if horizontal:
					ox += d
				else:
					oy += d
				var v := pad
				if ox >= 0 and oy >= 0 and ox < w and oy < h:
					v = src[oy * w + ox]
				acc += v * kernel[i]
			dst[y * w + x] = acc
	return dst


## Pistol bitmap: multiply 1, green offset +20/255 (anim_pistol track on the gun).
func _tint_green(s: Sprite2D) -> void:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform vec3 add = vec3(0.0);\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tvec3 rgb = clamp(c.rgb + add, vec3(0.0), vec3(1.0));\n\tCOLOR = vec4(rgb, c.a) * COLOR;\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("add", Vector3(0.0, PISTOL_GREEN, 0.0))
	s.material = mat


func _screen_tex(tex: Texture2D) -> Sprite2D:
	var mul := Sprite2D.new()
	var add := Sprite2D.new()
	mul.texture = tex
	add.texture = tex
	mul.centered = false
	add.centered = false
	for pair in [[mul, SCREEN_MUL], [add, SCREEN_ADD]]:
		var mat := ShaderMaterial.new()
		mat.shader = pair[1]
		(pair[0] as Sprite2D).material = mat
	add.name = "Add"
	mul.add_child(add)
	return mul


func _retire_map_fill() -> void:
	if _map_fill != null:
		_map_fill.visible = false


## A screen-blended part: this sprite multiplies by (1 - src), its child adds src.
func _screen(id: String, params: Dictionary) -> Sprite2D:
	var mul := _sprite(id)
	var add := _sprite(id)
	for pair in [[mul, SCREEN_MUL], [add, SCREEN_ADD]]:
		var mat := ShaderMaterial.new()
		mat.shader = pair[1]
		for key: String in params:
			mat.set_shader_parameter(key, params[key])
		(pair[0] as Sprite2D).material = mat
	add.name = "Add"
	mul.add_child(add)
	return mul


func _materials(part: Sprite2D) -> Array:
	return [part.material, (part.get_child(0) as Sprite2D).material]


func _set_screen(part: Sprite2D, key: String, value: Variant) -> void:
	for mat: ShaderMaterial in _materials(part):
		mat.set_shader_parameter(key, value)


func _sprite(id: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = id
	s.texture = _tex(id)
	s.centered = false
	var info: Dictionary = _info.get(id, {})
	s.hframes = maxi(1, int(info.get("frames", 1)))
	s.offset = -_vec(info.get("origin", [0, 0]))
	return s


func _tex(id: String) -> Texture2D:
	var path := DIR + id + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func _vec(v: Variant) -> Vector2:
	var a: Array = v
	return Vector2(float(a[0]), float(a[1]))
