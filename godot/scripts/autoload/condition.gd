extends Node

## Weapon and armor condition from Remains-Source2.
## Weapon.shoot wears a gun by 1 + ammo.increasedWear. WClub.crash wears melee on a hit.
## ArmorManager.damage wears the suit that is on, then takes it off at 0.
## Repair skill does not change wear. It changes repairMult (skills.xml).
## The durable perk (repair 4) sets armorVulner to 0.8. Remont sets jammedMult to 0.2.

const DATA := "res://assets/data/craft_condition.json"
const _UserDir := preload("res://scripts/user_dir.gd")
static var SAVE_PATH := _UserDir.run("condition.cfg")
const NO_WEAR := ["DAM_VENOM", "DAM_EMP", "DAM_POISON", "DAM_BLEED", "DAM_INTERNAL"]

var _weapons: Dictionary = {}
var _armors: Dictionary = {}
var _ammo_wear: Dictionary = {}
var _hp: Dictionary = {}
var _armor_lvl: Dictionary = {}
var _dirty := false
var _save_wait := 0.0
var _shot_ok := false
var _wore_shot := false
var _said: Dictionary = {}
var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_data()
	_load()
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func reset_run() -> void:
	_hp.clear()
	_armor_lvl.clear()
	_said.clear()
	_dirty = false
	_save()


func is_armor(id: String) -> bool:
	return _armors.has(id)


func is_durable_weapon(id: String) -> bool:
	return _weapons.has(id)


func armor_usable(id: String) -> bool:
	if not is_armor(id):
		return false
	var row: Dictionary = _armors[id]
	if bool(row.get("unbreakable", false)):
		return true
	return armor_hp(id) > 0.0


func armor_level(id: String) -> int:
	return int(_armor_lvl.get(id, 0))


func set_armor_level(id: String, level: int) -> void:
	_armor_lvl[id] = maxi(0, level)
	_dirty = true


func max_armor_level() -> int:
	if Progression == null:
		return 0
	return Progression.perk_rank("uparmor")


func weapon_hp(id: String) -> float:
	_ensure_weapon(id)
	return float(_hp.get(_wk(id), 0.0))


func armor_hp(id: String) -> float:
	_ensure_armor(id)
	return float(_hp.get(_ak(id), 0.0))


func weapon_max(id: String) -> int:
	return int((_weapons.get(id, {}) as Dictionary).get("maxhp", 0))


func armor_max(id: String) -> int:
	return int((_armors.get(id, {}) as Dictionary).get("maxhp", 0))


func forget(id: String) -> void:
	_hp.erase(_wk(id))
	_dirty = true


func fresh_weapon(id: String) -> void:
	if not _weapons.has(id):
		return
	_hp[_wk(id)] = float(weapon_max(id))
	_dirty = true


func set_weapon_hp(id: String, hp: float) -> void:
	if not _weapons.has(id):
		return
	_hp[_wk(id)] = clampf(hp, 0.0, float(weapon_max(id)))
	_dirty = true


func set_armor_hp(id: String, hp: float) -> void:
	if not _armors.has(id):
		return
	_hp[_ak(id)] = clampf(hp, 0.0, float(armor_max(id)))
	_dirty = true


func percent_text(current: float, maximum: float) -> String:
	if maximum <= 0.0:
		return ""
	var shown: float = float(snapped(current / maximum * 100.0, 0.1))
	return "%s%%" % shown


func weapon_line() -> String:
	var id := _gun_id()
	if id == "" or not _weapons.has(id):
		return ""
	var name := id
	if Inventory:
		name = Inventory.name_of(id)
	var cur := weapon_hp(id)
	var cap := float(weapon_max(id))
	var state := percent_text(cur, cap)
	if cur <= 0.0:
		state = OriginalLines.gui("broken")
	return "%s    %s" % [name, state]


func armor_line() -> String:
	var id := _worn_id()
	if id == "" or not _armors.has(id):
		return ""
	var name := id
	if Inventory:
		name = Inventory.name_of(id)
	var row: Dictionary = _armors[id]
	if bool(row.get("unbreakable", false)):
		return "%s    %s" % [name, percent_text(armor_hp(id), float(armor_max(id)))]
	var cur := armor_hp(id)
	var state := percent_text(cur, float(armor_max(id)))
	if cur <= 0.0:
		state = OriginalLines.gui("broken")
	return "%s    %s" % [name, state]


func repair_mult() -> float:
	# skills.xml repair: repairMult dop v0 0.2 vd 0.04, applied with skill points.
	var points := 0
	if Progression:
		points = Progression.rank("repair")
	return 0.2 + 0.04 * float(points)


func jammed_mult() -> float:
	if Progression and Progression.perk_rank("remont") >= 1:
		return 0.2
	return 1.0


func armor_vulner() -> float:
	if Progression and Progression.perk_rank("durable") >= 1:
		return 0.8
	return 1.0


func weapon_row(id: String) -> Dictionary:
	return (_weapons.get(id, {}) as Dictionary).duplicate(true)


func armor_row(id: String) -> Dictionary:
	return (_armors.get(id, {}) as Dictionary).duplicate(true)


func repair_weapon(id: String) -> bool:
	var row := weapon_row(id)
	if row.is_empty() or float(row.get("rep", 1.0)) <= 0.0:
		_say(OriginalLines.info("unFixFail"))
		return false
	var cap := float(row.get("maxhp", 0))
	var cur := weapon_hp(id)
	if cur >= cap:
		_say(OriginalLines.info("noRepair"))
		return false
	var gain := cap * repair_mult() * float(row.get("rep", 1.0)) * 0.25
	_hp[_wk(id)] = minf(cap, cur + gain)
	_dirty = true
	_say(OriginalLines.info("repairWeapon", Inventory.name_of(id) if Inventory else id, str(int(round(weapon_hp(id) / maxf(1.0, cap) * 100.0)))))
	return true


func repair_armor(id: String) -> bool:
	var row := armor_row(id)
	if row.is_empty() or bool(row.get("no_repair", false)) or bool(row.get("unbreakable", false)):
		_say(OriginalLines.info("unFixFail"))
		return false
	var cap := float(row.get("maxhp", 0))
	var cur := armor_hp(id)
	if cur >= cap:
		_say(OriginalLines.info("noRepair"))
		return false
	var parts := maxi(1, int(row.get("kol_comp", 1)))
	var gain := cap * repair_mult() / float(parts)
	_hp[_ak(id)] = minf(cap, cur + gain)
	_dirty = true
	_say(OriginalLines.info("repairWeapon", Inventory.name_of(id) if Inventory else id, str(int(round(armor_hp(id) / maxf(1.0, cap) * 100.0)))))
	return true


func adjust_hit(amount: int, tip: String) -> int:
	# UnitPlayer.damage wears current armor, then ArmorManager removes it at 0
	# before the hit is applied to health.
	if amount <= 0:
		return amount
	var amul := str(Inventory.amulet) if Inventory != null else ""
	var amul_resist := float((_armors.get(amul, {}).get("resists", {}) as Dictionary).get(tip, 0.0)) if amul != "" else 0.0
	var id := _worn_id()
	if id == "" or not _armors.has(id):
		return maxi(0, int(round(float(amount) * (1.0 - amul_resist))))
	var row: Dictionary = _armors[id]
	var resist := float((row.get("resists", {}) as Dictionary).get(tip, 0.0))
	var broke := false
	if not bool(row.get("unbreakable", false)) and tip not in NO_WEAR:
		var loss := float(amount) * armor_vulner()
		loss *= 1.0 - resist
		if tip == "DAM_ACID":
			loss *= 2.0
		elif tip == "DAM_PINKCLOUD":
			loss *= 3.0
		var cap := float(row.get("maxhp", 0))
		var cur := maxf(0.0, armor_hp(id) - loss)
		if cur <= 0.0:
			cur = 0.0
			broke = true
		_hp[_ak(id)] = minf(cap, cur)
		_dirty = true
		if broke:
			_strip_armor(id)
	if broke:
		return maxi(0, int(round(float(amount) * (1.0 - amul_resist))))
	return maxi(0, int(round(float(amount) * (1.0 - resist - amul_resist))))


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	_wore_shot = false
	_shot_ok = false
	var player := get_tree().get_first_node_in_group("player") as Node
	if player == null:
		return
	var id := _gun_id()
	if id == "" or not _weapons.has(id):
		return
	var row: Dictionary = _weapons[id]
	var kind := str(row.get("kind", ""))
	if not _trigger(player, id):
		return
	var cur := weapon_hp(id)
	if cur <= 0.0:
		player.set("_fire_cd", delta + 0.35)
		_say_key("broken:" + id, OriginalLines.info("brokenWeapon", _item_name(id)))
		return
	if kind == "melee":
		return
	if kind != "lightGun" and kind != "heavyGun":
		return
	if cur < float(row.get("maxhp", 1)) * 0.5:
		var breaking := (float(row.get("maxhp", 1)) - cur) / float(row.get("maxhp", 1)) * 2.0 - 1.0
		var roll := randf()
		var mag := maxi(20, int(row.get("mag", 0)))
		var jam_scale := jammed_mult()
		if roll < breaking / float(mag) * jam_scale:
			_jam(player, id)
			return
		if roll < breaking / 5.0 * jam_scale:
			player.set("_fire_cd", delta + 2.0 / 30.0)
			var rapid := 5
			if Inventory:
				rapid = int(Inventory.weapon_def(id).get("rapid", 5))
			if rapid > 5:
				_say_key("misfire", OriginalLines.info("misfire"))
			return
	_shot_ok = true


func _process(delta: float) -> void:
	_save_wait -= delta
	if _dirty and _save_wait <= 0.0:
		_save()
		_dirty = false
		_save_wait = 1.0
	_refresh_label()


func _exit_tree() -> void:
	if _dirty:
		_save()


func _on_node_added(node: Node) -> void:
	if node.is_in_group("hud"):
		_attach_label(node)
	if node is Area2D:
		node.ready.connect(_on_bullet.bind(node), CONNECT_ONE_SHOT)
	elif node is Line2D and node.points.size() >= 2 and node.width >= 1.5 and node.width <= 2.5:
		node.ready.connect(_on_swing.bind(node), CONNECT_ONE_SHOT)


func _on_bullet(node: Node) -> void:
	if not _shot_ok or _wore_shot or not is_instance_valid(node):
		return
	if not node.is_in_group("player_bullets"):
		return
	var id := _gun_id()
	if id == "" or not _weapons.has(id):
		return
	var kind := str((_weapons[id] as Dictionary).get("kind", ""))
	if kind != "lightGun" and kind != "heavyGun":
		return
	_wore_shot = true
	_wear_weapon(id, 1.0 + _extra_wear(id))


func _on_swing(line: Line2D) -> void:
	if get_tree().paused or not is_instance_valid(line):
		return
	var id := _gun_id()
	if id == "" or str((_weapons.get(id, {}) as Dictionary).get("kind", "")) != "melee":
		return
	if weapon_hp(id) <= 0.0:
		return
	var points := line.points
	if points.size() < 2:
		return
	var space := line.get_world_2d().direct_space_state
	if space == null:
		return
	var start := line.to_global(points[0])
	var stop := line.to_global(points[points.size() - 1])
	var query := PhysicsRayQueryParameters2D.create(start, stop, 69)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty() or not hit.collider is Node:
		return
	var body := hit.collider as Node
	if body.is_in_group("player"):
		return
	var dam := 1.0
	var dtype := str(body.get("damage_type")) if body.get("damage_type") != null else ""
	if dtype == "DAM_ACID":
		dam = 3.0
	elif float(body.get_meta("sost", 0.0)) > 2.0 and str(body.get_meta("id", body.name)).contains("mine"):
		dam = 15.0
	_wear_weapon(id, dam + _extra_wear(id))


func _wear_weapon(id: String, amount: float) -> void:
	if amount <= 0.0 or not _weapons.has(id):
		return
	var cap := float(weapon_max(id))
	var cur := maxf(0.0, weapon_hp(id) - amount)
	_hp[_wk(id)] = minf(cap, cur)
	_dirty = true


func _jam(player: Node, id: String) -> void:
	var reload := 1.0
	var dtype := ""
	if Inventory:
		var w := Inventory.weapon_def(id)
		reload = maxf(float(w.get("reload", 1.0)), 1.0) / 30.0
		dtype = str(w.get("damage_type", ""))
	player.set("_reload_id", id)
	player.set("_reload_left", reload)
	player.set("_fire_cd", reload)
	if dtype in ["DAM_LASER", "DAM_PLASMA", "DAM_EMP", "DAM_ELECTRIC"]:
		_say_key("jam:" + id, OriginalLines.info("weaponCircuit"))
	else:
		_say_key("jam:" + id, OriginalLines.info("weaponJammed"))


func _trigger(player: Node, id: String) -> bool:
	var reload_left := float(player.get("_reload_left"))
	var fire_cd := float(player.get("_fire_cd"))
	var delta := get_physics_process_delta_time()
	if reload_left > delta or fire_cd > delta:
		return false
	var auto := false
	if Inventory:
		auto = bool(Inventory.weapon_def(id).get("auto", false))
	if not auto and bool(player.get("_semi_lock")) and not Input.is_action_just_pressed("shoot"):
		return false
	if auto:
		return Input.is_action_pressed("shoot")
	return Input.is_action_pressed("shoot") or Input.is_action_just_pressed("shoot")


func _extra_wear(id: String) -> float:
	var ammo := str((_weapons.get(id, {}) as Dictionary).get("ammo", ""))
	return float(_ammo_wear.get(ammo, 0.0))


func _strip_armor(id: String) -> void:
	_say(OriginalLines.info("brokenArmor"))
	if Inventory == null or str(Inventory.worn) != id:
		return
	if Inventory.has_method("unworn"):
		Inventory.unworn()
		return
	Inventory.worn = ""
	Inventory._save()
	Inventory.changed.emit()


func _ensure_weapon(id: String) -> void:
	if id == "" or not _weapons.has(id) or _hp.has(_wk(id)):
		return
	_hp[_wk(id)] = float(weapon_max(id))
	_dirty = true


func _ensure_armor(id: String) -> void:
	if id == "" or not _armors.has(id) or _hp.has(_ak(id)):
		return
	_hp[_ak(id)] = float(armor_max(id))
	_dirty = true


func _gun_id() -> String:
	if Inventory == null:
		return ""
	return str(Inventory.weapon_id)


func _worn_id() -> String:
	if Inventory == null:
		return ""
	return str(Inventory.worn)


func _item_name(id: String) -> String:
	if Inventory:
		return Inventory.name_of(id)
	return id


func _wk(id: String) -> String:
	return "w:" + id


func _ak(id: String) -> String:
	return "a:" + id


func _say(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notice"):
		hud.show_notice(text)


func _say_key(key: String, text: String) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_said.get(key, 0)) < 700:
		return
	_said[key] = now
	_say(text)


func _attach_label(hud: Node) -> void:
	if _label != null and is_instance_valid(_label):
		return
	var host := hud.get_node_or_null("Root")
	if host == null:
		host = hud
	_label = Label.new()
	_label.name = "ConditionLabel"
	_label.position = Vector2(24, 168)
	_label.add_theme_color_override("font_color", Color(0.9, 0.82, 0.55))
	host.add_child(_label)


func _refresh_label() -> void:
	# Weapon, armor, and use lines are the gameplay HUD, not this English strip.
	if _label != null and is_instance_valid(_label):
		_label.visible = false
		_label.text = ""


func _load_data() -> void:
	if not FileAccess.file_exists(DATA):
		push_error("Condition missing craft_condition.json")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Condition could not parse craft_condition.json")
		return
	var doc: Dictionary = parsed
	_weapons = doc.get("weapons", {})
	_armors = doc.get("armors", {})
	_ammo_wear = doc.get("ammo_wear", {})


func _save() -> void:
	var cfg := ConfigFile.new()
	for key in _hp.keys():
		cfg.set_value("hp", str(key), float(_hp[key]))
	for key in _armor_lvl.keys():
		cfg.set_value("lvl", str(key), int(_armor_lvl[key]))
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if cfg.has_section("hp"):
		for key in cfg.get_section_keys("hp"):
			_hp[str(key)] = float(cfg.get_value("hp", key, 0.0))
	if cfg.has_section("lvl"):
		for key in cfg.get_section_keys("lvl"):
			_armor_lvl[str(key)] = int(cfg.get_value("lvl", key, 0))
