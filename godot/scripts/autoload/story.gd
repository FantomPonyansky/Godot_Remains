extends Node

## Game.as quests and notes (addQuest, showQuest, closeQuest, checkQuests,
## incQuests, addNote), Quest.as, the Npc.as state that is saved (rep), and
## the story items: rewards, books, documents.
## Quest data: assets/data/story/quests.json (tools/extract_story.py).
## Names and stage lines are text pack <txt> entries (quest pid, pid + sub id).
## Saved through WorldState provider "story". Triggers stay in Travel.

signal quests_changed
signal notes_changed

const QUESTS_PATH := "res://assets/data/story/quests.json"
const NPCS_PATH := "res://assets/data/story/npcs.json"
const ITEMS_PATH := "res://assets/data/story/items.json"
const StoryText := preload("res://scripts/story/story_text.gd")
const BASE_NOTES: PackedStringArray = ["helpControl", "helpGl1", "helpGl2"]

## Quest.as for a quest and for each of its stages (sub).
class Quest:
	extends RefCounted
	var id := ""
	var xml: Dictionary = {}
	var par: Quest
	var sub := false
	var nsub := 0
	var subs: Array = []
	var subs_id: Dictionary = {}
	var main := false
	var is_check := false
	var nn := false
	var collect := ""
	var col_tip := 0
	var is_del := false
	var give := ""
	var est := 0
	var kol := 1
	var can_be_use := false
	var gived := 0
	var pay := 0
	var prev_res := ""
	var hidden := false
	var invis := false
	var result := false
	var report := ""
	var beg_dial := ""
	var end_dial := ""
	var end_script := ""
	var state := 0
	var sp := 0
	var xp := 0
	var rep := 0
	var trigger := ""
	var trigger_set: Variant = "1"
	var story: Node

	func _init(owner: Node, data: Dictionary, load_obj: Dictionary = {}, parent: Quest = null, n: int = 0) -> void:
		story = owner
		xml = data
		id = str(data.get("id", ""))
		if parent != null:
			par = parent
			sub = true
		state = 1
		nsub = n
		if not load_obj.is_empty():
			state = int(load_obj.get("state", 1))
			est = int(load_obj.get("est", 0))
			gived = int(load_obj.get("gived", 0))
		empl_init()
		if data.has("collect"):
			collect = str(data.collect)
			is_check = true
			if par != null:
				par.is_check = true
			is_del = data.has("del")
			col_tip = int(data.get("coltip", 0))
		give = str(data.get("give", ""))
		pay = int(data.get("pay", 0))
		if data.has("kol"):
			kol = int(data.kol)
		report = str(data.get("report", ""))
		can_be_use = data.has("us")
		hidden = data.has("hidden")
		invis = data.has("invis")
		if data.has("result"):
			result = true
			if par != null:
				par.result = true
		sp = int(data.get("sp", 0))
		xp = int(data.get("xp", 0))
		rep = int(data.get("rep", 0))
		if data.has("trigger"):
			trigger = str(data.trigger)
			trigger_set = str(data.get("triggerset", "1"))
			if state == 2 and Travel.trigger(trigger) == null:
				Travel.set_trigger(trigger, trigger_set)
		if load_obj.has("invis"):
			invis = bool(load_obj.invis)
		if not sub:
			main = data.has("main")
			var saved_subs: Dictionary = load_obj.get("subs", {}) if load_obj.get("subs", {}) is Dictionary else {}
			var k := 1
			for s_v in data.get("subs", []):
				var s: Dictionary = s_v
				var q := Quest.new(owner, s, saved_subs.get(str(s.get("id", "")), {}), self, k)
				subs_id[q.id] = q
				subs.append(q)
				k += 1

	func empl_init() -> void:
		beg_dial = str(xml.get("begdial", ""))
		end_dial = str(xml.get("enddial", ""))
		end_script = str(xml.get("endscr", ""))
		nn = xml.has("nn")

	func pid() -> String:
		return par.id + id if sub else id

	func nazv() -> String:
		var s := StoryText.quest_name(pid())
		return s if s != "" else "[%s]" % id

	func info() -> String:
		var s := StoryText.quest_info(pid())
		return s if s != "" else "---"

	func save() -> Dictionary:
		var obj := {"id": id, "state": state, "est": est, "gived": gived, "invis": invis}
		if not sub:
			var out := {}
			for q: Quest in subs:
				out[q.id] = q.save()
			obj["subs"] = out
		return obj

	func inc(cid: String, n: int = 1) -> void:
		if cid == collect:
			est += n
		if not sub:
			for q: Quest in subs:
				q.inc(cid, n)

	func deposit() -> void:
		story.give_rows(xml.get("deposit", []))

	func check(cid: String = "") -> String:
		var res := ""
		if sub:
			if collect != "" and col_tip == 0 and gived < kol:
				est = mini(Inventory.count(collect) + gived, kol)
				if give == "":
					if est >= kol:
						state = 2
						if par.result:
							par.is_result()
					elif can_be_use:
						if state < 2:
							state = 1
						else:
							est = kol
					else:
						state = 1
				if cid != "" and collect == cid:
					res = "%s %d/%d" % [nazv(), est, kol]
				est = Inventory.count(collect)
			if collect != "" and col_tip == 1:
				if Inventory.count(collect) > 0:
					state = 2
					if par.result:
						par.is_result()
				if cid != "" and collect == cid:
					res = nazv()
		else:
			if state == 2:
				return ""
			var cl := true
			for q: Quest in subs:
				var res2 := q.check(cid)
				if res2 != "":
					res = res2
				if q.state < 2 and not q.nn:
					cl = false
			if cl:
				close()
		if res == prev_res or res == "":
			return ""
		prev_res = res
		return res

	func ch_give(npc: String, us: bool = false) -> bool:
		if sub:
			if give == "" or collect == "":
				return false
			est = Inventory.count(collect)
			if est > 0 and kol - gived > 0:
				est = mini(est, kol - gived)
				if us:
					Inventory.spend(collect, est)
					gived += est
					if pay > 0:
						Inventory.add("money", est * pay)
						story.info("reward", OriginalLines.name_of("money"), str(est * pay))
					story.info("withdraw", OriginalLines.name_of(collect), str(est))
					est = 0
					if gived >= kol:
						close()
				return true
			return false
		var ok := false
		for q: Quest in subs:
			if q.ch_give(npc, us):
				ok = true
		check("")
		return ok

	func ch_report(npc: String, us: bool = false) -> bool:
		if sub:
			return false
		var cl := true
		var rep_q: Quest = null
		for q: Quest in subs:
			if q.report != "" and q.report == npc:
				rep_q = q
			elif q.state < 2 and not q.nn:
				cl = false
		if cl and rep_q != null:
			if us:
				rep_q.close()
				check("")
			return true
		return false

	func is_closed() -> void:
		for q: Quest in subs:
			if q.state < 2:
				return
		close()

	func is_result() -> void:
		for i in subs.size():
			if not (subs[i] as Quest).result:
				continue
			var cl := true
			for j in range(i - 1, -1, -1):
				if (subs[j] as Quest).state < 2:
					cl = false
			if cl:
				(subs[i] as Quest).invis = false

	func close_sub(sid: String) -> void:
		if state == 2 or sid == "" or not subs_id.has(sid):
			return
		(subs_id[sid] as Quest).close()
		if result:
			is_result()
		if state == 1:
			is_closed()

	func show_sub(sid: String) -> void:
		if sid == "" or not subs_id.has(sid):
			return
		(subs_id[sid] as Quest).invis = false

	func close() -> void:
		if state == 2:
			return
		state = 2
		if not sub:
			for q: Quest in subs:
				if q.is_del:
					story.withdraw(q.collect, q.kol if q.col_tip == 0 else 1)
		if sp != 0:
			story.add_skill_points(sp)
		if xp != 0:
			Progression.add_xp(xp)
		if rep != 0:
			story.rep += rep
		if trigger != "":
			Travel.set_trigger(trigger, trigger_set)
		story.give_rows(xml.get("reward", []))
		if sub:
			story.info("doneStage", nazv())
		else:
			story.info("doneTask", nazv())
			SfxBank.play("quest_ok")
		if end_dial != "" and story.dial_on():
			story.close_pip()
			ScriptsEngine.dialog(end_dial)
		if end_script != "":
			ScriptsEngine.run_script(end_script)
		story.quests_changed.emit()


## Pers.rep: reputation, saved with the story.
var rep := 0
var quests: Dictionary = {}
var notes: Array[String] = []
var npc_rep: Dictionary = {}

var _quest_data: Dictionary = {}
var _npc_data: Dictionary = {}
var _item_data: Dictionary = {}


func _ready() -> void:
	_quest_data = _read(QUESTS_PATH)
	_npc_data = _read(NPCS_PATH)
	_item_data = _read(ITEMS_PATH)
	Locale.language_changed.connect(_on_language)
	call_deferred("_register")


func _register() -> void:
	WorldState.run_reset.connect(reset_run)
	WorldState.register("story", get_state, set_state)
	reset_run()


func _on_language(_lang: String) -> void:
	StoryText.reset()
	quests_changed.emit()
	notes_changed.emit()


func reset_run() -> void:
	rep = 0
	quests.clear()
	notes.clear()
	npc_rep.clear()
	for note in BASE_NOTES:
		add_note(note)
	quests_changed.emit()


func get_state() -> Dictionary:
	var q := {}
	for id in quests:
		q[id] = (quests[id] as Quest).save()
	return {"rep": rep, "quests": q, "notes": notes.duplicate(), "npcs": npc_rep.duplicate(true)}


func set_state(data: Variant) -> void:
	if not data is Dictionary:
		return
	rep = int(data.get("rep", 0))
	quests.clear()
	notes.clear()
	for n in data.get("notes", []):
		notes.append(str(n))
	npc_rep = (data.get("npcs", {}) as Dictionary).duplicate(true)
	var saved: Dictionary = data.get("quests", {})
	for id in saved:
		add_quest(str(id), saved[id])
	# Game.init: closed quests give their next quests on load.
	for id in quests.keys():
		var q: Quest = quests[id]
		if q.state == 2:
			for nxt in q.xml.get("next", []):
				add_quest(str((nxt as Dictionary).get("id", "")))
	for note in BASE_NOTES:
		add_note(note)
	quests_changed.emit()
	notes_changed.emit()


# --- Game.as quests ---

## Game.addQuest. load_obj is a saved quest; then no message, sound or dialog.
func add_quest(id: String, load_obj: Dictionary = {}, _no_vis: bool = false, snd: bool = true, show_dial: bool = true) -> Quest:
	if quests.has(id):
		var have: Quest = quests[id]
		if have.state == 0:
			have.state = 1
			info("addTask", have.nazv())
			SfxBank.play("quest")
			have.is_closed()
			have.deposit()
			if have.state == 2:
				info("doneTask", have.nazv())
			quests_changed.emit()
		return have
	if not _quest_data.has(id):
		push_warning("Story: unknown quest %s" % id)
		return null
	var q := Quest.new(self, _quest_data[id], load_obj)
	quests[q.id] = q
	if load_obj.is_empty() and q.state > 0:
		info("addTask", q.nazv())
		q.deposit()
		if snd:
			SfxBank.play("quest")
	if load_obj.is_empty() and show_dial and q.beg_dial != "" and dial_on():
		close_pip()
		ScriptsEngine.dialog(q.beg_dial)
	quests_changed.emit()
	return q


func show_quest(id: String, sid: String) -> void:
	var q: Quest = quests.get(id)
	if q == null:
		q = add_quest(id, {}, true)
	if q == null or q.state == 2:
		return
	q.show_sub(sid)
	for s: Quest in q.subs:
		if s.id == sid:
			info("addTask2", s.nazv())
			SfxBank.play("quest")
			break
	quests_changed.emit()


## Game.closeQuest: an empty or negative sid closes the whole quest.
func close_quest(id: String, sid: String = "") -> void:
	var q: Quest = quests.get(id)
	if q == null:
		q = add_quest(id, {}, true)
	if q == null or q.state == 2:
		return
	if sid == "" or int(sid) < 0:
		q.close()
	else:
		q.close_sub(sid)
	quests_changed.emit()


func check_quests(cid: String) -> String:
	var res := ""
	for q: Quest in quests.values():
		if q.state == 1 and q.is_check:
			var r := q.check(cid)
			if r != "":
				res = r
	if res != "":
		quests_changed.emit()
	return res


func inc_quests(cid: String, n: int = 1) -> void:
	for q: Quest in quests.values():
		if q.state == 1 and q.is_check:
			q.inc(cid, n)
			q.check(cid)
	quests_changed.emit()


func quest(id: String) -> Quest:
	return quests.get(id)


## PipPageInfo quests: state > 0, sorted by state, main first, name.
func quest_list() -> Array:
	var arr: Array = []
	for q: Quest in quests.values():
		if q.state > 0:
			arr.append(q)
	arr.sort_custom(func(a: Quest, b: Quest) -> bool:
		if a.state != b.state:
			return a.state < b.state
		if a.main != b.main:
			return a.main
		return a.nazv().naturalnocasecmp_to(b.nazv()) < 0)
	return arr


## PipPage.infoQuest in BBCode: info, employer, numbered stages, closed
## stages dark, numbers and counts yellow.
func quest_text(id: String, yellow: String, dark: String) -> String:
	var q: Quest = quests.get(id)
	if q == null:
		return ""
	var s := _bb(q.info())
	if str(q.xml.get("empl", "")) != "":
		s += "\n\n" + _bb(OriginalLines.unit(str(q.xml.empl)))
	s += "\n"
	var n := 1
	for st: Quest in q.subs:
		if st.invis and st.state < 2:
			continue
		s += "\n"
		if st.state == 2:
			s += "[color=#%s]" % dark
		s += "[color=#%s]%d.[/color] " % [yellow, n]
		if st.hidden and st.state < 2 and st.est <= 0:
			s += "?????"
		else:
			s += _bb(st.nazv())
		if st.collect != "" and st.col_tip == 0:
			if st.give != "":
				s += " ([color=#%s]%d/%d[/color])" % [yellow, st.gived, st.kol]
				if st.est > 0 and st.state < 2:
					s += " ([color=#%s]+%d[/color])" % [yellow, st.est]
			else:
				s += " ([color=#%s]%d/%d[/color])" % [yellow, st.est, st.kol]
		if st.nn:
			s += " (%s)" % OriginalLines.pip("nn")
		if st.state == 2:
			s += "[/color]"
		n += 1
	return s


## Text pack [..] marks a highlight (yellow span); BBCode needs its own brackets.
func _bb(s: String) -> String:
	return s.replace("[", "\u0001").replace("]", "\u0002").replace("\u0001", "[color=#ffff33]").replace("\u0002", "[/color]")


## Npc vendors: give quest items to npc / report to npc (Vendor tasks).
func give_items(npc: String) -> bool:
	var ok := false
	for q: Quest in quests.values():
		if q.state == 1 and q.ch_give(npc, true):
			ok = true
		if q.state == 1 and q.ch_report(npc, true):
			ok = true
	if ok:
		quests_changed.emit()
	return ok


# --- notes ---

## Game.addNote: once per run (trigger note_<id>).
func add_note(id: String) -> void:
	if Travel.trigger("note_" + id) != null and notes.has(id):
		return
	Travel.set_trigger("note_" + id, 1)
	if notes.has(id):
		return
	notes.append(id)
	notes_changed.emit()


## PipPageInfo notes: dialogues with imp > 0; imp 3 first, the rest newest first.
func note_list() -> Array:
	var top: Array = []
	var rest: Array = []
	for id in notes:
		var d := StoryText.dialogue(id)
		var ico := int(d.get("imp", 0))
		if ico <= 0:
			continue
		var title := str(d.get("title", ""))
		if title == "" and not (d.get("lines", []) as Array).is_empty():
			title = StoryText.line_text((d.lines as Array)[0])
		var row := {"id": id, "title": StoryText.lp_name(title), "ico": ico}
		if ico == 3:
			top.append(row)
		else:
			rest.append(row)
	rest.reverse()
	return top + rest


func note_text(id: String) -> String:
	return StoryText.mess_text(id, true)


# --- NPC state (Npc.as) ---

func npc_data(id: String) -> Dictionary:
	return _npc_data.get(id, {})


func get_npc_rep(id: String) -> int:
	return int(npc_rep.get(id, 0))


func set_npc_rep(id: String, value: int) -> void:
	npc_rep[id] = value


# --- items ---

## ItemInteraction.giveReward rows: {id, kol} items and {trigger, set} flags.
func give_rows(rows: Variant) -> void:
	if not rows is Array:
		return
	for row_v in rows:
		var row: Dictionary = row_v
		if row.has("id"):
			give_reward(str(row.id), int(row.get("kol", -1)))
		if row.has("trigger"):
			Travel.set_trigger(str(row.trigger), str(row.set) if row.has("set") else 1)


## ItemInteraction.giveReward: take(item, 2) with the reward line.
func give_reward(id: String, kol: int = -1) -> void:
	take(id, kol, 2)


## Pers.addSkillPoint (quest sp).
func add_skill_points(n: int) -> void:
	Progression.skill_points += n
	if Progression.has_method("_commit"):
		Progression.call("_commit")


## ItemInteraction.take for scripts (tr 0) and rewards (tr 2).
func take(id: String, kol: int = -1, tr: int = 0) -> void:
	if id == "":
		return
	var n := maxi(kol, 1)
	var first := Inventory.count(id) == 0
	Inventory.add(id, n)
	var name := Inventory.name_of(id)
	if tr == 2:
		if n > 1:
			info("reward", name, str(n))
		else:
			info("reward2", name)
	elif tr == 0:
		if id == "money":
			info("takeMoney", str(n))
		else:
			info("take", name + (" (%d)" % n if n > 1 else ""))
	ScriptsEngine.item_taken(id, first)


## ItemInteraction.withdraw: the item leaves the bag with the withdraw line.
func withdraw(id: String, n: int = 1) -> void:
	if id == "" or n <= 0:
		return
	Inventory.spend(id, mini(n, Inventory.count(id)))
	info("withdraw", Inventory.name_of(id), str(n))


func is_book(id: String) -> bool:
	return str((_item_data.get(id, {}) as Dictionary).get("tip", "")) == "book"


func is_document(id: String) -> bool:
	return (_item_data.get(id, {}) as Dictionary).has("text")


## ItemInteraction.useItem for a book (perk or upSkill, then lbook) or a
## document (its dialogue, and its perk). Books are spent; documents stay.
func read_item(id: String) -> bool:
	var row: Dictionary = _item_data.get(id, {})
	if row.is_empty() or Inventory.count(id) <= 0:
		return false
	if _in_battle():
		info("noUseCombat")
		return false
	if row.has("text"):
		close_pip()
		ScriptsEngine.dialog(str(row.text))
		if row.has("perk"):
			Progression.grant_perk(str(row.perk))
		return true
	if str(row.get("tip", "")) != "book":
		return false
	if Inventory.hard_inv() and not _at_base():
		info("noBase")
		return false
	if row.has("perk"):
		Progression.grant_perk(str(row.perk))
	else:
		Progression.upskill_from_book(id)
	Inventory.add("lbook", 1)
	Inventory.spend(id, 1)
	return true


# --- helpers ---

## GUI.infoText: an 'info' line with @1/@2.
func info(id: String, a1: String = "", a2: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	if hud != null and hud.has_method("show_notice"):
		hud.show_notice(OriginalLines.info(id, a1, a2))


## A port_strings line in the info log.
func info_port(key: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	if hud != null and hud.has_method("show_notice"):
		hud.show_notice(Locale.t(key))


## GameContainer.dialOn (settings: dialon).
func dial_on() -> bool:
	return bool(UiSettings.value("game", "dialon", true))


## PipBuck.onoff(-1).
func close_pip() -> void:
	var pause := pause_menu()
	if pause != null and pause.has_method("close_pipbuck"):
		pause.call("close_pipbuck")


## PipBuck.onoff(page, sub).
func open_pip(page: int, sub: int = 0) -> void:
	var pause := pause_menu()
	if pause != null and pause.has_method("open_pipbuck_at"):
		pause.call("open_pipbuck_at", page, sub)


func pause_menu() -> Node:
	var scene := get_tree().current_scene if is_inside_tree() else null
	return scene.find_child("PauseMenu", true, false) if scene != null else null


func _in_battle() -> bool:
	return GameState.has_method("_in_battle") and bool(GameState.call("_in_battle"))


func _at_base() -> bool:
	return Travel.can_travel_here()


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Story: missing %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
