extends Node

## Probation.as: one trial room of a land (a "prob" row from LandSpawn.plan_prob).
## Location.out / over run when the player leaves or enters the room. A box
## opened or a unit killed in the room is the check() event; the wave
## countdown steps only while the player is inside (Location.step).
##
## Doors are the room's doorout passages: -1 all off, 0 all but uid "begin",
## 1 all on. Prize boxes (@prize) stay shut until the trial closes, unless the
## trial has @prize itself (prizeActive). Closing counts triggers prob_<id>
## (the world map's kolProb), says closeProb, plays quest_ok and runs the
## close script. Scripts in/out/alarm/close run through land_props.

const TPS := 30.0
const BEG_T := 90
const NEXT_T := 300
const ROOM := Vector2(48 * 40, 25 * 40)

var id := ""
var info: Dictionary = {}
var room := Vector2i.ZERO
var closed := false
var active := false
var is_close := false
var prize_active := false
var on_wave := false
var nwave := 0
var maxwave := 0
var t_wave := 0
var kol_en := 0
var kill_en := 0

var _props: Node
var _room_cache: Array = []
var _room_count := -1
var _inside := false
var _acc := 0.0
var _wave_units: Array = []
var _seen := ""
var _help_shown := false


func setup(row: Dictionary, props: Node) -> void:
	_props = props
	info = (row.get("attrs", {}) as Dictionary).get("prob", {})
	id = str(info.get("id", row.get("id", "")))
	var r: Array = row.get("room", [0, 0])
	room = Vector2i(int(r[0]), int(r[1]))
	name = "Trial_" + id
	is_close = str(info.get("close", "")) != ""
	prize_active = str(info.get("prize", "")) != ""
	maxwave = (info.get("waves", []) as Array).size()
	closed = bool(props.flag("prob|" + id, false))
	add_to_group("trial")
	# Probation: a trial that is not tip 2 bans the pet (loc.petOn).
	if str(info.get("tip", "")) != "2":
		var land := props.get_parent()
		var envs: Dictionary = land.get_meta("room_env") if land != null and land.has_meta("room_env") else {}
		if envs.has(room):
			(envs[room] as Dictionary)["pet"] = false


func nazv() -> String:
	return OriginalLines.text("map", id)


## Location.prob for the room at a world point.
func holds(at: Vector2) -> bool:
	return Vector2i(floori(at.x / ROOM.x), floori(at.y / ROOM.y)) == room


func _process(delta: float) -> void:
	if GameState.paused:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var inside := holds(player.global_position)
	if inside != _inside:
		_inside = inside
		if inside:
			_over(player)
		else:
			_out()
	_prepare_prizes()
	if not inside:
		return
	_acc += delta * TPS
	var steps := 0
	while _acc >= 1.0 and steps < 4:
		_acc -= 1.0
		steps += 1
		_step()
	_watch_events()


func _step() -> void:
	if not on_wave:
		return
	if t_wave > 0:
		t_wave -= 1
	if t_wave == 1 and nwave < maxwave:
		_create_wave()
	if t_wave % 30 == 1:
		_mess(str(floori(t_wave / 30.0)))


## Location.over: the trial name, back to its default doors, the in script,
## and a closing trial (@close) starts at once.
func _over(player: Node2D) -> void:
	_mess(nazv(), player)
	if not closed:
		default_prob()
	_run("in")
	if is_close:
		activate_prob()


## Location.out: a passed trial hands out its prizes; otherwise the out
## script runs and a running wave is called off.
func _out() -> void:
	if closed:
		for node in _room_nodes():
			if bool(node.get_meta("prize", false)) and not bool(node.get_meta("spent", false)):
				_props.call("_open_loot", node, true)
	else:
		_run("out")
		if on_wave:
			_reset_wave()


## Script actprob.
func activate_prob() -> void:
	if closed or active or not _inside:
		return
	active = true
	_doors(-1)


func default_prob() -> void:
	active = false
	_doors(0)


## Script wave.
func begin_wave() -> void:
	if on_wave:
		return
	_doors(-1)
	on_wave = true
	kol_en = 0
	kill_en = 0
	nwave = 0
	t_wave = BEG_T


## Location.signal in this room starts the alarm script.
func alarm() -> void:
	_run("alarm")


## Interact allact prob_help (termh): GUI.informText. The hint itself comes on
## the next read (the original's help button on that panel).
func show_help() -> void:
	var text := "[%s]\n\n%s" % [nazv(), OriginalLines.desc("map", id)]
	var env: Dictionary = {}
	var land := _props.get_parent()
	if land != null and land.has_meta("room_env"):
		env = (land.get_meta("room_env") as Dictionary).get(room, {})
	for pair in [["levit", "restr_levit"], ["port", "restr_port"], ["destroy", "restr_des"]]:
		if not bool(env.get(pair[0], true)):
			text += "\n" + OriginalLines.gui(pair[1])
	var help := OriginalLines.help("map", id)
	if help != "":
		text += "\n\n" + (help if _help_shown else OriginalLines.gui("need_help"))
		_help_shown = true
	ScriptsEngine.inform(text, 2)


func check() -> void:
	if closed:
		return
	if _all_con():
		_close_prob()


func _all_con() -> bool:
	for con_v in info.get("cons", []):
		var con: Dictionary = con_v
		var tip := str(con.get("tip", ""))
		if (tip == "box" or tip == "") and str(con.get("uid", "")) != "":
			var box: Node = _props.call("script_target", str(con.uid))
			if box != null and is_instance_valid(box) and not _box_open(box) and str(box.get_meta("cont", "")) != "empty":
				return false
		elif tip == "unit":
			for unit in _room_units():
				var hit := (str(con.get("uid", "")) != "" and str(unit.get_meta("uid", "")) == str(con.uid)) \
					or (str(con.get("qid", "")) != "" and str(unit.get_meta("qid", "")) == str(con.qid))
				if hit and not _dead(unit):
					return false
			if str(con.get("uid", "")) != "":
				var named: Node = _props.call("script_target", str(con.uid))
				if named != null and is_instance_valid(named) and not _dead(named):
					return false
		elif tip == "wave":
			if nwave < maxwave or kill_en < kol_en:
				return false
	return true


func _close_prob() -> void:
	closed = true
	active = false
	_props.set_flag("prob|" + id, true)
	var t: Variant = Travel.trigger("prob_" + id)
	Travel.set_trigger("prob_" + id, 1 if t == null else int(t) + 1)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_notice"):
		hud.show_notice(OriginalLines.info("closeProb", nazv()))
	SfxBank.play("quest_ok")
	_doors(1)
	if not prize_active:
		for node in _room_nodes():
			if bool(node.get_meta("prize", false)):
				node.set_meta("prize_locked", false)
	_run("close")


func _create_wave() -> void:
	var waves: Array = info.get("waves", [])
	if nwave >= waves.size():
		return
	var w: Dictionary = waves[nwave]
	var n := 0
	var spawner: Variant = _props.get("_en_spawn")
	for obj_v in w.get("objs", []):
		var unit: Node = spawner.wave_spawn("%d,%d" % [room.x, room.y], obj_v, n) if spawner != null else null
		if unit != null:
			_wave_units.append(unit)
		kol_en += 1
		n += 1
	if str(w.get("t", "")) != "":
		t_wave = int(float(str(w.t)) * TPS)
	nwave += 1


func _check_wave() -> void:
	kill_en += 1
	if kill_en >= kol_en:
		t_wave = NEXT_T if nwave < maxwave else 0


func _reset_wave() -> void:
	on_wave = false
	for unit in _wave_units:
		if is_instance_valid(unit):
			unit.queue_free()
	_wave_units.clear()


## Box opens and unit deaths in the room are the check() events.
func _watch_events() -> void:
	for unit in _wave_units.duplicate():
		if not is_instance_valid(unit) or _dead(unit):
			_wave_units.erase(unit)
			_check_wave()
	var marks := PackedStringArray()
	for node in _room_nodes():
		if _box_open(node):
			marks.append(str(node.get_instance_id()))
	var dead := 0
	for unit in _room_units():
		if _dead(unit):
			dead += 1
	var sig := "%s|%d|%d" % [",".join(marks), dead, kill_en]
	if _seen == "":
		_seen = sig
		return
	if sig != _seen:
		_seen = sig
		check()


func _prepare_prizes() -> void:
	for node in _room_nodes():
		if bool(node.get_meta("prize", false)) and not node.has_meta("prize_locked"):
			node.set_meta("prize_locked", not prize_active and not closed)


func _doors(turn: int) -> void:
	for node in _room_nodes():
		if str(node.get_meta("id", "")) != "doorout":
			continue
		var on := turn == 1 or (turn == 0 and str(node.get_meta("uid", "")) == "begin")
		node.set_meta("usable", on)
		if node is CanvasItem:
			(node as CanvasItem).visible = on


## Props in the trial room, rescanned when the prop count changes (a land holds
## hundreds of props and this runs every frame).
func _room_nodes() -> Array:
	if _props == null:
		return []
	var count := _props.get_child_count()
	if count != _room_count:
		_room_count = count
		_room_cache.clear()
		for node in _props.get_children():
			if node is Node2D and holds((node as Node2D).global_position):
				_room_cache.append(node)
	var out: Array = []
	for node in _room_cache:
		if is_instance_valid(node):
			out.append(node)
	return out


func _room_units() -> Array:
	var out: Array = []
	for unit in get_tree().get_nodes_in_group("enemies"):
		if unit is Node2D and holds((unit as Node2D).global_position):
			out.append(unit)
	return out


func _dead(unit: Node) -> bool:
	if not is_instance_valid(unit):
		return true
	var d: Variant = unit.get("_dead")
	return bool(d) if d != null else bool(unit.get_meta("dead", false))


func _box_open(node: Node) -> bool:
	return bool(node.get_meta("opened", false)) or bool(node.get_meta("door_open", false)) or bool(node.get_meta("box_open", false))


func _run(eve: String) -> void:
	for scr_v in info.get("scr", []):
		var scr: Dictionary = scr_v
		if str(scr.get("eve", "")) == eve:
			_props.call("run_actions", scr.get("acts", []), "", self, eve)


func _mess(text: String, player: Node2D = null) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	var down := player != null and player.global_position.y - room.y * ROOM.y < 300.0
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_message"):
		hud.show_message(text, down)
