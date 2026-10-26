extends Node2D

## Telekinesis.grab: target.vis.filters = [teleFilter], GlowFilter(teleColor, 1, 6, 6, 1, 3),
## and the player's teleTransform tint. Release clears both.
## One glow copy per drawn part sits behind the whole host. Copies reuse the
## part's texture; only a Polygon2D is rasterised, once per shape.

const _WeaponVis := preload("res://scripts/weapon_vis.gd")
const _Look := preload("res://scripts/pony_look.gd")
const _GLOW := preload("res://assets/shaders/glow_filter.gdshader")
## The 13-tap kernel reaches 6 px past the art.
const MARGIN := 7.0

var host: Node2D
## The caster's teleColor. Null is the player's (app.cMagic).
var color: Variant = null
## GlowFilter alpha, strength and blur (sigma ~ blur * 0.49).
var alpha := 1.0
var strength := 1.0
var sigma := 2.96
var _glows: Dictionary = {}


## caster_color: the holder's teleColor (null for the player's own).
static func attach(host: Node, caster_color: Variant = null) -> Node2D:
	if host == null or not is_instance_valid(host):
		return null
	var aura := host.get_node_or_null("MagicAura") as Node2D
	if aura == null:
		aura = (load("res://scripts/magic_aura.gd") as GDScript).new() as Node2D
		aura.name = "MagicAura"
		aura.set("host", host)
		host.add_child(aura)
	aura.set("color", caster_color)
	return aura


static func clear(host: Node) -> void:
	if host == null or not is_instance_valid(host):
		return
	var aura := host.get_node_or_null("MagicAura")
	if aura:
		host.remove_child(aura)
		aura.queue_free()


## UnitPlayer.teleTransform: each multiplier is Appear.trMagic * 0.5 + 1.
static func tele_tint() -> Color:
	var magic := _Look.tint(_Look.state().get("magic", [0, 255, 0]))
	return Color(magic.r * 0.5 + 1.0, magic.g * 0.5 + 1.0, magic.b * 0.5 + 1.0, 1.0)


func _ready() -> void:
	z_index = -1


func _process(_delta: float) -> void:
	if host == null or not is_instance_valid(host):
		queue_free()
		return
	position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	modulate = _undo_modulate()
	var tint: Color = color if color is Color else _WeaponVis.tele_color()
	visible = alpha > 0.0
	if not visible:
		return
	var found: Array = []
	# A unit's vis is its body clip. Its weapon, shield and markers are other objects.
	var body: Variant = host.get("anim") if host.is_in_group("enemies") else null
	if body is CanvasItem:
		found.append(body)
		_walk(body as Node, found)
	else:
		_walk(host, found)
	var seen := {}
	for node in found:
		var id := (node as Node).get_instance_id()
		seen[id] = true
		if not _glows.has(id):
			_glows[id] = _make()
		_update(node, _glows[id], tint)
	for id in _glows.keys():
		if not seen.has(id):
			var glow: Node = _glows[id]
			if is_instance_valid(glow):
				glow.queue_free()
			_glows.erase(id)


func _walk(node: Node, found: Array) -> void:
	for child in node.get_children():
		if child == self or str(child.name) == "MagicAura" or str(child.name) == "Glow" or child.has_meta("no_tele_glow"):
			continue
		if child is Sprite2D or child is AnimatedSprite2D or child is Polygon2D:
			found.append(child)
		_walk(child, found)


func _make() -> Sprite2D:
	var glow := Sprite2D.new()
	var mat := ShaderMaterial.new()
	mat.shader = _GLOW
	mat.set_shader_parameter("margin", MARGIN)
	glow.material = mat
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(glow)
	return glow


func _update(node: Node, glow: Sprite2D, color: Color) -> void:
	var item := node as CanvasItem
	var shown := item.is_visible_in_tree()
	var region := Rect2(0, 0, 1, 1)
	var flip := Vector2.ONE
	if node is Polygon2D:
		shown = shown and _poly_texture(node as Polygon2D, glow)
	else:
		var tex := _texture_of(node)
		shown = shown and tex != null
		if shown:
			glow.texture = tex
			glow.centered = bool(node.get("centered"))
			var off: Variant = node.get("offset")
			glow.offset = off if off is Vector2 else Vector2.ZERO
			glow.flip_h = bool(node.get("flip_h"))
			glow.flip_v = bool(node.get("flip_v"))
			flip = Vector2(-1.0 if glow.flip_h else 1.0, -1.0 if glow.flip_v else 1.0)
			glow.region_enabled = false
			if node is Sprite2D and (node as Sprite2D).region_enabled:
				glow.region_enabled = true
				glow.region_rect = (node as Sprite2D).region_rect
				var size := _base_size(tex)
				region = Rect2(glow.region_rect.position / size, glow.region_rect.size / size)
			elif tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
				var atlas := tex as AtlasTexture
				var size := atlas.atlas.get_size()
				region = Rect2(atlas.region.position / size, atlas.region.size / size)
	glow.visible = shown
	if not shown:
		return
	glow.transform = global_transform.affine_inverse() * (node as Node2D).global_transform
	var mat := glow.material as ShaderMaterial
	mat.set_shader_parameter("glow_color", Color(color.r, color.g, color.b, alpha))
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("sigma", sigma)
	mat.set_shader_parameter("region", Vector4(region.position.x, region.position.y, region.end.x, region.end.y))
	mat.set_shader_parameter("flip", flip)


func _texture_of(node: Node) -> Texture2D:
	if node is Sprite2D:
		return (node as Sprite2D).texture
	if node is AnimatedSprite2D:
		var anim := node as AnimatedSprite2D
		if anim.sprite_frames == null:
			return null
		var which := anim.animation
		if not anim.sprite_frames.has_animation(which):
			return null
		return anim.sprite_frames.get_frame_texture(which, anim.frame)
	return null


func _base_size(tex: Texture2D) -> Vector2:
	if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
		return (tex as AtlasTexture).atlas.get_size()
	return Vector2(maxf(tex.get_width(), 1), maxf(tex.get_height(), 1))


func _poly_texture(poly: Polygon2D, glow: Sprite2D) -> bool:
	var points := poly.polygon
	if points.size() < 3:
		return false
	var key := hash(points)
	if glow.get_meta("poly_key", 0) == key and glow.texture != null:
		return true
	var box := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	var w := maxi(int(ceil(box.size.x)), 1)
	var h := maxi(int(ceil(box.size.y)), 1)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			if Geometry2D.is_point_in_polygon(box.position + Vector2(x + 0.5, y + 0.5), points):
				img.set_pixel(x, y, Color.WHITE)
	glow.texture = ImageTexture.create_from_image(img)
	glow.centered = false
	glow.offset = box.position + poly.offset
	glow.region_enabled = false
	glow.flip_h = false
	glow.flip_v = false
	glow.set_meta("poly_key", key)
	return true


func _undo_modulate() -> Color:
	var chain := Color.WHITE
	var node: Node = get_parent()
	while node is CanvasItem:
		chain *= (node as CanvasItem).modulate
		node = node.get_parent()
	return Color(1.0 / maxf(chain.r, 0.05), 1.0 / maxf(chain.g, 0.05), 1.0 / maxf(chain.b, 0.05), 1.0)
