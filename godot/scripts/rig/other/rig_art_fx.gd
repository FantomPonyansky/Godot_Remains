class_name RigArtFx extends Node2D
## Step 19.2: the art-side effects a generated rig cannot express as plain nodes inside its
## `osn/body` CanvasGroup (P1: no group inside the group; a blend shader under a group reads
## the group's back buffer, not the scene). Emitted by tools/manifest2tscn.py as the `art_fx`
## child of the rig root, right after `osn` (before the front attachments); never hand-edited.
##
## (1) Blend mirrors (`metadata/mirrors`: [{source, mirror, blend}]). A blended leaf inside
##     `body` (the turret muzzle flares, steel's sparks, necrboss' `fiol`, visualscene's flares,
##     the player's `magic`/`sin`, turret5's `tur_cr` shield) stays where it is -- its path, frame
##     ranges, visibility, transforms and texture swaps remain rig_base's -- drawn with the plain
##     colour-transform material at self_modulate alpha 0, and a mirror Sprite2D under this node
##     (outside the group) draws it with the blend shader against the scene. Every frame
##     (process_priority MIRROR_PRIORITY: after the World's clip advance and the unit drivers)
##     the mirror copies the source's visibility in tree, global transform, texture/region/offset/
##     flip, its colour-transform uniforms and the modulate accumulated from the source up to the
##     rig root (bone brightness, the bone alpha of `tur_cr`), times `body.self_modulate` (stealth).
##     A mirror draws over the whole body (front-most flares: exact; a blended leaf that sits
##     between bones: a deviation recorded per rig in 19_2_art_effects/results.md). One screen
##     copy precedes the mirrors when one of them is shown (EntityEffects.BlendCopy, the 19.3 copy
##     policy, when that class exists; else a BackBufferCopy in viewport mode toggled here).
##     19.4: while `body` carries a FilterStack the leaf draws itself in the group with the blend
##     material and the mirror hides (Flash blends the leaves of a filtered clip inside its
##     offscreen bitmap, against the body alone; a hideObject shadow hides them too).
## (2) Library filters (`metadata/filters`: [{sprite, filters, source, frames}]), D-I's sprite-local
##     form: EntityEffects.sprite_set_filters on the listed bone sprite while the rig's source
##     timeline (`source`; "" = always) shows a frame inside `frames` ([[a, b], ...] 0-based source
##     frames; [] = always). A tween ramp from the zero form is stepped (on from its end key; the
##     XFL records carry the zero form on the ramp frames). The sprite's previous colour-transform
##     material keeps receiving rig_base's channel tints and transforms; its ct uniforms are copied
##     into the shown material every frame (19.1: the local CT carries the bone's tint).
## (3) 26.5 (D26-074) merged groups (`metadata/group_filters`: [{group, sprites, filters, source,
##     frames}]): a glow/shadow bone filter on a node of several static sprites (visualscene's
##     `encl_sym`, the game-over title of `sceneGO`). Flash filters the composite of the sprites, so
##     while the filter is on the sprites are merged once (in draw order, at their common texel
##     scale) into one texture on a `_fx_merged` Sprite2D under the group node, which carries the
##     sprite-local stack; the sources stop drawing (self_modulate alpha 0) and draw again when off.
## (4) 2026-10-11 (human verdict D-09): the root symbol's own instance filters (index.json
##     attachments[].filters). A record of (2) may carry `blend` (the megadron `dis`: glow, then
##     the attachment's screen blend -- the local blend shader draws filter -> CT -> alpha -> blend
##     against the scene, as Flash blends the filtered instance); a group of (3) may be the whole
##     `osn/body` with its sprites at any depth (the spectre's `osn` glow: the static bones merged
##     at their transforms relative to the group, the merged sprite after the last source's
##     branch, the bones' colour transform copied into it every frame; a runtime body stack still
##     applies on top, as Flash nests the `osn` filter inside `vis.filters`).

const MIRROR_PRIORITY := 1000

var _rig: Node = null
var _body: CanvasItem = null
var _mirrors: Array[Dictionary] = []     # {src: Sprite2D, dst: Sprite2D, chain: Array[CanvasItem]}
var _filters: Array[Dictionary] = []     # {spr, list: Array[FlashFilter], source, frames, on, tex, ct_mat}
var _groups: Array[Dictionary] = []      # 26.5: {node, sprs, list, source, frames, on, merged}
var _copy: BackBufferCopy = null
var _copy_is_policy := false
var _ready_done := false


func _ready() -> void:
	process_priority = MIRROR_PRIORITY
	# a follower of the rig's state, never of its clock: a driver that disables the rig's
	# processing (the tick-driven harnesses, PROCESS_MODE_DISABLED) must not freeze the mirrors
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rig = get_parent()
	if _rig == null:
		return
	if _rig.is_node_ready():
		_setup()
	else:
		_rig.ready.connect(_setup, CONNECT_ONE_SHOT)


func _setup() -> void:
	if _ready_done or _rig == null:
		return
	_ready_done = true
	_body = _rig.get_node_or_null("osn/body") as CanvasItem
	for rec: Dictionary in get_meta("mirrors", []):
		var src := _rig.get_node_or_null(NodePath(str(rec.get("source", "")))) as Sprite2D
		var dst := get_node_or_null(NodePath(str(rec.get("mirror", "")))) as Sprite2D
		if src == null or dst == null:
			push_error("RigArtFx: %s: mirror %s -> %s unresolved" % [_rig.name, rec.get("source"), rec.get("mirror")])
			continue
		var chain: Array[CanvasItem] = []
		var n: Node = src.get_parent()
		while n != null and n != _rig:
			if n is CanvasItem:
				chain.append(n)
			n = n.get_parent()
		dst.visible = false
		_mirrors.append({"src": src, "dst": dst, "chain": chain, "plain": src.material, "stacked": false})
	if not _mirrors.is_empty():
		_make_copy()
	for rec: Dictionary in get_meta("filters", []):
		var spr := _rig.get_node_or_null(NodePath(str(rec.get("sprite", "")))) as Sprite2D
		if spr == null:
			push_error("RigArtFx: %s: filtered sprite %s unresolved" % [_rig.name, rec.get("sprite")])
			continue
		var list: Array = EntityEffects.copy_stack(rec.get("filters", []))
		if list.is_empty():
			continue
		var blend := str(rec.get("blend", "normal")).to_lower()
		if blend != "normal" and (not EntityEffects.BLEND_ID.has(blend) or FlashUiBlend.under_canvas_group(spr)):
			push_error("RigArtFx: %s: %s: blend '%s' cannot be drawn here (drawn normal)" % [_rig.name, rec.get("sprite"), blend])
			blend = "normal"
		_filters.append({"spr": spr, "list": list, "source": str(rec.get("source", "")),
				"frames": rec.get("frames", []), "on": false, "tex": null,
				"ct_mat": spr.material as ShaderMaterial, "blend": blend})
	for rec: Dictionary in get_meta("group_filters", []):
		var g := _rig.get_node_or_null(NodePath(str(rec.get("group", "")))) as Node2D
		var sprs: Array = []
		for sp in rec.get("sprites", []):
			var s2 := _rig.get_node_or_null(NodePath(str(sp))) as Sprite2D
			if s2 != null:
				sprs.append(s2)
		var glist: Array = EntityEffects.copy_stack(rec.get("filters", []))
		if g == null or sprs.size() < 2 or glist.is_empty():
			push_error("RigArtFx: %s: merged group %s unresolved" % [_rig.name, rec.get("group")])
			continue
		sprs.sort_custom(func(a, b): return _draws_before(a, b, g))
		_groups.append({"node": g, "sprs": sprs, "list": glist, "source": str(rec.get("source", "")),
				"frames": rec.get("frames", []), "on": false, "merged": null})
	_update()


func _make_copy() -> void:
	var consts: Dictionary = (EntityEffects as Script).get_script_constant_map()
	if consts.has("BlendCopy"):
		_copy = consts["BlendCopy"].new()
		_copy.set("target", (_mirrors[0]["dst"] as Sprite2D))
		_copy_is_policy = true
	else:
		_copy = BackBufferCopy.new()
		_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		_copy.visible = false
	_copy.name = "blend_copy"
	add_child(_copy)
	move_child(_copy, 0)


func _process(_delta: float) -> void:
	if _ready_done:
		_update()


func _update() -> void:
	var shown := 0
	var body_a := 1.0
	if _body != null:
		body_a = _body.self_modulate.a
	# 19.4: while `body` carries a FilterStack (the player's setFilters, emergence, NecrBoss'
	# shadow/ghost) Flash renders the filtered clip into an offscreen bitmap first, so its
	# blended leaves blend inside that bitmap -- against the body alone, never the scene (and a
	# hideObject shadow hides them too). The source then draws itself in the group with the
	# blend material (the group's back buffer is exactly that bitmap) and the mirror is hidden;
	# without a stack the mirror draws against the scene (19.2).
	var stacked := _body is CanvasGroup and not FilterStack.record(_body).is_empty()
	for m: Dictionary in _mirrors:
		var src: Sprite2D = m["src"]
		var dst: Sprite2D = m["dst"]
		if not is_instance_valid(src):
			dst.visible = false
			continue
		if stacked != bool(m["stacked"]):
			m["stacked"] = stacked
			if stacked:
				src.material = dst.material
				src.self_modulate.a = 1.0
			else:
				src.material = m["plain"]
				src.self_modulate.a = 0.0
		if stacked:
			dst.visible = false
			var pm := m["plain"] as ShaderMaterial
			var bm := dst.material as ShaderMaterial
			if pm != null and bm != null:
				for p in ["ct_multiply", "ct_offset", "ct_brightness"]:
					var v: Variant = pm.get_shader_parameter(p)
					if v != null:
						bm.set_shader_parameter(p, v)
			continue
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
		dst.hframes = src.hframes
		dst.vframes = src.vframes
		dst.frame = src.frame
		dst.global_transform = src.global_transform
		var mod := Color(src.self_modulate.r, src.self_modulate.g, src.self_modulate.b, 1.0) * src.modulate
		for c: CanvasItem in m["chain"]:
			mod *= c.modulate
		mod.a *= body_a
		dst.modulate = mod
		var sm := src.material as ShaderMaterial
		var dm := dst.material as ShaderMaterial
		if sm != null and dm != null:
			for p in ["ct_multiply", "ct_offset", "ct_brightness"]:
				var v: Variant = sm.get_shader_parameter(p)
				if v != null:
					dm.set_shader_parameter(p, v)
	if _copy != null and not _copy_is_policy:
		_copy.visible = shown > 0
	elif _copy != null and _copy_is_policy and shown > 0:
		# the policy's target is the first shown mirror (decide_copy reads its visibility)
		for m: Dictionary in _mirrors:
			if (m["dst"] as Sprite2D).visible:
				_copy.set("target", m["dst"])
				break
	for f: Dictionary in _filters:
		_update_filter(f)
	for g: Dictionary in _groups:
		_update_group(g)
		_sync_group_ct(g)


## 26.5 (D26-074): a merged group on/off with its source frames (see the header, (3)).
func _update_group(g: Dictionary) -> void:
	var on := _source_frame_on(g)
	if on and g["merged"] == null:
		g["merged"] = _merge(g)
		if g["merged"] == null:
			return   # a source texture not loaded yet (lazy): next frame
	if on == g["on"]:
		return
	g["on"] = on
	var m: Sprite2D = g["merged"]
	if m != null:
		m.visible = on
		EntityEffects.sprite_set_filters(m, EntityEffects.copy_stack(g["list"]) if on else [])
		# asset-fidelity P2 (2026-10-12): the installed local stack keeps one-tap sampling (footprint 0) - Flash runs a
		# filter's kernel over the symbol's raster at texel resolution; footprint-sampling the source under the glow
		# kernel blurred the megadron `dis` cell (gallery lib_megadron_dis p99 23/255 vs 1.2 with one tap).
	for s: Sprite2D in g["sprs"]:
		if is_instance_valid(s):
			s.self_modulate.a = 0.0 if on else 1.0


## (4) The merged sprite draws the bones' colour transform (the room tint, a dieTransform):
## copied from the first source's material every frame (the sources share the bone tint).
func _sync_group_ct(g: Dictionary) -> void:
	var m: Sprite2D = g["merged"]
	if not g["on"] or m == null or (g["sprs"] as Array).is_empty():
		return
	var src := (g["sprs"][0] as Sprite2D).material as ShaderMaterial
	var dst := m.material as ShaderMaterial
	if src == null or dst == null or src == dst:
		return
	for p in ["ct_multiply", "ct_offset"]:
		var v: Variant = src.get_shader_parameter(p)
		if v != null:
			dst.set_shader_parameter(p, v)


## A sprite's transform relative to the group node (the product of its ancestors' up to it;
## null when the node is not an ancestor).
static func _rel_xform(s: Node, node: Node) -> Variant:
	var t := Transform2D.IDENTITY
	var n: Node = s
	while n != null and n != node:
		if n is Node2D:
			t = (n as Node2D).transform * t
		n = n.get_parent()
	return t if n == node else null


## Draw order under the group node: the sibling indices from the node down, compared in turn.
static func _draws_before(a: Node, b: Node, g: Node) -> bool:
	var ka := _order_key(a, g)
	var kb := _order_key(b, g)
	for i in mini(ka.size(), kb.size()):
		if ka[i] != kb[i]:
			return ka[i] < kb[i]
	return ka.size() < kb.size()


static func _order_key(s: Node, g: Node) -> Array:
	var k: Array = []
	var n: Node = s
	while n != null and n != g:
		k.push_front(n.get_index())
		n = n.get_parent()
	return k


## The group's sprites composited in draw order into one texture at their common texel scale
## (null while a texture is missing or the sprites differ in scale/rotation: then unmerged).
func _merge(g: Dictionary) -> Sprite2D:
	var sprs: Array = g["sprs"]
	var node: Node2D = g["node"]
	var rel: Array = []
	for s: Sprite2D in sprs:
		rel.append(_rel_xform(s, node))
	var sc: Vector2 = (rel[0] as Transform2D).get_scale() if rel[0] != null else Vector2.ZERO
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in sprs.size():
		var s: Sprite2D = sprs[i]
		if s.texture == null:
			return null
		var t: Variant = rel[i]
		if t == null or not (t as Transform2D).get_scale().is_equal_approx(sc) \
				or absf((t as Transform2D).x.y) > 1e-6 or absf((t as Transform2D).y.x) > 1e-6 \
				or sc.x <= 0.0 or sc.y <= 0.0 \
				or s.region_enabled or s.hframes != 1 or s.vframes != 1:
			push_error("RigArtFx: %s: group %s: sprites differ in scale/rotation; not merged" % [_rig.name, g["node"].name])
			g["sprs"] = []
			return null
		var o := (t as Transform2D).origin / sc + s.offset
		lo = lo.min(o)
		hi = hi.max(o + s.texture.get_size())
	var size := Vector2i((hi - lo).ceil())
	var img := Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
	for i in sprs.size():
		var s: Sprite2D = sprs[i]
		var si := s.texture.get_image()
		if si == null:
			return null
		if si.is_compressed():
			si.decompress()
		si.clear_mipmaps()
		si.convert(Image.FORMAT_RGBA8)
		var o := (rel[i] as Transform2D).origin / sc + s.offset - lo
		img.blend_rect(si, Rect2i(Vector2i.ZERO, si.get_size()), Vector2i(o.round()))
	var m := Sprite2D.new()
	m.name = "_fx_merged"
	m.centered = false
	m.scale = sc
	m.offset = lo
	m.texture = ImageTexture.create_from_image(img)
	m.visible = false
	# after the group's child that holds the last source (the source itself for a flat group)
	var last: Node = sprs[sprs.size() - 1]
	while last.get_parent() != node:
		last = last.get_parent()
	node.add_child(m)
	node.move_child(m, last.get_index() + 1)
	return m


func _source_frame_on(f: Dictionary) -> bool:
	var frames: Array = f["frames"]
	var source: String = f["source"]
	if source == "" and frames.is_empty():
		return true
	if not (_rig.has_method("get_current_anim") and _rig.has_method("get_anim_meta")
			and _rig.has_method("get_flash_frame")):
		return true
	var cur: String = _rig.get_current_anim()
	var meta: Dictionary = _rig.get_anim_meta(cur)
	if source != "" and str(meta.get("source", cur)) != source:
		return false
	if frames.is_empty():
		return true
	var fr: int = int(_rig.get_flash_frame()) - 1
	for r in frames:
		if fr >= int(r[0]) and fr <= int(r[1]):
			return true
	return false


func _update_filter(f: Dictionary) -> void:
	var spr: Sprite2D = f["spr"]
	if not is_instance_valid(spr):
		return
	var on := _source_frame_on(f)
	if on != f["on"]:
		f["on"] = on
		if on:
			# (4): the attachment's blend drawn by the local blend shader after the filters
			EntityEffects.sprite_state(spr)["blend"] = f.get("blend", "normal")
			EntityEffects.sprite_set_filters(spr, EntityEffects.copy_stack(f["list"]))
		else:
			EntityEffects.sprite_state(spr)["blend"] = "normal"
			EntityEffects.sprite_set_filters(spr, [])
			spr.material = f["ct_mat"]   # back to the bone's own colour-transform material (and blend)
		f["tex"] = spr.texture
	elif on and spr.texture != f["tex"]:
		f["tex"] = spr.texture
		EntityEffects.sprite_geometry_changed(spr)
	# the bone's colour transform: rig_base writes the original material; the shown one copies it
	var ct_mat: ShaderMaterial = f["ct_mat"]
	var cur := spr.material as ShaderMaterial
	if ct_mat != null and cur != null and cur != ct_mat:
		cur.set_shader_parameter("ct_multiply", ct_mat.get_shader_parameter("ct_multiply"))
		var off: Variant = ct_mat.get_shader_parameter("ct_offset")
		if off != null:
			cur.set_shader_parameter("ct_offset", off)


## Test/inspection surface: the mirror and filter records.
func get_mirrors() -> Array[Dictionary]:
	return _mirrors


func get_filter_records() -> Array[Dictionary]:
	return _filters


func get_group_records() -> Array[Dictionary]:
	return _groups
