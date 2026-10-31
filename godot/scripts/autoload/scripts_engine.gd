extends Node

## Script.as: scripts from Scripts.xml, map objects, lands, quests and NPC
## dialogs. A step is {act, targ, val, t, n, opt1, opt2}; t is seconds in the
## data and frames (30 a second) here. A script with a delay, a dial, dialog,
## inform or landlevel step runs on a timer, else all its steps run at once.
## Land scripts step only while their land is shown (Land.step); the GUI
## dialog and inform scripts always step. Nothing steps while the game is
## paused. Triggers live in Travel.triggers.
## Ctr.keyPressed (left click) advances a waiting line, keyPressed2 (right
## click) skips the rest; the port adds A / accept / interact and B / cancel.

const FPS := 30.0
const REP_GOOD := 70
const Registry := preload("res://scripts/map/land_registry.gd")
const StoryText := preload("res://scripts/story/story_text.gd")
const DialogueBox := preload("res://scripts/story/dialogue_box.gd")
const StoryScreen := preload("res://scripts/story/story_screen.gd")
const EFFECTS_PATH := "res://assets/data/effects.json"
const TIMED: PackedStringArray = ["dial", "dialog", "inform", "landlevel"]
## Script.com: every command without a target.
const COMMANDS: PackedStringArray = [
	"control off", "control on", "mess", "dial", "dialog", "inform", "landlevel",
	"allact", "take", "takeArmor", "fav", "armor", "xp", "perk", "eff", "remeff",
	"music", "music_rep", "anim", "turn", "black", "dblack", "gui off", "gui on",
	"refill", "upland", "locon", "locoff", "quest", "showstage", "show", "stage",
	"trigger", "goto", "gotoland", "openland", "passed", "actprob", "alarm",
	"trus", "checkall", "robots", "weapch", "alicorn", "wave", "pip",
	"speceffect", "scene", "endgame", "gameover", "wait",
]
## Commands the port accepts but cannot show yet: they only log once.
const STUBS: PackedStringArray = []
const AlicornForm := preload("res://scripts/story/alicorn_form.gd")
const WorkAnim := preload("res://scripts/player_work_anim.gd")
const ImpMess := preload("res://scripts/imp_mess.gd")

class StoryScript:
	extends RefCounted
	var id := ""
	var eve := ""
	var acts: Array = []
	var owner_ref: WeakRef
	var land_id := ""
	var gui := false
	var on_timer := false
	var running := false
	var wait := false
	var ncom := 0
	var tcom := 0
	var dial_n := -1
	var act_obj: Dictionary = {}

	func owner() -> Node:
		return owner_ref.get_ref() as Node if owner_ref != null else null


var key_pressed := false
var key_pressed2 := false
## GameContainer.alicorn: Littlepip in the alicorn armour (portrait lpa).
var alicorn := false
## Commands seen in data that Script.com does not have: act -> count.
var unknown: Dictionary = {}
var dial_script: StoryScript
var inform_script: StoryScript

var _land_scripts: Array = []
var _cache: Dictionary = {}
var _stub_logged: Dictionary = {}
var _tick_acc := 0.0
var _box: DialogueBox
var _screen: StoryScreen
var _mess_text := ""
var _mess_left := 0
var _show_on := false
var _show_at := Vector2.ZERO
var _effect_t: Dictionary = {}
## Location.trus per room cell.
var _trus: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box = DialogueBox.new()
	add_child(_box)
	_screen = StoryScreen.new()
	add_child(_screen)
	dial_script = make({"id": "dialScript", "acts": [{"act": "dialog"}]})
	dial_script.gui = true
	inform_script = make({"id": "informScript", "acts": [{"act": "inform"}]})
	inform_script.gui = true
	var eff: Variant = JSON.parse_string(FileAccess.get_file_as_string(EFFECTS_PATH)) if FileAccess.file_exists(EFFECTS_PATH) else null
	if eff is Dictionary:
		for row_v in (eff as Dictionary).get("effects", []):
			_effect_t[str(row_v.get("id", ""))] = float(row_v.get("t", 0))
	Travel.land_entered.connect(_on_land_entered)
	call_deferred("_connect_reset")


func _connect_reset() -> void:
	WorldState.run_reset.connect(reset_run)
	WorldState.register("alicorn", func() -> Variant: return alicorn, _set_alicorn)


## Pers.load obj.alicorn: UnitPlayer init calls alicornOn(false).
func _set_alicorn(data: Variant) -> void:
	alicorn = bool(data)
	if alicorn:
		call_deferred("_alicorn_quiet")


func _alicorn_quiet() -> void:
	AlicornForm.on(false)


func reset_run() -> void:
	_land_scripts.clear()
	_cache.clear()
	dial_script.running = false
	inform_script.running = false
	alicorn = false
	_trus.clear()
	_show_on = false
	_mess_text = ""
	key_pressed = false
	key_pressed2 = false
	_box.hide_all()
	_screen.reset()


# --- making and starting scripts ---

## Script(xml, land, owner, tt). data is {id?, eve?, acts: [{act, targ, val,
## t (seconds), n, opt1, opt2}]}; tt forces the timer.
func make(data: Dictionary, owner: Node = null, tt := false) -> StoryScript:
	var s := StoryScript.new()
	s.id = str(data.get("id", ""))
	s.eve = str(data.get("eve", ""))
	for a_v in data.get("acts", []):
		if not a_v is Dictionary:
			continue
		var a: Dictionary = a_v
		var act := str(a.get("act", ""))
		if act == "":
			continue
		var step := {
			"act": act,
			"targ": str(a.get("targ", "")),
			"val": str(a.get("val", "")),
			"t": int(round(float(str(a.get("t", "0"))) * FPS)) if str(a.get("t", "")) != "" else 0,
			"n": str(a.get("n", "-1")),
			"opt1": int(float(str(a.get("opt1", "0")))),
			"opt2": int(float(str(a.get("opt2", "0")))),
		}
		if act in TIMED or int(step.t) > 0:
			s.on_timer = true
		s.acts.append(step)
	if tt:
		s.on_timer = true
	s.owner_ref = weakref(owner) if owner != null else null
	s.land_id = current_land()
	return s


## Script.start.
func start(s: StoryScript) -> void:
	if s == null or s.acts.is_empty():
		return
	if s.on_timer:
		s.ncom = 0
		_com(s, s.acts[0])
		s.tcom = int(s.acts[0].t)
		s.running = true
		if not s.gui and not _land_scripts.has(s):
			_land_scripts.append(s)
	else:
		for obj in s.acts.duplicate():
			_com(s, obj)


## One script per source (key), like the Script object an Area or Box keeps:
## starting it again while it runs restarts it.
func run(data: Dictionary, owner: Node = null, key: String = "", tt := false) -> StoryScript:
	var s: StoryScript = _cache.get(key) if key != "" else null
	if s == null or s.land_id != current_land():
		s = make(data, owner, tt)
		if key != "":
			_cache[key] = s
	start(s)
	return s


## Steps as land_props keeps them (script_of rows).
func run_steps(steps: Array, owner: Node = null, key: String = "") -> void:
	if steps.is_empty():
		return
	run({"acts": steps}, owner, key)


## Game.runScript: a named Scripts.xml script.
func run_script(id: String, owner: Node = null) -> void:
	var data := Registry.script(id)
	if data.is_empty():
		push_warning("ScriptsEngine: no script %s" % id)
		return
	var copy := data.duplicate(true)
	copy["id"] = id
	run(copy, owner, "named:" + id)


## GUI.dialog: the dialog script with this dialogue.
func dialog(id: String) -> void:
	(dial_script.acts[0] as Dictionary)["val"] = id
	start(dial_script)


## GUI.inform.
func inform(text: String, mod: int = 1, pushed := false) -> void:
	var a: Dictionary = inform_script.acts[0]
	a["val"] = text
	a["opt2"] = mod
	a["opt1"] = 1 if pushed else 0
	start(inform_script)


## Land itemScripts[id] (Land1s/Lands <scr eve="take" item>) and the quest
## collect line, after an item reaches the bag. first: the bag had none.
func item_taken(id: String, first: bool = true) -> void:
	if first:
		var data := land_item_script(current_land(), id)
		if not data.is_empty():
			run(data, null, "take:%s:%s" % [current_land(), id])
	var res := Story.check_quests(id)
	if res != "":
		Story.info("collect", res)
	ImpMess.item_taken(get_tree(), id)


## Unit.die / UnitCaptive.free with a questId: the land's script for it and
## the quest counter.
func quest_unit(qid: String) -> void:
	if qid == "":
		return
	var data := land_item_script(current_land(), qid)
	if not data.is_empty():
		run(data, null, "take:%s:%s" % [current_land(), qid])
	Story.inc_quests(qid)


func land_item_script(land_id: String, item: String) -> Dictionary:
	for row_v in Registry.land(land_id).get("scr", []):
		var row: Dictionary = row_v
		if str(row.get("eve", "")) == "take" and str(row.get("item", "")) == item:
			return row
	return {}


## Area.step: scrOver on entering, once only for trig areas (triggers[uid]).
func area_over(area: Node, uid: String, steps: Array, trig: bool) -> void:
	if steps.is_empty():
		return
	if trig and uid != "":
		if _num(Travel.trigger(uid)) == 1:
			return
		Travel.set_trigger(uid, 1)
	run_steps(steps, area, "over:%d" % area.get_instance_id())


func area_out(area: Node, steps: Array) -> void:
	run_steps(steps, area, "out:%d" % area.get_instance_id())


func is_waiting() -> bool:
	if dial_script.running and dial_script.wait:
		return true
	if inform_script.running and inform_script.wait:
		return true
	var here := current_land()
	for s: StoryScript in _land_scripts:
		if s.running and s.wait and s.land_id == here:
			return true
	return false


func current_land() -> String:
	var land := get_tree().get_first_node_in_group("active_land") if is_inside_tree() else null
	if land == null:
		return ""
	var value: Variant = land.get("land_id")
	return str(value) if value != null and str(value) != "" else "begin"


# --- stepping ---

func _process(delta: float) -> void:
	if not Travel.has_host():
		if _box.visible_any():
			_box.hide_all()
		return
	if GameState.paused:
		return
	_tick_acc += delta * FPS
	var ticks := mini(int(_tick_acc), 5)
	_tick_acc -= float(ticks)
	for _i in ticks:
		_tick()


func _tick() -> void:
	if dial_script.running:
		_step(dial_script)
	if inform_script.running:
		_step(inform_script)
	var here := current_land()
	for s: StoryScript in _land_scripts.duplicate():
		if s.running and s.land_id == here:
			_step(s)
	_land_scripts = _land_scripts.filter(func(s: StoryScript) -> bool: return s.running)
	_show_step()
	_trus_step()
	if _mess_left > 0:
		_mess_left -= 1


## Script.step.
func _step(s: StoryScript) -> void:
	if s.tcom > 0:
		s.tcom -= 1
	if s.tcom > 0:
		return
	if s.wait:
		if key_pressed2:
			s.dial_n = 10000
		elif not key_pressed:
			return
		if s.dial_n < 0:
			_box.hide_all()
			s.wait = false
		else:
			s.dial_n += 1
			if dial_text(s.act_obj.val, s.dial_n, int(s.act_obj.opt1) > 0, true):
				key_pressed = false
				return
			_box.hide_all()
			Travel.set_control(true)
			s.wait = false
		key_pressed = false
		key_pressed2 = false
	s.ncom += 1
	if s.ncom >= s.acts.size():
		s.running = false
		_box.hide_all()
	else:
		_com(s, s.acts[s.ncom])
		s.tcom = int(s.acts[s.ncom].t)


## GUI.dialText: line n of dialogue id, or a ready line {mod, pushed, text}.
## False when there is no such line.
func dial_text(id: Variant, n: int, down: bool, wait: bool) -> bool:
	if id is String:
		var rows := StoryText.lines(id)
		if rows.is_empty() or n >= rows.size():
			return false
		Story.add_note(id)
		return _box.show_line(rows[maxi(n, 0)], down, wait, alicorn)
	if id is Dictionary:
		return _box.show_line(id, down, wait, alicorn)
	_box.hide_all()
	return false


# --- commands ---

## Script.com.
func _com(s: StoryScript, obj: Dictionary) -> void:
	s.act_obj = obj
	if _box.dial_visible():
		_box.hide_all()
	key_pressed = false
	key_pressed2 = false
	s.wait = false
	s.dial_n = -1
	var act := str(obj.act)
	var val := str(obj.val)
	var n := str(obj.n)
	if str(obj.targ) != "":
		_target(s, str(obj.targ), act, val)
		return
	match act:
		"control off":
			Travel.set_control(false)
		"control on":
			Travel.set_control(true)
		"mess":
			_mess(StoryText.mess_text(val), int(obj.opt1) > 0, int(obj.opt2) > 0)
		"dial":
			if not (int(obj.t) > 0):
				s.wait = true
			dial_text(val, int(n), int(obj.opt1) > 0, s.wait)
		"dialog":
			if Story.dial_on():
				Travel.set_control(false)
				s.wait = true
				s.dial_n = 0
				dial_text(val, 0, int(obj.opt1) > 0, true)
		"inform":
			Travel.set_control(false)
			s.wait = true
			s.dial_n = 0
			dial_text({"mod": int(obj.opt2), "push": 1 if int(obj.opt1) > 0 else 0, "text": val, "plain": true}, 0, false, true)
		"landlevel":
			var land := Registry.land(val)
			if Story.dial_on() and not land.is_empty():
				Travel.set_control(false)
				s.wait = true
				var dif := Registry.int_of(land.get("dif"), 0)
				var lvl := int(Progression.level)
				var t := "%s\n%s: [%d]\n%s: [%d]" % [OriginalLines.text("map", val), OriginalLines.pip("recLevel"), dif, OriginalLines.pip("isperslvl"), lvl]
				if dif > lvl:
					t += "\n\n" + OriginalLines.pip("wrLevel")
				dial_text({"mod": 1, "text": t, "plain": true}, 0, false, true)
		"allact":
			var props := _props()
			if props != null and props.has_method("all_act"):
				props.all_act(val, n)
		"take":
			if int(n) < 0:
				if Inventory.count(val) > 0:
					Story.withdraw(val, -int(n))
			else:
				Story.take(val, maxi(int(n), 1))
		"takeArmor":
			if Inventory.count(val) <= 0:
				Inventory.add(val, 1)
		"armor":
			if Inventory.worn != val:
				Inventory.wear(val)
		"xp":
			Progression.add_xp(int(val))
		"perk":
			Progression.grant_perk(val)
		"eff":
			var secs := float(obj.opt2) if int(obj.opt2) > 0 else float(_effect_t.get(val, 0.0))
			GameState.start_effect(val, secs)
		"remeff":
			GameState.end_effect(val)
		"music":
			AudioManager.play_story(val, int(n) if int(n) > 0 else 0)
		"music_rep":
			if Story.rep >= REP_GOOD:
				AudioManager.play_story(val)
		"anim":
			# UnitPlayer.anim: opt1 holds the last frame (animOff), else work dey for the clip.
			if val == "" or val == "null":
				WorkAnim.stop(_player())
			else:
				WorkAnim.play(_player(), val, -1, int(obj.opt1) > 0)
		"turn":
			var player := _player()
			if player != null:
				var dir := 1.0 if float(val) > 0.0 else -1.0
				if "facing" in player:
					player.set("facing", dir)
				if player is CharacterBody2D:
					(player as CharacterBody2D).velocity.x += dir * 3.0 * FPS
		"black":
			Travel.set_black(float(val))
		"dblack":
			Travel.set_dblack(float(val))
		"gui off":
			_hp_bars(false)
		"gui on":
			_hp_bars(true)
		"refill":
			Travel.refill()
		"upland":
			Travel.up_land_level()
		"quest":
			Story.add_quest(val)
		"showstage":
			Story.show_quest(val, n)
		"show":
			_show_on = false
		"stage":
			Story.close_quest(val, n)
		"trigger":
			Travel.set_trigger(val, int(n) if n.is_valid_int() else n)
		"goto":
			var parts := val.split(" ")
			if parts.size() == 2:
				_goto_room(int(parts[0]), int(parts[1]))
		"gotoland":
			if n == "2":
				Travel.goto_land(val, "", true)
			elif n == "1":
				Travel.goto_land(val, "%d:%d" % [int(obj.opt1), int(obj.opt2)])
			else:
				var props := _props()
				if props != null and props.has_method("script_goto_land"):
					props.script_goto_land(val)
				else:
					Travel.goto_land(val)
		"openland":
			Travel.open_land(val)
		"passed":
			Travel.pass_land()
		"alarm":
			var props := _props()
			var player := _player()
			if props != null and player != null and props.has_method("_raise_alarm"):
				props.call("_raise_alarm", player.global_position)
		"checkall":
			for npc in get_tree().get_nodes_in_group("story_npc"):
				if npc.has_method("script_command"):
					npc.script_command("check", "")
		"weapch":
			Inventory.equip(val)
		"alicorn":
			if float(val) <= 0.0:
				AlicornForm.off()
			else:
				AlicornForm.on()
		"fav":
			Favorites.fav_item(val, int(n))
		"locon", "locoff":
			var props := _props()
			var player := _player()
			if props != null and player != null and props.has_method("room_power"):
				props.room_power(player.global_position, act == "locon")
		"robots":
			var props := _props()
			var player := _player()
			if props != null and player != null and props.has_method("robocells"):
				props.robocells(player.global_position)
		"trus":
			var at := _room_point(s)
			if at != Vector2.INF:
				_trus[_cell(at)] = _num(val)
		"actprob", "wave":
			var trial := _trial()
			if trial != null:
				if act == "wave":
					trial.begin_wave()
				else:
					trial.activate_prob()
		"pip":
			var page := int(val)
			if page < 0:
				Story.close_pip()
			elif page == 4:
				Story.info_port("trade_not_yet")
			else:
				Story.open_pip(page, int(n) if int(n) > 0 else 0)
		"speceffect":
			_screen.spec_effect(float(n))
		"scene":
			if val != "":
				_screen.show_scene(val, int(n))
			else:
				_screen.hide_scene()
		"endgame":
			_endgame(0)
		"gameover":
			_endgame(1)
		"wait":
			s.wait = true
			s.dial_n = 0
		_:
			if act in STUBS:
				_stub(act)
			else:
				unknown[act] = int(unknown.get(act, 0)) + 1
				if int(unknown[act]) == 1:
					push_warning("ScriptsEngine: unknown command %s in %s" % [act, s.id])


## Obj.command on land.uidObjs[targ] ("this" is the owner).
func _target(s: StoryScript, targ: String, act: String, val: String) -> void:
	var node: Node = s.owner() if targ == "this" else _uid(targ)
	if node == null or not is_instance_valid(node):
		return
	if act == "show" and node is Node2D:
		_show_on = true
		_show_at = (node as Node2D).global_position
	if node.has_method("script_command"):
		node.script_command(act, val)
		return
	var props := _props()
	if props != null and props.has_method("script_command"):
		props.script_command(node, act, val)


func _uid(uid: String) -> Node:
	var props := _props()
	if props != null and props.has_method("script_target"):
		return props.script_target(uid)
	return null


## World.endgame: the final scene, or gameover.
func _endgame(kind: int) -> void:
	var s := ""
	if kind == 1:
		_screen.show_scene("gameover", 0)
		s = OriginalLines.gui("end_bad")
	elif Story.rep >= REP_GOOD:
		_screen.show_scene("endgame", 0)
		s = OriginalLines.gui("end_good")
		AudioManager.play_story("music_fall_2")
	else:
		_screen.show_scene("endgame", 0)
		s = OriginalLines.gui("end_norm")
	_screen.scene_text(StoryText.lp_name(s))


## GUI.messText(id, "", down, push): pushed lines add to a message still up.
func _mess(text: String, down: bool, push: bool) -> void:
	if text == "":
		return
	if push and _mess_left > 0 and _mess_text != "":
		text = _mess_text + "\n" + text
	_mess_text = text
	_mess_left = 150
	var hud := _hud()
	if hud != null and hud.has_method("show_message"):
		hud.show_message(text.replace("[", "").replace("]", ""), down)


## GUI.hpBarOnOff.
func _hp_bars(on: bool) -> void:
	var hud := _hud()
	if hud == null:
		return
	for path in ["Root/Bars", "Root/HpText", "Root/Effects"]:
		var node := hud.get_node_or_null(path) as CanvasItem
		if node != null:
			node.visible = on


## Land.gotoXY: the player to land room x:y at its spawn cell.
func _goto_room(x: int, y: int) -> void:
	var props := _props()
	var host := get_tree().current_scene
	if props == null or host == null or not props.has_method("room_spawn"):
		return
	var at: Variant = props.room_spawn(x, y)
	if at is Vector2 and host.has_method("place_player"):
		host.place_player(at)


## Camera.showOn: the view leans toward the shown object, then back.
func _show_step() -> void:
	var player := _player()
	if player == null:
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var goal := (_show_at - player.global_position) if _show_on else Vector2.ZERO
	if cam.offset.distance_to(goal) < 0.5:
		cam.offset = goal
	else:
		cam.offset = cam.offset.lerp(goal, 0.1)


func _on_land_entered(_id: String) -> void:
	AudioManager.clear_story()
	_show_on = false
	_trus.clear()
	if alicorn:
		Inventory._push_armor.call_deferred(AlicornForm.VISUAL)


## Location.trus: the room shakes every tick while the player is in it.
func _trus_step() -> void:
	if _trus.is_empty():
		return
	var player := _player()
	if player == null:
		return
	var t := float(_trus.get(_cell(player.global_position), 0.0))
	if t > 0.0:
		CamShake.quake(t * 0.5, t)


## The room point of a script: its owner, else the player.
func _room_point(s: StoryScript) -> Vector2:
	var owner := s.owner()
	if owner is Node2D and is_instance_valid(owner):
		return (owner as Node2D).global_position
	var player := _player()
	return player.global_position if player != null else Vector2.INF


func _cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / 1920.0), floori(at.y / 1000.0))


## Location.prob of the player's room.
func _trial() -> Node:
	var props := _props()
	var player := _player()
	if props == null or player == null or not props.has_method("trial_at"):
		return null
	return props.trial_at(player.global_position)


func _stub(act: String) -> void:
	if _stub_logged.has(act):
		return
	_stub_logged[act] = true
	print("ScriptsEngine: %s is not shown in the port yet" % act)


func _num(v: Variant) -> float:
	if v == null:
		return 0.0
	if v is int or v is float:
		return float(v)
	var s := str(v)
	return float(s) if s.is_valid_float() else 0.0


func _props() -> Node:
	return get_tree().get_first_node_in_group("land_props") if is_inside_tree() else null


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null


func _hud() -> Node:
	return get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
