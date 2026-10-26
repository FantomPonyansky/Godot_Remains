extends RefCounted

## Door and wooden-wall art from texture1.swf vis* clips.
## The map cell is the bottom of the footprint. The clip's origin sits on that
## cell's bottom edge, and the picture is drawn upward (BoundingBox.center).
## hit is the closed clip's solid size. sprite is the PNG's top-left relative
## to that solid, so an opening leaf can hang outside the closed footprint.
## objs.xml tip=door. hp and thre are copied onto the door's tiles (Box.initDoor).
## Tile.udar ignores a hit when thre > char_destroy, then subtracts the full
## destroy value. There is no per-type resistance; mat only picks debris.
## septum is hp 30 with no thre. indoor1–4 are tip=box with no hp, so they stay shut
## until used. A placed indestruct attribute becomes 10000/10000 (Box.as), except begDoor.

const TILE := 40.0
const _DIR := "res://assets/sprites/doors/"
const _ObjArt := preload("res://scripts/map/obj_art.gd")

## id -> [hit_w, hit_h, sprite_x, sprite_y, hp, threshold, breakable]
const SPEC := {
	"door1": [40, 80, 0, 0, 60, 10, 1],
	"door1a": [40, 80, 0, 0, 300, 50, 1],
	"door1b": [40, 80, 0, 0, 400, 50, 1],
	"door2": [40, 80, 0, 0, 1000, 100, 1],
	"door2a": [40, 80, -10, 0, 1000, 100, 1],
	"door3": [40, 120, 0, 0, 5000, 800, 1],
	"door4": [40, 120, 0, 0, 5000, 800, 1],
	"hatch1": [80, 40, 0, -50, 60, 10, 1],
	"hatch2": [80, 40, 0, -8, 1000, 100, 1],
	"indoor1": [51, 85, 0, 0, 0, 0, 0],
	"indoor2": [53, 85, 0, 0, 0, 0, 0],
	"indoor3": [56, 56, 0, 0, 0, 0, 0],
	"indoor4": [53, 85, 0, 0, 0, 0, 0],
	"septum": [40, 120, 0, 0, 30, 0, 1],
	"grate": [40, 120, 0, 0, 1000, 100, 1],
	"hgrate": [120, 40, 0, -80, 1000, 100, 1],
	"window1": [40, 80, 0, 0, 10, 0, 1],
	"window2": [40, 80, 0, 0, 1000, 100, 1],
	"platform1": [120, 40, 0, 0, 5000, 800, 1],
	"alib1": [40, 280, 0, 0, 10000, 1000, 1],
	"alib2": [280, 40, 0, 0, 10000, 1000, 1],
	"basedoor": [40, 120, 0, 0, 4000, 800, 1],
	"encldoor": [40, 120, 0, 0, 4000, 800, 1],
	"enclpole": [40, 120, 0, 0, 5000, 800, 1],
	"stdoor": [40, 120, 0, 0, 1000, 100, 1],
}

## objs.xml mat. E_Material: 1 metal, 3 wood, 5 glass, 7 force field.
const _SURFACE := {
	"septum": "wood", "door1": "wood", "door1a": "wood", "hatch1": "wood",
	"grate": "metal", "hgrate": "metal", "platform1": "metal",
	"door1b": "metal", "door2": "metal", "door2a": "metal", "door3": "metal", "hatch2": "metal",
	"window1": "glass", "window2": "glass",
	"door4": "force", "alib1": "force", "alib2": "force", "enclpole": "force",
	"basedoor": "metal", "encldoor": "metal", "stdoor": "metal",
}

static var _cache: Dictionary = {}


static func drop_cache() -> void:
	_cache.clear()


static func known(id: String) -> bool:
	return SPEC.has(id)


static func spawn(id: String, cell: Vector2, footprint_w: float, opac: float, opened: bool) -> StaticBody2D:
	var spec: Array = SPEC.get(id, [footprint_w, TILE * 2.0, 0, 0, 0, 0, 0])
	var hit := Vector2(float(spec[0]), float(spec[1]))
	if hit.x < 1.0:
		hit.x = footprint_w
	var anchor := Vector2(cell.x + footprint_w * 0.5, cell.y + TILE - 1.0)
	var body := StaticBody2D.new()
	body.set_script(load("res://scripts/door_body.gd"))
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(anchor.x - hit.x * 0.5, anchor.y - hit.y)
	body.set_meta("door_id", id)
	body.set_meta("door_w", hit.x)
	body.set_meta("door_h", hit.y)
	body.set_meta("hp", int(spec[4]))
	body.set_meta("thre", int(spec[5]))
	body.set_meta("breakable", int(spec[6]) != 0)
	body.set_meta("surface", str(_SURFACE.get(id, "")))
	var see := opac < 0.5
	body.set_meta("sight_transparency", 1.0 if see else 0.0)
	body.set_meta("blocks_sight", not see)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	box.size = hit
	shape.shape = box
	shape.position = hit * 0.5
	body.add_child(shape)
	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Box.as: wall objects (doors) go to visObjs[0], under boxes (sloy 1, z -2) and units.
	sprite.z_index = -3
	sprite.position = Vector2(float(spec[2]), float(spec[3]))
	body.add_child(sprite)
	_ObjArt.shade(sprite, id)
	apply(body, opened)
	return body


## Box.as sets hp and thre to 10000 when the placed tag has indestruct.
## begDoor is door3 with locktip 0 and no indestruct. Keep its type stats anyway.
static func apply_instance(body: Node) -> void:
	if str(body.get_meta("uid", "")) == "begDoor":
		return
	if not bool(body.get_meta("indestruct", false)):
		return
	body.set_meta("hp", 10000)
	body.set_meta("thre", 10000)


static func apply(body: Node, is_open: bool) -> void:
	if bool(body.get_meta("dead", false)):
		return
	body.set_meta("door_open", is_open)
	var see := float(body.get_meta("sight_transparency", 0.0)) >= 0.99
	body.set_meta("blocks_sight", not is_open and not see)
	if body is CollisionObject2D:
		(body as CollisionObject2D).collision_layer = 0 if is_open else 1
	var shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.disabled = is_open
	var visual := body.get_node_or_null("Visual") as Sprite2D
	if visual == null:
		return
	var id := str(body.get_meta("door_id", ""))
	var tex := _tex(id, "open" if is_open else "close")
	visual.position = _sprite_at(id)
	visual.modulate = Color(1, 1, 1, 1)
	if tex == null:
		visual.visible = not is_open
		return
	visual.texture = tex
	visual.visible = true


static func break_open(body: Node) -> void:
	if not bool(body.get_meta("dead", false)):
		preload("res://scripts/prop_sfx.gd").node_obj(body, "die")
	body.set_meta("dead", true)
	body.set_meta("door_open", true)
	body.set_meta("blocks_sight", false)
	body.set_meta("usable", false)
	body.set_meta("hp", 0)
	if body is CollisionObject2D:
		(body as CollisionObject2D).collision_layer = 0
	var shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.disabled = true
	var visual := body.get_node_or_null("Visual") as Sprite2D
	if visual == null:
		return
	var id := str(body.get_meta("door_id", ""))
	var tex := _tex(id, "die")
	visual.position = _sprite_at(id)
	visual.modulate = Color(1, 1, 1, 1)
	if tex == null:
		visual.visible = false
		return
	visual.texture = tex
	visual.visible = true


static func _sprite_at(id: String) -> Vector2:
	var spec: Array = SPEC.get(id, [0, 0, 0, 0, 0, 0, 0])
	return Vector2(float(spec[2]), float(spec[3]))


static func _tex(id: String, state: String) -> Texture2D:
	var path := _DIR + id + "_" + state + ".png"
	if _cache.has(path):
		return _cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		var fr := _ObjArt.label_frame(id, state)
		_cache[path] = _ObjArt.texture(id, fr) if fr > 0 else null
		return _cache[path] as Texture2D
	var tex := load(path) as Texture2D
	_cache[path] = tex
	return tex
