extends RefCounted

## Dialogue side of the text pack (TextParser.dialogue / messText / repText):
## <txt id> entries with their <n> lines (<r p mod push m s1..s5>), the <t>
## title and imp, quest names and <info>, <replic><rep act id> barks.
## OriginalLines keeps only the first text of an entry, so this reads the
## same text_<lang>.xml again in the active language.

const PATH := "res://assets/data/text_%s.xml"
const _KEY_ACTIONS := {
	"keyLeft": "move_left", "keyRight": "move_right", "keyBeUp": "aim_up", "keySit": "aim_down",
	"keyJump": "jump", "keyRun": "sprint", "keyAttack": "shoot", "keyReload": "reload",
	"keyTele": "telekinesis", "keyAction": "interact", "keyScrUp": "weapon_prev",
	"keyScrDown": "weapon_next", "keyPip": "pip_toggle", "keySats": "sats",
	"keyPet": "pet_command", "keyPunch": "melee", "keyMagic": "magic_attack", "keyDef": "cast_spell",
	"keyGrenad": "grenade", "keyCrack": "crack", "keyDash": "dash", "keyArmor": "armor_ability",
	"keyItem": "use_item", "keyItemNext": "item_next", "keyItemPrev": "item_prev",
	"keyPot": "quick_heal", "keyMana": "quick_mana", "keyLook": "look", "keyZoom": "zoom",
	"keyFull": "fullscreen", "keyQuest": "pip_quest", "keyInvent": "pip_invent",
	"keyStatus": "pip_status", "keySkills": "pip_skills", "keyMed": "pip_med", "keyMap": "pip_map",
}

static var _lang := ""
static var _dials: Dictionary = {}
static var _barks: Dictionary = {}


## {imp, title, keys: {s1..}, lines: [{p, mod, push, m, keys, text}]} or {}.
static func dialogue(id: String) -> Dictionary:
	_ensure()
	return _dials.get(id, {})


static func has_dialogue(id: String) -> bool:
	return not dialogue(id).is_empty()


## Lines of a dialogue; a plain <n> text is one line.
static func lines(id: String) -> Array:
	return dialogue(id).get("lines", [])


## Quest.nazv: localText("quest", pid). Quest names are <txt> entries.
static func quest_name(pid: String) -> String:
	var d := dialogue(pid)
	if d.is_empty() or (d.lines as Array).is_empty():
		return ""
	return str((d.lines as Array)[0].get("text", ""))


static func quest_info(pid: String) -> String:
	return str(dialogue(pid).get("info", ""))


## TextParser.messText(id, 0, imp): the whole entry as one text. With
## notes_only, entries without imp give "". Lines of an imp=1 dialogue are
## prefixed " - " (speakers) like the PipBuck notes page.
static func mess_text(id: String, notes_only: bool = false) -> String:
	var d := dialogue(id)
	if d.is_empty():
		return ""
	var tip := int(d.get("imp", 0))
	if notes_only and tip <= 0:
		return ""
	var rows: Array = d.get("lines", [])
	var out: PackedStringArray = []
	if rows.size() == 1 and (rows[0] as Dictionary).keys() == ["text"]:
		out.append(line_text(rows[0]))
	else:
		for row_v in rows:
			var row: Dictionary = row_v
			var s := line_text(row)
			if tip == 1 and str(row.get("p", "")) != "":
				s = " - " + s
			out.append(s)
	return add_keys("\n".join(out), d.get("keys", {}))


## One line ready to show: mat split, @1..@5 keys, [br], @lp. [..] stays.
static func line_text(row: Dictionary) -> String:
	var s := str(row.get("text", ""))
	if row.has("m"):
		var parts := s.split("|")
		s = parts[1] if mat_filter() and parts.size() > 1 else parts[0]
	s = add_keys(s, row.get("keys", {}))
	return lp_name(s.replace("[br]", "\n").replace("\t", "").replace("\r", ""))


## TextParser.repText: a random bark for unit replic id and act, or "".
static func bark(id: String, act: String) -> String:
	_ensure()
	var rows: Array = _barks.get(id + "_" + act, [])
	if rows.is_empty():
		return ""
	var s := str(rows[randi() % rows.size()])
	var a := s.find("#")
	if a >= 0:
		var b := s.rfind("#")
		var pair := s.substr(a + 1, b - a - 1).split("|")
		s = s.substr(0, a) + pair[0] + s.substr(b + 1)
	return lp_name(s)


static func lp_name(s: String) -> String:
	return s.replace("@lp", Locale.player_name()).replace("&lp", Locale.player_name())


static func add_keys(s: String, keys: Dictionary) -> String:
	for i in range(1, 6):
		var k := "s%d" % i
		if keys.has(k):
			s = s.replace("@%d" % i, "[%s]" % key_label(str(keys[k])))
	return s


static func key_label(key_id: String) -> String:
	var action := str(_KEY_ACTIONS.get(key_id, ""))
	if action != "" and InputMap.has_action(action):
		return Prompts.action_plain(action)
	return OriginalLines.key(key_id)


## GameContainer.matFilter (settings: mat).
static func mat_filter() -> bool:
	return bool(UiSettings.value("game", "mat", true))


static func reset() -> void:
	_lang = ""
	_dials.clear()
	_barks.clear()


static func _ensure() -> void:
	var lang := OriginalLines.language()
	if lang == _lang:
		return
	_lang = lang
	_dials.clear()
	_barks.clear()
	var path := PATH % lang
	var xml := XMLParser.new()
	if not FileAccess.file_exists(path) or xml.open(path) != OK:
		push_warning("StoryText: text pack missing: %s" % path)
		return
	var cur: Dictionary = {}
	var cur_id := ""
	var row: Dictionary = {}
	var bark_key := ""
	var in_n := false
	var field := ""
	var text := ""
	while xml.read() == OK:
		match xml.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag := xml.get_node_name()
				if tag == "txt" and cur_id == "":
					cur_id = xml.get_named_attribute_value_safe("id")
					cur = {"imp": int(xml.get_named_attribute_value_safe("imp")), "keys": _keys_of(xml), "lines": []}
					if xml.is_empty():
						cur_id = ""
				elif tag == "rep" and bark_key == "":
					bark_key = xml.get_named_attribute_value_safe("id") + "_" + xml.get_named_attribute_value_safe("act")
					if not _barks.has(bark_key):
						_barks[bark_key] = []
				elif cur_id != "" and tag == "n":
					in_n = true
					field = "n"
					text = ""
				elif cur_id != "" and tag == "info":
					field = "info"
					text = ""
				elif cur_id != "" and in_n and tag == "t":
					field = "t"
					text = ""
				elif tag == "r" and (in_n or bark_key != ""):
					field = "r"
					text = ""
					row = {}
					if cur_id != "":
						for i in xml.get_attribute_count():
							var an := xml.get_attribute_name(i)
							if an in ["p", "mod", "push", "m"]:
								row[an] = xml.get_attribute_value(i)
						var keys := _keys_of(xml)
						if not keys.is_empty():
							row["keys"] = keys
					if xml.is_empty():
						field = ""
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if field != "":
					text += xml.get_node_data()
			XMLParser.NODE_ELEMENT_END:
				var end := xml.get_node_name()
				if end == "r" and field == "r":
					if bark_key != "" and cur_id == "":
						(_barks[bark_key] as Array).append(text.strip_edges())
					else:
						row["text"] = text.strip_edges()
						(cur.lines as Array).append(row)
					field = ""
				elif end == "t" and field == "t":
					cur["title"] = text.strip_edges()
					field = "n"
					text = ""
				elif end == "n" and in_n:
					in_n = false
					if (cur.lines as Array).is_empty() and text.strip_edges() != "":
						(cur.lines as Array).append({"text": text.strip_edges()})
					field = ""
				elif end == "info" and field == "info":
					cur["info"] = text.strip_edges().replace("[br]", "\n")
					field = ""
				elif end == "txt" and cur_id != "":
					if not _dials.has(cur_id):
						_dials[cur_id] = cur
					cur_id = ""
				elif end == "rep":
					bark_key = ""


static func _keys_of(xml: XMLParser) -> Dictionary:
	var out := {}
	for i in range(1, 6):
		var k := "s%d" % i
		if xml.has_attribute(k):
			out[k] = xml.get_named_attribute_value(k)
	return out
