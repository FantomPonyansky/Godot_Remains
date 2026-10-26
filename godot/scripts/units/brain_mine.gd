extends UnitBrain

## Mine: armed (state 1) it scans a box sens wide and from sens above to sens * 0.4
## below every 4 ticks; a target inside starts the fuse (state 2), and it blows up
## after explTime ticks. It stays faint until the player spots it, and the player
## can disarm it with Explosives (a fumble sets it off, success picks it up).

var sens := 100.0
var expl_time := 15
var expl_radius := 0.0
var knock := 0.0
var wdestroy := 0.0
var damage1 := 0.0
var visibility := 300.0
var chain := false
var ai_n := randi() % 5
var seen := false
## Mine.otschet: in-range scans a light-stepping player (activateTrap 1) gets for free.
var otschet := 10


func configure() -> void:
	var m: Dictionary = row.get("mine", {})
	sens = float(m.get("sens", 100))
	expl_time = int(m.get("time", 15))
	expl_radius = float(m.get("expl", 0.0))
	knock = float(m.get("knock", 5.0))
	wdestroy = float(m.get("destroy", 10.0))
	damage1 = dam * (randf() * 0.3 + 0.85)
	ai_state = 1
	acts_held = true
	flips_sprite = false
	u.set("_trup", false)
	u.set("points", 0)
	u.set("fraction", 2)
	u.set("_can_lift", true)
	u.set("_detect_delay", float(u.get("_detect_delay")) * 0.5)
	var mtr := int(m.get("lvl", 1))
	var ndif := mini(5, int(u.get_meta("ndif", 2)))
	var lvl := mini(int(round(1.0 + randf() * float(ndif + 1))), 5)
	if mtr >= 5 or id == "zebmine" or id == "balemine":
		lvl = randi_range(5, 7)
		if id == "zebmine":
			chain = true
			visibility = 180.0
	u.set_meta("mine", lvl)
	u.set_meta("mine_tip", 3)


func ready() -> void:
	var res: Node = u.get_node_or_null("Resistances")
	if res != null:
		var mult: Dictionary = res.get("multipliers")
		mult["DAM_EMP"] = 1.0
		mult["DAM_VENOM"] = 0.0
		res.set("multipliers", mult)
	_set_vis(false)
	anim("armed")
	var lp := u.get_tree().get_first_node_in_group("land_props")
	if lp != null and lp.has_method("_add_use"):
		lp.call("_add_use", u, "remine")


func _set_vis(v: bool) -> void:
	seen = v
	u.anim.modulate.a = 1.0 if v else 0.1


## Interact.successRemine / fiascoRemine after LockUse rolled the disarm.
func lock_result(result: Dictionary) -> bool:
	if int(result.get("blast", 0)) > 0:
		activate()
		return false
	if int(u.get_meta("mine", 0)) <= 0:
		remine()
	return false


func remine() -> void:
	u.set_meta("usable", false)
	u.remove_from_group("tk_use")
	var host := u.get_tree().current_scene
	if host != null:
		u.call("_spawn_drop", host, id, 1, u.global_position + Vector2(0.0, -6.0))
	sound(str(row.get("snd", {}).get("dem", "")))
	u.queue_free()


## UnitPlayer.bindChain: fetter for 10 s, anchored at the mine.
func _bind_chain() -> void:
	Effects.add(null, "fetter", 10 * int(TPS), 1.0, 0.0, false)
	Effects.set("_fet", u.global_position)


func activate() -> void:
	u.set_meta("mine", 0)
	u.set_meta("usable", false)
	ai_state = 2
	_set_vis(true)


func drop_loot() -> void:
	explode(damage1, tip, expl_radius)


func command(com: String, _val: String = "") -> void:
	if com == "activate":
		activate()


func control() -> void:
	ai_n += 1
	var p := player_node()
	if p != null and p.get("_use_node") == u:
		return
	if ai_state == 1 and float(u.get("_detect_delay")) <= 0.0 and sens > 0.0:
		var trap := GameState.activate_trap()
		if ai_n % 4 == 0 and p != null and not bool(u.get("_friendly")) and trap > 0.0:
			var d: Vector2 = u.call("_feet", p) - u.global_position
			var emp_ok := tip != "DAM_EMP" or bool(p.get_meta("mech", false))
			if d.x < sens and d.x > -sens and d.y < sens * 0.4 and d.y > -sens and emp_ok:
				if otschet > 0 and trap == 1.0:
					otschet -= 1
				else:
					if chain:
						_bind_chain()
					activate()
		# Held by telekinesis, every 10 ticks a 10% chance to arm the fuse.
		if ai_state == 1 and bool(u.get("levitated")) and ai_n % 10 == 1 and randf() < 0.1:
			activate()
	elif ai_state == 2:
		if expl_time % 5 == 3:
			sound(str(row.get("snd", {}).get("sens", "")))
		expl_time -= 1
	if expl_time <= 0:
		u.call("_begin_death")
		return
	if ai_n % 10 == 0 and not seen and p != null:
		if u.global_position.distance_squared_to(u.call("_feet", p)) < visibility * visibility:
			_set_vis(true)


func animate() -> void:
	if ai_state == 2:
		anim_frame("f3" if (expl_time / 2) % 2 == 0 else "armed", 0)
