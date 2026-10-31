class_name EntityEffects
extends RefCounted
## Stand-in for OTHER's effects layer, which the port does not have: OTHER's player rig
## runtime calls it for body filter stacks and sprite filters. Nothing is drawn; the blend
## mirrors fall back to a BackBufferCopy (rig_art_fx.gd `_make_copy`).

const BLEND_ID := {}


static func copy_stack(stack: Array) -> Array:
	return stack.duplicate(true)


static func to_filter(v: Variant) -> Variant:
	return v


static func group_show(_group: CanvasGroup, _stack: Array) -> void:
	pass


static func group_set_param(_group: CanvasGroup, _index: int, _param: String, _value: Variant) -> void:
	pass


static func group_post_ct(_group: CanvasGroup, _mult: Color, _off: Color) -> void:
	pass


static func sprite_set_filters(_spr: Sprite2D, _stack: Array) -> void:
	pass


static func sprite_state(_spr: Sprite2D) -> Dictionary:
	return {}


static func sprite_geometry_changed(_spr: Sprite2D) -> void:
	pass


static func sprite_set_ct(_spr: Sprite2D, _ct: Variant) -> void:
	pass
