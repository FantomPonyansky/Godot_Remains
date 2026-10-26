extends RefCounted

## Appear.as. Coat, mane, highlight, eye, and magic are RGB bytes 0-255.
## Mane style is 1..5, eye shape is 1..6. The second mane color is optional.
## There is no cutie-mark control on that screen.
## colorToTransform: multiplier = channel / 290 + (290 - 255) / 255.

const _UserDir := preload("res://scripts/user_dir.gd")
static var PATH := _UserDir.settings("appearance.cfg")

const MAX_HAIR := 5
const MAX_EYE := 6

static var _cached := false
static var _state: Dictionary = {}


static func defaults() -> Dictionary:
	return {
		"fur": [163, 163, 163],
		"hair": [133, 70, 9],
		"hair1": [255, 255, 255],
		"eye": [22, 243, 67],
		"magic": [0, 255, 0],
		"vis_hair1": false,
		"eye_style": 1,
		"hair_style": 1,
	}


static func state() -> Dictionary:
	if not _cached:
		_state = load_state()
		_cached = true
	return _state


static func set_state(next: Dictionary, persist: bool) -> void:
	_state = _copy(next)
	_cached = true
	if persist:
		save_state(_state)


static func load_state() -> Dictionary:
	var out := defaults()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return out
	if not cfg.has_section_key("look", "fur_r"):
		return out
	for key in ["fur", "hair", "hair1", "eye", "magic"]:
		out[key] = [
			_byte(cfg, key + "_r", out[key][0]),
			_byte(cfg, key + "_g", out[key][1]),
			_byte(cfg, key + "_b", out[key][2]),
		]
	out.vis_hair1 = bool(cfg.get_value("look", "vis_hair1", false))
	out.eye_style = clampi(int(cfg.get_value("look", "eye_style", 1)), 1, MAX_EYE)
	out.hair_style = clampi(int(cfg.get_value("look", "hair_style", 1)), 1, MAX_HAIR)
	return out


static func save_state(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	for key in ["fur", "hair", "hair1", "eye", "magic"]:
		var rgb: Array = data[key]
		cfg.set_value("look", key + "_r", int(rgb[0]))
		cfg.set_value("look", key + "_g", int(rgb[1]))
		cfg.set_value("look", key + "_b", int(rgb[2]))
	cfg.set_value("look", "vis_hair1", bool(data.vis_hair1))
	cfg.set_value("look", "eye_style", clampi(int(data.eye_style), 1, MAX_EYE))
	cfg.set_value("look", "hair_style", clampi(int(data.hair_style), 1, MAX_HAIR))
	cfg.save(PATH)


static func multiplier(byte: int) -> float:
	return float(clampi(byte, 0, 255)) / 290.0 + (290.0 - 255.0) / 255.0


static func tint(rgb: Array) -> Color:
	return Color(multiplier(int(rgb[0])), multiplier(int(rgb[1])), multiplier(int(rgb[2])), 1.0)


static func _byte(cfg: ConfigFile, key: String, fallback: int) -> int:
	return clampi(int(cfg.get_value("look", key, fallback)), 0, 255)


static func _copy(data: Dictionary) -> Dictionary:
	var out := {}
	for key in data.keys():
		var value: Variant = data[key]
		if value is Array:
			out[key] = (value as Array).duplicate()
		else:
			out[key] = value
	return out
