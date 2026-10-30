class_name FlashFilter
extends RefCounted
## Stand-in for OTHER's Flash filter objects (see entity_effects.gd).


static func from_xfl(_rec: Dictionary) -> FlashFilter:
	return FlashFilter.new()


func _set_param(_param: String, _value: Variant) -> void:
	pass
