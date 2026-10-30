extends Node2D
class_name UnitFx
## Emitter.cast / Part.step for the parts the vclass units throw (parts.xml rows),
## plus their Sound.ps one-shots (Sounds.xml variants) and Sound.pshum hums.
## One host per scene in group "unit_fx"; parts tick at the original 30 Hz.

const _WeaponFx := preload("res://scripts/weapon_fx.gd")
const TPS := 30.0
const MAX_PARTS := 400
const SHEETS := "res://assets/sprites/sheets/units/"
const BLITS := "res://assets/fx_blits/"

## parts.xml: vis = packed fx_* symbol, blit = [png, cell w, cell h].
const PARTS := {
	"shmatok": {"vis": "fx_shmatok", "alph": true, "minliv": 20, "rliv": 40, "grav": 0.8, "minv": 2, "rv": 10, "rot": true, "dy": -5},
	"bloat_kap": {"vis": "fx_bloat_kap", "alph": true, "minliv": 20, "rliv": 40, "grav": 0.8, "minv": 2, "rv": 10, "dy": -5},
	"metal": {"vis": "fx_metal", "alph": true, "minliv": 20, "rliv": 40, "grav": 1.0, "minv": 2, "rv": 10, "rot": true, "dy": -5, "rsc": 0.4},
	"pole": {"vis": "fx_pole", "alph": true, "minliv": 20, "rliv": 10, "add": true, "minv": 3, "rv": 8, "rsc": 0.4, "brake": 0.92},
	"fake": {"blit": ["visualFake.png", 140, 142], "cols": 3, "cells": [0, 1, 2, 3, 4, 5, 6, 7, 7, 7, 7, 7, 7, 7, 7], "origin": [69.4, 72.6], "tex_scale": 0.5, "anim": true, "alph": true, "minliv": 8, "add": true},
	"blast": {"vis": "fx_blast", "anim": true, "minliv": 10},
	"gwall": {"vis": "fx_gwall", "anim": true, "minliv": 12, "add": true},
	"slow": {"blit": ["visualSlow.png", 51, 51], "origin": [25.4, 25.4], "tex_scale": 0.5, "alph": true, "minliv": 20, "rliv": 10, "rsc": 0.2, "brake": 0.91},
	"black": {"vis": "fx_black", "alph": true, "minliv": 20, "rliv": 10, "minv": 3, "rv": 8, "rsc": 0.4, "brake": 0.92},
	"miniexpl": {"vis": "fx_miniexpl", "anim": true, "minliv": 5},
	"expl": {"blit": ["17_sprExpl.png", 240, 240], "anim": true, "minliv": 15},
	"explw": {"blit": ["15_sprExplW.png", 240, 240], "anim": true, "minliv": 15, "add": true},
	"baleblast": {"vis": "fx_baleblast", "anim": true, "minliv": 30},
	"bloodblast": {"vis": "fx_bloodblast", "anim": true, "minliv": 30},
	"bloodexpl1": {"blit": ["21_sprBl1.png", 240, 240], "anim": true, "minliv": 20},
	"bloodexpl2": {"blit": ["20_sprBl2.png", 240, 240], "anim": true, "minliv": 20},
	"bloodexpl3": {"blit": ["19_sprBl3.png", 240, 240], "anim": true, "minliv": 20},
	"buma": {"vis": "fx_buma", "anim": true, "minliv": 5},
	"pole2": {"blit": ["visualPole2.png", 252, 240], "cols": 2, "nframes": 3, "origin": [128.0, 120.0], "tex_scale": 0.5, "alph": true, "minliv": 10, "rliv": 5},
	"discharge": {"vis": "fx_discharge", "alph": true, "minliv": 5, "rot": true, "add": true},
	"bloodblast2": {"vis": "fx_bloodblast2", "anim": true, "minliv": 120},
	"necrblast": {"vis": "fx_necrblast", "anim": true, "minliv": 30},
	"necrblast2": {"vis": "fx_necrblast2", "anim": true, "minliv": 120},
	"necrblast3": {"vis": "fx_necrblast3", "anim": true, "minliv": 30},
	"iskr_bul": {"blit": ["29_sprIskr.png", 3, 3], "alph": true, "minliv": 15, "rliv": 5, "grav": 0.7, "minv": 5, "rv": 3, "dy": -5, "add": true},
	"blood": {"blit": ["41_sprBlood.png", 5, 5], "alph": true, "minliv": 20, "rliv": 20, "grav": 1.0, "rv": 5, "dy": -6},
	"tele": {"blit": ["40_sprBSpark.png", 9, 9], "alph": true, "minliv": 10, "rliv": 20, "rv": 5, "add": true},
	"telered": {"blit": ["23_sprRSpark.png", 9, 9], "alph": true, "minliv": 10, "rliv": 20, "rv": 5, "add": true},
	"lift": {"blit": ["40_sprBSpark.png", 9, 9], "alph": true, "minliv": 20, "rliv": 20, "dy": -5, "rdy": -5, "add": true},
	"teleport": {"vis": "fx_teleport", "anim": true, "minliv": 12},
	"quake": {"vis": "fx_quake", "anim": true, "minliv": 10, "add": true},
	"necronoise": {"vis": "fx_necronoise", "anim": true, "minliv": 9},
	"vsos": {"blit": ["visualVsos.png", 134, 134], "origin": [70.0, 70.0], "tex_scale": 0.5, "alph": true, "minliv": 30, "rsc": 0.2},
	"green_spark": {"vis": "fx_green_spark", "alph": true, "minliv": 20, "rliv": 10, "add": true, "minv": 8, "rv": 1, "rsc": 0.4, "brake": 0.92},
	"blue_spark": {"vis": "fx_blue_spark", "alph": true, "minliv": 20, "rliv": 10, "add": true, "minv": 8, "rv": 1, "rsc": 0.4, "brake": 0.92},
	"orange_spark": {"vis": "fx_orange_spark", "alph": true, "minliv": 20, "rliv": 10, "add": true, "minv": 8, "rv": 1, "rsc": 0.4, "brake": 0.92},
	# Wall chips (Grafon.dyrka) stay one PNG per frame. Chunks kusok / steklo / schep
	# are the OTHER strips (random frame, Part.isAnim 0).
	"kusok": {"blit": ["visualKusok.png", 54, 60], "cols": 3, "nframes": 5, "origin": [24.0, 38.0], "tex_scale": 0.5, "alph": true, "minliv": 20, "rliv": 40, "grav": 1.0, "minv": 2, "rv": 10, "rot": true, "dy": -5},
	"kusokB": {"debris": "kusokB", "alph": true, "minliv": 20, "rliv": 40, "grav": 1.0, "minv": 2, "rv": 10, "rot": true, "dy": -5},
	"kusokD": {"debris": "kusokD", "alph": true, "minliv": 20, "rliv": 40, "grav": 1.0, "minv": 2, "rv": 10, "rot": true, "dy": -5},
	"steklo": {"blit": ["visualSteklo.png", 48, 47], "cols": 3, "nframes": 5, "origin": [22.2, 33.2], "tex_scale": 0.5, "alph": true, "minliv": 20, "rliv": 40, "grav": 1.0, "minv": 2, "rv": 10, "rot": true, "dy": -5},
	"kusoch": {"debris": "kusoch", "alph": true, "minliv": 20, "rliv": 40, "grav": 1.0, "minv": 2, "rv": 6, "rot": true, "dy": -5},
	"kusochB": {"debris": "kusochB", "alph": true, "minliv": 20, "rliv": 40, "grav": 1.0, "minv": 2, "rv": 6, "rot": true, "dy": -5},
	"schep": {"blit": ["visualSchep.png", 46, 96], "cols": 3, "nframes": 5, "origin": [19.0, 52.0], "tex_scale": 0.5, "alph": true, "minliv": 20, "rliv": 40, "grav": 1.0, "minv": 2, "rv": 10, "rot": true, "dy": -5},
	"schepoch": {"debris": "schepoch", "alph": true, "minliv": 20, "rliv": 40, "grav": 1.0, "minv": 2, "rv": 6, "rot": true, "dy": -5},
	# Bullet.explVis, Desintegr, Pers.upLevel, UnitPlayer and status parts.
	"fireexpl": {"blit": ["17_sprExpl.png", 240, 240], "anim": true, "minliv": 15, "add": true},
	"balefire": {"blit": ["16_sprBale.png", 240, 360], "anim": true, "minliv": 60, "fstep": 0.5},
	"plaexpl": {"vis": "fx_plaexpl", "anim": true, "minliv": 25},
	"impexpl": {"vis": "fx_impexpl", "anim": true, "minliv": 25},
	"iceexpl": {"vis": "fx_iceexpl", "anim": true, "minliv": 25},
	"sparkleexpl": {"vis": "fx_sparkleexpl", "anim": true, "minliv": 25},
	"acidexpl": {"vis": "fx_acidexpl", "anim": true, "minliv": 10},
	"radioblast": {"vis": "fx_radioblast", "anim": true, "minliv": 30},
	"react": {"blit": ["24_sprReact.png", 60, 60], "anim": true, "minliv": 15, "add": true},
	"ttexpl": {"blit": ["17_sprExpl.png", 240, 240], "anim": true, "minliv": 15, "scale": 2.0, "rsc": 0.5},
	"ttplaexpl": {"vis": "fx_plaexpl", "anim": true, "minliv": 25, "scale": 2.0, "rsc": 0.5},
	"gas": {"vis": "fx_gas", "alph": true, "prealph": true, "minliv": 60, "rdy": 1, "rot": true, "maxkol": 1},
	"pinkgas": {"vis": "fx_pinkgas", "alph": true, "prealph": true, "minliv": 60, "rdy": 1, "rot": true, "maxkol": 1},
	"steam": {"vis": "fx_steam", "minliv": 30, "rdy": 1, "grav": -0.2, "rot": true, "anim": true, "rsc": 0.3, "maxkol": 1},
	"snow": {"blit": ["visualSnow.png", 55, 64], "cols": 2, "nframes": 4, "origin": [27.6, 31.6], "tex_scale": 0.5, "alph": true, "minliv": 20, "rliv": 10, "minv": 15, "rv": 5, "rot": true, "rsc": 0.6, "brake": 0.95},
	"bubble": {"blit": ["visualBubble.png", 35, 35], "origin": [17.4, 17.4], "tex_scale": 0.5, "alph": true, "minliv": 20, "rliv": 10, "grav": -0.4, "rv": 3, "rsc": 0.6, "brake": 0.95},
	"fire": {"blit": ["32_sprFire.png", 50, 67], "loop": 17, "alph": true, "prealph": true, "minliv": 100, "rliv": 30},
	"iskr": {"blit": ["29_sprIskr.png", 3, 3], "alph": true, "minliv": 20, "rliv": 20, "grav": 0.5, "minv": 10, "rv": 5, "dy": -5, "add": true},
	"iskr_wall": {"blit": ["29_sprIskr.png", 3, 3], "alph": true, "minliv": 10, "rliv": 10, "grav": 0.5, "minv": 1, "rv": 2, "dy": -2, "add": true},
	"burn": {"blit": ["29_sprIskr.png", 3, 3], "alph": true, "minliv": 20, "rliv": 20, "grav": -0.5, "rv": 5, "dy": -3, "add": true},
	"kap": {"blit": ["28_sprKap.png", 3, 3], "alph": true, "minliv": 15, "rliv": 5, "grav": 1.0, "minv": 3, "rv": 3, "dy": -5},
	"magrun": {"blit": ["28_sprKap.png", 3, 3], "alph": true, "minliv": 15, "rliv": 5},
	"acidkap": {"blit": ["31_sprGBlood.png", 5, 5], "alph": true, "minliv": 20, "rliv": 20, "grav": 1.0, "rv": 10, "dy": -6},
	"gblood": {"blit": ["31_sprGBlood.png", 5, 5], "alph": true, "minliv": 20, "rliv": 20, "grav": 1.0, "rv": 5, "dy": -5},
	"pblood": {"blit": ["25_sprPBlood.png", 5, 5], "alph": true, "minliv": 20, "rliv": 20, "grav": 1.0, "rv": 5, "dy": -6},
	"krupa": {"blit": ["27_sprKrupa.png", 5, 5], "alph": true, "minliv": 20, "rliv": 20, "grav": 0.5, "rv": 5, "dy": 3},
	"plakap": {"blit": ["PlasmaKap.png", 14, 22], "origin": [6.0, 14.0], "tex_scale": 0.5, "alph": true, "minliv": 15, "rliv": 5, "grav": 0.6, "rgrav": 0.4, "rdx": 1, "rdy": 2},
	"die_spark": {"vis": "fx_die_spark", "alph": true, "minliv": 20, "rliv": 20, "grav": -0.1, "rgrav": -0.2, "rdx": 1, "rdy": 1, "rsc": 0.7, "add": true},
	"gold_spark": {"vis": "fx_gold_spark", "alph": true, "minliv": 20, "rliv": 10, "add": true, "minv": 8, "rv": 1, "rsc": 0.4, "brake": 0.92},
	"redray": {"vis": "fx_redray", "minliv": 50, "rot": true, "rsc": 0.7, "anim": true, "otklad": 15},
	"sign1": {"vis": "fx_sign1", "minliv": 20, "anim": true},
	"magsymbol": {"vis": "fx_magsymbol", "minliv": 30, "anim": true},
	"zzz": {"vis": "fx_zzz", "alph": true, "minliv": 20, "rliv": 10, "grav": -0.2, "rv": 3, "rsc": 0.6, "brake": 0.95},
	"throw": {"vis": "fx_throw", "anim": true, "minliv": 5},
	"unlock": {"vis": "fx_unlock", "anim": true, "minliv": 17, "add": true},
}
## Emitter maxkol: at most 12 live parts per group (gas clouds, steam).
const MAXKOL := 12
const DEBRIS := "res://assets/sprites/debris/"
## Flash parts (flPlasma, flLaser, flSpark, visualFlare, visualEclipse, visualBum) already live in WeaponFx.
const FLARES := ["plasma", "laser", "spark", "flare", "eclipse", "bum", "bumn"]
## Sounds.xml rows with several <s> children: Sound.ps picks one at random.
const VARIANTS := {"bat": 2, "bloat": 4, "vortex_cut": 3}
const HUM_HOLD := 4

static var _frames_cache := {}

var _parts: Array = []
var _acc := 0.0
var _hums := {}
var _kols := {}
var _add_mat: CanvasItemMaterial


static func host(tree: SceneTree) -> UnitFx:
	if tree == null:
		return null
	var found := tree.get_first_node_in_group("unit_fx") as UnitFx
	if found != null:
		return found
	var scene := tree.current_scene
	if scene == null:
		return null
	var node := UnitFx.new()
	node.name = "UnitFx"
	node.z_index = 6
	node.add_to_group("unit_fx")
	scene.add_child(node)
	return node


## Emitter.emit(id, loc, x, y, {kol, rx, ry, dx, dy, alpha, ...}).
static func emit(tree: SceneTree, id: String, at: Vector2, param: Dictionary = {}) -> void:
	if id in FLARES:
		var kol := mini(int(param.get("kol", 1)), 50)
		for _i in kol:
			_WeaponFx.flare(tree, at + _spread(param), id)
		return
	var h := host(tree)
	if h != null:
		h._cast(id, at, param)


## Sound.ps(id): no distance falloff in the original, only pan.
static func snd(id: String, volume: float = 1.0) -> void:
	if id == "":
		return
	var stem := id
	var n := int(VARIANTS.get(id, 0))
	if n > 0:
		stem = "%s%d" % [id, randi_range(1, n)]
	# units.xml names some die sounds ('expl') that Sounds.xml lacks; the original stays silent.
	if not ResourceLoader.exists("res://assets/sfx/%s.mp3" % stem) and not ResourceLoader.exists("res://assets/sfx/%s.wav" % stem):
		return
	SfxBank.play(stem, volume)


## Sound.pshum(id, vol): a looped hum held at the loudest volume asked this tick.
static func hum(tree: SceneTree, id: String, volume: float) -> void:
	if id == "" or volume <= 0.0:
		return
	var h := host(tree)
	if h != null:
		h._hum(id, volume)


## Unit sndRun: k = (800 - dist) / 800, doubled under 0.5, else full.
static func hum_volume(dist: float, radius: float = 800.0) -> float:
	var k := (radius - dist) / radius
	if k <= 0.0:
		return 0.0
	return k * 2.0 if k < 0.5 else 1.0


static func _spread(param: Dictionary) -> Vector2:
	var rx := float(param.get("rx", 0))
	var ry := float(param.get("ry", 0))
	return Vector2((randf() - 0.5) * rx, (randf() - 0.5) * ry)


func _ready() -> void:
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _cast(id: String, at: Vector2, param: Dictionary) -> void:
	var def: Dictionary = PARTS.get(id, {})
	if def.is_empty():
		return
	var frames := _frames(def)
	if frames.is_empty():
		return
	var kol := mini(int(param.get("kol", 1)), 50)
	var group := int(def.get("maxkol", 0))
	for _i in kol:
		if group > 0 and int(_kols.get(group, 0)) >= MAXKOL:
			return
		if _parts.size() >= MAX_PARTS:
			var old: Dictionary = _parts.pop_front()
			_drop(old)
		var p := _make(def, frames, at + _spread(param), param)
		if group > 0:
			p["group"] = group
			_kols[group] = int(_kols.get(group, 0)) + 1
		_parts.append(p)


func _drop(p: Dictionary) -> void:
	if is_instance_valid(p.node):
		(p.node as Node).queue_free()
	var group := int(p.get("group", 0))
	if group > 0:
		_kols[group] = maxi(0, int(_kols.get(group, 0)) - 1)


func _make(def: Dictionary, frames: Array, at: Vector2, param: Dictionary) -> Dictionary:
	var spr := Sprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	var anim := bool(def.get("anim", false))
	var loop := mini(int(def.get("loop", 0)), frames.size())
	var fr := 0 if anim else randi() % (loop if loop > 0 else frames.size())
	if int(param.get("frame", 0)) > 0:
		fr = mini(int(param.frame) - 1, frames.size() - 1)
	var f: Dictionary = frames[fr]
	spr.texture = f.tex
	spr.offset = f.offset
	var sc := float(f.scale)
	var dsc := float(def.get("scale", 1.0))
	var rsc := float(def.get("rsc", 0))
	if rsc > 0.0:
		dsc = dsc - rsc + randf() * rsc
	sc *= dsc
	sc *= float(param.get("scale", 1.0))
	spr.scale = Vector2(-sc if int(param.get("mirr", 0)) == 1 else sc, sc)
	if bool(def.get("rot", false)):
		spr.rotation = randf() * TAU
	if bool(def.get("add", false)):
		spr.material = _add_mat
	spr.modulate.a = float(param.get("alpha", 1.0))
	var alpha := spr.modulate.a
	if bool(def.get("prealph", false)):
		spr.modulate.a = 0.0
	spr.position = at
	add_child(spr)
	var vel := Vector2.ZERO
	var minv := float(def.get("minv", 0))
	var rv := float(def.get("rv", 0))
	if minv > 0.0 or rv > 0.0:
		var a := randf() * TAU
		vel = Vector2(sin(a), cos(a)) * (randf() * rv + minv)
	vel += Vector2(float(def.get("dx", 0)) + float(param.get("dx", 0)), float(def.get("dy", 0)) + float(param.get("dy", 0)))
	vel.x += (randf() - 0.5) * float(def.get("rdx", 0))
	vel.y += (randf() - 0.5) * float(def.get("rdy", 0))
	var liv := int(randf() * float(def.get("rliv", 0)) + float(def.get("minliv", 10)))
	var otklad := int(def.get("otklad", 0))
	if otklad > 0:
		otklad = int(randf() * otklad + 1)
		spr.visible = false
	return {
		"node": spr, "vel": vel, "liv": liv, "mliv": liv, "frames": frames, "fr": fr, "fp": float(fr), "anim": anim,
		"loop": loop, "fstep": float(def.get("fstep", 1.0)), "otklad": otklad,
		"grav": float(def.get("grav", 0)) + randf() * float(def.get("rgrav", 0)), "brake": float(def.get("brake", 1)),
		"alph": bool(def.get("alph", false)), "prealph": bool(def.get("prealph", false)), "alpha": alpha,
		"dr": (randf() - 0.5) * 0.3 if bool(def.get("rot", false)) else 0.0,
	}


func _frames(def: Dictionary) -> Array:
	var key := str(def.get("vis", "")) if def.has("vis") else str(def.get("debris", "")) if def.has("debris") else str(def.blit[0])
	if _frames_cache.has(key):
		return _frames_cache[key]
	var out: Array = []
	if def.has("debris"):
		var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEBRIS + "debris.json")) if FileAccess.file_exists(DEBRIS + "debris.json") else null
		var row: Dictionary = (table as Dictionary).get(key, {}) if table is Dictionary else {}
		var anchor: Array = row.get("anchor", [0, 0])
		for i in int(row.get("frames", 0)):
			var tex := load(DEBRIS + "%s_%d.png" % [key, i]) as Texture2D
			if tex != null:
				out.append({"tex": tex, "offset": -Vector2(float(anchor[0]), float(anchor[1])), "scale": 1.0})
	elif def.has("vis"):
		var entry := UnitBrain.vis_of(key)
		var tex := load(SHEETS + str(entry.get("sheet", ""))) as Texture2D if not entry.is_empty() else null
		if tex != null:
			var cell: Array = entry.cell
			var anchor: Array = entry.get("anchor", [0, 0])
			var cols := maxi(1, int(entry.get("cols", 1)))
			var scale := float(entry.get("scale", 1))
			for idx_v in entry.clips.stay.frames:
				var idx := int(idx_v)
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2((idx % cols) * float(cell[0]), (idx / cols) * float(cell[1]), float(cell[0]), float(cell[1]))
				out.append({"tex": at, "offset": -Vector2(float(anchor[0]), float(anchor[1])), "scale": scale})
	else:
		var tex := load(BLITS + str(def.blit[0])) as Texture2D
		if tex != null:
			var w := int(def.blit[1])
			var hgt := int(def.blit[2])
			var cols := int(def.get("cols", 0))
			if cols <= 0:
				cols = maxi(1, tex.get_width() / w)
			var cells: Array = def.get("cells", [])
			var count := cells.size()
			if count == 0:
				count = int(def.get("nframes", 0))
			if count == 0:
				count = maxi(1, tex.get_width() / w)
			var origin := Vector2(w, hgt) / 2.0
			var origin_v: Variant = def.get("origin", null)
			if origin_v is Array and origin_v.size() >= 2:
				origin = Vector2(float(origin_v[0]), float(origin_v[1]))
			var tex_scale := float(def.get("tex_scale", 1.0))
			for i in count:
				var cell := int(cells[i]) if not cells.is_empty() else i
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2((cell % cols) * w, int(float(cell) / float(cols)) * hgt, w, hgt)
				out.append({"tex": at, "offset": -origin, "scale": tex_scale})
	_frames_cache[key] = out
	return out


func _hum(id: String, volume: float) -> void:
	var row: Dictionary = _hums.get(id, {})
	if row.is_empty():
		var stream := load("res://assets/sfx/%s.mp3" % id) as AudioStream
		if stream == null:
			return
		stream = stream.duplicate()
		if "loop" in stream:
			stream.set("loop", true)
		var pl := AudioStreamPlayer.new()
		pl.stream = stream
		add_child(pl)
		row = {"pl": pl, "req": 0.0, "vol": 0.0, "hold": 0}
		_hums[id] = row
	row.req = maxf(float(row.req), minf(volume, 1.0))


func _process(delta: float) -> void:
	_acc += delta * TPS
	var n := mini(int(_acc), 4)
	_acc -= int(_acc)
	for _i in n:
		_step()


func _step() -> void:
	var i := 0
	while i < _parts.size():
		var p: Dictionary = _parts[i]
		var spr := p.node as Sprite2D
		if int(p.otklad) > 0 and is_instance_valid(spr):
			p.otklad -= 1
			if int(p.otklad) == 0:
				spr.visible = true
			i += 1
			continue
		p.liv -= 1
		if p.liv <= 0 or not is_instance_valid(spr):
			_drop(p)
			_parts.remove_at(i)
			continue
		spr.position += p.vel
		p.vel.y += p.grav
		p.vel *= p.brake
		spr.rotation += p.dr
		if p.anim or int(p.loop) > 0:
			p.fp += float(p.fstep)
			var frames: Array = p.frames
			if int(p.loop) > 0 and p.fp >= float(p.loop):
				p.fp = 0.0
			p.fr = int(p.fp)
			if p.fr >= frames.size():
				_drop(p)
				_parts.remove_at(i)
				continue
			var f: Dictionary = frames[p.fr]
			spr.texture = f.tex
		if p.alph and p.liv < 9:
			spr.modulate.a = float(p.alpha) * p.liv / 10.0
		elif p.prealph and int(p.mliv) - int(p.liv) < 9:
			spr.modulate.a = float(p.alpha) * (int(p.mliv) - int(p.liv)) / 10.0
		elif p.alph or p.prealph:
			spr.modulate.a = float(p.alpha)
		i += 1
	for id in _hums.keys():
		var row: Dictionary = _hums[id]
		var pl := row.pl as AudioStreamPlayer
		if float(row.req) > 0.0:
			row.vol = row.req
			row.req = 0.0
			row.hold = HUM_HOLD
		if int(row.hold) > 0:
			row.hold -= 1
			pl.volume_db = linear_to_db(float(row.vol))
			if not pl.playing:
				pl.play()
		elif pl.playing:
			pl.stop()
