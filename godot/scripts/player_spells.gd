extends RefCounted

## Spellbook, casts, crystal and blood, portal and telekinesis.
## p is the player body. Tick order stays in player.gd; these names forward.

const _Body := preload("res://scripts/player.gd")

var p: _Body

func _init(host: _Body) -> void:
	p = host

var _spell_cd: int = 0

var _cast_glow: float = 0.0

var _spellbook: Dictionary = {}

var _spell_culd: Dictionary = {}

var _crystal_tried: bool = false

## t_levitfilter: levitFilter1 alpha t/20 and blur t/4 + 2.
var _t_levitfilter := -1.0

var _levit_aura: Node2D

## Obj.levit / teleHolder / fracLevit. A foe's Telekinesis sets them; levit is
## then the struggle counter. Unheld, levit is 1 while self-levitating.
var levit: int = 0

var tele_holder: Node = null

var frac_levit: int = 0

## Unit.damWall / t_throw: a telekinetic throw arms a wall hit for t_throw ticks.
var dam_wall: float = 0.0

var t_throw: int = 0

var _held_at := Vector2.INF

var _slow_left: int = 0

var _slow_tick: int = 0

var _slow_radius: float = 200.0

var _crystal_on: bool = false

var _crystal_grace: int = 0

var _shit_hp: float = 0.0

var _blood_left: int = 0

var _moon: Node2D

var _crystal_ring: Sprite2D

var _shit_ring: Sprite2D

var _inh_ring: Sprite2D

var _blood_auras: Array = []

var _heavy_id: int = 0

var _hide_id: int = 0

var _tele_obj: Node2D = null

var _tele_vel := Vector2.ZERO

var _tk_was_down := false

var _t_port: int = 0

var _port_cel: Sprite2D

## keyAttack during the charge clears keyTele and keyAttack until each key comes up again.
var _port_cut := false

var _port_shot_cut := false

## UnitPlayer.animate t_levitfilter and setFilters. Lifted by a foe (levit,
## fracLevit != fraction): its levitFilter2 in its colour. Own levitation or a
## double jump in progress (dJump): levitFilter1 in teleColor, fading in by 2
## a tick while levitating, 10 while the air jump pushes, out by 1 after.
func _tick_levit_glow(_delta: float) -> void:
	var ticks := Sim.frame_steps
	var holder: Variant = p.get_meta("levit_by") if p.has_meta("levit_by") else null
	var lifted := p._move._levitating or holder is Color
	if lifted and _t_levitfilter <= 20.0:
		_t_levitfilter += 2.0 * ticks
	if p._move._djump2 and _t_levitfilter <= 20.0:
		_t_levitfilter += 10.0 * ticks
	if not lifted and not p._move._djump2 and _t_levitfilter >= 0.0:
		_t_levitfilter -= ticks
	var t := minf(_t_levitfilter, 20.0)
	var show := t > 0.0 and (holder is Color or p._move._levitating or p._move._djump)
	if not show:
		if _levit_aura != null and is_instance_valid(_levit_aura):
			_levit_aura.set("alpha", 0.0)
		return
	if _levit_aura == null or not is_instance_valid(_levit_aura):
		_levit_aura = p._Aura.attach(p.puppet)
		# The tail sits at z -1; the glow goes behind it.
		_levit_aura.z_index = -2
	if holder is Color:
		_levit_aura.set("color", holder)
		_levit_aura.set("alpha", 1.0)
		_levit_aura.set("strength", 1.0)
		_levit_aura.set("sigma", 2.96)
	else:
		_levit_aura.set("color", null)
		_levit_aura.set("alpha", t / 20.0)
		_levit_aura.set("strength", 2.0)
		# Flash blur b at quality 3 is a gaussian of sigma ~0.493 b; the kernel holds 2.96.
		_levit_aura.set("sigma", minf(0.493 * (t / 4.0 + 2.0), 2.96))

## True while a foe holds the player. UnitPlayer jump with levit > 1 only does levit--;
## Telekinesis.hold lets go once it reaches 1. A holder that died, left the tree or
## stopped ticking (its room went idle) lets go here.
func _tick_held(jump_just: bool) -> bool:
	if tele_holder != null:
		var gone := not is_instance_valid(tele_holder) or not tele_holder.is_inside_tree() or bool(tele_holder.get("_dead"))
		if gone or Engine.get_physics_frames() - int(p.get_meta("tele_frame", 0)) > 10:
			levit = 0
			tele_holder = null
			if p.has_meta("levit_by"):
				p.remove_meta("levit_by")
	if tele_holder == null:
		levit = 1 if p._move._levitating else 0
		_held_at = Vector2.INF
		return false
	# Unit.setNull and teleport zero levit; the holder lets go on its next hold.
	if _held_at != Vector2.INF and p.global_position.distance_squared_to(_held_at) > 200.0 * 200.0:
		levit = 0
	_held_at = p.global_position
	if levit <= 0:
		return false
	if jump_just and levit > 1:
		levit -= 1
	return true

## Unit.damageWall during t_throw: a wall met faster than damWallSpeed (12 px a tick)
## deals |v| / damWallSpeed * damWall blunt damage and ends t_throw.
func _tick_throw_wall(_delta: float, pre_v: Vector2) -> void:
	if t_throw <= 0:
		return
	t_throw = maxi(0, t_throw - Sim.frame_steps)
	if dam_wall <= 0.0:
		return
	var v := pre_v / 30.0
	for i in p.get_slide_collision_count():
		var hit := p.get_slide_collision(i)
		var other := hit.get_collider() as Node
		if other == null or other.is_in_group("enemies"):
			continue
		var n := hit.get_normal()
		var into := -v.x * signf(n.x) if absf(n.x) > 0.7 else -v.y * signf(n.y)
		if into <= 12.0:
			continue
		t_throw = 0
		var dam := v.length() / 12.0 * dam_wall
		WorldOps.damage(p, HitInfo.make(int(round(dam)), "DAM_BLUNT"))
		var half := (p.CROUCH_SIZE if p._sit else p.BODY_SIZE) * 0.5
		var at := p.global_position + Vector2(-n.x * half.x, -half.y - n.y * half.y)
		Fx.particles("bum", at, {"source": p})
		Fx.sound("hit_flesh", at, {"source": p})
		return

func _action_taken_by_spell(action: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and _key_taken_by_spell((event as InputEventKey).physical_keycode):
			return true
	return false

func _key_taken_by_spell(code: int) -> bool:
	return MagicBinds != null and MagicBinds.key_taken(code)

func _load_spellbook() -> void:
	_spellbook.clear()
	for entry_v in p._weapons:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		if str(entry.get("kind", "")) == "spell":
			_spellbook[str(entry.get("id", ""))] = entry
	if not FileAccess.file_exists("res://assets/data/spells.json"):
		return
	var parsed: Variant = DataLib.load("res://assets/data/spells.json")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for entry_v in (parsed as Dictionary).get("spells", []):
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var id := str(entry.get("id", ""))
		if id == "" or _spellbook.has(id):
			continue
		_spellbook[id] = entry

func _cast_quick(id: String, dir: Vector2) -> void:
	var spell: Dictionary = _spellbook.get(id, {})
	if spell.is_empty() or not p._Flags.allows("weapons"):
		return
	# Quick cells hold only spells the player carries (equipment.getSpell).
	if Inventory == null or Inventory.count(id) <= 0:
		return
	# Crystal shield is held. The key edge only starts the hold path, which pays once.
	if id == "sp_cryst" or str(spell.get("effect", "")) == "crystal":
		return
	if not _spell_ready(spell):
		_spell_cd = p._hold_ticks(0.25)
		return
	var handled := _cast_spell(spell, dir)
	if handled <= 0:
		_spell_cd = p._hold_ticks(0.25)
		return
	_pay_cast(spell)
	_play_spell_sound(spell)

func _spell_blast(w: Dictionary) -> void:
	var rad := float(w.get("radius", 500.0))
	var power := 1.0
	if Progression:
		power = 1.0 + 0.1 * float(Progression.rank("tele"))
	var dam := float(w.get("damage", 20.0)) * power
	for enemy in p.get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		var body := enemy as Node2D
		var away := body.global_position - p.global_position
		var dist := away.length()
		if dist > rad or dist < 1.0:
			continue
		var sila := dam * (1.0 - dist / rad) * (Rng.randf(&"combat") * 0.4 + 0.8)
		sila = minf(sila, dam)
		if "velocity" in body:
			body.velocity = away.normalized() * sila * 30.0
		# Spell.cast_blast: stun += random * telePower * dam, in ticks.
		if body.has_method("apply_stun"):
			body.apply_stun(int(Rng.randf(&"combat") * power * float(w.get("damage", 20.0))))
	Fx.particles("blast", p.global_position, {"source": p})

func _spell_dash(w: Dictionary) -> void:
	# Spell.cast_kdash does nothing under @levitoff.
	if not p._Flags.allows("levit"):
		return
	var tele := 1.0
	if Progression:
		tele = 1.0 + 0.1 * float(Progression.rank("tele"))
	var spd := float(w.get("damage", 20.0)) * (1.0 + (tele - 1.0) * 0.5)
	# Spell.cast_kdash aims from the top of the box and pushes by at most spd.
	# kdash_t (prod) holds off gravity and braking, then velocity *= 0.3.
	var height := p.CROUCH_SIZE.y if p._sit else p.BODY_SIZE.y
	var v := p._cursor_world() - (p.global_position - Vector2(0.0, height))
	var rasst := v.length()
	if rasst < 0.001:
		v = Vector2(p.facing, 0.0)
	var prod := 15
	if spd > rasst / 15.0:
		prod = int(round(rasst / maxf(spd, 0.001))) + 1
	prod = maxi(prod, 7)
	p._climbing = false
	p._move._levitating = false
	p.velocity += v.limit_length(spd) * 30.0
	p._move._kdash_left = p._hold_ticks(float(prod) / 30.0)

func _tick_slow(delta: float) -> void:
	if _slow_left <= 0.0:
		if _inh_ring:
			_inh_ring.visible = false
		return
	_slow_left = p._spend(_slow_left)
	if _slow_left <= 0 and _inh_ring:
		_inh_ring.visible = false
	_slow_tick = p._spend(_slow_tick)
	if _slow_tick > 0:
		return
	_slow_tick = p._hold_ticks(1.0)
	for enemy in p.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if p.global_position.distance_to(enemy.global_position) > _slow_radius:
			continue
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(40.0 / 30.0)

func _start_slow(entry: Dictionary) -> void:
	var power := 1.0 + 0.1 * float(Progression.rank("magic"))
	_slow_radius = float(entry.get("radius", 200)) * power
	_slow_left = p._hold_ticks(60.0)
	_slow_tick = 0
	if _inh_ring:
		_inh_ring.call("play_from", 1)

func _spell_cooldown(entry: Dictionary) -> float:
	# t_culd = round(culd * 30 * spellDown) ticks. spellDown drops 0.1 per Magic level.
	return roundf(_spell_culd_base(entry) * 30.0 * Progression.spell_down()) / 30.0

func _update_telekinesis(held: bool, cursor: Vector2, delta: float) -> void:
	# actTele: each keyTele press toggles. It drops what is held, or grabs
	# when the magic bar has at least 200. Telekinesis.hold then steers the body
	# toward the cursor until a drop rule fires.
	var pressed := held and not _tk_was_down
	_tk_was_down = held
	_tick_port(held, cursor, delta)
	if _tele_obj != null and not is_instance_valid(_tele_obj):
		_tele_obj = null
	# Telekinesis.hold: another caster's grab replaced teleHolder; drop the reference only.
	if _tele_obj != null and _tele_obj.get_meta("tele_holder", p) != p:
		_tele_obj = null
		_tele_vel = Vector2.ZERO
	if pressed:
		if _tele_obj != null:
			_drop_tele()
		else:
			_try_grab(cursor)
	if _tele_obj != null and not _tele_keeps():
		_drop_tele()
	_tick_magic_channel()
	if _tele_obj == null:
		return
	_steer_tele(cursor, delta)

## spell_port (Pers.portPoss): keyTele held for portTime ticks counts t_port; letting go
## then runs actPort. The GUI portCel shows past 15 ticks.
func _tick_port(held: bool, cursor: Vector2, _delta: float) -> void:
	var can := Progression.pers("portPoss", 0.0) > 0.0 and GameState.spells_allowed() and not (ScriptsEngine != null and ScriptsEngine.alicorn)
	if _port_cut:
		_port_cut = held
		held = false
	elif held and LocalInput.just_pressed(&"shoot", p.pid):
		_port_cut = true
		_port_shot_cut = true
		_t_port = 0
		held = false
	if held and not LocalInput.held(&"interact", p.pid) and not Travel.can_travel_here():
		if can and not _spell_culd.has("port"):
			_t_port += Sim.frame_steps
	else:
		if _t_port >= p.PORT_TIME and can and p._Flags.allows("port"):
			_act_port(cursor)
		_t_port = 0
	_show_port_cel(cursor)

func _port_feet(cursor: Vector2) -> Vector2:
	return Vector2(roundf(cursor.x / 40.0) * 40.0, roundf(cursor.y / 40.0 + 1.0) * 40.0 - 1.0)

## checkPort: magic over portMana, a tile the player can see, and room to stand there.
func _check_port(cursor: Vector2) -> bool:
	if GameState.magic < p.PORT_MANA * GameState.mana_cost_mult():
		return false
	if p.sky_mode:
		return true
	var feet := _port_feet(cursor)
	# t.visibility >= 0.8: lit now or remembered, no line of sight needed.
	var fog := p.get_tree().get_first_node_in_group("fog")
	if fog != null and fog.get("_state") != null:
		if float(fog.call("tile_seen", cursor)) < 0.8:
			return false
	else:
		var eye := p.global_position + Vector2(0.0, -p.BODY_SIZE.y * 0.75)
		if not Sight.los_clear(eye, Vector2(roundf(cursor.x / 40.0) * 40.0, roundf(cursor.y / 40.0) * 40.0)):
			return false
	var space := p.get_world_2d().direct_space_state
	var rect := RectangleShape2D.new()
	rect.size = p.BODY_SIZE - Vector2(2.0, 2.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = rect
	query.transform = Transform2D(0.0, feet - Vector2(0.0, p.BODY_SIZE.y * 0.5))
	query.collision_mask = 1
	query.exclude = [p.get_rid()]
	for found in space.intersect_shape(query, 4):
		var node := found.collider as Node
		if node != null and node != p and not _is_one_way(node):
			return false
	return true

## actPort: Unit.teleport(eff 1), then manaSpell(portMagic, portMana) and t_culd = spellDown * portDown.
func _act_port(cursor: Vector2) -> void:
	var mult := GameState.mana_cost_mult()
	if GameState.magic < p.PORT_MANA * mult and GameState.magic < float(GameState.MAX_MAGIC) * 0.99:
		p._notice(OriginalLines.info("overMana"))
		return
	if not _check_port(cursor):
		return
	Fx.particles("tele", p.global_position - Vector2(0.0, p.BODY_SIZE.y * 0.5), {"rx": p.BODY_SIZE.x, "ry": p.BODY_SIZE.y, "kol": 30, "source": p})
	# Unit.teleport: setPos keeps dx / dy; only levit is cleared.
	p.global_position = _port_feet(cursor)
	p._move._levitating = false
	Fx.particles("teleport", p.global_position - Vector2(0.0, p.BODY_SIZE.y * 0.5), {"source": p})
	Fx.sound("teleport", p.global_position, {"source": p})
	_fog_relight()
	GameState.pay_spell(p.PORT_MAGIC * mult, p.PORT_MANA * mult)
	if _tele_obj != null:
		_drop_tele()
	# loc.electroDam: blinking into a live room shocks and sets the player alight.
	var land := p._Flags.active_land()
	var actors := land.get_node_or_null("Actors") if land != null else null
	var electro := float(actors.call("room_electro", p._Flags.cell_of(p.global_position))) if actors != null and actors.has_method("room_electro") else 0.0
	if electro > 0.0:
		GameState.apply_damage_f(electro, "DAM_ELECTRIC", true)
		Fx.sound("electro", p.global_position, {"source": p})
		Effects.add(p, "burning", 40)
		Fx.particles("iskr", p.global_position + Vector2(0, -39), {"kol": 40, "source": p})
	_spell_culd["port"] = p._hold_ticks(Progression.spell_down() * p.PORT_DOWN / 30.0)

## alicornPort: no cooldown and no manaHP, alicornPortMana off the magic bar.
func _alicorn_port(cursor: Vector2) -> void:
	var cost := Progression.pers("alicornPortMana", 500.0)
	if GameState.magic < cost and GameState.magic < float(GameState.MAX_MAGIC) * 0.99:
		p._notice(OriginalLines.info("overMana"))
		return
	if not _check_port(cursor):
		return
	Fx.particles("tele", p.global_position - Vector2(0.0, p.BODY_SIZE.y * 0.5), {"rx": p.BODY_SIZE.x, "ry": p.BODY_SIZE.y, "kol": 30, "source": p})
	p.global_position = _port_feet(cursor)
	p._move._levitating = false
	Fx.particles("teleport", p.global_position - Vector2(0.0, p.BODY_SIZE.y * 0.5), {"source": p})
	Fx.sound("teleport", p.global_position, {"source": p})
	_fog_relight()
	if _tele_obj != null:
		_drop_tele()
	GameState.pay_spell(cost, 0.0)

func _fog_relight() -> void:
	var fog := p.get_tree().get_first_node_in_group("fog")
	if fog != null:
		fog.call("relight_after_jump")

func _show_port_cel(cursor: Vector2) -> void:
	if _t_port <= 15.0:
		if _port_cel != null:
			_port_cel.visible = false
		return
	if _port_cel == null:
		_port_cel = Sprite2D.new()
		_port_cel.top_level = true
		_port_cel.z_index = 50
		_port_cel.centered = true
		p.add_child(_port_cel)
	var frame := 3
	if _check_port(cursor):
		frame = 1 if _t_port < p.PORT_TIME else 2
	_port_cel.texture = load(p._PORT_CEL % frame) as Texture2D
	_port_cel.global_position = Vector2(roundf(cursor.x / 40.0) * 40.0, roundf(cursor.y / 40.0) * 40.0)
	_port_cel.visible = true

func _try_grab(cursor: Vector2) -> void:
	_heavy_id = 0
	_hide_id = 0
	if GameState.magic < 200.0 or not p._Flags.allows("tele"):
		return
	var pick := _pick_aimed(cursor, ["levitatable", "enemies", "ground_loot", "pickups"], _tele_radius(), p.TELE_SNAP, false)
	if pick == null:
		return
	if _tele_needs_los() and not _los_to(pick):
		_show_hidden(pick)
		return
	if not _levit_poss(pick):
		return
	if _tele_massa(pick) > _max_tele_massa():
		_show_too_heavy(pick)
		return
	_grab_tele(pick)
	if pick.is_in_group("enemies"):
		pick.set_meta("levit_r", _levit_r(pick))

## UnitPlayer drop rules: past teleDist * 1.2, magic bar at 0, a unit held past
## levit_max * unitLevitMult breaks free (levitPoss off until levit_r decays).
func _tele_keeps() -> bool:
	var reach := _tele_radius()
	if p.global_position.distance_squared_to(_body_center(_tele_obj)) > reach * reach * 1.2:
		return false
	if GameState.magic <= 0.0:
		return false
	if _tele_obj.is_in_group("enemies"):
		if bool(_tele_obj.get("_dead")):
			return _tele_obj.is_in_group("levitatable")
		var r := float(_tele_obj.get_meta("levit_r", 0.0)) + p.get_physics_process_delta_time() * 30.0
		_tele_obj.set_meta("levit_r", r)
		var cap := float(p._UnitMassa.row(_tele_obj).get("levit_max", 0))
		if cap > 0.0 and r > cap * Progression.unit_levit_mult():
			_tele_obj.set_meta("levit_broke", true)
			return false
	return true

## Unit.levit_r: counts up while lifted, down (from at most 60) while free.
## levitPoss comes back once it is down to 1.
func _levit_r(body: Node) -> float:
	var r := minf(float(body.get_meta("levit_r", 0.0)), 60.0)
	# Sim.tick still moves while paused, so a broken grab keeps decaying in the PipBuck.
	var since = float(Sim.tick - int(body.get_meta("levit_r_at", 0)))
	return maxf(0.0, r - since)

func _levit_poss(body: Node) -> bool:
	if not body.is_in_group("enemies"):
		return true
	var data := p._UnitMassa.row(body)
	if not data.is_empty() and not bool(data.get("levit", true)):
		return false
	if bool(body.get_meta("levit_broke", false)):
		if _levit_r(body) > 1.0:
			return false
		body.set_meta("levit_broke", false)
	return true

## Obj.massa: units from units.xml, crates from objs.xml, loot 0.1.
func _tele_massa(body: Node) -> float:
	if body.is_in_group("enemies"):
		return p._UnitMassa.massa(body)
	return _carried_massa(body)

## Pers.maxTeleMassa (Telekinesis level table) times the trauma_mana stage mult.
func _max_tele_massa() -> float:
	return Progression.max_tele_mass() * GameState.tele_mass_mult()

## UnitPlayer.actions mana block: a held object costs sqrt(massa) * teleMult per
## tick above telePorog, self-levitation levitDMana plus levitDManaUp while rising.
func _tick_magic_channel() -> void:
	var holding := _tele_obj != null
	if not holding and not p._move._levitating:
		return
	var drain := 0.0
	if holding:
		var m := _tele_massa(_tele_obj)
		if m > Progression.tele_porog():
			drain += sqrt(m) * Progression.tele_mult()
	if p._move._levitating:
		drain += Progression.levit_dmana()
		if LocalInput.held(&"aim_up", p.pid):
			drain += Progression.levit_dmana_up()
	GameState.channel(drain, p._move._levitating)

## throwTele (keyAction while holding): throwDmagic * massa off the magic bar,
## 5% of that off manaHP, then the object gets throwForce away from the player.
## A short bar scales the force down. Without spells the hold just drops.
func _throw_tele() -> void:
	var body := _tele_obj
	if not GameState.spells_allowed():
		_drop_tele()
		return
	var force := Progression.throw_force()
	var dm := 0.0
	if force > 0.0:
		dm = _tele_massa(body) * Progression.throw_dmagic() * GameState.mana_cost_mult()
	var have := maxf(GameState.magic, 0.0)
	if dm <= have:
		GameState.drain_magic(dm)
		GameState.damage_mana(dm * 0.05)
	else:
		force *= have / dm
		GameState.damage_mana(have * 0.05)
		GameState.drain_magic(GameState.magic)
	# Settings.VANILLA_THROW trims the carry speed to teleAccel * 4 first.
	var vel := _tele_vel.limit_length(Progression.tele_accel() * 4.0)
	var away := _body_center(body) - (p.global_position + Vector2(0.0, -(p.CROUCH_SIZE.y if p._sit else p.BODY_SIZE.y) * 0.5 - 10.0))
	_tele_vel = vel + away.limit_length(force)
	if "t_throw" in body:
		body.t_throw = 2
	_drop_tele(false)
	if force > 0.0:
		Fx.sound("dash", p.global_position, {"source": p})

func _push_horn_glow() -> void:
	var w := p._weapon()
	var kind := str(w.get("kind", ""))
	var spell_weapon := kind == "magic" or bool(w.get("spell", false)) or str(w.get("delivery", "")) == "spell"
	var weapon_held := false
	if not w.is_empty() and kind != "internal" and not spell_weapon:
		if kind == "melee":
			weapon_held = true
		elif p.puppet.has_method("weapon_visible"):
			weapon_held = bool(p.puppet.weapon_visible())
	var tele := _tele_obj != null and is_instance_valid(_tele_obj)
	var heavy := tele and _carried_massa(_tele_obj) >= 1.0
	var spell := _cast_glow > 0.0 or _crystal_on or _shit_hp > 0.0 or _blood_left > 0.0 or _slow_left > 0.0
	if _moon != null and is_instance_valid(_moon):
		spell = true
	p.puppet.set_magic_activity(weapon_held, tele, spell, heavy)

func _carried_massa(body: Node) -> float:
	# Loot.massa is 0.10. A crate at or above 1 is the heavy horn glow.
	if "massa" in body:
		return float(body.massa)
	if body.has_meta("massa"):
		return float(body.get_meta("massa"))
	if body.is_in_group("ground_loot") or body.is_in_group("pickups"):
		return 0.1
	return 1.0

func _grab_tele(body: Node2D) -> void:
	_release_strays(body)
	_detach_from_player(body)
	_tele_obj = body
	_tele_vel = Vector2.ZERO
	_mark_tele(body, true)
	p._Aura.attach(body)
	# Telekinesis.grab: setChildIndex(vis, numChildren - 1).
	var layer := body.get_parent()
	if layer != null:
		layer.move_child(body, layer.get_child_count() - 1)

func _detach_from_player(body: Node2D) -> void:
	var walk: Node = body.get_parent()
	var under := false
	while walk:
		if walk == p:
			under = true
			break
		walk = walk.get_parent()
	if not under:
		return
	var host := p.get_tree().current_scene
	if host == null or host == body:
		return
	var at := body.global_position
	body.reparent(host)
	body.global_position = at

func _drop_tele(trim: bool = true) -> void:
	var body := _tele_obj
	# Telekinesis.release trims to teleAccel * 4 (Settings.VANILLA_THROW).
	var leftover := (_tele_vel.limit_length(Progression.tele_accel() * 4.0) if trim else _tele_vel) * 30.0
	_tele_obj = null
	if body != null and is_instance_valid(body) and body.is_in_group("enemies"):
		body.set_meta("levit_r_at", Sim.tick)
	_tele_vel = Vector2.ZERO
	if body == null or not is_instance_valid(body):
		return
	p._Aura.clear(body)
	body.set_meta("tele_driven", false)
	if body.has_meta("tele_holder") and body.get_meta("tele_holder") == p:
		body.remove_meta("tele_holder")
	if body.has_method("set_levitated"):
		body.set_levitated(false)
		if "velocity" in body:
			body.velocity = leftover
	elif body.has_method("release_vel"):
		body.release_vel(leftover)
	elif body.has_method("release"):
		body.release()
	elif "held" in body:
		body.held = false
	if body is CanvasItem and not body.has_method("set_levitated"):
		(body as CanvasItem).modulate = Color.WHITE

func _mark_tele(body: Node2D, on: bool) -> void:
	body.set_meta("tele_driven", on)
	if not on:
		return
	body.set_meta("tele_holder", p)
	if body.has_method("set_levitated"):
		body.set_levitated(true, _body_center(body), 0.0)
	elif body.has_method("hold_at"):
		body.hold_at(_body_center(body), 0.0, 0.0)
	elif "held" in body:
		body.held = true
	if body is CanvasItem and not body.has_method("set_levitated"):
		(body as CanvasItem).modulate = p._Aura.tele_tint()

func _release_strays(keep: Node) -> void:
	var seen := {}
	for group_name in ["levitatable", "enemies", "ground_loot", "pickups"]:
		for node in p.get_tree().get_nodes_in_group(group_name):
			if node == keep or seen.has(node) or not is_instance_valid(node):
				continue
			seen[node] = true
			if node.get("held") == true and node.has_method("release"):
				node.release()
			elif node.get("levitated") == true and node.has_method("set_levitated"):
				node.set_meta("tele_driven", false)
				node.set_levitated(false)

func _steer_tele(cursor: Vector2, _delta: float) -> void:
	# Telekinesis.hold steers the object's centre toward the cursor (celX, celY).
	# teleSpeed is 8 + 1.5 per skill level, in pixels per 30 Hz tick.
	# Approach is min(speed, the stop-in-time speed, 35% of the gap).
	# Velocity then changes by at most teleAccel. Release keeps that velocity.
	var speed := Progression.tele_speed()
	var accel := Progression.tele_accel()
	for _i in mini(Sim.frame_steps, 4):
		if not is_instance_valid(_tele_obj):
			break
		var to := cursor - _body_center(_tele_obj)
		var dist := to.length()
		var steer := -_tele_vel
		if dist > 0.0:
			var disc := sqrt(2.0 * accel * dist + accel * accel * 0.25) - accel * 0.5
			var approach := minf(speed, minf(maxf(disc, 0.0), dist * 0.35))
			steer = -_tele_vel + to / dist * approach
		if steer.length() > accel:
			steer = steer.normalized() * accel
		_tele_vel += steer
		_tele_vel = _carry_move(_tele_obj, _tele_vel)
	# A carried drop inside Loot.osnRad is granted this frame. The hold ends first.
	if is_instance_valid(_tele_obj) and _tele_obj.is_in_group("ground_loot") and _tele_obj.has_method("try_autopick"):
		_tele_obj.try_autopick()

func _tele_radius() -> float:
	if p._owns_perk("telemaster"):
		return p.TELE_RADIUS_MASTER
	return p.TELE_RADIUS

func _tele_needs_los() -> bool:
	# UnitPlayer checks perk telemaster, not a Telekinesis skill cutoff.
	# skills.xml id "tele" never clears line of sight on its own. @portoff needs it too.
	return not p._owns_perk("telemaster") or not p._Flags.allows("port")

func _tele_eye() -> Vector2:
	# isLine starts at feet.y - height * 0.75.
	var height := p.CROUCH_SIZE.y if p._move._sitting_on_ground() else p.BODY_SIZE.y
	return p.global_position + Vector2(0.0, -height * 0.75)

func _los_to(body: Node2D) -> bool:
	# Location.isLine from the eye (75% of body height) to the object's centre.
	# Full-height solids and closed doors block. The target itself does not.
	# Perk telemaster skips the test.
	if not _tele_needs_los():
		return true
	var dest := _body_center(body)
	return _line_clear(_tele_eye(), dest, body, _aim_rect(body).grow(8.0))

func tele_blocks_use(node: Node) -> bool:
	if not _tele_needs_los():
		return false
	if not node is Node2D:
		return false
	if _los_to(node as Node2D):
		return false
	p._notice(OriginalLines.info("noVisible"))
	return true

func _try_tele_use(cursor: Vector2) -> void:
	p.set_meta("tk_claim", false)
	# actAction: the object under the cursor (onCursor), within actionDist (200px).
	# Levitatable covers a box you can already grab, even if it is not tagged tk_use.
	var target := _pick_aimed(cursor, ["tk_use", "levitatable", "pickups", "ground_loot"], p.ACTION_REACH, 0.0, true)
	if target == null:
		return
	p.set_meta("tk_claim", true)
	if tele_blocks_use(target):
		return
	for props in p.get_tree().get_nodes_in_group("land_props"):
		if props.has_method("use_prop") and bool(props.use_prop(target)):
			return
	if target.has_method("collect"):
		target.collect()
	elif target.has_method("pickup"):
		WorldOps.take_loot(target)

func _pick_aimed(cursor: Vector2, groups: Array, radius: float, snap: float, for_use: bool) -> Node2D:
	var best: Node2D = null
	var best_gap := 0.0
	var best_inside := false
	var seen := {}
	var reach2 := radius * radius
	# Body centres sit within 600 px of the origin (wide areas and doors); skip far
	# nodes before the real checks.
	var coarse2 := (radius + 600.0) * (radius + 600.0)
	for group_name in groups:
		for node in p._RoomActivity.near(p.get_tree(), group_name):
			if not node is Node2D or node == p or seen.has(node) or not is_instance_valid(node):
				continue
			seen[node] = true
			var body := node as Node2D
			if p.global_position.distance_squared_to(body.global_position) > coarse2:
				continue
			if not _aimed_ok(body, for_use):
				continue
			if p.global_position.distance_squared_to(_body_center(body)) > reach2:
				continue
			var gap := _cursor_gap(body, cursor)
			var inside := gap <= 0.0
			if not inside and (snap <= 0.0 or gap > snap):
				continue
			if best != null:
				if best_inside and not inside:
					continue
				if inside == best_inside and gap >= best_gap:
					continue
			best = body
			best_gap = gap
			best_inside = inside
	return best

func _aimed_ok(body: Node2D, for_use: bool) -> bool:
	if for_use:
		if body.is_in_group("enemies"):
			return false
		if bool(p._PS.getv(body, "spent", false)):
			return false
		if not bool(p._PS.getv(body, "usable", true)):
			return false
		return true
	if body.is_in_group("enemies") and body.get("_can_lift") == false:
		return false
	if body.has_meta("levit_poss") and not bool(body.get_meta("levit_poss")):
		return false
	return true

func _show_hidden(target: Node) -> void:
	var id := target.get_instance_id()
	if id == _hide_id:
		return
	_hide_id = id
	p._notice(OriginalLines.info("noVisible"))

func _cursor_gap(body: Node2D, cursor: Vector2) -> float:
	var rect := _aim_rect(body)
	if rect.has_point(cursor):
		return 0.0
	var dx := 0.0
	if cursor.x < rect.position.x:
		dx = rect.position.x - cursor.x
	elif cursor.x > rect.end.x:
		dx = cursor.x - rect.end.x
	var dy := 0.0
	if cursor.y < rect.position.y:
		dy = rect.position.y - cursor.y
	elif cursor.y > rect.end.y:
		dy = cursor.y - rect.end.y
	return Vector2(dx, dy).length()

func _body_center(body: Node2D) -> Vector2:
	var shaped := _shape_rect(body)
	if shaped.size != Vector2.ZERO:
		return shaped.get_center()
	return _aim_rect(body).get_center()

func _aim_rect(body: Node2D) -> Rect2:
	var rect := _shape_rect(body)
	var visual := body.get_node_or_null("Visual") as Sprite2D
	if visual and visual.visible and visual.texture:
		var art := _sprite_rect(visual)
		if rect.size == Vector2.ZERO:
			return art
		return rect.merge(art)
	if rect.size != Vector2.ZERO:
		return rect
	var size := Vector2.ZERO
	if body.has_meta("size"):
		size = body.get_meta("size")
	elif body.has_meta("box"):
		size = body.get_meta("box")
	elif body.has_meta("door_w"):
		size = Vector2(float(body.get_meta("door_w")), float(body.get_meta("door_h", 40.0)))
	if size.x < 1.0 or size.y < 1.0:
		size = Vector2(32, 32)
		return Rect2(body.global_position - size * 0.5, size)
	return Rect2(body.global_position, size)

func _shape_rect(body: Node2D) -> Rect2:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is RectangleShape2D):
		return Rect2()
	var box := shape_node.shape as RectangleShape2D
	if box.size.x < 1.0 or box.size.y < 1.0:
		return Rect2()
	var center := shape_node.global_position
	return Rect2(center - box.size * 0.5, box.size)

func _sprite_rect(sprite: Sprite2D) -> Rect2:
	var tex := sprite.texture.get_size()
	var scaled := Vector2(tex.x * absf(sprite.global_scale.x), tex.y * absf(sprite.global_scale.y))
	var origin := sprite.global_position + sprite.offset * sprite.global_scale.abs()
	if sprite.centered:
		origin -= scaled * 0.5
	return Rect2(origin, scaled)

func _carry_move(body: Node2D, vel: Vector2) -> Vector2:
	# Box.run steps by at most maxdelta and stops on collision == 1.
	# Levitating objects ignore one-way platforms. They pass through other props.
	if not is_instance_valid(body):
		return vel
	if not body is PhysicsBody2D:
		body.global_position += vel
		return vel
	var phys := body as PhysicsBody2D
	var saved := phys.collision_mask
	phys.collision_mask = 1
	vel = _push_axis(phys, vel, Vector2(vel.x, 0.0))
	if is_instance_valid(phys):
		vel = _push_axis(phys, vel, Vector2(0.0, vel.y))
	if is_instance_valid(phys):
		phys.collision_mask = saved
	return vel

func _push_axis(body: PhysicsBody2D, vel: Vector2, axis: Vector2) -> Vector2:
	var left := axis
	var ignored: Array[CollisionObject2D] = []
	var guard := 0
	while left.length() > 0.01 and guard < 8 and is_instance_valid(body):
		guard += 1
		var slice := left
		if slice.length() > p.CARRY_STEP:
			slice = slice.limit_length(p.CARRY_STEP)
		var hit := body.move_and_collide(slice, true, 0.08, false)
		if hit == null:
			body.global_position += slice
			left -= slice
			continue
		var other := hit.get_collider() as Node
		var normal := hit.get_normal()
		var blocked := other != null and _carry_wall(other) and _opposes(normal, slice)
		if not blocked:
			var block := other as CollisionObject2D
			if block != null and block not in ignored:
				body.add_collision_exception_with(block)
				ignored.append(block)
				continue
			body.global_position += slice
			left -= slice
			continue
		var travel := hit.get_travel()
		if travel.length() > 0.01:
			body.global_position += travel
		vel = _bounce_carry(vel, normal, body)
		left = Vector2.ZERO
	for other in ignored:
		if is_instance_valid(body) and is_instance_valid(other):
			body.remove_collision_exception_with(other)
	return vel

func _opposes(normal: Vector2, motion: Vector2) -> bool:
	return normal.dot(motion) < -0.01

func _bounce_carry(vel: Vector2, normal: Vector2, body: Node) -> Vector2:
	# Box.run: a slow hit stops. Faster than 10 px/tick rebounds at 0.2.
	# A floor hit also kills a small horizontal speed. A ceiling hit clears Y.
	if absf(normal.x) > absf(normal.y):
		if absf(vel.x) > 10.0:
			vel.x = -vel.x * 0.2
		else:
			vel.x = 0.0
		if normal.x * vel.x < 0.0:
			vel.x = 0.0
		return vel
	if normal.y < 0.0:
		var mass := 0.1 if body.is_in_group("ground_loot") or body.is_in_group("pickups") else 1.0
		if body.has_meta("massa"):
			mass = float(body.get_meta("massa"))
		if vel.y < 5.0 or mass > 1.0:
			vel.y = 0.0
		else:
			vel.y *= -0.2
		if absf(vel.x) < 5.0:
			vel.x = 0.0
		else:
			vel.x *= 0.92
		return vel
	vel.y = 0.0
	return vel

func _carry_wall(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group("player") or node.is_in_group("levitatable") or node.is_in_group("ground_loot") or node.is_in_group("pickups") or node.is_in_group("enemies"):
		return false
	if _is_closed_door(node):
		return true
	if _is_one_way(node):
		return false
	if node.is_in_group("tk_use"):
		return false
	var parent := node.get_parent()
	var pname := str(parent.name) if parent else ""
	if pname in ["Solids", "Slopes"]:
		return true
	if pname in ["Platforms", "Ladders"]:
		return false
	return bool(p._PS.getv(node, "blocks_sight", false))

func _sight_wall(node: Node) -> bool:
	if _is_closed_door(node):
		return true
	if not _carry_wall(node):
		return false
	return _full_height(node)

func _full_height(node: Node) -> bool:
	var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and shape.shape is RectangleShape2D:
		return (shape.shape as RectangleShape2D).size.y >= 39.0
	if node.get_node_or_null("CollisionPolygon2D") != null:
		return true
	return true

func _is_closed_door(node: Node) -> bool:
	if not node.has_meta("door_id") and not ("door_open" in node):
		return false
	if bool(p._PS.getv(node, "dead", false)) or bool(p._PS.getv(node, "door_open", false)):
		return false
	if node is CollisionObject2D and (node as CollisionObject2D).collision_layer == 0:
		return false
	var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and shape.disabled:
		return false
	return true

func _is_one_way(node: Node) -> bool:
	var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return shape != null and shape.one_way_collision

func _line_clear(from: Vector2, to: Vector2, target: Node, rect: Rect2) -> bool:
	var delta := to - from
	var dist := delta.length()
	if dist <= 1.0:
		return true
	var space := p.get_world_2d().direct_space_state
	if space == null:
		return true
	var steps := int(dist / p.CARRY_STEP) + 1
	for i in range(1, steps + 1):
		var point := from.lerp(to, float(i) / float(steps))
		if rect.has_point(point):
			return true
		if _point_wall(space, point, target):
			return false
	return true

func _point_wall(space: PhysicsDirectSpaceState2D, point: Vector2, target: Node) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	for hit in space.intersect_point(query, 8):
		var collider: Object = hit.collider
		if collider == target or not collider is Node:
			continue
		if _sight_wall(collider as Node):
			return true
	return false

## HUD liftability: the object's massa against _levitation_skill.
func _levitate_difficulty(body: Node) -> float:
	return _tele_massa(body)

func _levitation_skill() -> float:
	return _max_tele_massa()

func _show_too_heavy(target: Node) -> void:
	var id := target.get_instance_id()
	if id == _heavy_id:
		return
	_heavy_id = id
	p._notice(OriginalLines.gui("heavy"))

func _spell_power() -> float:
	# skills.xml magic: spellPower v0=1 vd=0.1
	var rank := 0.0
	if Progression:
		rank = float(Progression.rank("magic"))
	return 1.0 + 0.1 * rank

## x is the magic bar cost (items.xml magic), y the Pers.manaHP cost (mana),
## both times allDManaMult. warlock adds warlockDManaMult, which Spell.cast
## leaves out of its check but applies to the payment.
func _spell_costs(entry: Dictionary, warlock: bool) -> Vector2:
	var mult := GameState.mana_cost_mult()
	if warlock:
		mult *= Progression.warlock_mult()
	return Vector2(float(entry.get("magic", 0.0)), float(entry.get("mana", 0.0))) * mult

## Spell.cast gates before the effect runs: spellsPoss, t_culd, magic, manaHP.
func _spell_ready(entry: Dictionary) -> bool:
	if p.rat or Effects.attack_forever():
		return false
	# Spell.cast: the alicorn casts only sp_mshit.
	if ScriptsEngine.alicorn and str(entry.get("id", "")) != "sp_mshit":
		return false
	if not GameState.spells_allowed() or (str(entry.get("id", "")) in p._ATK_SPELLS and not GameState.attack_allowed()):
		p._notice(OriginalLines.info("noSpells"))
		Fx.sound("nomagic", p.global_position, {"source": p})
		return false
	var left := int(_spell_culd.get(str(entry.get("id", "")), 0))
	if left > 0:
		if _spell_culd_base(entry) * 30.0 >= 100.0:
			p._notice(OriginalLines.info("spellCuld", str(ceili(float(left) / 30.0))))
		Fx.sound("nomagic", p.global_position, {"source": p})
		return false
	var cost := _spell_costs(entry, false)
	var why := GameState.spell_block(minf(cost.x, 999.0), cost.y)
	if why != "":
		p._notice(OriginalLines.info(why))
		Fx.sound("nomagic", p.global_position, {"source": p})
		return false
	return true

## Spell.cast est == 1: manaSpell(magic, mana) drops the telekinesis hold, then
## t_culd = culd * spellDown.
func _pay_cast(entry: Dictionary) -> void:
	var cost := _spell_costs(entry, true)
	GameState.pay_spell(cost.x, cost.y)
	if _tele_obj != null:
		_drop_tele()
	_cast_glow = 0.45
	var culd := _spell_cooldown(entry)
	if culd > 0.0:
		_spell_culd[str(entry.get("id", ""))] = p._hold_ticks(culd)

func _spell_culd_base(entry: Dictionary) -> float:
	return float(entry.get("cooldown", entry.get("culd", 0.0)))

func _play_spell_sound(entry: Dictionary) -> void:
	var snd := str(entry.get("sound", ""))
	if snd != "":
		Fx.sound(snd, p.global_position, {"source": p})

func _cast_spell(entry: Dictionary, _dir: Vector2) -> int:
	var id := str(entry.get("id", ""))
	var effect := str(entry.get("effect", ""))
	if id == "sp_cryst" or effect == "crystal":
		return 2
	if effect == "slow" or id == "sp_slow":
		_start_slow(entry)
		return 1
	if effect == "blast" or id == "sp_blast":
		_spell_blast(entry)
		return 1
	if effect == "dash" or id == "sp_kdash":
		_spell_dash(entry)
		return 1
	if effect == "barrier" or id == "sp_mwall":
		return 1 if _cast_mwall(entry) else 0
	if effect == "ghost_wall" or id == "sp_gwall":
		return 1 if _cast_gwall(entry) else 0
	if effect == "shield" or id == "sp_mshit":
		_cast_mshit(entry)
		return 1
	if effect == "moonblade" or id == "sp_moon":
		_cast_moon(entry)
		return 1
	if effect == "blood_shield" or id == "sp_invulner":
		return 1 if _cast_blood(entry) else 0
	return -1

func _magic_origin() -> Vector2:
	if p.puppet.has_method("spell_origin"):
		return p.puppet.spell_origin()
	return p.global_position + Vector2(0.0, -32.0)

func _spell_target(entry: Dictionary) -> Variant:
	var origin := _magic_origin()
	var target := p._cursor_world()
	var id := str(entry.get("id", ""))
	var needs_los := int(entry.get("line", 0)) == 1 or id in ["sp_mwall", "sp_gwall"]
	if needs_los and Sight != null and not Sight.los_clear(origin, target):
		p._notice(OriginalLines.info("noVisible"))
		return null
	var dist := float(entry.get("dist", 0.0))
	if dist <= 0.0 and id in ["sp_mwall", "sp_gwall"]:
		dist = 300.0
	if dist > 0.0:
		var delta := target - origin
		var length := delta.length()
		if length > dist:
			target = origin + delta / length * dist
	return target

func _cast_mwall(entry: Dictionary) -> bool:
	var point: Variant = _spell_target(entry)
	if point == null:
		return false
	var host := p.get_tree().current_scene
	if host == null:
		return false
	var hp := float(entry.get("spell_hp", 200.0)) * _spell_power()
	var wall := p._Barrier.new()
	host.add_child(wall)
	wall.global_position = point
	wall.setup_mwall(hp)
	return true

func _cast_gwall(entry: Dictionary) -> bool:
	var point: Variant = _spell_target(entry)
	if point == null:
		return false
	var host := p.get_tree().current_scene
	if host == null:
		return false
	var power := _spell_power()
	var hp := float(round(float(entry.get("spell_hp", 100.0)) * power))
	var seconds := float(round(float(entry.get("damage", 10.0)) * power))
	var placed := 0
	var aim: Vector2 = point
	for offset in [Vector2(0, -40), Vector2.ZERO, Vector2(0, 40)]:
		var center := _tile_center(aim + offset)
		Fx.particles("gwall", center, {"source": p})
		if not _tile_open(center):
			continue
		var tile := p._Barrier.new()
		host.add_child(tile)
		tile.global_position = center
		tile.setup_gtile(hp, seconds)
		placed += 1
	if placed <= 0:
		p._notice(Locale.t("spell_no_room"))
		return false
	return true

func _tile_center(world: Vector2) -> Vector2:
	return Vector2(floor(world.x / 40.0) * 40.0 + 20.0, floor(world.y / 40.0) * 40.0 + 20.0)

func _tile_open(center: Vector2) -> bool:
	var space := p.get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 36)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, center)
	params.collision_mask = 1 | 4 | 32 | 64
	params.collide_with_areas = true
	params.collide_with_bodies = true
	for result in space.intersect_shape(params, 8):
		var collider: Object = result.collider
		if collider is Node and (collider as Node).is_in_group("ladders"):
			return false
		if collider is CollisionObject2D and ((collider as CollisionObject2D).collision_layer & (1 | 4 | 64)) != 0:
			return false
	return true

func _cast_mshit(entry: Dictionary) -> void:
	# shithp = hp * spellPower, then UnitPlayer steps it down by 0.05 per tick.
	_shit_hp = float(entry.get("spell_hp", 150.0)) * _spell_power()
	if ScriptsEngine.alicorn:
		_shit_hp = Progression.pers("alicornShitHP", 2000.0)

func _cast_moon(entry: Dictionary) -> void:
	var power := _spell_power()
	# UnitPet moonblade: level = pers.level - 1, hp 70 and dam 15, each times
	# (1 + 0.1 * level) and spellPower.
	var grow := 1.0 + 0.1 * float(maxi(0, int(Progression.level) - 1))
	var pet_hp := 70.0 * grow * power
	var pet_dam := 15.0 * grow * power
	if _moon != null and is_instance_valid(_moon) and _moon.has_method("heal_full"):
		_moon.heal_full()
		return
	var host := p.get_tree().current_scene
	if host == null:
		return
	var moon := p._Moon.new()
	host.add_child(moon)
	moon.global_position = p.global_position + Vector2(0.0, -80.0)
	moon.setup(p, pet_hp, pet_dam)
	_moon = moon

func _cast_blood(entry: Dictionary) -> bool:
	# cast_invulner fails when bloodHP <= dam * 3. dam is 50, so the gate is 150.
	# The spend is bloodDamage(dam, BLEED): dam * 3 * random(), so 0–150 off bloodHP.
	var dam := float(entry.get("damage", 50.0))
	if not GameState.try_blood_shield(dam):
		# cast_invulner fails quietly when blood is too low.
		return false
	_blood_left = p._hold_ticks(4.0)
	return true

func _tick_spell_state(delta: float) -> void:
	# Spell.step: every carried spell counts its own t_culd down.
	for id in _spell_culd.keys():
		var left := int(_spell_culd[id]) - Sim.frame_steps
		if left <= 0:
			_spell_culd.erase(id)
		else:
			_spell_culd[id] = left
	_tick_crystal(delta)
	if _shit_hp > 0.0:
		_shit_hp = maxf(0.0, _shit_hp - 0.05 * 30.0 * delta)
	if _blood_left > 0.0:
		_blood_left = p._spend(_blood_left)
	if _shit_ring:
		if _shit_hp > 0.0 and not _shit_ring.visible:
			_shit_ring.call("play_from", 1)
		elif _shit_hp <= 0.0:
			_shit_ring.visible = false
	for aura in _blood_auras:
		aura.set("alpha", 1.0 if _blood_left > 0.0 else 0.0)
	for clip in [_inh_ring, _shit_ring, _crystal_ring]:
		if clip:
			clip.scale.x = absf(clip.scale.x) * (-1.0 if p.facing < 0.0 else 1.0)
	if _inh_ring:
		_inh_ring.position.x = -1.0 if p.facing >= 0.0 else 1.0

func _tick_crystal(delta: float) -> void:
	var held := _crystal_held()
	var was_on := _crystal_on
	if not held:
		_crystal_tried = false
	if held and not _crystal_on and _crystal_grace <= 0.0:
		var spell := _crystal_spell()
		if _crystal_tried:
			pass
		elif not _spell_ready(spell):
			_crystal_tried = true
		else:
			_pay_cast(spell)
			_crystal_on = true
			_crystal_grace = p._hold_ticks(5.0 / 30.0)
			Fx.sound("crystal", p.global_position, {"source": p})
	elif held:
		_crystal_grace = p._hold_ticks(5.0 / 30.0)
	if _crystal_grace > 0:
		if _crystal_ring and _crystal_grace == 5 and int(_crystal_ring.call("frame")) < 10:
			_crystal_ring.call("play_from", 10)
		_crystal_grace = p._spend(_crystal_grace)
		_crystal_on = _crystal_grace > 0.0
	else:
		_crystal_on = false
	if _crystal_ring:
		if _crystal_on and not was_on:
			_crystal_ring.call("play_from", 1)
		elif not _crystal_on:
			_crystal_ring.visible = false
	GameState.magic_locked = _crystal_on

func _crystal_held() -> bool:
	if Inventory == null or Inventory.count("sp_cryst") <= 0:
		return false
	if MagicBinds != null and MagicBinds.is_held("sp_cryst"):
		return true
	return str(Inventory.spell_id) == "sp_cryst" and LocalInput.held(&"cast_spell", p.pid)

func _crystal_spell() -> Dictionary:
	var spell: Dictionary = _spellbook.get("sp_cryst", {})
	if spell.is_empty() and Inventory != null:
		spell = Inventory.weapon_def("sp_cryst")
	if spell.is_empty():
		return {"id": "sp_cryst", "magic": 50, "mana": 5}
	return spell

func _shielded_amount(amount: int, tip: String) -> int:
	var bypass := tip in ["DAM_BLEED", "DAM_POISON", "DAM_INTERNAL"]
	if _crystal_on and not bypass:
		# dam *= 5 / spellPower comes off the magic bar, a tenth of it off manaHP, and regen restarts.
		var drain := float(amount) * 5.0 / _spell_power()
		GameState.pay_spell(drain, drain * 0.1)
		if GameState.magic <= 0.0:
			_crystal_on = false
			_crystal_grace = 0
			GameState.magic_locked = false
		return 0
	if _blood_left > 0.0 and not bypass:
		if _shit_hp > 0.0:
			_shit_hp = maxf(0.0, _shit_hp - float(amount))
		return 0
	if _shit_hp > 0.0 and not bypass:
		_shit_hp = maxf(0.0, _shit_hp - float(amount))
		return maxi(0, amount - p.SHIT_ARMOR)
	return amount

