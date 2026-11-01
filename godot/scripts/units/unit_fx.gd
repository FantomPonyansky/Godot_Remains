extends Node2D
class_name UnitFx
## Emitter.cast / Part.step for the parts the vclass units throw (parts.xml rows),
## plus their Sound.ps one-shots (Sounds.xml variants) and Sound.pshum hums.
## One host per scene in group "unit_fx"; parts tick at the original 30 Hz.

const _WeaponFx := preload("res://scripts/weapon_fx.gd")
const _StatusPart := preload("res://scripts/status_part.gd")
const TPS := 30.0
const MAX_PARTS := 400
const SHEETS := "res://assets/sprites/sheets/units/"
const BLITS := "res://assets/fx_blits/"

## parts.xml: vis = packed fx_* symbol, blit = [png, cell w, cell h].
const PARTS_PATH := "res://assets/data/unit_parts.json"
static var PARTS: Dictionary = {}


static func _load_parts() -> bool:
	var data: Variant = DataLib.load(PARTS_PATH)
	if data is Dictionary:
		PARTS = data
	return true


static var _parts_ready: bool = _load_parts()
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
		stem = "%s%d" % [id, Rng.randi_range(&"fx", 1, n)]
	# units.xml names some die sounds ('expl') that Sounds.xml lacks; the original stays silent.
	if not ResourceLoader.exists("res://assets/sfx/%s.mp3" % stem) and not ResourceLoader.exists("res://assets/sfx/%s.wav" % stem):
		return
	Fx.sound(stem, Vector2.ZERO, {"volume": volume})


## Sound.pshum(id, vol): a looped hum held at the loudest volume asked this tick.
static func hum(tree: SceneTree, id: String, volume: float) -> void:
	if id == "" or volume <= 0.0 or tree == null:
		return
	if host(tree) == null:
		return
	Fx.sound(id, Vector2.ZERO, {"volume": volume, "hum": true})


## Unit sndRun: k = (800 - dist) / 800, doubled under 0.5, else full.
static func hum_volume(dist: float, radius: float = 800.0) -> float:
	var k := (radius - dist) / radius
	if k <= 0.0:
		return 0.0
	return k * 2.0 if k < 0.5 else 1.0


static func _spread(param: Dictionary) -> Vector2:
	var rx := float(param.get("rx", 0))
	var ry := float(param.get("ry", 0))
	return Vector2((Rng.randf(&"fx") - 0.5) * rx, (Rng.randf(&"fx") - 0.5) * ry)


var _playing := false


func _ready() -> void:
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if not Fx.particled.is_connected(_on_fx_particles):
		Fx.particled.connect(_on_fx_particles)
	if not Fx.sounded.is_connected(_on_fx_hum):
		Fx.sounded.connect(_on_fx_hum)
	if not Fx.flashed.is_connected(_on_fx_flash):
		Fx.flashed.connect(_on_fx_flash)


## Playback must not emit Fx again. _playing drops a re-entrant particle.
func _on_fx_particles(kind: String, at: Vector2, opts: Dictionary, _eid: String, _local: bool) -> void:
	if _playing:
		return
	_playing = true
	if opts.has("sparks"):
		_WeaponFx.sparks(get_tree(), at, int(opts.sparks))
	elif bool(opts.get("flare", false)):
		_WeaponFx.flare(get_tree(), at, kind)
	elif bool(opts.get("status", false)):
		_StatusPart.emit(get_tree(), kind, at)
	else:
		UnitFx.emit(get_tree(), kind, at, opts)
	_playing = false


## Bullet tracer ghost. Same sprite (or the thin line when the shot has no texture)
## that bullet.gd used to parent on the current scene for 0.06 s.
func _on_fx_flash(at: Vector2, opts: Dictionary, _eid: String, _local: bool) -> void:
	if not bool(opts.get("tracer", false)):
		return
	var host := get_tree().current_scene
	if host == null:
		return
	var life := float(opts.get("life", 0.06))
	if bool(opts.get("line", false)):
		var line := Line2D.new()
		line.width = float(opts.get("width", 2.0))
		var color: Variant = opts.get("color", Color(1.0, 0.28, 0.18))
		line.default_color = color if color is Color else Color(1.0, 0.28, 0.18)
		var a: Vector2 = opts.get("from", at)
		var b: Vector2 = opts.get("to", at)
		line.points = PackedVector2Array([host.to_local(a), host.to_local(b)])
		host.add_child(line)
		get_tree().create_timer(life).timeout.connect(line.queue_free)
		return
	var ghost := Sprite2D.new()
	var tex: Variant = opts.get("texture")
	if tex is Texture2D:
		ghost.texture = tex
	ghost.centered = bool(opts.get("centered", false))
	var off: Variant = opts.get("offset", Vector2.ZERO)
	if off is Vector2:
		ghost.offset = off
	ghost.texture_filter = int(opts.get("filter", CanvasItem.TEXTURE_FILTER_PARENT_NODE))
	var mat: Variant = opts.get("material")
	if mat is Material:
		ghost.material = mat
	var mod: Variant = opts.get("modulate", Color.WHITE)
	if mod is Color:
		ghost.modulate = mod
	ghost.rotation = float(opts.get("rotation", 0.0))
	var sc: Variant = opts.get("scale", Vector2.ONE)
	if sc is Vector2:
		ghost.scale = sc
	host.add_child(ghost)
	var tip: Vector2 = opts.get("to", at)
	ghost.global_position = tip
	get_tree().create_timer(life).timeout.connect(ghost.queue_free)


func _on_fx_hum(id: String, _at: Vector2, opts: Dictionary, _eid: String, _local: bool) -> void:
	if not bool(opts.get("hum", false)):
		return
	_hum(id, float(opts.get("volume", 1.0)))


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
	var fr := 0 if anim else Rng.randi(&"fx") % (loop if loop > 0 else frames.size())
	if int(param.get("frame", 0)) > 0:
		fr = mini(int(param.frame) - 1, frames.size() - 1)
	var f: Dictionary = frames[fr]
	spr.texture = f.tex
	spr.offset = f.offset
	var sc := float(f.scale)
	var dsc := float(def.get("scale", 1.0))
	var rsc := float(def.get("rsc", 0))
	if rsc > 0.0:
		dsc = dsc - rsc + Rng.randf(&"fx") * rsc
	sc *= dsc
	sc *= float(param.get("scale", 1.0))
	spr.scale = Vector2(-sc if int(param.get("mirr", 0)) == 1 else sc, sc)
	if bool(def.get("rot", false)):
		spr.rotation = Rng.randf(&"fx") * TAU
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
		var a := Rng.randf(&"fx") * TAU
		vel = Vector2(sin(a), cos(a)) * (Rng.randf(&"fx") * rv + minv)
	vel += Vector2(float(def.get("dx", 0)) + float(param.get("dx", 0)), float(def.get("dy", 0)) + float(param.get("dy", 0)))
	vel.x += (Rng.randf(&"fx") - 0.5) * float(def.get("rdx", 0))
	vel.y += (Rng.randf(&"fx") - 0.5) * float(def.get("rdy", 0))
	var liv := int(Rng.randf(&"fx") * float(def.get("rliv", 0)) + float(def.get("minliv", 10)))
	var otklad := int(def.get("otklad", 0))
	if otklad > 0:
		otklad = int(Rng.randf(&"fx") * otklad + 1)
		spr.visible = false
	return {
		"node": spr, "vel": vel, "liv": liv, "mliv": liv, "frames": frames, "fr": fr, "fp": float(fr), "anim": anim,
		"loop": loop, "fstep": float(def.get("fstep", 1.0)), "otklad": otklad,
		"grav": float(def.get("grav", 0)) + Rng.randf(&"fx") * float(def.get("rgrav", 0)), "brake": float(def.get("brake", 1)),
		"alph": bool(def.get("alph", false)), "prealph": bool(def.get("prealph", false)), "alpha": alpha,
		"dr": (Rng.randf(&"fx") - 0.5) * 0.3 if bool(def.get("rot", false)) else 0.0,
	}


func _frames(def: Dictionary) -> Array:
	var key := str(def.get("vis", "")) if def.has("vis") else str(def.get("debris", "")) if def.has("debris") else str(def.blit[0])
	if _frames_cache.has(key):
		return _frames_cache[key]
	var out: Array = []
	if def.has("debris"):
		var table: Variant = DataLib.load(DEBRIS + "debris.json") if FileAccess.file_exists(DEBRIS + "debris.json") else null
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
