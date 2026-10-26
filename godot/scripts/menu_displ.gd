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
const HORN_SPARKS: Array[Vector2] = [Vector2(-10.85, -7.6), Vector2(4.9, -3.85), Vector2(11.4, 6.6), Vector2(-2.1, 3.85)]
const PISTOL_SPARKS: Array[Vector2] = [Vector2(7.45, -25.55), Vector2(-9.3, 5.45), Vector2(8.7, 31.95),
	Vector2(2.45, 15.2), Vector2(-4.55, -20.3), Vector2(7.45, -1.3), Vector2(-10.8, -10.05)]

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
var _sparks: Array[Sprite2D] = []
var _wavs: Array[Sprite2D] = []
var _map: SubViewport
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
	pipka.add_child(_displaced("displ1", Vector2(10.0, 15.0)))
	pipka.add_child(_sprite("mane"))
	var horn := _sprite("horn")
	horn.position = Vector2(52.0, 55.05)
	pipka.add_child(horn)
	_add_magic(horn, "horn_glow", 0.58, 90.0, 0.67)
	_add_sparks(horn, "horn_spark", HORN_SPARKS)
	pipka.add_child(_displaced("displ2", Vector2(0.0, 5.0)))
	pipka.add_child(_sprite("ear"))
	_pistol = _sprite("pistol")
	_pistol.position = _pistol_at
	pipka.add_child(_pistol)
	_add_magic(_pistol, "pistol_glow", 1.0, 0.0, 1.0)
	_add_magic(_pistol, "pistol_glow2", 1.0, 90.0, 0.67)
	_add_sparks(_pistol, "pistol_spark", PISTOL_SPARKS)
	_apply()
	return pipka


func _process(delta: float) -> void:
	_acc = minf(_acc + delta, TICK * 4.0)
	while _acc >= TICK:
		_acc -= TICK
		_timelines()
		if playing:
			_anim()


## MovieClip timelines run whether or not Displ.anim does.
func _timelines() -> void:
	_frame += 1
	for spark in _sparks:
		spark.frame = _frame % spark.hframes
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
	for i in _wavs.size():
		var v := _wavs[i]
		var step := SPD + i / 2.0
		v.position.x -= step
		v.position.y += step * 0.3
		if v.position.x < -DIS_X * 2.0:
			v.position.x = DIS_X
			v.scale = Vector2(_rng.randf_range(2.0, 3.0), 3.0)
			v.modulate.a = _rng.randf_range(0.5, 1.0)
		if v.position.y > DIS_Y:
			v.position.y = -DIS_Y
	_apply()
	if _groza != null:
		_storm()


func _apply() -> void:
	if _pistol != null:
		_pistol.position = _pistol_at + Vector2(sin(_t_anim / 100.0) * 2.0, -(cos(_t_anim / 100.0) - 1.0) * 8.0)
	for ring: Array in _rings:
		var angle := deg_to_rad(float(ring[1]) + _t_anim * float(ring[2]))
		for mat: ShaderMaterial in ring[0]:
			mat.set_shader_parameter("ring_angle", angle)


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
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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


func _displaced(id: String, scale_xy: Vector2) -> Sprite2D:
	var s := _sprite(id)
	var mat := ShaderMaterial.new()
	mat.shader = DISPLACE
	mat.set_shader_parameter("map_tex", _map.get_texture())
	mat.set_shader_parameter("disp_scale", scale_xy)
	mat.set_shader_parameter("origin", _vec(_info[id]["origin"]))
	s.material = mat
	return s


## part.magic (screen) with magic.krug (multiply) turning at base + t * speed degrees.
func _add_magic(parent: Node2D, id: String, ring_scale: float, base: float, speed: float) -> void:
	var krug: Dictionary = _info["krug"]
	var glow := _screen(id, {"use_ring": true, "ring_tex": _tex("krug"), "ring_origin": _vec(krug["origin"]),
		"ring_size": Vector2(float(krug["w"]), float(krug["h"])), "ring_scale": ring_scale})
	parent.add_child(glow)
	_rings.append([_materials(glow), base, speed])


func _add_sparks(parent: Node2D, id: String, at: Array[Vector2]) -> void:
	for p in at:
		var spark := _screen(id, {})
		spark.position = p
		parent.add_child(spark)
		_sparks.append(spark)
		_sparks.append(spark.get_child(0) as Sprite2D)


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
