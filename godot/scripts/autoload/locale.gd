extends Node

## The one language switch. Original lines (OriginalLines, text_*.xml) and
## port-only strings (port_strings.json, {key: {"en": ..., "ru": ...}}) both
## follow `language`. The choice is stored in user://settings.cfg [ui] language;
## with nothing stored the OS locale picks ru or en.
## Screens connect `language_changed` and relabel in place.

signal language_changed(lang_id: String)

const PORT_STRINGS := "res://assets/data/port_strings.json"
const NAMES := {"ru": "Русский", "en": "English"}

var _strings: Dictionary = {}
var _port: Dictionary = {}
var language: String = "en"


func _ready() -> void:
	_load_port_strings()
	load_language(OriginalLines.language())


func languages() -> PackedStringArray:
	var out: PackedStringArray = []
	for lang in ["ru", "en"]:
		if FileAccess.file_exists(OriginalLines.PATH % lang):
			out.append(lang)
	return out


func language_name(lang_id: String) -> String:
	return str(NAMES.get(lang_id, lang_id))


## Saves the choice, swaps every text cache and tells open screens.
func set_language(lang_id: String) -> void:
	if not lang_id in languages():
		return
	UiSettings.set_value("ui", "language", lang_id)
	if lang_id == language and OriginalLines.language() == lang_id:
		return
	OriginalLines.set_language(lang_id)
	load_language(lang_id)


func cycle_language(step: int = 1) -> void:
	var langs := languages()
	if langs.is_empty():
		return
	set_language(langs[posmod(langs.find(language) + step, langs.size())])


func load_language(lang_id: String) -> void:
	language = lang_id
	_strings.clear()
	var path := "res://assets/data/text_%s.xml" % lang_id
	if not FileAccess.file_exists(path):
		push_warning("Locale file missing: %s" % path)
		return
	var xml := XMLParser.new()
	var err := xml.open(path)
	if err != OK:
		push_warning("Failed to open locale: %s" % path)
		return
	var current_id := ""
	while xml.read() == OK:
		match xml.get_node_type():
			XMLParser.NODE_ELEMENT:
				if xml.get_node_name() == "unit":
					current_id = xml.get_named_attribute_value_safe("id")
			XMLParser.NODE_TEXT:
				if current_id != "" and xml.get_node_data().strip_edges() != "":
					if not _strings.has(current_id):
						_strings[current_id] = xml.get_node_data().strip_edges()
			XMLParser.NODE_ELEMENT_END:
				if xml.get_node_name() == "unit":
					current_id = ""
	language_changed.emit(lang_id)


func get_text(id: String, fallback: String = "") -> String:
	if _strings.has(id):
		return str(_strings[id])
	return fallback if fallback != "" else id


## Port-only string. Falls back to English, then to `fallback`, then the key.
func t(key: String, fallback: String = "") -> String:
	var entry: Variant = _port.get(key)
	if entry is Dictionary:
		var s := str(entry.get(language, entry.get("en", "")))
		if s != "":
			return s
	return fallback if fallback != "" else key


## t() with "%s" / "%d" arguments.
func tf(key: String, args: Array) -> String:
	return t(key) % args


func player_name() -> String:
	return get_text("littlepip", "Littlepip")


func _load_port_strings() -> void:
	_port.clear()
	if not FileAccess.file_exists(PORT_STRINGS):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PORT_STRINGS))
	if data is Dictionary:
		_port = data
