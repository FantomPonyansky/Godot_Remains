extends RefCounted

## One registry for the debug console. The help lines are the command list
## in DEBUG_COMMANDS.md, under that file's update notice.

const LINES: PackedStringArray = [
	"help — List every command and what it does.",
	"give <item_id> [count] — Add a catalog item, weapon, armor, consumable, or schematic. Count defaults to 1.",
	"spell <id> — Add that spell or magic weapon. A spell becomes the current spell (cast with the cast key), a magic weapon is equipped.",
	"perk <id> — Grant one rank of a perk from perks.xml without a perk point or its requirements (spell_port = teleport). Port debug only.",
	"effect <name> [seconds] — Apply a status the game already has: cut, poison, igni, ice, blind, acid, pink, stun, slow, potion_fly, or alicorn. Seconds set the duration, or the stack added for cut and poison. Defaults are cut 5, poison 5, igni 7, stun 2, slow 5, potion_fly 120, alicorn 20, and 15 for ice, blind, acid, and pink. Unit statuses need a selection that has that status. potion_fly and alicorn apply to the player when the player is selected or nothing is. Unknown names are rejected.",
	"eff <id> [ticks] — Add an effs.xml effect (burning, drunk, mint, f_hp, curse, ...) through Effects.add, as the original console 'eff'. It goes on the selected unit, or the player when the player or nothing is selected. Ticks (30 a second) override the effs.xml duration.",
	"remeff <id> — End that effect on the selection or the player (Effects.remove; a chem leaves its post effect).",
	"select — Print the current selection.",
	"params — List the selection's settable fields: exported properties, script variables, and metadata that already exist, such as hp, lock, and fraction.",
	"set <field> <value> — Set a number, bool, or string field on the selection.",
	"set <node_path> <field> <value> — Set that field on a node by path, without clicking it.",
	"clear — Drop the selection.",
	"debug — Once per run, grant every magic spell, every carried weapon, and every armor, 60 rounds of each ammo type, and 3 of each of 3 items from every consumable type. Raises level, Telekinesis, and the levitation and selflevit perks to the original minimums for that magic and for air jump and hover.",
	"lands — List the land ids from Lands.xml that land accepts.",
	"land <id> — Go to that land the way a land exit does (fade, Game.gotoLand rules: refused with a damaged organ unless it is the base camp). A land already visited this run is kept as it was left; begin is the stable.",
	"quiet <id> — Go to that land and stop enemy AI. Enemies already there, and any that spawn after, stay put. quiet on turns AI back on without moving. A new game turns it back on.",
	"openland <id|all> — Open that land on the PipBuck world map (script openland), or every land.",
	"worldmap — Open the PipBuck world map in travel mode, as the map table does.",
	"die — Kill the player: the original death, then respawn at the last checkpoint (in hardcore, the end of the run).",
	"heal — Fill hit points and set head, torso, legs, and blood to full. Clears radiation, which otherwise caps hit points.",
	"physhz [30|60] [interp 0|1] — Show or set the physics tick rate (default 30, the original's logic rate) and physics interpolation (default on). Runtime only, not saved.",
	"god [0|1] — Toggle (or set) god mode: no damage or radiation, magic and mana stay full, spells cost nothing. Port debug only.",
	"artcache [0|1] — Print or set load on demand: on a land change, art only the old land used is freed (setting foe/art/load_on_demand, flags --art-on-demand / --art-preload). Takes effect at the next land change.",
	"tp <room_x> <room_y> [cell_x] [cell_y] — Put the player in that room of the current land (rooms 48 x 25 cells; room y from the top). Two numbers land near the floor of the room; four pick a cell. Port debug only.",
	"trials — List every trial (tip 1) id and the land that can hold it.",
	"trial <id> — Go to that trial chamber (rebuilds the land and plants the room if it is missing). Port debug only.",
	"bosses — List every boss arena (tip 2) id and the land that can hold it.",
	"boss <id> — Go to that boss arena. Port debug only.",
	"surfend — Rebuild surf and put the player in room 11,0 just left of the surfStory trigger (raiders + Calamity scene); Calamity's rep is reset to 0. Port debug only.",
	"arena — Heal, turn god mode on and go to perf_arena, the dev-only stress land (12 busy Mane rooms, mixed enemies, stacked crates). Port debug only.",
	"hardcore [0|1] — Print or set hardcore mode for this profile. In hardcore a death ends the run.",
	"hardinv [0|1] — Print or set limited inventory for this run, with carried weight against each limit (weapons, spells, equipment, ammo, other).",
	"rep [n] — Print or set the reputation (pers rep), shown with its title on the PipBuck status page.",
	"refill — Restock every vendor now, as a visited land does (Game.refillVendors): stock tops up, waiting tasks open, info 'refill'.",
	"vendor [id] [inter] — List the Vendors.xml ids, or open that vendor's Торговля page without its pony. inter is the npc type (doc, adoc, vdoc, v), default none.",
	"stand — Open the base weapon stand screen.",
]

# Durations and stacks match the fields enemy.gd and GameState already tick.
# Writes go straight to those fields so a debug apply is not rolled away by resist.
const _UNIT := {
	"cut": {"field": "_cut", "clock": "_cut_clock", "stack": true, "default": 5.0},
	"poison": {"field": "_poison", "clock": "_poison_clock", "stack": true, "default": 5.0},
	"igni": {"field": "_burn_left", "clock": "_burn_clock", "dps": "_burn_dps", "dps_default": 2.0, "default": 7.0, "clears": "_ice_t"},
	"ice": {"field": "_ice_t", "default": 15.0, "clears": "_burn_left"},
	"blind": {"field": "_blind_t", "default": 15.0},
	"acid": {"field": "_acid_left", "clock": "_acid_clock", "dps": "_acid_dps", "dps_default": 2.0, "default": 15.0},
	"pink": {"field": "_pink_left", "clock": "_pink_clock", "dps": "_pink_dps", "dps_default": 20.0, "default": 15.0},
	"stun": {"field": "_stun_t", "default": 2.0},
	"slow": {"field": "_slow_t", "default": 5.0},
}

const _PLAYER := {
	"potion_fly": 120.0,
	"alicorn": 20.0,
}

const _CATALOGS := [
	["res://assets/data/content/items.json", "items"],
	["res://assets/data/content/weapons_catalog.json", "weapons"],
	["res://assets/data/weapons.json", "weapons"],
	["res://assets/data/content/consumables.json", "items"],
]

var _run := {}
var _ids := {}
var _ids_ready := false
var _const_re: RegEx


func _init() -> void:
	_run = {
		"help": _cmd_help,
		"give": _cmd_give,
		"spell": _cmd_spell,
		"perk": _cmd_perk,
		"effect": _cmd_effect,
		"eff": _cmd_eff,
		"remeff": _cmd_remeff,
		"select": _cmd_select,
		"params": _cmd_params,
		"set": _cmd_set,
		"clear": _cmd_clear,
		"debug": _cmd_debug,
		"lands": _cmd_lands,
		"land": _cmd_land,
		"quiet": _cmd_quiet,
		"openland": _cmd_openland,
		"worldmap": _cmd_worldmap,
		"die": _cmd_die,
		"heal": _cmd_heal,
		"god": _cmd_god,
		"physhz": _cmd_physhz,
		"arena": _cmd_arena,
		"tp": _cmd_tp,
		"trials": _cmd_trials,
		"trial": _cmd_trial,
		"bosses": _cmd_bosses,
		"boss": _cmd_boss,
		"surfend": _cmd_surfend,
		"artcache": _cmd_artcache,
		"hardcore": _cmd_hardcore,
		"hardinv": _cmd_hardinv,
		"rep": _cmd_rep,
		"refill": _cmd_refill,
		"vendor": _cmd_vendor,
		"stand": _cmd_stand,
	}


func run(console, line: String) -> String:
	var args := tokenize(line)
	if args.is_empty():
		return ""
	var name := args[0].to_lower()
	if not _run.has(name):
		return "unknown command '%s'" % args[0]
	var rest := PackedStringArray()
	for i in range(1, args.size()):
		rest.append(args[i])
	return str(_run[name].call(console, rest))


func tokenize(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	var n := line.length()
	while i < n:
		var ch := line[i]
		if ch == " " or ch == "\t":
			i += 1
			continue
		if ch == "\"" or ch == "'":
			var quote := ch
			i += 1
			var quoted := ""
			while i < n and line[i] != quote:
				quoted += line[i]
				i += 1
			if i < n:
				i += 1
			out.append(quoted)
			continue
		var word := ""
		while i < n and line[i] != " " and line[i] != "\t":
			word += line[i]
			i += 1
		out.append(word)
	return out


func usage(name: String) -> String:
	var hits := PackedStringArray()
	for line in LINES:
		var head := line.split(" — ", true, 1)[0]
		if head.split(" ", true, 1)[0] == name:
			hits.append(line)
	return "\n".join(hits)


func _cmd_help(_console, args: PackedStringArray) -> String:
	if args.is_empty():
		return "\n".join(LINES)
	var text := usage(args[0].to_lower())
	if text == "":
		return "unknown command '%s'" % args[0]
	return text


func _cmd_give(console, args: PackedStringArray) -> String:
	if args.is_empty() or args.size() > 2:
		return usage("give")
	var id := args[0]
	var n := 1
	if args.size() == 2:
		if not args[1].is_valid_int():
			return "count must be a whole number"
		n = int(args[1])
		if n <= 0:
			return "count must be above 0"
	if not _known_item(console, id):
		return "unknown item '%s'" % id
	var bags: Node = console.get_node_or_null("/root/Inventory")
	if bags == null or not bags.has_method("add") or not bags.has_method("count"):
		return "inventory is not available"
	var before := int(bags.call("count", id))
	bags.call("add", id, n)
	var after := int(bags.call("count", id))
	var label := id
	if bags.has_method("name_of"):
		label = str(bags.call("name_of", id))
	if after <= before:
		if before > 0:
			return "already carrying %s" % label
		return "could not add %s" % label
	return "gave %d %s (now %d)" % [after - before, label, after]


func _cmd_perk(_console, args: PackedStringArray) -> String:
	if args.size() != 1:
		return usage("perk")
	var id := args[0]
	if Progression._perk_def(id).is_empty():
		return "unknown perk '%s'" % id
	var before := Progression.perk_rank(id)
	Progression.grant_perk(id)
	return "%s rank %d -> %d" % [id, before, Progression.perk_rank(id)]


func _cmd_spell(console, args: PackedStringArray) -> String:
	if args.size() != 1:
		return usage("spell")
	var id := args[0]
	var bags: Node = console.get_node_or_null("/root/Inventory")
	if bags == null or not bags.has_method("is_spell") or not bags.has_method("equip"):
		return "inventory is not available"
	if not bool(bags.call("is_spell", id)):
		return "unknown spell '%s'" % id
	if int(bags.call("count", id)) <= 0:
		bags.call("add", id, 1)
	if int(bags.call("count", id)) <= 0:
		return "could not add %s" % id
	var selected := str(bags.get("spell_id")) == id or str(bags.get("weapon_id")) == id
	if not selected and not bool(bags.call("equip", id)):
		return "could not equip %s" % id
	var label := id
	if bags.has_method("name_of"):
		label = str(bags.call("name_of", id))
	return "equipped %s" % label


func _cmd_effect(console, args: PackedStringArray) -> String:
	if args.is_empty() or args.size() > 2:
		return usage("effect")
	var name := args[0].to_lower()
	var amount := -1.0
	if args.size() == 2:
		if not args[1].is_valid_float():
			return "seconds must be a number"
		amount = float(args[1])
		if amount <= 0.0:
			return "seconds must be above 0"
	if _UNIT.has(name):
		var spec: Dictionary = _UNIT[name]
		if amount < 0.0:
			amount = float(spec["default"])
		var target = console.live_selection()
		if target == null:
			return "select a unit"
		if not (str(spec["field"]) in target):
			return "cannot apply %s to %s" % [name, console.object_title(target)]
		_apply_unit(target, spec, amount)
		return "applied %s to %s" % [name, console.object_title(target)]
	if _PLAYER.has(name):
		if amount < 0.0:
			amount = float(_PLAYER[name])
		var who = console.live_selection()
		if who != null and not who.is_in_group("player"):
			return "cannot apply %s to %s" % [name, console.object_title(who)]
		var state: Node = console.get_node_or_null("/root/GameState")
		if state == null or not state.has_method("start_effect"):
			return "cannot apply %s" % name
		state.call("start_effect", name, amount)
		return "applied %s for %ss" % [name, amount]
	return "unknown status '%s'" % name


func _cmd_eff(console, args: PackedStringArray) -> String:
	if args.is_empty() or args.size() > 2:
		return usage("eff")
	var id := args[0]
	var ticks := -1
	if args.size() == 2:
		if not args[1].is_valid_int() or int(args[1]) <= 0:
			return "ticks must be a whole number above 0"
		ticks = int(args[1])
	var effects: Node = console.get_node_or_null("/root/Effects")
	if effects == null:
		return "effects are not available"
	if (effects.call("def_of", id) as Dictionary).is_empty():
		return "unknown effect '%s'" % id
	var target = console.live_selection()
	if target != null and not (target is Node):
		target = null
	var e: Dictionary = effects.call("add", target, id, ticks)
	if e.is_empty():
		return "could not add %s" % id
	var who := "player" if target == null or target.is_in_group("player") else str(console.object_title(target))
	return "%s on %s for %s" % [id, who, "ever" if bool(e.forever) else "%d ticks" % int(e.t)]


func _cmd_remeff(console, args: PackedStringArray) -> String:
	if args.size() != 1:
		return usage("remeff")
	var effects: Node = console.get_node_or_null("/root/Effects")
	if effects == null:
		return "effects are not available"
	var target = console.live_selection()
	if target != null and not (target is Node):
		target = null
	if not bool(effects.call("has", target, args[0])):
		return "no %s there" % args[0]
	effects.call("remove", target, args[0])
	return "removed %s" % args[0]


func _cmd_select(console, args: PackedStringArray) -> String:
	if not args.is_empty():
		return usage("select")
	var node = console.live_selection()
	if node == null:
		return "nothing selected"
	return str(console.describe(node))


func _cmd_params(console, args: PackedStringArray) -> String:
	if not args.is_empty():
		return usage("params")
	var node = console.live_selection()
	if node == null:
		return "nothing selected"
	var listed := fields_of(node)
	if listed.is_empty():
		return "no settable fields"
	var lines := PackedStringArray()
	for key in listed.keys():
		var info: Dictionary = listed[key]
		lines.append("%s = %s" % [key, info["value"]])
	return "\n".join(lines)


func _cmd_set(console, args: PackedStringArray) -> String:
	if args.size() < 2:
		return usage("set")
	if args.size() == 2:
		var selected = console.live_selection()
		if selected == null:
			return "nothing selected"
		return _assign(selected, args[0], args[1])
	var found := _find_node(console, args[0])
	if found != null:
		return _assign(found, args[1], _join(args, 2))
	var selected_now = console.live_selection()
	if selected_now != null and fields_of(selected_now).has(args[0]):
		return _assign(selected_now, args[0], _join(args, 1))
	return "no node '%s'" % args[0]


func _cmd_clear(console, args: PackedStringArray) -> String:
	if not args.is_empty():
		return usage("clear")
	console.clear_selection()
	return "cleared"


# perks.xml: levitation needs character level 1. selflevit rank 1 needs Telekinesis
# skill level 2 (Pers.getSkLevel, 5 points). Spell weapons use perslvl, and their
# weapon skill level (lvl) is 0, so Magic points are not required to cast.
# Flight is armor ableFly. No perk grants it.
const _AMMO_STACK := 60
const _FEW := 3
const _CARRIED: PackedStringArray = ["melee", "lightGun", "heavyGun", "explosives"]
const _MOVE_PERKS: PackedStringArray = ["levitation", "selflevit"]
const _SELFLEVIT_SKILL := 2


func _cmd_debug(console, args: PackedStringArray) -> String:
	if not args.is_empty():
		return usage("debug")
	var bags: Node = console.get_node_or_null("/root/Inventory")
	if bags == null or not bags.has_method("add") or not bags.has_method("note_kit"):
		return "inventory is not available"
	if bool(bags.get("kit_granted")):
		return "debug kit already granted this run"
	var spells := 0
	var weapons := 0
	var need_level := 1
	for row_v in _list("res://assets/data/weapons.json", "weapons"):
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var id := str(row.get("id", ""))
		if id == "":
			continue
		var kind := str(row.get("kind", ""))
		if kind == "magic" or bool(row.get("spell", false)):
			bags.call("add", id, 1)
			spells += 1
			need_level = maxi(need_level, int(row.get("pers_lvl", 0)))
		elif kind in _CARRIED:
			bags.call("add", id, 1)
			weapons += 1
	var armor := 0
	var suits: Variant = _json("res://assets/data/craft_condition.json").get("armors", {})
	if typeof(suits) == TYPE_DICTIONARY:
		for key in (suits as Dictionary).keys():
			var suit := str(key)
			if suit == "":
				continue
			bags.call("add", suit, 1)
			armor += 1
	var ammo := _ammo_bases()
	for id in ammo:
		bags.call("add", id, _AMMO_STACK)
	var picks := _consumable_picks()
	for pick_v in picks:
		var pick: Dictionary = pick_v
		bags.call("add", str(pick.get("id", "")), _FEW)
	var prog: Node = console.get_node_or_null("/root/Progression")
	var level_now := 1
	var tele_points := 0
	var tele_level := 0
	var magic_points := 0
	var magic_level := 0
	if prog != null and prog.has_method("raise_level") and prog.has_method("raise_skill"):
		prog.call("raise_level", need_level)
		tele_points = _points_for_skill_level(prog, _SELFLEVIT_SKILL)
		prog.call("raise_skill", "tele", tele_points)
		if prog.has_method("grant_perk"):
			for perk_id in _MOVE_PERKS:
				prog.call("grant_perk", perk_id)
		level_now = int(prog.get("level"))
		tele_points = int(prog.call("rank", "tele"))
		tele_level = int(prog.call("skill_level_of", "tele"))
		magic_points = int(prog.call("rank", "magic"))
		magic_level = int(prog.call("skill_level_of", "magic"))
	bags.call("note_kit")
	var kinds := _consumable_kinds(picks)
	return "granted %d spells, %d weapons, %d armor, %d ammo types x%d, %d consumables x%d (%s). Level %d. Perks levitation, selflevit. Telekinesis %d (skill level %d). Magic %d (skill level %d; spell weapons require skill level 0)." % [
		spells, weapons, armor, ammo.size(), _AMMO_STACK, picks.size(), _FEW, kinds,
		level_now, tele_points, tele_level, magic_points, magic_level,
	]


func _points_for_skill_level(prog: Node, skill_level_need: int) -> int:
	var points := 0
	while points < 20 and int(prog.call("skill_level", points, false)) < skill_level_need:
		points += 1
	return points


func _ammo_bases() -> PackedStringArray:
	var ids := {}
	for row_v in _list("res://assets/data/content/items.json", "items"):
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		if str(row.get("type", "")) != "a":
			continue
		var id := str(row.get("id", ""))
		if id != "":
			ids[id] = true
	var bases := {}
	for key in ids.keys():
		var id := str(key)
		var base := id
		var cut := id.rfind("_")
		if cut > 0 and ids.has(id.substr(0, cut)):
			base = id.substr(0, cut)
		bases[base] = true
	var names: Array[String] = []
	for key in bases.keys():
		names.append(str(key))
	names.sort()
	var out := PackedStringArray()
	for id in names:
		out.append(id)
	return out


func _consumable_picks() -> Array:
	var by_tip := {}
	var order: Array[String] = []
	for row_v in _list("res://assets/data/content/consumables.json", "items"):
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var tip := str(row.get("tip", ""))
		var id := str(row.get("id", ""))
		if tip == "" or id == "":
			continue
		if not by_tip.has(tip):
			by_tip[tip] = []
			order.append(tip)
		var bucket: Array = by_tip[tip]
		if bucket.size() < _FEW:
			bucket.append(id)
	var picks: Array = []
	for tip in order:
		for id in by_tip[tip]:
			picks.append({"id": id, "tip": tip})
	return picks


func _consumable_kinds(picks: Array) -> String:
	var seen := {}
	var names: Array[String] = []
	for pick_v in picks:
		if typeof(pick_v) != TYPE_DICTIONARY:
			continue
		var tip := str((pick_v as Dictionary).get("tip", ""))
		if tip == "" or seen.has(tip):
			continue
		seen[tip] = true
		names.append(tip)
	return ", ".join(names)


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _list(path: String, key: String) -> Array:
	var rows: Variant = _json(path).get(key, [])
	if rows is Array:
		return rows
	return []


func _apply_unit(node: Node, spec: Dictionary, amount: float) -> void:
	var field := str(spec["field"])
	if bool(spec.get("stack", false)):
		var cur := float(node.get(field))
		if cur <= 0.0 and spec.has("clock") and str(spec["clock"]) in node:
			node.set(str(spec["clock"]), 1.0)
		node.set(field, cur + amount)
		return
	if spec.has("clears"):
		var clear_name := str(spec["clears"])
		if clear_name in node:
			node.set(clear_name, 0.0)
	if spec.has("clock") and str(spec["clock"]) in node:
		node.set(str(spec["clock"]), 0.0)
	if spec.has("dps") and str(spec["dps"]) in node:
		node.set(str(spec["dps"]), float(spec["dps_default"]))
	node.set(field, amount)


func _assign(node: Node, field: String, raw: String) -> String:
	var listed := fields_of(node)
	if not listed.has(field):
		return "no field '%s'" % field
	var info: Dictionary = listed[field]
	var parsed := _coerce(raw, info["value"])
	if not bool(parsed["ok"]):
		return str(parsed["error"])
	if bool(info["meta"]):
		node.set_meta(field, parsed["value"])
	else:
		node.set(field, parsed["value"])
	var now = node.get_meta(field) if bool(info["meta"]) else node.get(field)
	return "%s = %s" % [field, now]


func _coerce(raw: String, current: Variant) -> Dictionary:
	var kind := typeof(current)
	var low := raw.to_lower()
	match kind:
		TYPE_BOOL:
			if low == "true" or low == "1" or low == "yes":
				return {"ok": true, "value": true}
			if low == "false" or low == "0" or low == "no":
				return {"ok": true, "value": false}
			return {"ok": false, "error": "expected true or false"}
		TYPE_INT:
			if raw.is_valid_int():
				return {"ok": true, "value": int(raw)}
			if raw.is_valid_float():
				return {"ok": true, "value": int(float(raw))}
			return {"ok": false, "error": "expected a number"}
		TYPE_FLOAT:
			if not raw.is_valid_float():
				return {"ok": false, "error": "expected a number"}
			return {"ok": true, "value": float(raw)}
		TYPE_STRING:
			return {"ok": true, "value": raw}
		TYPE_STRING_NAME:
			return {"ok": true, "value": StringName(raw)}
		_:
			return {"ok": false, "error": "that field cannot be set"}


func fields_of(node: Node) -> Dictionary:
	var found := {}
	var blocked := _const_names(node)
	for prop in node.get_property_list():
		var usage := int(prop.get("usage", 0))
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		if (usage & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP)) != 0:
			continue
		if (usage & PROPERTY_USAGE_READ_ONLY) != 0:
			continue
		var pname := str(prop.get("name", ""))
		if pname == "" or blocked.has(pname):
			continue
		var typ := int(prop.get("type", TYPE_NIL))
		var value: Variant = node.get(pname)
		if typ == TYPE_NIL:
			typ = typeof(value)
		if not _primitive(typ):
			continue
		found[pname] = {"meta": false, "value": value}
	for key in node.get_meta_list():
		var meta_name := str(key)
		if meta_name == "" or found.has(meta_name):
			continue
		var meta_value: Variant = node.get_meta(key)
		if not _primitive(typeof(meta_value)):
			continue
		found[meta_name] = {"meta": true, "value": meta_value}
	var names: Array[String] = []
	for key in found.keys():
		names.append(str(key))
	names.sort()
	var ordered := {}
	for key in names:
		ordered[key] = found[key]
	return ordered


func _primitive(typ: int) -> bool:
	return typ == TYPE_BOOL or typ == TYPE_INT or typ == TYPE_FLOAT or typ == TYPE_STRING or typ == TYPE_STRING_NAME


func _const_names(node: Node) -> Dictionary:
	var names := {}
	var script: Script = node.get_script()
	if _const_re == null:
		_const_re = RegEx.new()
		_const_re.compile("(?m)^[ \\t]*const\\s+([A-Za-z_][A-Za-z0-9_]*)\\b")
	while script != null:
		for match in _const_re.search_all(script.source_code):
			names[match.get_string(1)] = true
		script = script.get_base_script()
	return names


func _known_item(console, id: String) -> bool:
	if id == "":
		return false
	_ensure_ids()
	if _ids.has(id):
		return true
	var bags: Node = console.get_node_or_null("/root/Inventory")
	if bags != null:
		if bags.has_method("is_spell") and bool(bags.call("is_spell", id)):
			return true
		if bags.has_method("is_gun") and bool(bags.call("is_gun", id)):
			return true
		if bags.has_method("weapon_def"):
			var row: Variant = bags.call("weapon_def", id)
			if row is Dictionary and not (row as Dictionary).is_empty():
				return true
		if bags.has_method("name_of") and str(bags.call("name_of", id)) != id:
			return true
		if bags.has_method("is_consumable") and bool(bags.call("is_consumable", id)):
			return true
	var state: Node = console.get_node_or_null("/root/GameState")
	if state != null and state.has_method("is_consumable") and bool(state.call("is_consumable", id)):
		return true
	var cond: Node = console.get_node_or_null("/root/Condition")
	return cond != null and cond.has_method("is_armor") and bool(cond.call("is_armor", id))


func _ensure_ids() -> void:
	if _ids_ready:
		return
	_ids_ready = true
	_ids["pip"] = true
	for pair in _CATALOGS:
		_take_ids(str(pair[0]), str(pair[1]))


func _take_ids(path: String, key: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for row in (parsed as Dictionary).get(key, []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var id := str((row as Dictionary).get("id", ""))
		if id != "":
			_ids[id] = true


func _find_node(console, path: String) -> Node:
	var tree: SceneTree = console.get_tree()
	if tree == null:
		return null
	if path.begins_with("/"):
		return tree.root.get_node_or_null(path)
	var scene := tree.current_scene
	if scene != null:
		var direct := scene.get_node_or_null(path)
		if direct != null:
			return direct
	return tree.root.find_child(path, true, false)


func _join(args: PackedStringArray, from: int) -> String:
	var parts := PackedStringArray()
	for i in range(from, args.size()):
		parts.append(args[i])
	return " ".join(parts)


func _land_ids() -> PackedStringArray:
	var registry := load("res://scripts/map/land_registry.gd")
	var out := PackedStringArray()
	for id in registry.ids():
		if str(registry.land(str(id)).get("tip", "")) != "prob":
			out.append(str(id))
	return out


func _cmd_lands(_console, args: PackedStringArray) -> String:
	if not args.is_empty():
		return usage("lands")
	return " ".join(_land_ids())


func _cmd_land(console, args: PackedStringArray) -> String:
	if args.size() != 1:
		return usage("land")
	var id := args[0]
	if not _land_ids().has(id):
		return "unknown land '%s'" % id
	var tree: SceneTree = console.get_tree()
	var host: Node = tree.current_scene if tree != null else null
	if host == null or not host.has_method("goto_land"):
		return "no game scene"
	host.goto_land(id)
	return "going to %s" % id


func _cmd_quiet(console, args: PackedStringArray) -> String:
	if args.size() == 1 and args[0] == "on":
		GameState.enemies_think = true
		return "enemy AI on"
	if args.size() != 1:
		return usage("quiet")
	var id := args[0]
	if not _land_ids().has(id):
		return "unknown land '%s'" % id
	var tree: SceneTree = console.get_tree()
	var host: Node = tree.current_scene if tree != null else null
	if host == null or not host.has_method("goto_land"):
		return "no game scene"
	GameState.enemies_think = false
	host.goto_land(id)
	return "enemy AI off, going to %s" % id


func _cmd_openland(_console, args: PackedStringArray) -> String:
	if args.size() != 1:
		return usage("openland")
	if args[0] == "all":
		for id in Travel.lands:
			Travel.open_land(str(id))
		return "all lands open"
	if not Travel.lands.has(args[0]):
		return "unknown land '%s'" % args[0]
	Travel.open_land(args[0])
	return "%s open" % args[0]


func _cmd_worldmap(_console, args: PackedStringArray) -> String:
	if not args.is_empty():
		return usage("worldmap")
	if not Travel.has_host():
		return "no game scene"
	Travel.call_deferred("open_travel_map")
	return "world map"


func _cmd_heal(_console, args: PackedStringArray) -> String:
	if not args.is_empty():
		return usage("heal")
	GameState.restore_body()
	return "health and organs restored"


func _cmd_god(_console, args: PackedStringArray) -> String:
	if args.size() > 1 or (args.size() == 1 and args[0] not in ["0", "1"]):
		return usage("god")
	GameState.god = (args[0] == "1") if args.size() == 1 else not GameState.god
	if GameState.god:
		GameState.restore_body()
		GameState.magic = float(GameState.MAX_MAGIC)
		GameState.mana_hp = GameState.mana_max()
		GameState._mana_moved()
		GameState._emit_magic()
	return "god mode %s" % ("on" if GameState.god else "off")


func _cmd_artcache(_console, args: PackedStringArray) -> String:
	var art := preload("res://scripts/art_cache.gd")
	if args.size() > 1 or (args.size() == 1 and args[0] not in ["0", "1"]):
		return usage("artcache")
	if args.size() == 1:
		art.set_enabled(args[0] == "1")
	return "load on demand %s (textures %.0f MB)" % ["on" if art.enabled() else "off", Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0]


func _cmd_physhz(console, args: PackedStringArray) -> String:
	var tree: SceneTree = console.get_tree()
	var i := 0
	while i < args.size():
		if args[i] in ["30", "60"]:
			Engine.physics_ticks_per_second = int(args[i])
			i += 1
		elif args[i] == "interp" and i + 1 < args.size() and args[i + 1] in ["0", "1"]:
			tree.physics_interpolation = args[i + 1] == "1"
			i += 2
		else:
			return usage("physhz")
	return "physics %d Hz, interpolation %s" % [Engine.physics_ticks_per_second, "on" if tree.physics_interpolation else "off"]


func _cmd_arena(console, args: PackedStringArray) -> String:
	if not args.is_empty():
		return usage("arena")
	if not _land_ids().has("perf_arena"):
		return "no perf_arena (run tools/make_perf_arena.py; debug builds only)"
	GameState.restore_body()
	GameState.god = true
	return _cmd_land(console, PackedStringArray(["perf_arena"]))


func _cmd_tp(console, args: PackedStringArray) -> String:
	if args.size() != 2 and args.size() != 4:
		return usage("tp")
	var host: Node = console.get_tree().current_scene
	if host == null or not host.has_method("place_player"):
		return "no game scene"
	var cx := int(args[2]) if args.size() == 4 else 24
	var cy := int(args[3]) if args.size() == 4 else 22
	var at := _cell_feet(int(args[0]), int(args[1]), cx, cy)
	host.place_player(at)
	return "player at room %s,%s" % [args[0], args[1]]


func _cmd_trials(_console, args: PackedStringArray) -> String:
	if not args.is_empty():
		return usage("trials")
	return _list_probs(false)


func _cmd_bosses(_console, args: PackedStringArray) -> String:
	if not args.is_empty():
		return usage("bosses")
	return _list_probs(true)


func _cmd_trial(console, args: PackedStringArray) -> String:
	if args.size() != 1:
		return usage("trial")
	return _goto_prob(console, args[0], false)


func _cmd_boss(console, args: PackedStringArray) -> String:
	if args.size() != 1:
		return usage("boss")
	return _goto_prob(console, args[0], true)


func _list_probs(boss: bool) -> String:
	var lines := PackedStringArray()
	for rec_v in _prob_catalog():
		var rec: Dictionary = rec_v
		if (str(rec.tip) == "2") != boss:
			continue
		var title := OriginalLines.text("map", str(rec.id))
		if title == str(rec.id):
			title = ""
		if title != "":
			lines.append("%s (%s) %s" % [rec.id, rec.land, title])
		else:
			lines.append("%s (%s)" % [rec.id, rec.land])
	if lines.is_empty():
		return "none"
	return "\n".join(lines)


func _prob_catalog() -> Array:
	var registry := load("res://scripts/map/land_registry.gd")
	var out: Array = []
	var seen := {}
	for id_v in registry.ids():
		var lid := str(id_v)
		if str(registry.land(lid).get("tip", "")) == "prob":
			continue
		for row_v in registry.land(lid).get("probs", []):
			var row: Dictionary = row_v
			var pid := str(row.get("id", ""))
			if pid == "" or seen.has(pid):
				continue
			seen[pid] = true
			out.append({"id": pid, "land": lid, "tip": str(row.get("tip", ""))})
	return out


func _prob_rec(pid: String) -> Dictionary:
	for rec_v in _prob_catalog():
		var rec: Dictionary = rec_v
		if str(rec.id) == pid:
			return rec
	return {}


func _goto_prob(console, pid: String, boss: bool) -> String:
	var rec := _prob_rec(pid)
	if rec.is_empty():
		return "unknown %s '%s'" % ["boss" if boss else "trial", pid]
	if boss and str(rec.tip) != "2":
		return "'%s' is a trial; use trial %s" % [pid, pid]
	if not boss and str(rec.tip) == "2":
		return "'%s' is a boss arena; use boss %s" % [pid, pid]
	var tree: SceneTree = console.get_tree()
	if _place_prob(tree, pid):
		return "player in %s" % pid
	if not Travel.has_host():
		return "no game scene"
	GameState.restore_body()
	GameState.debug_prob = pid
	Travel.crea = true
	Travel.goto_land(str(rec.land))
	_place_prob_on_arrival(tree, str(rec.land), pid)
	return "going to %s on %s" % [pid, rec.land]


func _place_prob(tree: SceneTree, pid: String) -> bool:
	var props := tree.get_first_node_in_group("land_props")
	if props == null:
		return false
	var room := _bound_prob_room(props, pid)
	if room == Vector2i(-1, -1):
		return false
	if props.has_method("_spawn_near"):
		props.call("_spawn_near", "%d,%d" % [room.x, room.y])
	var host: Node = tree.current_scene
	if host == null or not host.has_method("place_player"):
		return false
	host.place_player(_cell_feet(room.x, room.y, 24, 22))
	return true


func _bound_prob_room(props: Node, pid: String) -> Vector2i:
	var rooms: Variant = props.get("_bound_rooms")
	if not rooms is Array:
		return Vector2i(-1, -1)
	for room_v in rooms:
		var room: Dictionary = room_v
		if str(room.get("prob", "")) == pid:
			return Vector2i(int(room.x), int(room.y))
	return Vector2i(-1, -1)


func _place_prob_on_arrival(tree: SceneTree, land: String, pid: String) -> void:
	for i in 1800:
		await tree.process_frame
		if Travel.cur_land_id != land or Travel._loading:
			continue
		if not tree.current_scene.has_method("place_player"):
			continue
		for j in 30:
			await tree.process_frame
		if _place_prob(tree, pid):
			return
		return


func _cmd_surfend(console, args: PackedStringArray) -> String:
	if not args.is_empty():
		return usage("surfend")
	if not Travel.has_host():
		return "no game scene"
	Story.set_npc_rep("calam", 0)
	Travel.goto_land("surf", "", true)
	_place_on_arrival(console.get_tree(), "surf", _cell_feet(11, 0, 44, 22))
	return "going to the surf end"


func _cell_feet(rx: int, ry: int, cx: int, cy: int) -> Vector2:
	return Vector2(rx * 1920 + (cx + 0.5) * 40.0, ry * 1000 + (cy + 1) * 40.0 - 1.0)


func _place_on_arrival(tree: SceneTree, land: String, at: Vector2) -> void:
	for i in 1800:
		await tree.process_frame
		if Travel.cur_land_id == land and not Travel._loading and tree.current_scene.has_method("place_player"):
			for j in 30:
				await tree.process_frame
			tree.current_scene.place_player(at)
			return


func _cmd_die(_console, args: PackedStringArray) -> String:
	if not args.is_empty():
		return usage("die")
	if not Travel.has_host():
		return "no game scene"
	GameState.apply_damage(100000, "DAM_INTERNAL")
	return "dead"


func _cmd_hardcore(_console, args: PackedStringArray) -> String:
	if args.size() > 1:
		return usage("hardcore")
	if args.size() == 1:
		if args[0] not in ["0", "1"]:
			return usage("hardcore")
		Travel.set_hardcore(args[0] == "1")
	return "hardcore %d" % (1 if Travel.hardcore() else 0)


func _cmd_hardinv(_console, args: PackedStringArray) -> String:
	if args.size() > 1:
		return usage("hardinv")
	if args.size() == 1:
		if args[0] not in ["0", "1"]:
			return usage("hardinv")
		Inventory.set_hard_inv(args[0] == "1")
	return "hardinv %d  weapons %d/%d  spells %d/%d  equipment %.1f/%.0f  ammo %.1f/%.0f  other %.1f/%.0f" % [
		1 if Inventory.hard_inv() else 0,
		Inventory.mass_w(), int(Inventory.max_mass("maxmW")),
		Inventory.mass_m(), int(Inventory.max_mass("maxmM")),
		Inventory.mass(1), Inventory.max_mass("maxm1"),
		Inventory.mass(2), Inventory.max_mass("maxm2"),
		Inventory.mass(3), Inventory.max_mass("maxm3"),
	]


func _cmd_rep(_console, args: PackedStringArray) -> String:
	if args.size() > 1 or (args.size() == 1 and not args[0].is_valid_int()):
		return usage("rep")
	if args.size() == 1:
		Story.rep = int(args[0])
	return "rep %d (%s)" % [Story.rep, Vendors.rep_text(Story.rep)]


func _cmd_refill(_console, args: PackedStringArray) -> String:
	if not args.is_empty():
		return usage("refill")
	Vendors.refill_all()
	return "vendors restocked"


func _cmd_vendor(_console, args: PackedStringArray) -> String:
	Vendors._ensure()
	if args.is_empty():
		return " ".join(PackedStringArray(Vendors._xml.keys()))
	if args.size() > 2 or not Vendors._xml.has(args[0]):
		return usage("vendor")
	Vendors.vendor = Vendors.vendor_of(args[0])
	Vendors.npc_id = ""
	Vendors.npc_inter = args[1] if args.size() > 1 else ""
	Story.open_pip(4, 1)
	return "vendor %s" % args[0]


func _cmd_stand(_console, args: PackedStringArray) -> String:
	if not args.is_empty():
		return usage("stand")
	var host: Variant = Engine.get_main_loop()
	if not host is SceneTree:
		return "no scene"
	preload("res://scripts/stand_screen.gd").open(host as SceneTree)
	return "stand"
