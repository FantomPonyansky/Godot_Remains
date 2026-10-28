class_name OriginalLines
extends RefCounted

## Strings from the original text pack (text_ru.xml, or text_en.xml when the
## Настройки language is English). HUD and PipBuck copy is read from here.

const PATH := "res://assets/data/text_%s.xml"
const _UserDir := preload("res://scripts/user_dir.gd")
static var SETTINGS := _UserDir.settings("settings.cfg")
const SECTIONS: PackedStringArray = [
	"gui", "info", "pip", "weapon", "item", "obj", "ammo", "eff", "key", "unit", "armor", "map", "name", "txt",
]

static var _text: Dictionary = {}
static var _keys: Dictionary = {}
## pip_eff.json: AllData textvar / eff rows by perk, skill or item id.
static var _vars: Dictionary = {}
static var _st: Dictionary = {}
static var _ready := false
static var _lang := ""


static func language() -> String:
	if _lang == "":
		var cfg := ConfigFile.new()
		_lang = system_language()
		if cfg.load(SETTINGS) == OK:
			_lang = str(cfg.get_value("ui", "language", _lang))
		if not FileAccess.file_exists(PATH % _lang):
			_lang = system_language()
	return _lang


## First launch: Russian for a Russian OS, English otherwise.
static func system_language() -> String:
	return "ru" if OS.get_locale_language() == "ru" else "en"


## Use Locale.set_language from game code; this only swaps the cached pack.
static func set_language(lang: String) -> void:
	if not FileAccess.file_exists(PATH % lang):
		return
	_lang = lang
	_text.clear()
	_keys.clear()
	_ready = false


static func gui(id: String) -> String:
	return _line("gui", id)


static func info(id: String, a1: String = "", a2: String = "") -> String:
	var line := _line("info", id).replace("@1", a1).replace("@2", a2)
	if _st.size() > 512:
		_st.clear()
	_st[line] = str(_keys.get("info\n" + id, {}).get("st", ""))
	return line


## Res.txt "f": the line's <info st> (span class r<st>), "" for the default .r,
## null for a line that did not come from info().
static func info_style(line: String) -> Variant:
	return _st.get(line)


static func pip(id: String) -> String:
	return _line("pip", id)


static func eff(id: String) -> String:
	return _line("eff", id)


static func key(id: String) -> String:
	return _line("key", id)


static func unit(id: String) -> String:
	return _line("unit", id)


static func text(section: String, id: String) -> String:
	return _line(section, id)


## The <info> body under an entry, with [br] turned into line breaks.
static func desc(section: String, id: String) -> String:
	_ensure()
	var raw := str(_text.get(section + "\n" + id + "\ninfo", ""))
	raw = raw.replace("[br]", "\n").replace("\t", "")
	# Res.txt razd 1: addKeys on the entry and on its <info>, @N -> [key].
	var keys := keys_of(section, id).duplicate()
	keys.merge(keys_of(section, id, "info"))
	if keys.is_empty() or not raw.contains("@"):
		return raw
	return (load("res://scripts/story/story_text.gd") as GDScript).call("add_keys", raw, keys)


## First <info> body for an id across the item-like sections.
## The <mess> line under an entry (GUI.infoEffText for effects).
static func mess(section: String, id: String) -> String:
	_ensure()
	var raw := str(_text.get(section + "\n" + id + "\nmess", ""))
	var keys := keys_of(section, id).duplicate()
	keys.merge(keys_of(section, id, "mess"))
	if keys.is_empty() or not raw.contains("@"):
		return raw
	return (load("res://scripts/story/story_text.gd") as GDScript).call("add_keys", raw, keys)


## The <help> line under an entry (TextParser.txt n 3: a trial hint).
static func help(section: String, id: String) -> String:
	_ensure()
	return str(_text.get(section + "\n" + id + "\nhelp", ""))


static func desc_of(id: String) -> String:
	for section: String in ["weapon", "item", "armor", "ammo", "eff", "obj", "unit"]:
		var body := desc(section, id)
		if body != "":
			return text_vars(body, id) if section == "item" else body
	return ""


## PipPage.addVar: #N -> [sN] from the AllData textvar row (level 1 unless lvl > 1).
static func text_vars(s: String, id: String, lvl: int = 1) -> String:
	if not s.contains("#"):
		return s
	if _vars.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/pip_eff.json"))
		_vars = parsed if parsed is Dictionary else {"": {}}
	var tv: Array = (_vars.get(id, {}) as Dictionary).get("textvar", [])
	if tv.is_empty():
		return s
	var row: Dictionary = tv[lvl - 1] if lvl > 1 and lvl - 1 < tv.size() else tv[0]
	for k in range(1, 6):
		if row.has("s%d" % k):
			s = s.replace("#%d" % k, "[%s]" % str(row["s%d" % k]))
	return s


static func has(section: String, id: String) -> bool:
	_ensure()
	return _text.has(section + "\n" + id)


static func name_of(id: String) -> String:
	if id == "":
		return ""
	_ensure()
	for section: String in ["weapon", "item", "armor", "obj", "ammo", "eff", "unit"]:
		var k: String = section + "\n" + id
		if _text.has(k):
			return str(_text[k])
	return id


## The s1..s5 key ids (keyJump, ...) on an entry, for StoryText.add_keys.
static func keys_of(section: String, id: String, part: String = "") -> Dictionary:
	_ensure()
	var k := section + "\n" + id + ("\n" + part if part != "" else "")
	return _keys.get(k, {})


static func _store_keys(k: String, xml: XMLParser) -> void:
	var row := {}
	for i in range(1, 6):
		var v := xml.get_named_attribute_value_safe("s%d" % i)
		if v != "":
			row["s%d" % i] = v
	var st := xml.get_named_attribute_value_safe("st")
	if st != "":
		row["st"] = st
	if not row.is_empty():
		_keys[k] = row


static func _line(section: String, id: String) -> String:
	_ensure()
	var k := section + "\n" + id
	if _text.has(k):
		return str(_text[k])
	return id


static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	var path := PATH % language()
	if not FileAccess.file_exists(path):
		push_warning("Original text pack missing: %s" % path)
		return
	var xml := XMLParser.new()
	if xml.open(path) != OK:
		push_warning("Original text pack failed to open")
		return
	var section := ""
	var id := ""
	var capture := ""
	while xml.read() == OK:
		match xml.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag := xml.get_node_name()
				var tag_id := xml.get_named_attribute_value_safe("id")
				if tag in SECTIONS and tag_id != "" and (id == "" or tag != "info"):
					if xml.is_empty():
						continue
					section = tag
					id = tag_id
					_store_keys(section + "\n" + id, xml)
					capture = ""
				elif tag == "n" and section != "" and id != "":
					capture = "n"
				elif tag == "info" and section != "" and id != "":
					capture = "info"
				elif tag == "mess" and section != "" and id != "":
					capture = "mess"
					_store_keys(section + "\n" + id + "\nmess", xml)
				elif tag == "help" and section != "" and id != "":
					capture = "help"
			XMLParser.NODE_TEXT:
				if capture != "" and id != "":
					var k := section + "\n" + id
					if capture == "info" or capture == "mess" or capture == "help":
						k += "\n" + capture
					if not _text.has(k):
						var raw := xml.get_node_data().strip_edges()
						if raw != "":
							_text[k] = raw
			XMLParser.NODE_ELEMENT_END:
				var end := xml.get_node_name()
				if end == "n" or (end == "info" and capture == "info") or (end == "mess" and capture == "mess") or (end == "help" and capture == "help"):
					capture = ""
				elif end == section:
					id = ""
					section = ""
