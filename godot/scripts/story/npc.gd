extends Node2D

## UnitNPC with its Npc (Npc.as), and UnitCaptive. Npcs.xml rows come from
## assets/data/story/npcs.json; rep is saved by Story.
## Npc.check picks the first <dial> whose conditions hold: using the NPC runs
## it (its scr script with the dialog in front, then trigger dial_<id> and
## checkall), else it only sets the status (sign icon, userAction).
## activate without a dialog: travel map, doctor page, autodoc repair,
## patient, vendor (the PipBuck trade page), ndial or the "dial" bark.
## Art: visual<Vis> with the visNPCIco head icon (NpcVis sheets); a stand-in
## body with the name only when a sheet is missing.
## Groups: story_npc, land_objects.

const StoryText := preload("res://scripts/story/story_text.gd")
const NpcVis := preload("res://scripts/story/npc_vis.gd")
const FPS := 30.0
const BARK_COOLDOWN := 30
const _Bullet := preload("res://scenes/bullet.tscn")
## units.xml <vis replic>: the bark set when the npc has no replic of its own.
const REPLIC := {"vendor": "vendor", "doctor": "doctor", "captive": "captive", "ponpon": "ponpon"}

var kind := "npc"
var npc_id := ""
var unit_id := ""
var uid := ""
var data: Dictionary = {}
var row: Dictionary = {}
var is_hidden := false
var zzz_gen := false
var npc_inter := ""
var vendor := ""
var ua1 := ""
var ua2 := ""
var ndial := ""
var id_replic := ""
var silent := false
var no_turn := false
var facing := 1.0
var ai_tip := ""
## UnitCaptive.statusCapt: 1 once the cage is open.
var status_capt := 0
var qid := ""
## Unit.trig (appearance condition) and Unit.trigDis (Unit.checkTrig failed).
var trig := ""
var trig_off := false

var _props: Node
var _body: Polygon2D
var _name_label: Label
var _sign: Label
var _vis_root: Node2D
var _vis: AnimatedSprite2D
var _pon: AnimatedSprite2D
var _ico: AnimatedSprite2D
var _ico_frame := 1
## UnitCaptive / UnitPonPon tr (pony look, 1-based) and sr (cage).
var _tr := 1
var _sr := 0
var _t_anim := 0
var _bark: Label
var _bark_left := 0
var _t_replic := 0
var _t_ref := 0
var _que: Array = []
var _wait := 0
var _fly_to: Variant = null
## Top-left of the npc's room; script cells (fly) are room-local.
var _room_origin := Vector2.ZERO
## UnitNPC.zanyato: fighting, no talk.
var busy := false
var _airborne := false
var _fall_v := 0.0
var _cel: Node2D = null
var _gun_row := {}
var _gun_t := 0
var _gun_reload := 0
var _gun_rounds := -1
var _tick_acc := 0.0


func setup(plan_row: Dictionary, props: Node) -> void:
	row = plan_row
	_props = props
	var attrs: Dictionary = row.get("attrs", {})
	unit_id = str(row.get("unit_id", row.get("id", "npc")))
	uid = str(row.get("uid", ""))
	qid = str(attrs.get("qid", ""))
	trig = str(attrs.get("trig", ""))
	var cl := str(row.get("cl", "UnitNPC"))
	kind = {"UnitCaptive": "captive", "UnitPonPon": "ponpon", "UnitTrain": "train"}.get(cl, "npc")
	var feet: Array = row.get("feet", [0, 0])
	position = Vector2(float(feet[0]), float(feet[1]))
	var room: Array = row.get("room", [])
	if room.size() >= 2:
		_room_origin = Vector2(int(room[0]) * 1920.0, int(room[1]) * 1000.0)
	name = "npc_%s" % (uid if uid != "" else unit_id)
	add_to_group("story_npc")
	add_to_group("land_objects")
	set_meta("uid", uid)
	set_meta("id", unit_id)
	if kind == "npc":
		npc_id = str(attrs.get("npc", ""))
		data = Story.npc_data(npc_id) if npc_id != "" else {}
		if data.is_empty():
			npc_id = unit_id
			vendor = unit_id
			npc_inter = "doc" if unit_id == "doctor" else "vr"
		else:
			npc_inter = str(data.get("inter", ""))
			vendor = str(data.get("vendor", ""))
			ua1 = str(data.get("ua1", ""))
			ua2 = str(data.get("ua2", ""))
			ndial = str(data.get("ndial", ""))
			id_replic = str(data.get("replic", ""))
			silent = data.has("silent")
			no_turn = data.has("noturn")
			if vendor != "" and npc_inter == "":
				npc_inter = "doc" if vendor == "doctor" else "vr"
		# UnitNPC.as:99: an explicit npcXML replic (even '' for the autodoc, a
		# machine) overrides the unit-class default (units.xml vis replic).
		if not data.has("replic"):
			id_replic = str(REPLIC.get(unit_id, ""))
		if attrs.has("ai"):
			ai_tip = str(attrs.ai)
		_airborne = str(attrs.get("fly", "0")) not in ["", "0"]
	else:
		id_replic = str(REPLIC.get(kind, ""))
		npc_id = kind
	if attrs.has("tr"):
		_tr = int(attrs.tr)
	elif kind == "captive" or kind == "ponpon":
		_tr = int(_flag("tr", randi_range(1, 11)))
		_set_flag("tr", _tr)
	_sr = int(attrs.get("sr", 0))
	if kind == "captive":
		status_capt = int(_flag("captive", int(attrs.get("st", 0))))
		if not attrs.has("lock"):
			set_meta("locktip", 1)
			set_meta("lock", 1.0 if status_capt == 0 else 0.0)
	_build()
	_t_replic = int(randf() * 1500.0) if kind == "captive" else int(randf() * 500.0 + 200.0)
	_init_npc()
	if attrs.has("hide"):
		_hide()
	refresh()
	check()
	_apply_hidden()


## The interaction word (Interact.userAction) for land_props._add_use.
func user_action() -> String:
	return str(get_meta("user_action", "dial"))


func rep() -> int:
	return Story.get_npc_rep(npc_id)


func set_rep(v: int) -> void:
	Story.set_npc_rep(npc_id, v)


# --- Npc.as ---

## Npc.init.
func _init_npc() -> void:
	if npc_id == "calam":
		if rep() == 0 or _num(Travel.trigger("rbl_visited")) > 0:
			is_hidden = true
		if rep() == 1:
			ai_tip = "agro"
	if npc_id == "steel2":
		refresh()
	if npc_id == "adoc" and rep() <= 1:
		set_meta("act_time", 45)


## Npc.refresh.
func refresh() -> void:
	var storm := _num(Travel.trigger("storm"))
	match npc_id:
		"calam2":
			is_hidden = storm > 0
		"calam3":
			is_hidden = storm != 1
		"calam4":
			is_hidden = storm != 2 and storm != 3
		"calam5":
			is_hidden = storm != 3
		"steel2":
			is_hidden = _num(Travel.trigger("mbase_visited")) > 0
		"steel":
			is_hidden = storm == 5
		"askari":
			is_hidden = _num(Travel.trigger("story_ranger")) > 0
		"askari2":
			is_hidden = not (_num(Travel.trigger("story_ranger")) > 0) or storm > 0
		"patient":
			zzz_gen = rep() == 2
		"observer":
			is_hidden = _num(Travel.trigger("observer")) != 1
		"observer2":
			is_hidden = storm != 2
		"askari3":
			is_hidden = not (storm >= 2)
		"mentor":
			is_hidden = _num(Travel.trigger("theend")) > 0


## UnitNPC.npcFun / UnitCaptive.free: the player used the NPC.
func use_object(_from_timer: bool = false) -> void:
	if kind == "captive":
		_free()
		return
	if busy or _t_ref > 0:
		return
	_t_ref = (1 + randi() % 5) * BARK_COOLDOWN
	if not no_turn:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			facing = -1.0 if global_position.x > player.global_position.x else 1.0
			_face()
	activate()


## Npc.activate.
func activate() -> void:
	if check(true) and npc_inter != "patient":
		return
	match npc_inter:
		"travel":
			Travel.open_travel_map()
		"doc", "vdoc":
			_pip(6)
		"adoc":
			if rep() <= 1:
				repair()
			else:
				_pip(6)
		"patient":
			patient()
		_:
			if vendor != "":
				_pip(4)
			elif ndial != "":
				ScriptsEngine.dialog(ndial)
			else:
				script_command("tell", "dial")


## Npc.pip: PipBuck.vendor / npcId / npcInter, then the trade (4) or
## healing (6) page.
func _pip(n: int) -> void:
	Vendors.open_npc(self, n)
	script_command("replicVse", "")


## Npc.check.
func check(us: bool = false) -> bool:
	for dial_v in data.get("dials", []):
		var dial: Dictionary = dial_v
		var did := str(dial.get("id", ""))
		if Travel.trigger("dial_" + did) != null and _truthy(Travel.trigger("dial_" + did)):
			continue
		if dial.has("lvl") and int(dial.lvl) > int(Progression.level):
			continue
		if dial.has("barter") and int(dial.barter) > Progression.skill_level_of("barter"):
			continue
		if dial.has("trigger"):
			var want: Variant = dial.n if dial.has("n") else 1
			if not _eq(Travel.trigger(str(dial.trigger)), want):
				continue
		if dial.has("prev") and not _eq(Travel.trigger("dial_" + str(dial.prev)), 1):
			continue
		if dial.has("land") and not bool((Travel.lands.get(str(dial.land), {}) as Dictionary).get("access", false)):
			continue
		if dial.has("armor") and Inventory.worn != str(dial.armor):
			continue
		if dial.has("pet"):
			continue
		if dial.has("quest"):
			var q: Variant = Story.quest(str(dial.quest))
			if q == null or q.state != 1:
				continue
			if dial.has("sub"):
				var sq: Variant = q.subs_id.get(str(dial.sub))
				if sq == null or sq.invis:
					continue
		if us:
			var scr: Array = dial.get("scr", [])
			if not scr.is_empty():
				var acts: Array = ((scr[0] as Dictionary).get("acts", []) as Array).duplicate(true)
				if Story.dial_on():
					acts.push_front({"act": "dialog", "val": did})
				acts.append({"act": "trigger", "val": "dial_" + did, "n": "1"})
				acts.append({"act": "checkall", "n": "1"})
				ScriptsEngine.start(ScriptsEngine.make({"id": did, "acts": acts}, self, true))
			else:
				if Story.dial_on():
					ScriptsEngine.dialog(did)
				Travel.set_trigger("dial_" + did, 1)
			for rew_v in dial.get("reward", []):
				var rew: Dictionary = rew_v
				if rew.has("id"):
					Story.give_reward(str(rew.id), int(rew.get("kol", -1)))
			if dial.has("music"):
				AudioManager.play_story(str(dial.music))
			check()
		else:
			set_status(2 if dial.has("imp") else 1)
		return true
	if not us:
		set_status(0)
	return false


## Npc.setStatus.
func set_status(dial: int = 0) -> void:
	var action := "dial"
	_set_ico(29 + dial if dial > 0 else _ico_frame - 1)
	if dial > 0:
		_sign.text = "!" if dial == 2 else "?"
		action = ua1 if ua1 != "" else "dial"
		script_command("sign", "")
	else:
		_sign.visible = false
		if ua2 != "":
			action = ua2
		elif npc_inter == "doc" or npc_inter == "vdoc":
			action = "therapy"
		elif npc_inter == "patient":
			if str(Travel.trigger("patient_tr2")) == "1":
				set_meta("act_time", 0)
				action = "dial"
			else:
				set_meta("act_time", 30)
				action = "see"
		elif npc_inter == "adoc":
			action = "repair" if rep() <= 1 else "therapy"
		elif vendor != "":
			action = "trade"
	set_meta("user_action", action)
	set_meta("hold_use", int(get_meta("act_time", 0)) > 0)


## Npc.repair (the base autodoc).
func repair() -> void:
	var quest: Dictionary = data.get("quest", {})
	if not quest.is_empty() and Story.quest(str(quest.get("id", ""))) == null:
		Story.add_quest(str(quest.id))
		return
	var skill := str(data.get("needskill", ""))
	if skill == "":
		return
	var sk := Progression.skill_level_of(skill)
	var ok := false
	if sk < 2:
		ScriptsEngine.dialog("rblAutoDocR1")
	elif sk >= 5:
		ScriptsEngine.dialog("rblAutoDocR5")
		ok = true
	elif rep() == 1:
		ok = true
		for node_v in data.get("rep", []):
			var node: Dictionary = node_v
			var have := Inventory.count(str(node.id))
			if have < int(node.get("kol", 1)):
				Story.info("required", Inventory.name_of(str(node.id)), str(int(node.get("kol", 1)) - have))
				ok = false
		if ok:
			for node_v in data.get("rep", []):
				var node: Dictionary = node_v
				if Inventory.count(str(node.id)) > 0:
					Story.withdraw(str(node.id), int(node.get("kol", 1)))
			ScriptsEngine.dialog("rblAutoDocR4")
		else:
			ScriptsEngine.dialog("rblAutoDocR3")
	else:
		ScriptsEngine.dialog("rblAutoDocR2")
		set_rep(1)
	if ok:
		set_rep(2)
		set_meta("act_time", 0)
		set_status()
		if not quest.is_empty():
			Story.close_quest(str(quest.id), str(quest.get("cid", "")))


## Npc.patient.
func patient() -> void:
	var skill := str(data.get("needskill", ""))
	if skill == "":
		return
	var sk := Progression.skill_level_of(skill)
	if rep() == 2:
		if str(Travel.trigger("patient_tr2")) == "1":
			script_command("openEyes", "")
		else:
			ScriptsEngine.dialog("dialPatient7")
	elif rep() == 1:
		var item := str(data.get("needitem", ""))
		if Inventory.count(item) > 0:
			Inventory.spend(item, 1)
			set_rep(2)
			ScriptsEngine.dialog("dialPatient5")
			Travel.set_trigger("patient_tr2", "wait")
			Story.close_quest("patientHeal", "3")
			Story.show_quest("patientHeal", "4")
		else:
			ScriptsEngine.dialog("dialPatient8")
	elif sk < 4:
		ScriptsEngine.dialog("dialPatient2")
	else:
		ScriptsEngine.dialog("dialPatient3")
		set_rep(1)
		Travel.set_trigger("patient_tr1", 1)
		Story.close_quest("patientHeal", "1")
		Story.show_quest("patientHeal", "2")
		Story.show_quest("patientHeal", "3")
	refresh()


## UnitCaptive.free.
func _free() -> void:
	if status_capt > 0:
		return
	SfxBank.play("metal_door_open")
	_t_replic = 0
	if unit_id != "captive12":
		_replic("vse")
	status_capt = 1
	_set_flag("captive", 1)
	set_meta("usable", false)
	Progression.add_xp(500)
	_play("open")
	if _body != null:
		_body.color = Color(0.45, 0.45, 0.5, 0.5)
	_relabel()
	ScriptsEngine.quest_unit(qid)


# --- UnitNPC.command ---

func script_command(com: String, val: String) -> void:
	match com:
		"hide":
			_hide()
		"show":
			is_hidden = false
			visible = true
			modulate.a = 0.0
			_apply_hidden()
		"openEyes":
			_play("eyes")
			if _body != null:
				_body.color = Color(0.75, 0.7, 0.55, 0.9)
		"sign":
			_sign.visible = _ico == null and ai_tip != "fly" and bool(UiSettings.value("game", "help", true)) and get_meta("user_action", "") != ""
		"replicVse":
			_t_replic = 0
			_replic("vse")
		"rep":
			set_rep(int(val))
		"activate":
			is_hidden = false
			_apply_hidden()
		"unlock", "open":
			set_meta("lock", 0.0)
		_:
			_que.append({"com": com, "val": val})


## UnitNPC.control aiTip agro: shoot the first seen unit of another fraction in
## the room (findCel); with none left, sink and land (turnY UP), then talk.
func _agro_tick() -> void:
	if _gun_t > 0:
		_gun_t -= 1
	if _gun_reload > 0:
		_gun_reload -= 1
		if _gun_reload == 10:
			_gun_rounds = int(_gun().get("mag", 0))
	if not _alive_foe(_cel):
		_cel = _find_cel()
	busy = _cel != null
	if busy:
		facing = 1.0 if _cel.global_position.x > global_position.x else -1.0
		_face()
		_gun_shoot()
		return
	if not _airborne or _fly_to is Vector2:
		return
	_fall_v = minf(_fall_v + 1.0, 5.0)
	var space := get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0.0, _fall_v + 1.0), 1)
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		position.y += _fall_v
		return
	global_position.y = float(hit.position.y)
	_airborne = false
	_fall_v = 0.0
	ai_tip = ""
	script_command("sign", "")


func _alive_foe(node: Variant) -> bool:
	if not (node is Node2D) or not is_instance_valid(node):
		return false
	return not (node as Node).get("_dead") == true and not (node as Node).get("_friendly") == true and (node as Node2D).visible


func _find_cel() -> Node2D:
	var room := Rect2(_room_origin, Vector2(1920.0, 1000.0))
	var space := get_world_2d().direct_space_state
	var eye := global_position + Vector2(0.0, -50.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not _alive_foe(e) or not room.has_point((e as Node2D).global_position):
			continue
		var ray := PhysicsRayQueryParameters2D.create(eye, _foe_center(e), 1)
		if space.intersect_ray(ray).is_empty():
			return e
	return null


func _foe_center(e: Node2D) -> Vector2:
	var size: Variant = e.get("body_size")
	return e.global_position - Vector2(0.0, (size as Vector2).y * 0.5 if size is Vector2 else 30.0)


func _gun() -> Dictionary:
	if _gun_row.is_empty():
		var id := str(data.get("weap", ""))
		var f := FileAccess.open("res://assets/data/weapons.json", FileAccess.READ)
		var doc: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		if doc is Dictionary:
			for w in doc.get("weapons", []):
				if w is Dictionary and str(w.get("id", "")) == id:
					_gun_row = w
		if _gun_rounds < 0:
			_gun_rounds = int(_gun_row.get("mag", 0))
	return _gun_row


## Weapon.attack / shoot for the npc's currentWeapon: rapid ticks between shots,
## mag rounds, then reload + 10.
func _gun_shoot() -> void:
	var w := _gun()
	if w.is_empty() or _gun_t > 0 or _gun_reload > 0:
		return
	var cap := int(w.get("mag", 0))
	if cap > 0 and _gun_rounds <= 0:
		_gun_reload = int(w.get("reload", 0)) + 10
		return
	var host := get_tree().current_scene
	if host == null:
		return
	var eye := global_position + Vector2(0.0, -50.0)
	var dir := (_foe_center(_cel) - eye).normalized()
	var spread := float(w.get("spread", 0.0))
	if spread > 0.0:
		dir = dir.rotated(deg_to_rad((randf() - 0.5) * spread))
	var b := _Bullet.instantiate() as Area2D
	b.from_player = true
	b.fraction = 100
	b.weapon_id = str(w.get("id", ""))
	b.damage = int(w.get("damage", 1))
	b.damage_type = str(w.get("damage_type", "DAM_PIERCE"))
	b.speed = maxf(float(w.get("speed", 12.0)) * FPS, 40.0)
	b.direction = dir
	b.set_meta("owner_unit", self)
	host.add_child(b)
	b.global_position = eye + dir * minf(float(w.get("length", 0.0)), 40.0)
	_gun_t = maxi(1, int(w.get("rapid", 1)))
	if cap > 0:
		_gun_rounds -= 1


## UnitNPC.analiz: queued commands, one per frame.
func _analiz(q: Dictionary) -> void:
	var val := str(q.val)
	match str(q.com):
		"tell":
			_t_replic = 0
			_replic(val)
		"check":
			check()
		"ai":
			ai_tip = val
		"fly":
			var cel := val.split(":")
			if cel.size() >= 2:
				_fly_to = _room_origin + Vector2((int(cel[0]) + 1) * 40.0, int(cel[1]) * 40.0)
				_wait = 1000
		"rem":
			_hide()
		"turn":
			if val == "0":
				facing = -facing
			elif val == "-1":
				facing = -1.0
			else:
				facing = 1.0
			_face()
		"mater":
			pass


# --- frames ---

func _process(delta: float) -> void:
	if GameState.paused:
		return
	_tick_acc += delta * FPS
	var ticks := mini(int(_tick_acc), 5)
	_tick_acc -= float(ticks)
	for _i in ticks:
		_tick()


## UnitNPC.control / UnitCaptive.control.
func _tick() -> void:
	if trig != "" and _check_trig() == trig_off:
		_apply_hidden()
	if _t_ref > 0:
		_t_ref -= 1
	if _bark_left > 0:
		_bark_left -= 1
		if _bark_left == 0:
			_bark.visible = false
	if kind == "captive":
		if status_capt > 0 or unit_id == "captive12":
			return
		_t_replic -= 1
		if _t_replic <= 0:
			_replic("neutral")
			_t_replic = int(randf() * 500.0 + 1000.0)
		return
	if not ScriptsEngine.dial_script.running:
		_t_replic -= 1
		if _t_replic <= 0:
			if not silent:
				_replic("neutral")
			_t_replic = int(randf() * 500.0 + 200.0)
		if zzz_gen and _t_replic % 120 == 2:
			_say("z-z-z")
			_play("stay")
	_animate()
	if _wait > 0:
		_wait -= 1
	if _wait == 1:
		_fly_to = null
	if not _que.is_empty() and _wait <= 0:
		_analiz(_que.pop_front())
	if modulate.a < 1.0:
		modulate.a = minf(1.0, modulate.a + 0.05)
	if _fly_to is Vector2:
		var to: Vector2 = _fly_to
		var step := to - position
		if step.length() < 4.0:
			position = to
			_fly_to = null
			_wait = 0
		else:
			position += step.limit_length(6.0)
	if ai_tip == "agro" and not is_hidden:
		_agro_tick()
	if is_instance_valid(_props) and get_meta("usable", false):
		set_meta("feet", global_position)


## Unit.replic: a bark from the text pack's <replic> sets.
func _replic(act: String) -> void:
	if id_replic == "" or is_hidden or trig_off:
		return
	var s := StoryText.bark(id_replic, act)
	if s != "":
		_say(s)


func _say(s: String) -> void:
	_bark.text = s
	_bark.visible = true
	_bark.reset_size()
	_bark.position = Vector2(-_bark.size.x * 0.5, -120.0)
	_bark_left = 90 + s.length() * 2


func _hide() -> void:
	is_hidden = true
	_apply_hidden()


func _apply_hidden() -> void:
	trig_off = not _check_trig()
	visible = not is_hidden and not trig_off
	set_meta("usable", not is_hidden and not trig_off and status_capt == 0)


## Unit.checkTrig (Unit.as:899): trig 'eco' needs Pers.eco (perk econom, from
## the Barter skill: perks.xml:433), any other trig needs that trigger set to 1.
## Pers.as:1957 mirrors eco into triggers['eco'].
func _check_trig() -> bool:
	if trig == "":
		return true
	if trig == "eco":
		return Progression.perk_rank("econom") > 0
	return _num(Travel.trigger(trig)) == 1.0


func _face() -> void:
	_vis_root.scale.x = facing


## UnitNPC.animate: every 150-350 frames a random move1 / move2 clip; fly
## while flying.
func _animate() -> void:
	if _vis == null or kind != "npc":
		return
	var frames := _vis.sprite_frames
	if _fly_to is Vector2 or ai_tip == "fly" or _airborne:
		if frames.has_animation("fly") and _vis.animation != "fly":
			_vis.play("fly")
		return
	if _vis.animation == "fly":
		_vis.play("stay")
	if _t_anim > 0:
		_t_anim -= 1
		return
	_t_anim = int(randf() * 200.0 + 150.0)
	var clip := "move%d" % randi_range(1, 2)
	if frames.has_animation(clip) and _vis.animation != "eyes":
		_vis.play(clip)


func _play(clip: String) -> void:
	if _vis != null and _vis.sprite_frames.has_animation(clip):
		_vis.play(clip)


func _on_vis_finished() -> void:
	match str(_vis.animation):
		"move1", "move2":
			_vis.play("stay")
		"open":
			_vis.play("opened")
	_follow_pon()


## UnitCaptive: the pony (osn.pon) walks with the cage-open clip.
func _follow_pon() -> void:
	if _pon == null or kind != "captive" or _vis == null:
		return
	var path: Dictionary = NpcVis.entry("captive_ponpath")
	var offs: Array = (path.get("offsets", {}) as Dictionary).get(str(_vis.animation), [])
	var at := Vector2.ZERO
	if not offs.is_empty():
		var o: Array = offs[clampi(_vis.frame, 0, offs.size() - 1)]
		at = Vector2(float(o[0]), float(o[1]))
	_pon.position = at


func _set_ico(n: int) -> void:
	if _ico != null:
		_ico.frame = clampi(n, 0, _ico.sprite_frames.get_frame_count("ico") - 1)


func _vis_key() -> String:
	match kind:
		"captive":
			return "captive_s%d" % clampi(_sr, 0, 2)
		"train":
			return "trainarmor" if _tr == 1 else "train"
		"ponpon":
			return ""
	if data.has("vis"):
		return str(data.vis).to_lower()
	return "doctor" if unit_id == "doctor" else "vendor"


func _build() -> void:
	_vis_root = Node2D.new()
	_vis_root.name = "Vis"
	add_child(_vis_root)
	var key := _vis_key()
	if key != "":
		_vis = NpcVis.sprite(key)
	if _vis != null:
		_vis_root.add_child(_vis)
		_vis.animation_finished.connect(_on_vis_finished)
		_vis.frame_changed.connect(_follow_pon)
		if kind == "captive":
			_vis.play("opened" if status_capt > 0 else "closed")
		else:
			_vis.play("stay")
	if kind == "captive" or kind == "ponpon":
		_pon = NpcVis.still("captive_pon" if kind == "captive" else "ponpon", "pon", _tr - 1)
		if _pon != null:
			_vis_root.add_child(_pon)
			if kind == "captive" and _vis != null:
				_vis_root.move_child(_pon, 0)
			_follow_pon()
	if kind == "npc":
		_ico_frame = int(data.get("ico", 3 if unit_id == "doctor" else 2)) if data.has("ico") or data.is_empty() else 1
		_ico = NpcVis.still("npcico", "ico", _ico_frame - 1)
		if _ico != null:
			_ico.position = Vector2(0, -140)
			# The use icon draws over props and foreground, not under them.
			_ico.z_as_relative = false
			_ico.z_index = 60
			_vis_root.add_child(_ico)
	if _vis == null and _pon == null:
		_body = Polygon2D.new()
		var w := 36.0
		var h := 70.0 if kind != "captive" else 80.0
		_body.polygon = PackedVector2Array([Vector2(-w * 0.5, -h), Vector2(w * 0.5, -h), Vector2(w * 0.5, 0), Vector2(-w * 0.5, 0)])
		_body.color = Color(0.75, 0.7, 0.55, 0.9) if kind != "captive" else Color(0.55, 0.55, 0.6, 0.8)
		_vis_root.add_child(_body)
		_name_label = _label(14, Color("8affd0"))
		add_child(_name_label)
	_relabel()
	_sign = _label(22, Color("ffff33"))
	_sign.visible = false
	_sign.position = Vector2(-6, -140.0)
	_sign.z_as_relative = false
	_sign.z_index = 61
	add_child(_sign)
	_bark = _label(14, Color.WHITE)
	_bark.visible = false
	_bark.z_as_relative = false
	_bark.z_index = 61
	add_child(_bark)
	# Unit.boundingBox (units.xml phis sX x sY, npc 60 x 79, others 60 x 75): the
	# whole body is the use area, as the cursor test in GUI.as uses it.
	var area := CollisionShape2D.new()
	area.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	box.size = Vector2(60.0, 79.0 if unit_id == "npc" else 75.0)
	area.shape = box
	area.position = Vector2(0.0, -box.size.y * 0.5)
	area.disabled = true
	add_child(area)
	Locale.language_changed.connect(func(_l: String) -> void: _relabel())


func _relabel() -> void:
	if _name_label == null:
		return
	_name_label.text = nazv()
	_name_label.reset_size()
	_name_label.position = Vector2(-_name_label.size.x * 0.5, -96.0)


## UnitNPC.nazv (UnitNPC.as:98): unit text of the npc id, or of its name
## attribute. The original has no text for the random traveling vendor and
## prints its id, so the port gives it a name; an npc without unit text falls
## back to its unit class (merchant, doctor).
func nazv() -> String:
	if data.has("name"):
		return OriginalLines.unit(str(data.name))
	if kind != "npc":
		return OriginalLines.unit("cage" if status_capt > 0 else kind)
	if vendor == "random":
		return Locale.t("npc_traveling_merchant")
	if OriginalLines.has("unit", npc_id):
		return OriginalLines.unit(npc_id)
	return OriginalLines.unit(unit_id)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l


func _flag(key: String, fallback: Variant) -> Variant:
	if _props != null and _props.has_method("flag"):
		return _props.flag("%s_%s" % [key, _spot()], fallback)
	return fallback


func _set_flag(key: String, value: Variant) -> void:
	if _props != null and _props.has_method("set_flag"):
		_props.set_flag("%s_%s" % [key, _spot()], value)


func _spot() -> String:
	return uid if uid != "" else "%d_%d" % [int(position.x), int(position.y)]


static func _num(v: Variant) -> float:
	if v == null:
		return 0.0
	if v is int or v is float:
		return float(v)
	var s := str(v)
	return float(s) if s.is_valid_float() else 0.0


## AS3 loose ==: numbers compare as numbers, else as strings.
static func _eq(a: Variant, b: Variant) -> bool:
	if a == null:
		return b == null
	var sa := str(a)
	var sb := str(b)
	if sa.is_valid_float() and sb.is_valid_float():
		return float(sa) == float(sb)
	return sa == sb


static func _truthy(v: Variant) -> bool:
	if v == null:
		return false
	if v is int or v is float:
		return float(v) != 0.0
	return str(v) != ""
