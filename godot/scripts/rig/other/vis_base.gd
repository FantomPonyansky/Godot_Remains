class_name VisBase extends Node2D
## The one visual contract (Step 10.2, decision V1): every Flash `vis` the game
## drives is a VisBase — the 07 recorder `VisStub`, the generated rigs
## (`RigBase`), the tweened strips (`StripVis`) and the sprite-sheet bodies
## (`BlitVis`). 07's names are canonical (`vis_goto`, `vis_play`, `child`,
## `set_alpha`, `current_frame`, …); the one-piece spec's names map as in the
## Step 10 index ("V1"). Instances come from `VisRegistry.make`/`make_obj`
## (Res.getClass / grafon.getObj), never null.
##
## Frames: every frame argument and `current_frame` are 1-based Flash frames;
## the strip and rig metadata are 0-based and each adapter converts once.
## Mirroring is the root's `scale.x = storona` (`vis.scaleX = storona`, 22 AS3
## sites; there is no set_facing in the contract), never `flip_h`.
## `visible`, `position`, `scale`, `rotation` are the native Node2D ones.
##
## The base bodies are inert defaults (a one-frame MovieClip with no labels);
## the subclasses override the `_vb_*` hooks and the timeline methods.

## Label lookups that failed (the AS3 ArgumentError) and frames < 1, across
## every visual (read through `VisStub.missing_labels`, 07's name).
static var missing_labels: int = 0

const _REGISTRY_SCRIPT := "res://scripts/entity/vis_registry.gd"

## The linkage (class) name of the symbol.
var symbol: String = ""
## True when the class did not resolve (the AS3 `new null`; VisStub fallback).
var missing: bool = false
## Filters last assigned with set_filters: the list as given (a shallow copy of the
## array, the FlashFilter objects themselves -- the replays and the 10/14/16 verifiers
## compare them by identity). What is shown is the host's deep copy (Step 19.1, D-K).
var filters: Array = []

## DisplayObject.blendMode ("normal", "screen", "hardlight", …): recorded and
## rendered by the adapters (Step 19.1: strips/blits through EntityEffects; a rig
## records a root blend it cannot draw -- `RigBase.fx_blend_refused`).
var blend: String = "normal":
	set(v):
		blend = v
		_vb_blend_set(v)
## DisplayObject.transform.colorTransform (ColorTr: `off` in −255..255); the
## setter applies it.
var color_transform: ColorTr = null:
	set(v):
		color_transform = v
		_vb_color_transform_set(v)
## DisplayObject.cacheAsBitmap (recorded; no Godot meaning until Step 19).
var cache_as_bitmap: bool = false:
	set(v):
		cache_as_bitmap = v
		_vb_cache_as_bitmap_set(v)

## MovieClip.currentFrame (1-based).
var current_frame: int:
	get:
		return _vb_current_frame()
	set(v):
		_vb_frame = v
## MovieClip.totalFrames.
var total_frames: int:
	get:
		return _vb_total_frames()
	set(v):
		_vb_total = v
## MovieClip.isPlaying.
var playing: bool:
	get:
		return _vb_playing()
	set(v):
		_vb_play = v
## MovieClip.currentFrameLabel: the label on the current frame, "" when none.
var current_label: String:
	get:
		return _vb_current_label()

## DisplayObject.width/height = getBounds(parent).width/height: the axis-aligned
## box of the current frame's bounds through this node's transform (rotation
## included — D9, review B5: Emitter.as:201 divides by the rotated `len`'s
## width), rounded to twips (Flash reports twips/20; Box.scX/scY and Loot
## depend on it). Unrotated this is rect × |scale|, as before.
var width: float:
	get:
		return roundf(bounds_in_parent().size.x * 20.0) / 20.0
var height: float:
	get:
		return roundf(bounds_in_parent().size.y * 20.0) / 20.0

# Storage behind the default hooks (VisStub and the one-frame clips use them).
var _vb_frame: int = 1
var _vb_total: int = 1
var _vb_play: bool = false
## Own-space bounds of an inert node (a strip's named child: its recorded bounds).
var _vb_own_rect: Rect2 = Rect2()


# ---------------------------------------------------------------- timeline

## gotoAndStop(label | 1-based frame). An unknown label or a frame < 1 keeps
## the frame and counts in missing_labels.
func vis_goto(target) -> void:
	_vb_seek(target)


## gotoAndPlay(target); null = play().
func vis_play(target = null) -> void:
	if target != null:
		_vb_seek(target)
	_vb_play = true


## stop()
func vis_stop() -> void:
	_vb_play = false


## The `try { gotoAndStop(label) } catch` fallbacks become `if has_label(...)`.
func has_label(_label: String) -> bool:
	return false


# ---------------------------------------------------------------- children

## `vis.<name>`: the named child (dotted paths walk down), or null.
func child(path: String) -> VisBase:
	var cur: VisBase = self
	for part in path.split(".", false):
		if cur == null:
			return null
		cur = cur._vb_child_one(part.strip_edges())
	return cur if cur != self else null


## `addChild(new X())`: an instance resolved through the registry, added under
## `name`; it counts in this visual's bounds.
func add_vis_child(n: String, sym: String) -> VisBase:
	# loaded by path: a static reference would make every VisBase (rig_base.gd
	# too, run with --script) compile VisRegistry → VisStub → World
	var v: VisBase = load(_REGISTRY_SCRIPT).make(sym)
	v.set_meta("vis_added", true)
	if n != "":
		v.name = n
	add_child(v)
	return v


# ---------------------------------------------------------------- display

## alpha
func set_alpha(a: float) -> void:
	modulate.a = a


## `filters = [...]` (Step 19.1, D-K): recorded (`filters`, the array shallow-copied:
## Emitter.fils is shared) and shown through the adapter's host as DEEP COPIES taken
## now -- Flash copies `filters` on assignment, so a later write to a held
## FlashFilter (`dieFilter.alpha`, UnitPlayer.as:2580) shows nothing until the next
## `set_filters`. An equal structure only updates the changed parameters (no rebuild).
## Entries: FlashFilter, a 08.1 filter dict, or an XFL-style dict (`{"type":
## "GlowFilter", "blurX": "4"}` -> FlashFilter.from_xfl with the Animate defaults);
## anything else is refused with an error (EntityEffects.to_filter).
func set_filters(stack: Array) -> void:
	filters = stack.duplicate()
	if _vb_fx_host():
		_vb_filters_set(EntityEffects.copy_stack(stack))


## The per-tick parameter path (Step 19.1, D-K; emergence Unit.as:787-797): one
## parameter of the shown filter `index` (and of the recorded one), no copy of the
## list, no rebuild.
func set_filter_param(index: int, param: String, value) -> void:
	if index < 0 or index >= filters.size():
		push_error("%s: set_filter_param: no filter %d" % [self, index])
		return
	if filters[index] is FlashFilter:
		(filters[index] as FlashFilter)._set_param(param, value)
	if _vb_fx_host():
		_vb_filter_param(index, param, value)


## `<child>.text = s` (`numb.text`, `text.text`): the `texts` Labels of a
## strip; false when there is no such text field.
func set_text(path: String, s: String) -> bool:
	return _vb_set_text(path, s)


## `<child>.styleSheet = style; <child>.htmlText = html` (Emitter.as:215-217, the
## `gui`/`take` particles): StripVis renders it on its FlashTextField (Step 20.4);
## false here and wherever the visual has no such text field.
func set_html_text(_path: String, _html: String, _style: FlashStyleSheet = null) -> bool:
	return false


## BitmapData.draw(vis, m, ct) (Step 19.3, D-J): synchronous, on the CPU, every kind --
## `new BitmapData(width, height)` (int, the parent-space AABB) with the content drawn in
## own space at `-get_rect().position` (`getBounds(vis)`), `ct` concatenated after every
## leaf's own transform (`draw(..., ct)`); null when the size truncates below 1 x 1 or
## nothing is drawable (a VisStub, an empty container). See VisSnapshot. Consumers:
## Desintegr.as:34-38, Unit.initIcos (Unit.as:1490-1497), Sats.drawUnit (Sats.as:268-287).
func snapshot(ct: ColorTr = null) -> Image:
	return VisSnapshot.compose(self, ct)


## The own-space top-left of `snapshot()` (`getBounds(vis).topLeft`: Desintegr's
## `burnBm.x/y = rect.left/top`, Sats.as:279's `-getBounds(un.vis).topLeft`).
func snapshot_origin() -> Vector2:
	return VisSnapshot.origin_of(self)


## Weapon.getBulXY (Weapon.as:712-725): the marker `name` (`emit`) of the
## current frame mapped through this node's transform into the parent's
## space; `position` when the frame has no such marker.
func marker(marker_name: String) -> Vector2:
	var p = _vb_marker_local(marker_name)
	if p == null:
		return position
	return transform * (p as Vector2)


## getRect(self): the bounds in the symbol's own space at the current frame.
func get_rect() -> Rect2:
	return _rect()


## getBounds(parent): the own bounds through this node's transform (the
## axis-aligned box of the transformed rectangle).
func bounds_in_parent() -> Rect2:
	return transform * _rect()


func _to_string() -> String:
	return "vis(%s)" % symbol


# ---------------------------------------------------------------- hooks

func _vb_current_frame() -> int:
	return _vb_frame


func _vb_total_frames() -> int:
	return _vb_total


func _vb_playing() -> bool:
	return _vb_play


func _vb_current_label() -> String:
	return ""


func _vb_blend_set(_v: String) -> void:
	pass


## Step 19.1: true when set_filters reaches a renderer (an adapter, or a named child of
## one: `vis.osn` of a BlitVis, `kor` of a weapon strip).
func _vb_fx_host() -> bool:
	if not has_meta("named_child"):
		return false
	var p := get_parent()
	return p is VisBase and (p as VisBase)._vb_fx_host()


## The shown filters (deep copies): a named child forwards to its adapter.
func _vb_filters_set(copies: Array) -> void:
	var p := get_parent()
	if has_meta("named_child") and p is VisBase:
		(p as VisBase)._vb_child_filters_set(self, copies)


func _vb_filter_param(index: int, param: String, value) -> void:
	var p := get_parent()
	if has_meta("named_child") and p is VisBase:
		(p as VisBase)._vb_child_filter_param(self, index, param, value)


## A named child's filters (the adapter shows them on its own sprite: the child's art
## is baked into it).
func _vb_child_filters_set(_child: VisBase, _copies: Array) -> void:
	pass


func _vb_child_filter_param(_child: VisBase, _index: int, _param: String, _value) -> void:
	pass


## Step 19.4 (contract D-G, the ThunderHead `dieTransform`): a plain container (`new
## MovieClip()` holding Sprite2Ds, UnitThunderHead.as:60-64, `vis.transform.colorTransform`
## in vzdrzhne) renders its colour transform on its own Sprite2D descendants through the
## 19.1 sprite host; a VisBase child keeps its own `color_transform` (Flash concatenates the
## parent's into it -- a recorded deviation: the moln strips are not tinted by the shake).
func _vb_color_transform_set(ct: ColorTr) -> void:
	_ct_plain_sprites(self, ct)


static func _ct_plain_sprites(n: Node, ct: ColorTr) -> void:
	for c in n.get_children():
		if c is VisBase:
			continue
		if c is Sprite2D:
			EntityEffects.sprite_set_ct(c as Sprite2D, ct)
		_ct_plain_sprites(c, ct)


func _vb_cache_as_bitmap_set(_v: bool) -> void:
	pass


## One path element of `child`.
func _vb_child_one(_n: String) -> VisBase:
	return null


func _vb_marker_local(_n: String):
	return null


func _vb_set_text(_path: String, _s: String) -> bool:
	return false


## Own bounds (`_vb_own_rect`) united with the code-added VisBase children
## (add_vis_child), each through its transform.
func _rect() -> Rect2:
	return _vb_merge_added(_vb_own_rect, _vb_own_rect.size != Vector2.ZERO)


func _vb_merge_added(r: Rect2, has_r: bool) -> Rect2:
	for c in get_children():
		if not (c is VisBase) or not c.has_meta("vis_added"):
			continue
		var cr: Rect2 = c._rect()
		if cr.size == Vector2.ZERO:
			continue
		var t: Rect2 = (c as Node2D).transform * cr
		r = r.merge(t) if has_r else t
		has_r = true
	return r


## The base seek: a one-frame clip (frame n clamps to total_frames; no labels).
func _vb_seek(target) -> bool:
	if target is int or target is float:
		var f := AS3.i32(target)
		if f < 1:
			missing_labels += 1
			return false
		_vb_frame = mini(f, _vb_total_frames())
		return true
	missing_labels += 1
	return false
