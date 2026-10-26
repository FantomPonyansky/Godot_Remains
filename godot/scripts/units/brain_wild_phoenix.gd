extends UnitBrain

## UnitPhoenix: a wild balefire phoenix sitting on a box. Any hit, a fall or
## a push scares it off. "Tame" feeds it a radcookie; the fifth one runs the
## tamePhoenix script, whose "tame" command hands the bird over as the pet.

const FEEDS := 5

static var quest_ok := false

var t_fall := 0
var _gone := false


func configure() -> void:
	is_fly = false
	u.set("_flying", false)


func ready() -> void:
	u.remove_from_group("allies")
	u.set_meta("doop", true)
	var host := u.get_tree().get_first_node_in_group("land_props")
	if host != null and host.has_method("_add_use"):
		host.call("_add_use", u, "tame")
	# inter.t_action = 30: the feed is a one-second hold.
	u.set_meta("hold_use", true)
	u.set_meta("act_time", 30)
	# setNull: a bird already tamed does not come back.
	if int(_trigger("tame")) >= FEEDS:
		_scare()


func use_object(from_timer: bool) -> void:
	if _gone:
		return
	if not from_timer:
		var hold := player_node()
		if hold != null and hold.has_method("begin_use_timer"):
			hold.begin_use_timer(u)
		return
	if not quest_ok:
		Story.add_quest("tamePhoenix")
	var p := player_node()
	if p != null:
		storona = -1.0 if u.global_position.x > p.global_position.x else 1.0
	if Inventory.count("radcookie") > 0:
		Story.inc_quests("tame_ph")
		Inventory.spend("radcookie", 1)
		Travel.set_trigger("tame", int(_trigger("tame")) + 1)
		if int(_trigger("tame")) >= FEEDS and int(_trigger("pet_phoenix")) == 0:
			Travel.set_trigger("pet_phoenix", 1)
			ScriptsEngine.run_script("tamePhoenix", u)
		else:
			_scare()
			_mess("phoenixFeed2")
	else:
		_mess("phoenixFeed1")
	Travel.set_trigger("frag_" + id, 0)


func command(com: String, _val: String = "") -> void:
	if com != "tame":
		return
	var at := u.global_position
	_scare()
	Pets.call_pet("phoenix")
	if Pets.pet_alive():
		Pets.pet.global_position = at
		var b: Variant = Pets.pet.get("_brain")
		if b != null:
			b.detection = 0


func on_damage(_amount: float, _type: String, _bullet: Node, _tt: bool) -> float:
	_scare()
	return 0.0


func control() -> void:
	if _gone:
		return
	# The body settles onto its box over the first ticks after the spawn.
	if not stay and ticks > 5:
		t_fall += 1
	if t_fall >= 3 or absf(vel.x) > 1.0:
		_scare()
		return
	if not quest_ok and _under_cursor():
		Travel.set_trigger("frag_" + id, 0)
		Story.add_quest("tamePhoenix")
		quest_ok = true


func animate() -> void:
	anim("stay")


func expl() -> void:
	new_part("green_spark", 25)


## UnitPhoenix.die: sparks, gone, its die script runs.
func _scare() -> void:
	if _gone:
		return
	_gone = true
	expl()
	u.set_meta("usable", false)
	var host := u.get_tree().get_first_node_in_group("land_props")
	var acts: Variant = u.get("die_actions")
	if host != null and host.has_method("run_actions") and acts is Array and not (acts as Array).is_empty():
		host.run_actions(acts)
	Travel.set_trigger("frag_" + id, 0)
	u.queue_free()


func _under_cursor() -> bool:
	var p := player_node()
	if p == null:
		return false
	var at := p.get_global_mouse_position()
	var r := Rect2(u.global_position - Vector2(body().x * 0.5, body().y), body())
	return r.has_point(at)


func _trigger(key: String) -> Variant:
	var v: Variant = Travel.trigger(key)
	return 0 if v == null else v


func _mess(key: String) -> void:
	var hud := u.get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_message"):
		hud.show_message(OriginalLines.text("txt", key), u.global_position.y - room_origin().y < 300.0)
