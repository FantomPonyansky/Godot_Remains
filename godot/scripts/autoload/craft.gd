extends Node

## Crafting stations from Remains-Source2 PipPageWork and Interact.
## World objects: work (Верстак), himlab (Лаборатория), stove.
## Portable items mworkbench, mworkexpl, and mworklab open the same pages
## without a world object. Explosives recipes also show on the Верстак.
## A recipe is listed only when its schematic is in the inventory.
## The pages are drawn by the PipBuck (page 7, scripts/pip_trade.gd); the own
## screen here is used only where the scene has no PipBuck host.
## Ingredients count the home vault too (Item.kol + Item.vault).

const DATA := "res://assets/data/craft_condition.json"
const _DebugFlags := preload("res://scripts/debug_flags.gd")
const REACH := 72.0
## PipPageWork owlRep: robo owl hp back per scrap, before repairMult.
const OWL_REP := 100.0

const PORTABLE := {
	"mworkbench": "mworkbench",
	"mworkexpl": "expl",
	"mworklab": "lab",
}

var _stations: Dictionary = {}
var _recipes: Array = []
const PAGE_TITLES := {"craft": "work1", "upgrade": "work2", "repair": "work3"}

var _layer: CanvasLayer
var _root: Control
var _hint: Label
var _title: Label
var _detail: Label
var _list: VBoxContainer
var _tabs: HBoxContainer
var _open := false
var _paused_here := false
var _station := ""
var _page := 0
var _rows: Array = []
var _index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_data()
	_build_ui()
	UiNav.add_screen(_root, {"default": _default_focus, "back": _close, "tabs": _cycle_page})
	Locale.language_changed.connect(_on_language)
	Prompts.device_changed.connect(_on_device)
	if _recipes.size() != 75:
		push_error("Craft expected 75 source recipes, got %d" % _recipes.size())


func is_open() -> bool:
	return _open


## Interact allact work / lab / stove and the portable benches: PipBuck page 7
## (Ремесло) with workTip. Without a PipBuck host the own screen opens.
func open_station(station_id: String) -> void:
	if not _stations.has(station_id):
		return
	var pause := Story.pause_menu()
	if pause != null and pause.has_method("open_pipbuck_at"):
		Vendors.open_work(station_id)
		return
	_station = station_id
	_page = 0
	_index = 0
	_open = true
	_layer.visible = true
	_root.visible = true
	_paused_here = not GameState.paused
	if _paused_here:
		GameState.set_paused(true)
	_refresh()


func _process(_delta: float) -> void:
	if _open or get_tree().paused:
		return
	if not Input.is_action_just_pressed("interact"):
		return
	var who := get_tree().get_first_node_in_group("player")
	if who and who.get("rat") == true:
		return
	var node := _nearest()
	if node == null:
		return
	open_station(_station_of(node))


func _input(event: InputEvent) -> void:
	if _open:
		_ui_input(event)
		return
	if _portable_accept(event):
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo or not _DebugFlags.keys():
		return
	var key := (event as InputEventKey).physical_keycode
	if key == KEY_F8:
		_debug_spawn("work")
	elif key == KEY_F7:
		_debug_spawn("lab")
	elif key == KEY_F6:
		_debug_spawn("stove")
	else:
		return
	get_viewport().set_input_as_handled()


## Rows and tabs are focusable buttons; UiNav moves focus, LB/RB switch the
## page and B closes. Left/right also switch the page.
func _ui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion:
		return
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		_cycle_page(-1 if event.is_action_pressed("ui_left", true) else 1)
		get_viewport().set_input_as_handled()


func _cycle_page(step: int) -> void:
	var pages := _pages()
	if pages.size() < 2:
		return
	_page = posmod(_page + step, pages.size())
	_index = 0
	_refresh()


func _default_focus() -> Control:
	if _list != null:
		for child in _list.get_children():
			if child is Button and not child.is_queued_for_deletion():
				return child
	for child in _tabs.get_children():
		if child is Button and not child.is_queued_for_deletion():
			return child
	return null


func _on_language(_lang: String) -> void:
	_hint.text = _hint_text()
	if _open:
		_refresh()


func _on_device(_pad: bool) -> void:
	_hint.text = _hint_text()


func _hint_text() -> String:
	return Prompts.hint([["tabs", OriginalLines.pip("main7")], ["accept", OriginalLines.pip("choose")], ["back", OriginalLines.pip("mainclose")]])


func _portable_accept(event: InputEvent) -> bool:
	if _open or not event.is_action_pressed("ui_accept"):
		return false
	var pip := _find_pip(get_tree().root)
	if pip == null or int(pip.get("_index")) != 1:
		return false
	var ids: Variant = pip.get("_inv_ids")
	if not ids is Array:
		return false
	var slot := int(pip.get("_inv_i"))
	if slot < 0 or slot >= (ids as Array).size():
		return false
	var id := str((ids as Array)[slot])
	if not PORTABLE.has(id) or Inventory == null or Inventory.count(id) <= 0:
		return false
	open_station(str(PORTABLE[id]))
	return true


func _close() -> void:
	_open = false
	if _layer:
		_layer.visible = false
		_root.visible = false
	if _paused_here:
		_paused_here = false
		GameState.set_paused(false)


func _activate() -> void:
	if _index < 0 or _index >= _rows.size():
		return
	var row: Dictionary = _rows[_index]
	var page := str(_pages()[_page])
	if page == "craft":
		_craft(row)
	elif page == "repair":
		_repair(row)
	elif page == "upgrade":
		_upgrade(row)
	_refresh()


func _craft(row: Dictionary) -> void:
	if not _skill_ok(row):
		_say_need_skill(row)
		return
	var kol := _output_count(row)
	if not _pay(row):
		_say(OriginalLines.info("noMaterials"))
		return
	var result := str(row.get("result", ""))
	var kind := str(row.get("kind", "item"))
	if Inventory and Inventory.has_method("add_crafted"):
		Inventory.add_crafted(result, kol)
	elif Inventory:
		Inventory.add(result, kol)
	preload("res://scripts/imp_mess.gd").item_taken(get_tree(), result)
	if kind == "weapon" or kind == "explosives":
		Condition.fresh_weapon(result)
	elif kind == "armor":
		Condition.set_armor_level(result, 0)
		Condition.armor_hp(result)
	# PipPageWork: created / created3 / created4 / created2 by category.
	var have := str(Inventory.count(result)) if Inventory else ""
	match kind:
		"weapon":
			_say(OriginalLines.info("created", _name(result)))
		"armor":
			_say(OriginalLines.info("created3", _name(result)))
		"impl":
			_say(OriginalLines.info("created4", _name(result)))
		_:
			_say(OriginalLines.info("created2", _name(result), have))
	Story.check_quests(result)


func _say_need_skill(recipe: Dictionary) -> void:
	_say(OriginalLines.info("needSkill", OriginalLines.eff(str(recipe.get("skill", ""))), str(int(recipe.get("skill_level", 0)))))


func _repair(row: Dictionary) -> void:
	var id := str(row.get("id", ""))
	var kind := str(row.get("kind", ""))
	if Inventory == null:
		return
	if kind == "weapon":
		if Inventory.count("frag") < 1:
			_say(OriginalLines.info("noMaterials"))
			return
		if not Condition.repair_weapon(id):
			return
		Inventory.spend("frag", 1)
	elif kind == "armor":
		var part := str(row.get("component", id + "_comp"))
		if Inventory.count(part) < 1:
			_say(OriginalLines.info("noMaterials"))
			return
		if not Condition.repair_armor(id):
			return
		Inventory.spend(part, 1)
	elif kind == "owl":
		# PipPageWork L_INSTR: the robo owl is mended with scrap.
		if Inventory.count("scrap") < 1:
			_say(OriginalLines.info("noMaterials"))
			return
		if not Pets.repair_owl(OWL_REP * Condition.repair_mult()):
			return
		Inventory.spend("scrap", 1)


func _upgrade(row: Dictionary) -> void:
	var kind := str(row.get("kind", ""))
	var id := str(row.get("id", ""))
	if kind == "weapon":
		var recipe := _recipe_by_id("s_" + id)
		if recipe.is_empty():
			_say(OriginalLines.pip("emptycreate"))
			return
		if not _skill_ok(recipe):
			_say_need_skill(recipe)
			return
		if not _pay(recipe):
			_say(OriginalLines.info("noMaterials"))
			return
		var uid := id + "^1"
		var was := Inventory.weapon_id == id
		Inventory.spend(id, 1)
		if Inventory.has_method("add_crafted"):
			Inventory.add_crafted(uid, 1)
		else:
			Inventory.add(uid, 1)
		Condition.forget(id)
		Condition.fresh_weapon(uid)
		if was:
			Inventory.equip(uid)
		_say(OriginalLines.info("created", _name(uid)))
		return
	var need := int(row.get("kol", 0))
	var part := str(row.get("component", ""))
	if Inventory.count(part) < need:
		_say(OriginalLines.info("noMaterials"))
		return
	Inventory.spend(part, need)
	Condition.set_armor_level(id, Condition.armor_level(id) + 1)
	_say(OriginalLines.info("upArmor"))


func _refresh() -> void:
	if _title == null:
		return
	var pages := _pages()
	if _page >= pages.size():
		_page = 0
	_title.text = _station_name(_station)
	_fill_tabs(pages)
	_rows = _page_rows(str(pages[_page]))
	if _index >= _rows.size():
		_index = 0
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var tabs: Array = _tabs.get_children()
	var current: Control = tabs[_page] if _page < tabs.size() else null
	if _rows.is_empty():
		var empty := Label.new()
		empty.text = _empty_text(str(pages[_page]))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", Color(0.95, 0.78, 0.36))
		_list.add_child(empty)
		_detail.text = ""
		if current:
			current.grab_focus()
		return
	var buttons: Array = []
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.flat = true
		button.clip_text = true
		button.focus_mode = Control.FOCUS_ALL
		button.text = _row_text(row, str(pages[_page]))
		if not bool(row.get("skilled", true)):
			button.modulate = Color(1, 1, 1, 0.5)
		button.pressed.connect(_pick.bind(i))
		button.focus_entered.connect(_show_detail.bind(i))
		button.mouse_entered.connect(button.grab_focus)
		_list.add_child(button)
		buttons.append(button)
	UiNav.link_column(buttons, false)
	if current:
		buttons[0].focus_neighbor_top = buttons[0].get_path_to(current)
		for tab in tabs:
			(tab as Control).focus_neighbor_bottom = (tab as Control).get_path_to(buttons[0])
	_show_detail(_index)
	(buttons[_index] as Control).grab_focus()


func _show_detail(i: int) -> void:
	if i < 0 or i >= _rows.size():
		return
	_index = i
	_detail.text = _detail_text(_rows[i], str(_pages()[_page]))


func _pick(i: int) -> void:
	_index = i
	_activate()


func _page_rows(page: String) -> Array:
	if page == "craft":
		return _craft_rows()
	if page == "repair":
		return _repair_rows()
	if page == "upgrade":
		return _upgrade_rows()
	return []


func _craft_rows() -> Array:
	var benches: Array = (_stations.get(_station, {}) as Dictionary).get("benches", [])
	var out: Array = []
	for recipe_v in _recipes:
		var recipe: Dictionary = recipe_v
		if str(recipe.get("bench", "")) not in benches:
			continue
		if Inventory == null or Inventory.count(str(recipe.get("id", ""))) <= 0:
			continue
		if _already_made(recipe):
			continue
		var copy: Dictionary = recipe.duplicate(true)
		copy["skilled"] = _skill_ok(recipe)
		out.append(copy)
	out.sort_custom(_by_skill)
	return out


func _repair_rows() -> Array:
	var out: Array = []
	if Inventory == null:
		return out
	for id in Inventory.owned_weapon_ids():
		if not Condition.is_durable_weapon(id):
			continue
		var row := Condition.weapon_row(id)
		var kind := str(row.get("kind", ""))
		if kind != "melee" and kind != "lightGun" and kind != "heavyGun":
			continue
		if Condition.weapon_hp(id) >= float(row.get("maxhp", 0)):
			continue
		out.append({
			"id": id,
			"kind": "weapon",
			"skilled": true,
			"rep": float(row.get("rep", 1.0)) * 0.25,
		})
	for id_v in Inventory.carried():
		var id := str(id_v)
		if not Condition.is_armor(id):
			continue
		var suit := Condition.armor_row(id)
		if bool(suit.get("no_repair", false)) or bool(suit.get("unbreakable", false)):
			continue
		if Condition.armor_hp(id) >= float(suit.get("maxhp", 0)):
			continue
		var parts := maxi(1, int(suit.get("kol_comp", 1)))
		out.append({
			"id": id,
			"kind": "armor",
			"skilled": true,
			"component": str(suit.get("component", id + "_comp")),
			"rep": 1.0 / float(parts),
		})
	if Inventory.count("owl") > 0 and Pets.hp_of("owl") < float(Pets.stats("owl").maxhp):
		out.append({"id": "owl", "kind": "owl", "skilled": true, "component": "scrap",
			"rep": OWL_REP / float(Pets.stats("owl").maxhp)})
	return out


func _upgrade_rows() -> Array:
	var out: Array = []
	if Inventory == null or _station != "work":
		return out
	var cap := Condition.max_armor_level()
	if cap > 0:
		for id_v in Inventory.carried():
			var id := str(id_v)
			if not Condition.is_armor(id):
				continue
			var suit := Condition.armor_row(id)
			var lvl := Condition.armor_level(id)
			var max_lvl := int(suit.get("max_level", 0))
			if lvl >= max_lvl or lvl >= cap:
				continue
			var steps: Array = suit.get("upgrade_kol", [])
			if lvl + 1 >= steps.size():
				continue
			var kol := int(steps[lvl + 1])
			if kol <= 0:
				continue
			out.append({
				"id": id,
				"kind": "armor",
				"skilled": true,
				"kol": kol,
				"component": str(suit.get("component", id + "_comp")),
				"lvl": lvl,
			})
	for id in Inventory.carried():
		var w := Inventory.weapon_def(id)
		if w.is_empty() or int(w.get("skill", 0)) != 3 or id.contains("^"):
			continue
		var uid := id + "^1"
		if Inventory.weapon_def(uid).is_empty() or Inventory.count(uid) > 0:
			continue
		if _recipe_by_id("s_" + id).is_empty():
			continue
		out.append({"id": id, "kind": "weapon", "skilled": true, "variant": uid})
	return out


func _already_made(recipe: Dictionary) -> bool:
	var result := str(recipe.get("result", ""))
	var kind := str(recipe.get("kind", "item"))
	if kind == "explosives":
		return false
	if Inventory == null or Inventory.count(result) <= 0:
		return false
	if kind == "weapon" or kind == "armor":
		return true
	if kind == "impl" or bool(recipe.get("one", false)):
		return true
	return false


func _pay(recipe: Dictionary) -> bool:
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for key in ingredients.keys():
		if Inventory == null or Stash.total(str(key)) < int(ingredients[key]):
			return false
	for key in ingredients.keys():
		Stash.spend_with_vault(str(key), int(ingredients[key]))
	return true


func _output_count(recipe: Dictionary) -> int:
	var kol := maxi(1, int(recipe.get("kol", 1)))
	if str(recipe.get("perk", "")) == "potmaster" and Progression and Progression.perk_rank("potmaster") > 0:
		kol *= 2
	return kol


func _skill_ok(recipe: Dictionary) -> bool:
	var need := int(recipe.get("skill_level", 0))
	if need <= 0:
		return true
	if Progression == null:
		return false
	return Progression.skill_level_of(str(recipe.get("skill", ""))) >= need


func _by_skill(a: Dictionary, b: Dictionary) -> bool:
	var ao := 0 if bool(a.get("skilled", true)) else 1
	var bo := 0 if bool(b.get("skilled", true)) else 1
	if ao != bo:
		return ao < bo
	var ask := str(a.get("skill", ""))
	var bsk := str(b.get("skill", ""))
	if ask != bsk:
		return ask < bsk
	if int(a.get("skill_level", 0)) != int(b.get("skill_level", 0)):
		return int(a.get("skill_level", 0)) < int(b.get("skill_level", 0))
	return str(a.get("result", "")) < str(b.get("result", ""))


func _row_text(row: Dictionary, page: String) -> String:
	var id := str(row.get("result", row.get("id", "")))
	var name := _name(id)
	if page == "craft":
		var mark := Locale.t("craft_ready") if bool(row.get("skilled", true)) and _have_parts(row) else Locale.t("craft_missing")
		if not bool(row.get("skilled", true)):
			mark = "%s: %s %d" % [OriginalLines.pip("needskill"), OriginalLines.eff(str(row.get("skill", ""))), int(row.get("skill_level", 0))]
		var have := 0
		if Inventory:
			have = Inventory.count(id)
		return "%s    %s    x%d" % [name, mark, have]
	if page == "repair":
		var cur := 0.0
		var cap := 1.0
		if str(row.get("kind", "")) == "armor":
			cur = Condition.armor_hp(id)
			cap = float(Condition.armor_max(id))
		elif str(row.get("kind", "")) == "owl":
			cur = maxf(0.0, Pets.hp_of("owl"))
			cap = float(Pets.stats("owl").maxhp)
		else:
			cur = Condition.weapon_hp(id)
			cap = float(Condition.weapon_max(id))
		var back := float(row.get("rep", 0.0)) * Condition.repair_mult() * 100.0
		return "%s    %s    +%s%%" % [name, Condition.percent_text(cur, cap), snapped(back, 0.1)]
	if str(row.get("kind", "")) == "armor":
		return "%s    %s %d" % [name, OriginalLines.pip("level"), int(row.get("lvl", 0))]
	return "%s    %s" % [name, Locale.t("craft_unique")]


func _detail_text(row: Dictionary, page: String) -> String:
	if page == "repair":
		var part := "frag" if str(row.get("kind", "")) == "weapon" else str(row.get("component", ""))
		return "%s  %d" % [_name(part), Inventory.count(part) if Inventory else 0]
	if page == "upgrade" and str(row.get("kind", "")) == "armor":
		var part := str(row.get("component", ""))
		return "%s  %d / %d" % [_name(part), Inventory.count(part) if Inventory else 0, int(row.get("kol", 0))]
	var recipe := row
	if page == "upgrade":
		recipe = _recipe_by_id("s_" + str(row.get("id", "")))
	var ingredients: Dictionary = recipe.get("ingredients", {})
	var lines: PackedStringArray = []
	for key in ingredients.keys():
		var need := int(ingredients[key])
		var have := Inventory.count(str(key)) if Inventory else 0
		var line := "%s  %d / %d" % [_name(str(key)), have, need]
		if Stash.vault_count(str(key)) > 0:
			line += " (+%d %s)" % [Stash.vault_count(str(key)), OriginalLines.pip("invault")]
		lines.append(line)
	return "\n".join(lines)


func _have_parts(recipe: Dictionary) -> bool:
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for key in ingredients.keys():
		if Inventory == null or Stash.total(str(key)) < int(ingredients[key]):
			return false
	return true


func _empty_text(page: String) -> String:
	if page == "repair":
		return OriginalLines.pip("emptyrep")
	if page == "upgrade":
		return OriginalLines.pip("emptyupgrade")
	return OriginalLines.pip("emptycreate")


func _pages() -> Array:
	var pages: Array = (_stations.get(_station, {}) as Dictionary).get("pages", ["craft"])
	if pages.is_empty():
		return ["craft"]
	return pages


func _fill_tabs(pages: Array) -> void:
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	var made: Array = []
	for i in pages.size():
		var button := Button.new()
		button.text = OriginalLines.pip(str(PAGE_TITLES.get(str(pages[i]), pages[i])))
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		if i == _page:
			button.modulate = Color(1, 1, 0.7)
		button.pressed.connect(_set_page.bind(i))
		_tabs.add_child(button)
		made.append(button)
	for i in made.size():
		var b := made[i] as Control
		b.focus_neighbor_left = b.get_path_to(made[maxi(0, i - 1)])
		b.focus_neighbor_right = b.get_path_to(made[mini(made.size() - 1, i + 1)])
		b.focus_neighbor_top = b.get_path()


func _set_page(i: int) -> void:
	_page = i
	_index = 0
	_refresh()


func _recipe_by_id(id: String) -> Dictionary:
	for recipe_v in _recipes:
		var recipe: Dictionary = recipe_v
		if str(recipe.get("id", "")) == id:
			return recipe
	return {}


func _name(id: String) -> String:
	if Inventory:
		return Inventory.name_of(id)
	return id


func _say(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notice"):
		hud.show_notice(text)


func _station_name(station_id: String) -> String:
	var station: Dictionary = _stations.get(station_id, {})
	return OriginalLines.name_of(str(station.get("object", station_id)))


func _station_of(node: Node) -> String:
	var raw := str(node.get_meta("station", ""))
	if raw == "himlab":
		return "lab"
	if raw == "":
		var obj := str(node.get_meta("id", node.name))
		if obj == "himlab":
			return "lab"
		if obj in ["work", "stove"]:
			return obj
	return raw


func _nearest() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return null
	var best: Node2D = null
	var best_d := REACH
	for node in get_tree().get_nodes_in_group("craft_stations"):
		if not node is Node2D:
			continue
		var body := node as Node2D
		var gap := player.global_position.distance_to(body.global_position)
		if gap < best_d:
			best = body
			best_d = gap
	return best


func _debug_spawn(station_id: String) -> void:
	var host := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if host == null or player == null:
		return
	var at := player.global_position + Vector2(48, -8)
	if station_id == "lab":
		at += Vector2(36, 0)
	elif station_id == "stove":
		at += Vector2(72, 0)
	_place(station_id, at)
	_say(_station_name(station_id))


func _place(station_id: String, at: Vector2) -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var object_id := station_id
	if station_id == "lab":
		object_id = "himlab"
	var node := Node2D.new()
	node.name = object_id
	node.set_meta("station", station_id)
	node.set_meta("id", object_id)
	node.add_to_group("craft_stations")
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-30, -18), Vector2(30, -18), Vector2(30, 10), Vector2(-30, 10)
	])
	if station_id == "lab":
		poly.color = Color(0.25, 0.55, 0.35)
	elif station_id == "stove":
		poly.color = Color(0.55, 0.32, 0.18)
	else:
		poly.color = Color(0.45, 0.32, 0.18)
	node.add_child(poly)
	host.add_child(node)
	node.global_position = at


func _find_pip(node: Node) -> Node:
	if node.get("_inv_ids") != null and node is CanvasItem and (node as CanvasItem).visible:
		var ids: Variant = node.get("_inv_ids")
		if ids is Array and not (ids as Array).is_empty():
			return node
	for child in node.get_children():
		var found := _find_pip(child)
		if found:
			return found
	return null


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "CraftLayer"
	_layer.layer = 40
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.visible = false
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	if ResourceLoader.exists("res://theme/wasteland.tres"):
		root.theme = load("res://theme/wasteland.tres")
	_layer.add_child(root)
	_root = root
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.04, 0.025, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 48
	box.offset_top = 36
	box.offset_right = -48
	box.offset_bottom = -36
	root.add_child(box)
	_title = Label.new()
	_title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.36))
	_title.add_theme_font_size_override("font_size", 28)
	box.add_child(_title)
	_tabs = HBoxContainer.new()
	box.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
	box.add_child(_detail)
	_hint = Label.new()
	_hint.text = _hint_text()
	_hint.add_theme_color_override("font_color", Color(0.62, 0.48, 0.24))
	box.add_child(_hint)


func _load_data() -> void:
	if not FileAccess.file_exists(DATA):
		push_error("Craft missing craft_condition.json")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Craft could not parse craft_condition.json")
		return
	var doc: Dictionary = parsed
	_stations = doc.get("stations", {})
	_recipes = doc.get("recipes", [])


# --- PipBuck page 7 (PipPageWork) ---

func work_pages(station: String) -> Array:
	var pages: Array = (_stations.get(station, {}) as Dictionary).get("pages", ["craft"])
	return pages if not pages.is_empty() else ["craft"]


func work_rows(station: String, page: String) -> Array:
	_station = station
	return _page_rows(page)


func work_text(row: Dictionary, page: String) -> String:
	return _row_text(row, page)


func work_detail(row: Dictionary, page: String) -> String:
	return _detail_text(row, page)


func work_empty(page: String) -> String:
	return _empty_text(page)


func work_title(station: String) -> String:
	return _station_name(station)


func work_activate(station: String, page: String, row: Dictionary) -> void:
	_station = station
	if Travel.no_act():
		_say(OriginalLines.info("noAct"))
		return
	match page:
		"craft":
			_craft(row)
		"repair":
			_repair(row)
		"upgrade":
			_upgrade(row)


func counts() -> Dictionary:
	var benches := {"work": 0, "expl": 0, "lab": 0, "stove": 0}
	var potions := 0
	for recipe_v in _recipes:
		var recipe: Dictionary = recipe_v
		var bench := str(recipe.get("bench", ""))
		if benches.has(bench):
			benches[bench] = int(benches[bench]) + 1
		if str(recipe.get("result", "")).begins_with("potion_"):
			potions += 1
	benches["potions"] = potions
	benches["total"] = _recipes.size()
	return benches
