extends Node

const _IntroScreen := preload("res://scripts/intro_screen.gd")
const _WarmUp := preload("res://scripts/warm_up.gd")

## Game.as land list and travel rules (gotoLand, beginMission, gotoNextLevel,
## upLandLevel, checkTravel, enterToCurLand, Encounter), Land.enterLand /
## gotoCheckPoint, and the World.as exitStep and ggDieStep sequences with
## UnitPlayer.die / resurect. Counters are original frames at 30 a second.
## The script engine calls open_land, goto_land and pass_land.

signal lands_changed
signal land_entered(id: String)

const Registry := preload("res://scripts/map/land_registry.gd")
const HARDDIE := "res://assets/music/harddie.mp3"
const FPS := 30.0
const EXIT_FADE_OUT := 79
const EXIT_FADE_IN := 15
const DEATH_FADE_OUT := 50
const DEATH_RESPAWN := 50
const DEATH_RESURRECT := 99
const DYING_FRAMES := 100
## UnitPlayer t_work for work "die" and "res".
const DIE_WORK := 205
const RES_WORK := 100
const WorkAnim := preload("res://scripts/player_work_anim.gd")

enum Exit { NONE, LEAVING, FADE_OUT, LOAD_SCREEN, ENTER_LAND, PROMPT, WAIT, FADE_IN, SHOW_GUI }
enum Death { NONE, DYING, FADE_OUT, RESPAWN, RESURRECT, CONTROL }

var base_id := "rbl"
var mission_id := ""
var cur_land_id := "begin"
var triggers: Dictionary = {}
## LandAct save fields per land: access, visited, passed, st (landStage), cp (lastCpCode).
var lands: Dictionary = {}
## Game.crea: rebuild the next land entered.
var crea := false
## PipBuck.travel set by the map table or a travel NPC.
var travel_mode := false
## UnitPlayer.sost: 1 alive, 2 dying, 3 dying from a destroyed organ.
var sost := 1
var exit_state := Exit.NONE
var death_state := Death.NONE

var _cur_coord := ""
var _t_exit := 0
var _t_die := 0
var _tick_acc := 0.0
var _dblack := 0.0
var _layer: CanvasLayer
var _black: ColorRect
var _hard_screen: Control
var _hard_text := ""
var _hard_dead := false
var _harddie: AudioStreamPlayer
var _current_cp: Node
var _land_cp: Dictionary = {}
var _cp_code := ""
var _prev_cp_code := ""
var _up_stage: Dictionary = {}
var _loading := false
## GUIManager.vwait (visualWait): a random skill picture over "Загрузка…".
var _wait_layer: CanvasLayer
var _wait_box: Control
var _wait_pic: TextureRect
var _wait_text: Label
var _wait_pics: Array[Texture2D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.visible = false
	_layer.add_child(_black)
	_fresh_lands()
	call_deferred("_register_world_state")


func _register_world_state() -> void:
	var ws := get_node_or_null("/root/WorldState")
	if ws != null and ws.has_method("register"):
		ws.call("register", "travel", get_state, set_state)


## World.setLoadScreen(-1): visualWait centred, skill on a random frame,
## progres "loading". Drawn 1:1 on a 1080-high screen like the Flash stage.
func show_load_screen() -> void:
	if _wait_layer == null:
		_build_load_screen()
	if not _wait_pics.is_empty():
		_wait_pic.texture = _wait_pics[randi() % _wait_pics.size()]
	_wait_text.text = OriginalLines.gui("loading")
	var view := get_viewport().get_visible_rect().size
	_wait_box.scale = Vector2.ONE * (view.y / 1080.0)
	_wait_box.position = view * 0.5
	_wait_layer.visible = true


## World.offLoadScreen.
func hide_load_screen() -> void:
	if _wait_layer != null:
		_wait_layer.visible = false
	_IntroScreen.loaded(get_tree())


## Main menu / PipBuck load into game.tscn with the load screen up first;
## a new game with training shows the story screen in its place.
func enter_game() -> void:
	if _IntroScreen.pending and not SaveSlots.has_pending():
		_IntroScreen.show_now(get_tree())
	else:
		show_load_screen()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	# The menu opens only after the session warm-up; this covers any other entry.
	if not _WarmUp.done():
		_WarmUp.start(self)
	while not _WarmUp.done():
		await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _build_load_screen() -> void:
	_wait_layer = CanvasLayer.new()
	_wait_layer.layer = 100
	_wait_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_wait_layer)
	var fon := ColorRect.new()
	fon.color = Color.BLACK
	fon.set_anchors_preset(Control.PRESET_FULL_RECT)
	fon.mouse_filter = Control.MOUSE_FILTER_STOP
	_wait_layer.add_child(fon)
	_wait_box = Control.new()
	_wait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wait_layer.add_child(_wait_box)
	var i := 1
	while ResourceLoader.exists("res://assets/ui/loading/%d.png" % i):
		_wait_pics.append(load("res://assets/ui/loading/%d.png" % i))
		i += 1
	_wait_pic = TextureRect.new()
	_wait_pic.position = Vector2(-99.7, -109.7)
	_wait_pic.size = Vector2(200, 200)
	_wait_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wait_box.add_child(_wait_pic)
	var font: Font = load("res://theme/fonts/LiberationMono-Regular.ttf")
	_wait_text = Label.new()
	_wait_text.position = Vector2(-109.5, 96.6)
	_wait_text.size = Vector2(224, 36)
	_wait_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wait_text.add_theme_font_override("font", font)
	_wait_text.add_theme_font_size_override("font_size", 28)
	_wait_text.add_theme_color_override("font_color", Color("00ff99"))
	_wait_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wait_box.add_child(_wait_text)


# --- Script-engine API ---

## Script black: the screen cover at alpha, any fade stopped.
func set_black(alpha: float) -> void:
	_dblack = 0.0
	_set_black(clampf(alpha, 0.0, 1.0))


## Script dblack: the cover moves d / 100 a frame (Camera.dblack).
func set_dblack(d: float) -> void:
	_dblack = d
	if d > 0.0:
		_black.visible = true


## Script control off / on.
func set_control(on: bool) -> void:
	_control(on, true)


## Script openland: the land shows on the world map and can be travelled to.
func open_land(id: String) -> void:
	if not lands.has(id):
		return
	(lands[id] as Dictionary)["access"] = true
	lands_changed.emit()


## Script passed (current land when id is empty).
func pass_land(id: String = "") -> void:
	var key := id if id != "" else cur_land_id
	if not lands.has(key):
		return
	(lands[key] as Dictionary)["passed"] = true
	lands_changed.emit()


## Game.gotoLand. spawn is "x:y", the land room whose spawn point you arrive
## at (script gotoland n=1). fast skips the fade-out (n=2).
func goto_land(id: String, spawn: String = "", fast: bool = false) -> bool:
	if id == "":
		return false
	if _loading:
		# WorldState resuming a save asks for the saved land; set_state chose it.
		if exit_state == Exit.NONE and cur_land_id != _shown_id():
			exit_land(true)
		return true
	if id != base_id and not GameState.dopusk():
		_mess(_txt("nocont"))
		return false
	cur_land_id = id
	_cur_coord = spawn
	exit_land(fast)
	return true


## Game.beginMission: map travel.
func begin_mission(id: String) -> void:
	if id == cur_land_id:
		return
	if lands.has(id) and _tip(id) != "base":
		mission_id = id
		crea = true
	goto_land(id)


## Game.gotoNextLevel: the exit of a generated land rebuilds the mission land.
func goto_next_level() -> void:
	_cp_code = ""
	_prev_cp_code = ""
	_land_cp.erase(cur_land_id)
	if lands.has(cur_land_id):
		(lands[cur_land_id] as Dictionary).erase("cp_name")
		(lands[cur_land_id] as Dictionary).erase("cp_pos")
	crea = true
	refill()
	goto_land(mission_id if mission_id != "" else cur_land_id)


## Game.upLandLevel (script upland): once per visit.
func up_land_level() -> void:
	if not lands.has(cur_land_id):
		return
	if not bool(_up_stage.get(cur_land_id, false)):
		var act: Dictionary = lands[cur_land_id]
		act["st"] = int(act.get("st", 0)) + 1
	_up_stage[cur_land_id] = true


## Land.refill (script refill): Game.refillVendors once a land.
func refill() -> void:
	Vendors.land_refill(_active_land())


## Game.checkTravel.
func check_travel(id: String) -> bool:
	if cur_land_id == "grave":
		return false
	var fin := int(triggers.get("fin", 0))
	var land_fin := _fin(id)
	match fin:
		0:
			return true
		1:
			return land_fin == 0 or land_fin == 1
		2:
			return land_fin == 0 or land_fin == 2
		3:
			return land_fin == 2
	return true


## PipBuck.travel without the map table: a room with options base, or the
## home stable (Location.homeStable sets base).
func can_travel_here() -> bool:
	if cur_land_id == "stable_pi":
		return true
	var player := _player()
	var land := _active_land()
	if player == null or land == null:
		return false
	var props := land.get_node_or_null("Actors")
	if props == null or not props.has_method("room_options_at"):
		return false
	var options: Dictionary = props.call("room_options_at", player.global_position)
	return options.has("base")


func map_travel() -> bool:
	return travel_mode or can_travel_here()


## allact map: the world map in travel mode.
func open_travel_map() -> void:
	travel_mode = true
	var scene := get_tree().current_scene
	var pause := scene.find_child("PauseMenu", true, false) if scene != null else null
	if pause != null and pause.has_method("open_pipbuck"):
		pause.call("open_pipbuck", "pip_world")


## Item retr (rune of return).
func return_to_base() -> bool:
	if int(triggers.get("noreturn", 0)) == 1:
		return false
	return goto_land(base_id)


func trigger(key: String) -> Variant:
	return triggers.get(key)


func set_trigger(key: String, value: Variant = 1) -> void:
	triggers[key] = value


## Game.mReturn.
func m_return() -> bool:
	return not (int(triggers.get("noreturn", 0)) > 0)


func land_stage(id: String) -> int:
	return int((lands.get(id, {}) as Dictionary).get("st", 0))


func land_act(id: String) -> Dictionary:
	return lands.get(id, {})


## PipBuck.noAct: no PipBuck actions while leaving or dying.
func no_act() -> bool:
	return exit_state != Exit.NONE or sost > 1 or _hard_dead


func blocks_control() -> bool:
	return exit_state != Exit.NONE or death_state != Death.NONE or sost > 1 or _hard_dead


func hardcore() -> bool:
	return bool(UiSettings.value("game", "hardcore", false))


func set_hardcore(on: bool) -> void:
	UiSettings.set_value("game", "hardcore", on)


func current_cp() -> Node:
	return _current_cp if _current_cp != null and is_instance_valid(_current_cp) else null


func land_cp(id: String) -> Node:
	var cp: Variant = _land_cp.get(id)
	if is_instance_valid(cp) and cp is Node:
		return cp
	return null


## Location.createObj for a saved land: the checkpoint whose code was the
## last one used becomes the land's (Land.currentCP).
func checkpoint_built(cp: Node, land_id: String, code: String, rnd: bool) -> void:
	if bool(cp.get("main")):
		_land_cp[land_id] = cp
		return
	# A generated land is rebuilt from its seed when the player comes back, so
	# its checkpoints have no code; the one used last is found by name.
	if rnd:
		var named := str((lands.get(land_id, {}) as Dictionary).get("cp_name", ""))
		# Location.createCheck(true) opened the start checkpoint when the Land
		# was made; the same Land built again keeps the current one instead.
		if named != "" and "_start_active" in cp:
			cp.set("_start_active", false)
		if named != "" and str(cp.name) == named:
			_land_cp[land_id] = cp
			if land_id == cur_land_id and (_current_cp == null or not is_instance_valid(_current_cp)):
				_current_cp = cp
				cp.call_deferred("activate", true, true)
		return
	if code == "":
		return
	var last := str((lands.get(land_id, {}) as Dictionary).get("cp", ""))
	if (_cp_code != "" and code == _cp_code) or (_prev_cp_code != "" and code == _prev_cp_code) or code == last:
		_land_cp[land_id] = cp


## CheckPoint.activate after it has opened.
func checkpoint_activated(cp: Node, land_id: String, code: String) -> void:
	_current_cp = cp
	_cp_code = code
	if code != "":
		_prev_cp_code = code
		if lands.has(land_id):
			(lands[land_id] as Dictionary)["cp"] = code
	if lands.has(land_id) and _is_rnd(land_id) and cp is Node2D:
		var at := (cp as Node2D).global_position
		(lands[land_id] as Dictionary)["cp_name"] = str(cp.name)
		(lands[land_id] as Dictionary)["cp_pos"] = [at.x, at.y]
	_land_cp[land_id] = cp
	_notice(OriginalLines.info("checkPoint"))
	SaveSlots.save(0)


# --- Run state ---

func reset_run() -> void:
	_fresh_lands()
	triggers = {"noreturn": 1, "nomed": 1}
	base_id = "rbl"
	mission_id = ""
	cur_land_id = "begin"
	crea = false
	travel_mode = false
	sost = 1
	exit_state = Exit.NONE
	death_state = Death.NONE
	_cur_coord = ""
	_dblack = 0.0
	_current_cp = null
	_land_cp.clear()
	_cp_code = ""
	_prev_cp_code = ""
	_up_stage.clear()
	_hard_dead = false
	_close_hard_screen()
	_loading = false
	if _black != null:
		_black.visible = false
		_black.color.a = 0.0


## game.tscn start: begin is already on screen. A new game with the propusk
## option skips training (Game.init): it starts in the camp with the
## giveQuickstartItems kit (World.newGame2).
func begin_run() -> void:
	if bool(UiSettings.value("game", "propusk", false)) and not SaveSlots.has_pending():
		triggers["dial_dialCalam2"] = 1
		_give_quickstart()
		cur_land_id = base_id
		_set_black(1.0)
		exit_land(true)
		return
	if not SaveSlots.has_pending():
		preload("res://scripts/intro_screen.gd").show_if_pending(get_tree())
	_entered(cur_land_id, false)


func _give_quickstart() -> void:
	for step_v in Registry.script("giveQuickstartItems").get("acts", []):
		var step: Dictionary = step_v
		var val := str(step.get("val", ""))
		match str(step.get("act", "")):
			"take":
				Inventory.add(val, int(step.get("n", "1")))
			"weapch":
				Inventory.equip(val)
			"takeArmor":
				if Inventory.count(val) <= 0:
					Inventory.add(val, 1)
			"armor":
				if Inventory.worn != val:
					Inventory.wear(val)
			"fav":
				Favorites.fav_item(val, int(step.get("n", "0")))


func get_state() -> Dictionary:
	return {
		"lands": lands.duplicate(true),
		"triggers": triggers.duplicate(true),
		"base": base_id,
		"mission": mission_id,
		"land": cur_land_id,
		"cp": _cp_code,
		"prevcp": _prev_cp_code,
		"dead": _hard_dead,
		"dead_text": _hard_text,
	}


func set_state(data: Dictionary) -> void:
	_fresh_lands()
	var saved: Dictionary = data.get("lands", {})
	for key in saved:
		if not lands.has(key):
			continue
		var act: Dictionary = lands[key]
		var row: Dictionary = saved[key]
		for field in ["access", "visited", "passed", "st", "cp", "cp_name", "cp_pos"]:
			if row.has(field):
				act[field] = row[field]
	triggers = (data.get("triggers", {}) as Dictionary).duplicate(true)
	base_id = str(data.get("base", "rbl"))
	mission_id = str(data.get("mission", ""))
	cur_land_id = str(data.get("land", "begin"))
	_cp_code = str(data.get("cp", ""))
	_prev_cp_code = str(data.get("prevcp", ""))
	_hard_dead = bool(data.get("dead", false))
	_hard_text = str(data.get("dead_text", ""))
	if not lands.has(cur_land_id) or _is_rnd(cur_land_id):
		cur_land_id = "rbl"
	_loading = true
	lands_changed.emit()
	# HUD hides the load screen after applying a save if no exit is running yet.
	# Deferring this left one presented frame of the empty sky (and the whole
	# land build sat on that frame). The game scene is up by the time a save
	# is applied; before that, wait a frame.
	if _host() != null:
		_resume_saved()
	else:
		call_deferred("_resume_saved")


## Game.init with a save: a hardcore death stays dead, and a generated land
## is not kept, so the run goes on in the camp.
func _resume_saved() -> void:
	if _hard_dead:
		GameState.mark_dead(true)
		_control(false)
		_show_hard_screen(_hard_text)
		return
	if _host() != null and cur_land_id != _shown_id():
		_cur_coord = ""
		exit_land(true)
	elif _host() != null:
		_rebind_cp()
		_loading = false


## The land on screen was built before the save was read: its checkpoints
## pick Land.currentCP again from the saved codes, and the current one is open.
func _rebind_cp() -> void:
	_land_cp.erase(cur_land_id)
	for cp in get_tree().get_nodes_in_group("checkpoints"):
		if str(cp.get("land_id")) == cur_land_id:
			checkpoint_built(cp, cur_land_id, str(cp.get("code")), bool(cp.get("rnd")))
	var cp := land_cp(cur_land_id)
	if cp != null and not bool(cp.get("main")) and _cp_code != "" and str(cp.get("code")) == _cp_code:
		_current_cp = cp
		cp.call("activate", true, true)


func _fresh_lands() -> void:
	lands.clear()
	for id_v in Registry.ids():
		var id := str(id_v)
		var info := Registry.land(id)
		if info.is_empty() or str(info.get("tip", "")) == "prob" or info.has("prob"):
			continue
		lands[id] = {"access": info.has("acc"), "visited": false, "passed": false, "st": 0, "cp": ""}


# --- World.exitLand / exitStep ---

func exit_land(fast: bool = false) -> void:
	if exit_state != Exit.NONE:
		return
	_control(false)
	exit_state = Exit.FADE_OUT if fast else Exit.LEAVING
	_t_exit = 1


func _process(delta: float) -> void:
	if _host() == null:
		_leave_game_scene()
		return
	if GameState.paused:
		return
	_tick_acc += delta * FPS
	var ticks := mini(int(_tick_acc), 5)
	_tick_acc -= float(ticks)
	for _i in ticks:
		if exit_state != Exit.NONE:
			_exit_step()
		if death_state != Death.NONE:
			_die_step()
		_black_step()


func _exit_step() -> void:
	_t_exit -= 1
	if _t_exit > 0:
		return
	match exit_state:
		Exit.LEAVING:
			exit_state = Exit.FADE_OUT
			_t_exit = EXIT_FADE_OUT
			_dblack = 1.5
		Exit.FADE_OUT:
			# The load screen: black until the land is in.
			exit_state = Exit.LOAD_SCREEN
			_t_exit = 1
			_dblack = 0.0
			_set_black(1.0)
			show_load_screen()
		Exit.LOAD_SCREEN:
			exit_state = Exit.ENTER_LAND
			_t_exit = 1
			_enter_cur_land()
		Exit.ENTER_LAND:
			exit_state = Exit.PROMPT
			_t_exit = 1
		Exit.PROMPT:
			exit_state = Exit.WAIT
			_t_exit = 1
		Exit.WAIT:
			exit_state = Exit.FADE_IN
			_t_exit = EXIT_FADE_IN
			hide_load_screen()
			_set_black(1.0)
			_dblack = -10.0
			_control(true)
		Exit.FADE_IN:
			exit_state = Exit.SHOW_GUI
			_t_exit = 1
		Exit.SHOW_GUI:
			exit_state = Exit.NONE


## Camera.dblack: vblack alpha moves dblack / 100 a frame.
func _black_step() -> void:
	if _dblack > 0.0:
		_black.visible = true
		_black.color.a = minf(1.0, _black.color.a + _dblack / 100.0)
		if _black.color.a >= 1.0:
			_dblack = 0.0
	elif _dblack < 0.0:
		_black.color.a = maxf(0.0, _black.color.a + _dblack / 100.0)
		if _black.color.a <= 0.0:
			_dblack = 0.0
			_black.visible = false


func _leave_game_scene() -> void:
	if exit_state != Exit.NONE:
		hide_load_screen()
	if _hard_screen != null:
		_close_hard_screen()
	if _black.visible:
		_set_black(0.0)
	_dblack = 0.0
	exit_state = Exit.NONE
	death_state = Death.NONE


func _set_black(alpha: float) -> void:
	_black.color.a = alpha
	_black.visible = alpha > 0.0


## game.tscn opening on a land that is not built yet: black until it fades in.
func cover() -> void:
	_set_black(1.0)


func fade_alpha() -> float:
	return _black.color.a if _black.visible else 0.0


## Game.enterToCurLand with Land.enterLand.
func _enter_cur_land() -> void:
	_encounter()
	if not lands.has(cur_land_id):
		cur_land_id = "rbl"
	var host := _host()
	if host == null:
		return
	var act: Dictionary = lands[cur_land_id]
	var first := not _is_rnd(cur_land_id) and not bool(act.get("visited", false))
	var rebuild := crea
	crea = false
	if rebuild:
		_land_cp.erase(cur_land_id)
		act.erase("cp_name")
		act.erase("cp_pos")
	var land: Node = host.call("enter_land", cur_land_id, rebuild)
	if land == null:
		return
	act["visited"] = true
	var cp_pos: Array = act.get("cp_pos", [])
	if _cur_coord != "":
		var parts := _cur_coord.split(":")
		var lx := int(parts[0]) if parts.size() >= 1 else 0
		var ly := int(parts[1]) if parts.size() >= 2 else 0
		host.call("place_player", _room_spawn(land, lx, ly, host))
	elif _is_rnd(cur_land_id) and cp_pos.size() == 2 and land_cp(cur_land_id) == null:
		# Land.gotoCheckPoint: the checkpoint itself spawns with its room.
		_current_cp = null
		host.call("place_player", Vector2(float(cp_pos[0]), float(cp_pos[1])))
	elif land_cp(cur_land_id) != null and not first and cur_land_id != "begin":
		_current_cp = land_cp(cur_land_id)
		_goto_check_point()
		_current_cp.call("activate")
	else:
		host.call("place_player", host.call("entrance", cur_land_id))
	_cur_coord = ""
	_entered(cur_land_id, true)


func _entered(id: String, show_name: bool) -> void:
	_loading = false
	GameState.clear_battle()
	if id == "rbl":
		triggers["noreturn"] = 0
		triggers["nomed"] = 0
		triggers["rbl_visited"] = 1
	elif lands.has(id) and _tip(id) != "base":
		mission_id = id
	if lands.has(id):
		(lands[id] as Dictionary)["visited"] = true
	GameState.end_effect("potion_fly")
	if show_name:
		var title := OriginalLines.text("map", id)
		if _is_rnd(id):
			title += " - %d" % (land_stage(id) + 1)
		var player := _player()
		var down := player != null and player.get_global_transform_with_canvas().origin.y < 300.0
		_mess(title, down)
	_up_stage.erase(id)
	land_entered.emit(id)
	lands_changed.emit()


func _encounter() -> void:
	if cur_land_id == "random_canter" and not (int(triggers.get("encounter_way", 0)) > 0):
		cur_land_id = "way"
	if cur_land_id == "random_encl" and not (int(triggers.get("encounter_post", 0)) > 0):
		cur_land_id = "post"
	if cur_land_id == "stable_pi" and int(triggers.get("storm", 0)) == 4:
		cur_land_id = "stable_pi_atk"
	if cur_land_id == "stable_pi" and int(triggers.get("storm", 0)) == 5:
		cur_land_id = "stable_pi_surf"


## Land.gotoCheckPoint in the land on screen.
func _goto_check_point() -> void:
	var host := _host()
	var player := _player()
	if host == null or player == null:
		return
	var cp := current_cp()
	if cp == null:
		host.call("place_player", player.global_position)
		return
	var here := land_cp(cur_land_id)
	if str(cp.get("land_id")) != cur_land_id and here != null:
		cp = here
		_current_cp = here
		here.call("activate")
	if str(cp.get("land_id")) == cur_land_id:
		host.call("place_player", (cp as Node2D).global_position)
	else:
		host.call("place_player", host.call("entrance", cur_land_id))


## Land.setGGToSpawnPoint for room lx:ly of the land.
func _room_spawn(land: Node, lx: int, ly: int, host: Node) -> Vector2:
	var props := land.get_node_or_null("Actors")
	if props != null and props.has_method("room_spawn"):
		var at: Variant = props.call("room_spawn", lx, ly)
		if at is Vector2:
			return at
	return host.call("entrance", cur_land_id)


# --- UnitPlayer.die / World.ggDieStep ---

## UnitPlayer.die. sposob 10 is a destroyed organ (Pers.die).
func player_died(sposob: int = 0) -> void:
	if sost > 1:
		return
	if sposob >= 0 and sposob < 10 and sost == 1:
		GameState.die_damage()
	_control(false)
	if sost < 3:
		sost = 2
	if sposob >= 10:
		sost = 3
	WorkAnim.play(_player(), "die", DIE_WORK)
	GameState.mark_dead(true)
	if hardcore() and sposob >= 0:
		_hard_die(sposob == 10)
	else:
		_start_death(DYING_FRAMES)


## Pers.die: an organ at 0.
func organ_failed() -> void:
	_mess(_txt("gameover"))
	if sost == 1:
		player_died(10)
	else:
		sost = 3


func _start_death(frames: int) -> void:
	death_state = Death.DYING
	_t_die = frames


func _die_step() -> void:
	_t_die -= 1
	if _t_die > 0:
		return
	match death_state:
		Death.DYING:
			death_state = Death.FADE_OUT
			_t_die = DEATH_FADE_OUT
			_dblack = 2.2
		Death.FADE_OUT:
			if ScriptsEngine.alicorn:
				death_state = Death.NONE
				ScriptsEngine.run_script("gameover")
				return
			death_state = Death.RESPAWN
			_t_die = DEATH_RESPAWN
			if sost == 3:
				cur_land_id = base_id
				_enter_cur_land()
			else:
				_goto_check_point()
			_dblack = -4.0
		Death.RESPAWN:
			death_state = Death.RESURRECT
			_t_die = DEATH_RESURRECT
			_resurect()
		Death.RESURRECT:
			death_state = Death.CONTROL
			_t_die = 1
			_control(true)
		Death.CONTROL:
			death_state = Death.NONE


## UnitPlayer.resurect.
func _resurect() -> void:
	sost = 1
	GameState.revive()
	WorkAnim.play(_player(), "res", RES_WORK)


func _hard_die(organ: bool) -> void:
	_hard_dead = true
	_hard_text = "%s %s" % [_txt("hardDie2" if organ else "hardDie"), _player_name()]
	SaveSlots.save(0)
	_show_hard_screen(_hard_text)
	AudioManager.stop_music()
	if _harddie == null:
		_harddie = AudioStreamPlayer.new()
		_harddie.bus = UiSettings.MUSIC_BUS
		add_child(_harddie)
	var stream := load(HARDDIE) as AudioStream
	if stream != null:
		_harddie.stream = stream
		_harddie.play()


func is_hard_dead() -> bool:
	return _hard_dead


## Hardcore death: GUI.messText for 10000 frames and no respawn. The button
## is the port's way back to the main menu (the original leaves the PipBuck).
func _show_hard_screen(text: String) -> void:
	_close_hard_screen()
	var root := Control.new()
	root.name = "HardDeath"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = Vector2(900, 120)
	label.position = Vector2(-450, -140)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	if ResourceLoader.exists("res://theme/hud_sans.tres"):
		label.add_theme_font_override("font", load("res://theme/hud_sans.tres"))
	root.add_child(label)
	var button := Button.new()
	button.name = "ToMenu"
	button.text = Locale.t("pause_main_menu")
	button.set_anchors_preset(Control.PRESET_CENTER)
	button.size = Vector2(240, 36)
	button.position = Vector2(-120, 20)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_hard_to_menu)
	root.add_child(button)
	_hard_screen = root
	UiNav.add_screen(root, {"default": button})
	button.call_deferred("grab_focus")


func _close_hard_screen() -> void:
	if _hard_screen != null and is_instance_valid(_hard_screen):
		_hard_screen.queue_free()
	_hard_screen = null
	if _harddie != null:
		_harddie.stop()


func _hard_to_menu() -> void:
	preload("res://scripts/exit_trace.gd").arm(get_tree(), "hardcore death")
	_close_hard_screen()
	_set_black(0.0)
	GameState.set_paused(false)
	AudioManager.play_menu()
	get_tree().change_scene_to_file(load("res://scripts/editor/editor_play.gd").menu_dest())


# --- Helpers ---

## UnitPlayer.controlOff / controlOn. soft (scripts): keys and the weapon go,
## physics and the world keep running. Exits and death also stop the body.
func _control(on: bool, soft := false) -> void:
	var player := _player()
	if player == null:
		return
	if on and (_hard_dead or sost > 1):
		return
	if player.has_method("set_control_off"):
		player.set_control_off(not on)
	var frozen := not on and not soft
	player.set_physics_process(not frozen)
	player.set_process(not frozen)
	player.set_process_unhandled_input(not frozen)
	if frozen and player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	var puppet := player.get_node_or_null("Puppet")
	if puppet != null and puppet.has_method("set_weapon_shown"):
		puppet.set_weapon_shown(on)


## gg.ggControl is false (dialogue, inform, script control off).
func control_off() -> bool:
	var player := _player()
	return player != null and bool(player.get("control_off"))


func _host() -> Node:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene != null and scene.has_method("enter_land"):
		return scene
	return null


func has_host() -> bool:
	return _host() != null


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null


func _active_land() -> Node:
	return get_tree().get_first_node_in_group("active_land") if is_inside_tree() else null


func _shown_id() -> String:
	var land := _active_land()
	if land == null:
		return ""
	var value = land.get("land_id")
	return str(value) if value != null and str(value) != "" else "begin"


func _tip(id: String) -> String:
	return str(Registry.land(id).get("tip", ""))


func _is_rnd(id: String) -> bool:
	return Registry.land(id).has("rnd")


func _fin(id: String) -> int:
	return Registry.int_of(Registry.land(id).get("fin"), -1)


func _txt(id: String) -> String:
	return OriginalLines.text("txt", id).replace("[br]", "\n")


func _player_name() -> String:
	var saved := str(UiSettings.value("game", "name", ""))
	return saved if saved != "" else OriginalLines.unit("littlepip")


func _notice(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	if hud != null and hud.has_method("show_notice"):
		hud.show_notice(text)


func _mess(text: String, down: bool = false) -> void:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	if hud != null and hud.has_method("show_message"):
		hud.show_message(text, down)
