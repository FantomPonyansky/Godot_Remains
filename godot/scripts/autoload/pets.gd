extends Node

## UnitPlayer's companions: pets[], currentPet, callPet / uncallPet, noPet and
## noPet2, keyPet (tap orders, hold calls back), and the Pers pet stats. The
## active pet is an enemy.tscn body with brain_pet.gd; its hp share is kept
## here between calls and rooms. The moon is the moonblade spell (moonblade.gd).

const _UserDir := preload("res://scripts/user_dir.gd")
static var SAVE_PATH := _UserDir.run("pets.cfg")
const TPS := 30.0
const IDS: PackedStringArray = ["phoenix", "owl"]
## noPet2 = 5 * 30 after every call or recall.
const CALL_WAIT := 150
## k_pet: holding the key this many ticks calls the pet back.
const RECALL_HOLD := 20
const ACTION := "pet_command"
const ORDER_PICK := 30.0

var current := ""
var ret_pet := ""
var no_pet := 0
var no_pet2 := 0
## UnitPet hp / maxhp per id; sost 4 is a pet that is down or not out.
var proc := {"phoenix": 1.0, "owl": 1.0}
var down := {"phoenix": true, "owl": true}
var pet: CharacterBody2D = null

var _tick_acc := 0.0
var _k_pet := 0
var _held_out := false
var _pet_on := true
var _fresh_call := false
var _hud_seen: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_load()


func reset_run() -> void:
	_drop_pet()
	current = ""
	ret_pet = ""
	no_pet = 0
	no_pet2 = 0
	proc = {"phoenix": 1.0, "owl": 1.0}
	down = {"phoenix": true, "owl": true}
	_save()


## Pers.petRes for the difficulty, seconds.
func pet_res() -> int:
	return int(GameState.dif_value("pet_res"))


## UnitPet.setLevel: maxhp, dam, skin and allVulnerMult from Pers and the empathy perk.
func stats(id: String) -> Dictionary:
	var lvl := maxi(0, int(Progression.level) - 1) if Progression else 0
	var emp := Progression.perk_rank("empathy") if Progression else 0
	if id == "owl":
		var gun := 1.0 if _has("owl_weapon") else 0.0
		var armor := 1.0 if _has("owl_armor") else 0.0
		return {
			"maxhp": 200.0 * (1.0 + lvl * 0.1),
			"dam": (3.0 + 0.3 * emp + gun) * (1.0 + lvl * 0.1),
			"skin": 5.0 + emp + 3.0 * armor,
			"vulner": 1.0 - 0.1 * emp - 0.1 * armor,
		}
	return {
		"maxhp": 50.0 * (1.0 + lvl * 0.12),
		"dam": (2.0 + 0.5 * emp) * (1.0 + lvl * 0.1),
		"skin": 4.0 * emp,
		"vulner": 1.0 - 0.2 * emp,
	}


func autores(id: String) -> bool:
	return id == "phoenix"


func pet_name(id: String) -> String:
	return OriginalLines.unit(id)


func hp_of(id: String) -> float:
	if pet_alive() and current == id:
		return float(pet.get("hp"))
	return float(proc.get(id, 0.0)) * float(stats(id).maxhp)


## Item pet=: the whistle and the robo owl.
func item_pet(item_id: String) -> String:
	match item_id:
		"whistle":
			return "phoenix"
		"owl":
			return "owl"
	return ""


func use_item(item_id: String) -> bool:
	var id := item_pet(item_id)
	if id == "":
		return false
	if ScriptsEngine != null and bool(ScriptsEngine.get("alicorn")):
		_info(OriginalLines.info("alicornNot"))
		return false
	call_pet(id)
	return true


## UnitPlayer.callPet. f forces it past the cooldowns.
func call_pet(npet: String, f := false) -> void:
	if no_pet > 0 and not f:
		_info(OriginalLines.info("petNot"))
		return
	if (no_pet2 > 0 and not f) or (ScriptsEngine != null and bool(ScriptsEngine.get("alicorn"))):
		_info(OriginalLines.info("petNot2"))
		return
	if npet == "owl" and current == "owl" and hp_of("owl") <= 0.0 and not f:
		_info(OriginalLines.info("petNot3"))
		return
	no_pet2 = CALL_WAIT
	if pet_alive():
		_info(OriginalLines.info("petRecall", pet_name(current)))
		_recall()
	ret_pet = ""
	if current == npet:
		current = ""
	else:
		if pet_on():
			current = npet
			_fresh_call = true
			_spawn()
			_info(OriginalLines.info("petCall", pet_name(npet)))
		else:
			_info(OriginalLines.info("noPetCall"))
	_save()
	_hud()


## UnitPlayer.uncallPet. ret keeps it to come back (Effect alicorn and the like).
func uncall_pet(ret := false) -> void:
	if current != "":
		if ret:
			ret_pet = current
		_info(OriginalLines.info("petRecall", pet_name(current)))
		_recall()
		current = ""
		_save()
	_hud()


## Pet.heal from food (radcookie hpet): ItemInteraction refuses a full or absent pet.
func can_heal(id: String) -> bool:
	var top := float(stats(id).maxhp)
	return current == id and top - hp_of(id) >= 1.0


func heal(id: String, amount: float) -> void:
	if pet_alive() and current == id:
		var b: Variant = _brain()
		if b != null:
			b.heal(amount)
		return
	var top := float(stats(id).maxhp)
	proc[id] = clampf((hp_of(id) + amount) / top, 0.0, 1.0)
	_save()


## UnitPet.repair on the robo owl at a workbench. False when already whole.
func repair_owl(amount: float) -> bool:
	var top := float(stats("owl").maxhp)
	var hp := maxf(0.0, hp_of("owl"))
	if hp >= top:
		return false
	proc["owl"] = clampf((hp + amount) / top, 0.0, 1.0)
	if bool(down.get("owl", false)) and current == "owl":
		down["owl"] = false
		_info(OriginalLines.info("petRes", pet_name("owl")))
		_spawn()
	_save()
	_hud()
	return true


func pet_alive() -> bool:
	return pet != null and is_instance_valid(pet) and not pet.is_queued_for_deletion()


## Location.petOn: room options petoff.
func pet_on() -> bool:
	return _pet_on


## UnitPet.die: the brain reports a pet that went down.
func pet_died(id: String) -> void:
	down[id] = true
	proc[id] = 0.0
	if autores(id):
		_info(OriginalLines.info("petDie", pet_name(id), str(pet_res())))
		no_pet = pet_res() * int(TPS)
	else:
		_info(OriginalLines.info("petDie2", pet_name(id)))
	_save()
	_hud()


## The brain keeps the hp share current while the pet is out.
func note_hp(id: String, hp: float, top: float) -> void:
	if top > 0.0:
		proc[id] = clampf(hp / top, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if GameState.paused:
		return
	_tick_acc += delta * TPS
	var n := int(_tick_acc)
	_tick_acc -= n
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != _hud_seen:
		_hud_seen = hud
		_hud()
	_check_room(player)
	for _i in n:
		_tick(player)
	_keys(player, n)


func _tick(player: Node2D) -> void:
	if no_pet > 0:
		no_pet -= 1
		_hud()
	if no_pet2 > 0:
		no_pet2 -= 1
	if current == "" or player == null:
		return
	if not pet_alive():
		# A new room or level: the same pet comes along (the original keeps the object).
		if _pet_on and _host() != null and not bool(down.get(current, true)):
			_spawn()
		elif bool(down.get(current, true)) and no_pet <= 0 and autores(current) and _pet_on and _host() != null:
			_spawn()
		return
	var b: Variant = _brain()
	if b != null and b.down and no_pet <= 0 and autores(current):
		b.resurrect()


## keyPet: a tap sends the pet at the unit under the cursor or to the cursor; held
## past 20 ticks it comes back through walls.
func _keys(player: Node2D, n: int) -> void:
	if player == null or not InputMap.has_action(ACTION) or not _pet_on:
		return
	if Input.is_action_pressed(ACTION):
		if _held_out:
			return
		_k_pet += n
		if _k_pet > RECALL_HOLD:
			var b: Variant = _brain()
			if b != null:
				b.moveto(player.global_position + Vector2(0.0, -40.0), true)
			_k_pet = 0
			_held_out = true
		return
	if _k_pet > 0:
		var b: Variant = _brain()
		if b != null:
			var at := player.get_global_mouse_position()
			var cursor := get_tree().get_first_node_in_group("aim_cursor")
			if cursor != null and cursor.has_method("world_position"):
				at = cursor.world_position()
			var foe := _unit_at(at)
			if foe != null:
				b.atk(foe)
			else:
				b.moveto(at)
	_k_pet = 0
	_held_out = false


func _unit_at(at: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := ORDER_PICK
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is CharacterBody2D or not is_instance_valid(node) or int(node.get("hp")) <= 0:
			continue
		var body: Vector2 = node.get("body_size") if node.get("body_size") is Vector2 else Vector2(40, 40)
		var feet := (node as Node2D).global_position
		var r := Rect2(feet - Vector2(body.x * 0.5, body.y), body)
		if r.has_point(at):
			return node
		var d := r.get_center().distance_to(at)
		if d < best_d:
			best = node
			best_d = d
	return best


## UnitPlayer.inLoc: no companion in a petoff room.
func _check_room(player: Node2D) -> void:
	var on := true
	var lp := get_tree().get_first_node_in_group("land_props")
	if player != null and lp != null and lp.has_method("room_options_at"):
		var opts: Variant = lp.room_options_at(player.global_position)
		if opts is Dictionary and (opts as Dictionary).has("petoff"):
			on = false
	if on == _pet_on:
		return
	_pet_on = on
	if not pet_alive():
		return
	# The pet stays behind in the last room (vis.alpha 0, not ticked) and rejoins in the next petOn room.
	if not on:
		_info(OriginalLines.info("noPetFollow"))
		pet.visible = false
		pet.process_mode = Node.PROCESS_MODE_DISABLED
		pet.set_meta("petoff_layers", Vector2i(pet.collision_layer, pet.collision_mask))
		pet.collision_layer = 0
		pet.collision_mask = 0
	else:
		pet.process_mode = Node.PROCESS_MODE_INHERIT
		pet.visible = true
		if pet.has_meta("petoff_layers"):
			var lm: Vector2i = pet.get_meta("petoff_layers")
			pet.collision_layer = lm.x
			pet.collision_mask = lm.y
			pet.remove_meta("petoff_layers")
		if player != null:
			pet.global_position = player.global_position + Vector2(0.0, -20.0)


func _host() -> Node:
	var scene := get_tree().current_scene
	if scene == null or get_tree().get_first_node_in_group("player") == null:
		return null
	return scene


func _spawn() -> void:
	_drop_pet()
	var host := _host()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if host == null or player == null or current == "":
		return
	var packed := load("res://scenes/enemy.tscn") as PackedScene
	if packed == null:
		return
	var node := packed.instantiate() as CharacterBody2D
	node.set_meta("unit_id", current)
	node.set_meta("brain", "pet")
	node.set_meta("pet_call", _fresh_call)
	node.name = "Pet_" + current
	_fresh_call = false
	var at := player.global_position + Vector2(0.0, -20.0)
	node.position = at
	host.add_child(node)
	node.global_position = at
	pet = node
	_hud()


## UnitPet.recall: sost 4, sparks if it was showing, then the body goes.
func _recall() -> void:
	if not pet_alive():
		pet = null
		return
	var b: Variant = _brain()
	if b != null:
		b.recall()
	down[current] = true
	_drop_pet()


func _drop_pet() -> void:
	if pet_alive():
		pet.queue_free()
	pet = null


func _brain() -> Variant:
	if not pet_alive():
		return null
	return pet.get("_brain")


func _has(item_id: String) -> bool:
	return Inventory != null and Inventory.count(item_id) > 0


func _info(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("info_line"):
		hud.info_line(text)


## GUI.setPet: the bar under the mana, the respawn seconds, nothing without a pet.
func _hud() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("set_pet_hp"):
		return
	if current == "":
		hud.set_pet_hp(-1.0)
		if hud.has_method("set_pet_timer"):
			hud.set_pet_timer(-1)
		return
	var top := float(stats(current).maxhp)
	var hp := hp_of(current)
	hud.set_pet_hp(clampf(hp / top, 0.0, 1.0) if hp > 0.0 else 0.0)
	if hud.has_method("set_pet_timer"):
		hud.set_pet_timer(int(floor(no_pet / TPS)) if no_pet > 0 else -1)


func refresh_hud() -> void:
	_hud()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("pets", "current", current)
	cfg.set_value("pets", "ret", ret_pet)
	for id in IDS:
		cfg.set_value("proc", id, float(proc.get(id, 1.0)))
		cfg.set_value("down", id, bool(down.get(id, true)))
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	current = str(cfg.get_value("pets", "current", ""))
	ret_pet = str(cfg.get_value("pets", "ret", ""))
	for id in IDS:
		proc[id] = float(cfg.get_value("proc", id, 1.0))
		down[id] = bool(cfg.get_value("down", id, true))
	# UnitPlayer.setNull calls the current pet again on load.
	_fresh_call = current != ""
