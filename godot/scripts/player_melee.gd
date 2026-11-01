extends RefCounted

## Hoof, kick and the carried melee weapon.
## p is the player body. Tick order stays in player.gd; these names forward.

const _Body := preload("res://scripts/player.gd")

var p: _Body

func _init(host: _Body) -> void:
	p = host

var _carried: Node2D

var _carried_id: String = ""

var _melee_t: int = 0

var _melee_rapid: int = 0

var _melee_struck: Dictionary = {}

var _melee_prev: Array = []

var _melee_snd: bool = false

## Bullet.tilehit: one tile per blow. A swing (mtip 0) only hits the tile under the cursor.
var _melee_tile_hit: bool = false

var _melee_cel_tile := Vector2i.ZERO

var _wep_pos: Vector2 = Vector2.ZERO

var _wep_has: bool = false

var _wep_side: float = 1.0

var _wep_aim: Vector2 = Vector2.ZERO

var _wep_blum: float = 0.0

var _melee_pow: int = 0

var _melee_auto: int = 0

var _melee_combo: int = 0

var _melee_t_combo: int = 0

var _melee_power: float = 1.0

var _melee_quake := Vector2.ZERO

var _melee_vzz: Sprite2D

var _melee_vis = null

# UnitPlayer.t_up and weapUp. Read by the puppet and the carried melee weapon.
var _up_for: int = 0

var weapon_raised: bool = false

var _hoof_cd: int = 0

var _hoof_work: int = 0

var _hoof_hit: int = 0

var _hoof_kick: bool = false

var _hoof_used: bool = false

## Pers.meleeSpdMult: head trauma multiplies it, mmaster adds 0.15.
func _melee_spd() -> float:
	return maxf(GameState.melee_speed_mult() + Progression.pers("meleeSpdMult", 0.0), 0.05)

func _tick_hoof(delta: float) -> void:
	_hoof_cd = p._spend(_hoof_cd)
	_hoof_work = p._spend(_hoof_work)
	if _hoof_hit > 0:
		_hoof_hit = p._spend(_hoof_hit)
		if _hoof_hit <= 0.0:
			_land_hoof()
	if not InputMap.has_action("melee") or not (LocalInput.held(&"melee") or LocalInput.just_pressed(&"melee")) or not p._Flags.allows("weapons"):
		_hoof_used = false
		return
	# keyPunch as a rat drinks the antidote: remEffect("potion_rat").
	if p.rat:
		if not _hoof_used:
			_hoof_used = true
			Effects.remove(p, "potion_rat")
		return
	# keyPunch as the alicorn is alicornPort.
	if ScriptsEngine.alicorn:
		if not _hoof_used:
			_hoof_used = true
			p._spells._alicorn_port(p._cursor_world())
		return
	# keyPunch stays down until the swing starts or the key comes up. One swing per press.
	if _hoof_used or not _hoof_ready() or Effects.attack_forever() or not GameState.attack_allowed():
		return
	_hoof_used = true
	_hoof_kick = _kick_modifier()
	if _hoof_kick:
		p._move._run_for_kick = true
	_hoof_cd = p._hold_ticks(p.HOOF_RAPID)
	_hoof_work = p._hold_ticks(p.HOOF_RAPID)
	_hoof_hit = p._hold_ticks(p.HOOF_WINDUP)

func _hoof_ready() -> bool:
	# UnitPlayer punches only while stay, not sitting, and not holding left or right.
	if _hoof_cd > 0.0:
		return false
	if not p.is_on_floor() or p._climbing or p._move._levitating:
		return false
	if p._move._sitting_on_ground() or p._move._ceiling_blocks_stand():
		return false
	if LocalInput.held(&"move_left") or LocalInput.held(&"move_right"):
		return false
	return true

func _kick_modifier() -> bool:
	# WKick.kick = keyRun. "sprint" is Shift and L3, so Shift+F and L3+RB kick.
	return InputMap.has_action("sprint") and LocalInput.held(&"sprint")

func _land_hoof() -> void:
	var kick := _hoof_kick
	var sign_x := -p.facing if kick else p.facing
	if sign_x == 0.0:
		sign_x = 1.0
	var far := p.KICK_FAR if kick else p.HOOF_FAR
	var top := -50.0
	var bottom := -30.0 if kick else -10.0
	var space := p.get_world_2d().direct_space_state
	if space == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(far - p.HOOF_NEAR, bottom - top)
	var mid := p.global_position + Vector2(sign_x * (p.HOOF_NEAR + far) * 0.5, (top + bottom) * 0.5)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = rect
	query.transform = Transform2D(0.0, mid)
	# World (destructibles), enemies and traps. The hoof does not shoot the equipped gun.
	query.collision_mask = 1 | 4
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [p.get_rid()]
	# powerkick: punchDamMult +0.5 and kickDestroy 80.
	var unit_damage := p.HOOF_DAMAGE * (2.0 if kick else 1.0) * Progression.pers("punchDamMult", 1.0)
	var block_damage := Progression.pers("kickDestroy", p.KICK_DESTROY) if kick else p.HOOF_DESTROY
	var seen: Dictionary = {}
	for found in space.intersect_shape(query, 16):
		var node := found.collider as Node
		if node == null or node == p:
			continue
		var id := node.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		if node.is_in_group("enemies") and node.has_method("take_hit"):
			p._Resistances.apply(node, unit_damage * Progression.target_mult(node), p.HOOF_TYPE)
			Fx.sound("hit", p.global_position, {"source": p})
		elif node.is_in_group("trap_units"):
			p._Resistances.apply(node, unit_damage, p.HOOF_TYPE)
		elif node.is_in_group("destructibles"):
			p._Resistances.apply(node, block_damage, p.HOOF_TYPE)

func _melee(w: Dictionary) -> bool:
	# WClub.weaponAttack starts t_attack at rapid_act. The swing lands in _melee_tick.
	if _melee_t > 0:
		if _melee_t > 10:
			_melee_combo = 0
		return false
	var fx := p._WeaponVis.fx(str(w.get("id", "")))
	# resultRapid: rapid / skillConf * rapidMult (1 / meleeSpdMult). Saws skip rapidMult.
	var rapid := maxf(float(w.get("rapid", 5)), 1.0) / maxf(p._skill_conf(w), 0.05)
	if _mtip_of(w) != 2:
		rapid /= _melee_spd()
	_melee_rapid = maxi(int(rapid), 1)
	_melee_t = _melee_rapid
	_melee_auto = 3
	_melee_power = 1.0
	_melee_struck.clear()
	_melee_prev.clear()
	_melee_snd = false
	_melee_tile_hit = false
	# combinat: every 4th blow inside rapid + 20 ticks hits twice as hard.
	# Weapons that are neither auto nor chargeable get it by default.
	var combinat := bool(fx.get("combo", false)) or (not bool(w.get("auto", false)) and not bool(fx.get("pow", false)))
	if combinat:
		_melee_t_combo = _melee_rapid + 20
		_melee_combo += 1
		if _melee_combo >= 4:
			_melee_power = 2.0
			_melee_combo = 0
	if _mtip_of(w) == 2:
		var knock := float(fx.get("knock", 0))
		_melee_quake = Vector2(Rng.randf(&"fx") * knock, Rng.randf(&"fx") * knock)
	return true

func _mtip_of(w: Dictionary) -> int:
	var id := str(w.get("id", ""))
	if p.MELEE_MTIP.has(id):
		return int(p.MELEE_MTIP[id])
	return int(p.MELEE_MTIP.get(id.split("^")[0], 0))

func _tick_carried_weapon(_delta: float, cursor: Vector2) -> void:
	# The drawn weapon, which lags the selection while a change is under way.
	var w := p._weapons_c._armed
	if str(w.get("kind", "")) != "melee":
		_carried.visible = false
		_carried_id = ""
		_melee_t = 0
		_wep_has = false
		return
	_show_carried(w)
	if not _wep_has:
		_melee_tick(w, cursor, false)
	for _i in mini(Sim.frame_steps, 3):
		_melee_tick(w, cursor, true)
	_dress_carried()

func _show_carried(w: Dictionary) -> void:
	var id := str(w.get("id", ""))
	if id != _carried_id:
		_carried_id = id
		_wep_has = false
		_melee_prev.clear()
		_melee_combo = 0
		_melee_pow = 0
		for child in _carried.get_children():
			child.free()
		_build_carried(w)
	_carried.visible = true

func _build_carried(w: Dictionary) -> void:
	# Grip at the origin, blade along +X, same space the swing already uses.
	var sprite := Sprite2D.new()
	sprite.name = "Vis"
	_melee_vis = p._WeaponVis.clip(str(w.get("id", "")))
	if _melee_vis == null:
		return
	_melee_vis.goto_stop(1)
	_melee_vis.show(sprite)
	_carried.add_child(sprite)
	p._WeaponVis.make_glow(sprite)
	# visVzz, the swing trail. vis_lasm weapons have none.
	_melee_vzz = null
	if not bool(p._WeaponVis.fx(str(w.get("id", ""))).get("lasm", false)):
		var trail := p._WeaponVis.fx_clip("visVzz")
		if trail != null:
			_melee_vzz = Sprite2D.new()
			_melee_vzz.name = "Vzz"
			trail.show(_melee_vzz)
			_melee_vzz.visible = false
			_melee_vzz.set_meta("clip", trail)
			_carried.add_child(_melee_vzz)

func _dress_carried() -> void:
	var sprite := _carried.get_node_or_null("Vis") as Sprite2D
	if sprite == null or _melee_vis == null:
		return
	_melee_vis.show(sprite)
	p._WeaponVis.sync_glow(sprite, sprite.get_node_or_null("Glow") as Sprite2D, p._WeaponVis.tele_color(), true)

func _melee_tick(w: Dictionary, cursor: Vector2, advance: bool) -> void:
	var mtip := _mtip_of(w)
	if _melee_t == _melee_rapid:
		_melee_cel_tile = Vector2i(floori(cursor.x / 40.0), floori(cursor.y / 40.0))
	var length := maxf(float(w.get("length", 50.0)), 1.0)
	var min_l := float(w.get("min_length", length))
	if min_l <= 0.0:
		min_l = length
	var height := p.CROUCH_SIZE.y if p._sit else p.BODY_SIZE.y
	var weapon_y := p.global_position.y - height * 0.40
	if weapon_raised and _raised_clear(weapon_y - 40.0):
		weapon_y -= 40.0
	# UnitPlayer.setWeaponPos: during a change (t_work > 10) the weapon sits at half height.
	if p._weapons_c._chw_left > 10.0:
		weapon_y = p.global_position.y - height * 0.5
	var side := p.facing if p.facing != 0.0 else 1.0
	var chest := Vector2(p.global_position.x, p.global_position.y - height * 0.75)
	var ds := 40.0 * side
	var cel := cursor
	if mtip == 0:
		cel = Vector2(cursor.x - length * 0.8 * side, cursor.y + length * 0.3)
		cel = _solid_stop(chest, cel)
		_wep_side = 1.0 if cursor.x > p.global_position.x - 100.0 * side else -1.0
	else:
		if mtip == 2 or _melee_t <= 0:
			_wep_aim = _solid_stop(chest, cursor)
		cel = _wep_aim
		if mtip == 2:
			var back := cel - Vector2(p.global_position.x + ds, weapon_y)
			var reach := length - (length - min_l) * 0.5
			cel -= back.limit_length(reach)
		_wep_side = 1.0 if cel.x > p.global_position.x else -1.0
	var del := (cel - Vector2(p.global_position.x + ds, weapon_y)).limit_length(p.MELEE_RANGE)
	ds = p.MELEE_SIDE * side
	var target := Vector2(p.global_position.x + ds + del.x, weapon_y + del.y)
	# setWeaponPos isLaz: the base point is the body centre; the pull toward the cursor stays.
	if p._climbing:
		target.x = p.global_position.x + del.x
	if not _wep_has:
		_wep_pos = target
		_wep_has = true
	var step := (target - _wep_pos) * 0.5
	# norma(del, max(levitRun, 1 / massa)), massa = phis_massa / 50. No phis_massa, no cap.
	var massa := float(p._WeaponVis.fx(str(w.get("id", ""))).get("massa", 0.0)) / 50.0
	if massa > 0.0:
		step = step.limit_length(maxf(p.MELEE_RUN, 1.0 / massa))
	if advance:
		_wep_blum = (step.x * _wep_side + step.y) * 0.5
		_wep_pos += step
	var is_pow := false
	if advance:
		is_pow = _melee_power_tick(w)
	var rot := _carried_rot(mtip, cel, height, is_pow)
	var thrust := Vector2.ZERO
	if mtip == 1 and _melee_t > 0:
		var anim := -0.25 if is_pow else _swing_anim(float(_melee_t), float(maxi(_melee_rapid, 1)))
		thrust = Vector2(cos(rot), sin(rot)) * anim * p.MELEE_THRUST
	if advance:
		# animate(): quake decays by a random 0.5..0.8 each tick, snapping to 0 under 1.
		_melee_quake *= Rng.randf_range(&"fx", 0.5, 0.8)
		if absf(_melee_quake.x) < 1.0:
			_melee_quake.x = 0.0
		if absf(_melee_quake.y) < 1.0:
			_melee_quake.y = 0.0
		_wep_pos = _keep_out_of_walls(_wep_pos, rot, length, chest)
	_carried.global_position = _wep_pos + thrust + _melee_quake
	# blumR is in degrees, added to the rotation in degrees.
	_carried.global_rotation = rot + deg_to_rad(_wep_blum)
	_carried.scale = Vector2(1.0, _wep_side)
	if advance:
		if not is_pow:
			_strike_melee(w, mtip, rot, thrust, length, min_l)
			if _melee_t > 0:
				_melee_t -= 1
		_melee_frames(w, mtip, length, is_pow)

func _melee_power_tick(w: Dictionary) -> bool:
	# Weapon.attack / WClub.actions: holding a chargeable weapon past the windup
	# freezes the swing at -0.25 and builds powerMult = 1 + pow / (rapid * 2.15).
	var rapid := float(maxi(_melee_rapid, 1))
	var held := p._weapons_c._shoot_held() and p._weapons_c._chw_left <= 0.0 and _hoof_work <= 0.0
	if held and not bool(w.get("auto", false)) and _melee_auto > 0:
		_melee_auto = 3
		_melee_pow += 1
	if _melee_auto > 0:
		_melee_auto -= 1
	else:
		_melee_pow = 0
	if _melee_t_combo > 0:
		_melee_t_combo -= 1
	else:
		_melee_combo = 0
	var chargeable := bool(p._WeaponVis.fx(str(w.get("id", ""))).get("pow", false))
	if chargeable and _melee_t > 0 and float(_melee_t) < rapid * 5.0 / 6.0 and _melee_pow > 2 and float(_melee_pow) < rapid * 2.15:
		var charge := float(_melee_pow) / (rapid * 2.15)
		_melee_power = 1.0 + charge
		_melee_quake.y = charge * 30.0 * ((Rng.randf(&"fx") - 0.5) if _mtip_of(w) == 1 else 1.0)
		return true
	return false

func _melee_frames(w: Dictionary, mtip: int, length: float, is_pow: bool) -> void:
	var rapid := float(maxi(_melee_rapid, 1))
	var t := float(_melee_t)
	var active := _melee_t > 0 and t >= rapid * 0.5 and t < rapid * 5.0 / 6.0
	# vis_lasm clips: frame 1 idle, 2 swinging, 3 inside the hit window.
	if _melee_vis != null and bool(p._WeaponVis.fx(str(w.get("id", ""))).get("lasm", false)):
		_melee_vis.goto_stop(3 if active else (2 if _melee_t > 0 else 1))
	if _melee_vzz == null:
		return
	_melee_vzz.visible = mtip == 0 and active and not is_pow
	if not _melee_vzz.visible:
		return
	var trail = _melee_vzz.get_meta("clip")
	var strong := _melee_power > 1.5
	trail.goto_stop(2 if strong else 1)
	trail.show(_melee_vzz)
	_melee_vzz.modulate.a = 1.0 if strong else minf(10.0 / rapid, 1.0)
	_melee_vzz.scale = Vector2(length / 100.0, length / 100.0)

func _carried_rot(mtip: int, cel: Vector2, height: float, is_pow = false) -> float:
	var side := _wep_side if _wep_side != 0.0 else 1.0
	if mtip == 0:
		if _melee_t <= 0:
			return -PI * 0.5 - (PI / 6.0) * side
		var anim := -0.25 if is_pow else _swing_anim(float(_melee_t), float(maxi(_melee_rapid, 1)))
		return -PI * 0.5 + (-(PI / 6.0) + anim * PI) * side
	var chest := Vector2(p.global_position.x, p.global_position.y - height * 0.5)
	return (cel - chest).angle()

func _swing_anim(t: float, rapid: float) -> float:
	# WClub t_attack curve. Windup, then the fast half, then recover.
	if rapid <= 0.0:
		return 0.0
	if t >= rapid * 5.0 / 6.0:
		return -(rapid - t) / rapid * 1.5
	if t >= rapid * 0.5:
		return -0.25 + ((rapid - t) / rapid - (1.0 / 6.0)) * 3.75
	return t * 2.0 / rapid

func _strike_melee(w: Dictionary, mtip: int, rot: float, thrust: Vector2, length: float, min_l: float) -> void:
	if _melee_t <= 0:
		_melee_prev.clear()
		return
	var rapid := float(maxi(_melee_rapid, 1))
	var t := float(_melee_t)
	var dir := Vector2(cos(rot), sin(rot))
	var origin := _wep_pos + thrust
	if mtip == 2:
		if _melee_t == 1:
			_sweep_melee(origin + dir * min_l, origin + dir * length, w)
		return
	var points: Array[Vector2] = []
	if mtip == 1:
		points.append(origin + dir * length)
	else:
		var count := int(round(maxf(length - min_l, 0.0) / p.MELEE_SAMPLE))
		for i in count + 1:
			points.append(origin + dir * (min_l + float(i) * p.MELEE_SAMPLE))
	var active := t >= rapid * 0.5 and t < rapid * (5.0 / 6.0)
	if active and not _melee_snd:
		_melee_snd = true
		# WClub plays sndShoot at a random gain from 0.5 to 1.
		p._play_if_present(str(w.get("sound", "")), Rng.randf_range(&"fx", 0.5, 1.0))
	if _melee_prev.size() != points.size():
		_melee_prev = points.duplicate()
		return
	if active:
		for i in points.size():
			_sweep_melee(_melee_prev[i] as Vector2, points[i], w)
	_melee_prev = points.duplicate()

func _sweep_melee(a: Vector2, b: Vector2, w: Dictionary) -> void:
	var dist := a.distance_to(b)
	var steps := maxi(int(ceil(dist / 9.0)), 1)
	for i in steps + 1:
		_touch_melee(a.lerp(b, float(i) / float(steps)), w, (b - a).normalized())

func _touch_melee(at: Vector2, w: Dictionary, motion = Vector2.ZERO) -> void:
	var space := p.get_world_2d().direct_space_state
	if space == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, at)
	# World, enemies, and shelves. Only enemies and destructibles take the hit.
	query.collision_mask = 1 | 4 | 64
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [p.get_rid()]
	_crack_crate(at, w, motion)
	for found in space.intersect_shape(query, 8):
		var node := found.collider as Node
		if node == null or node == p:
			continue
		var id := node.get_instance_id()
		if _melee_struck.has(id):
			continue
		if node.has_method("hit_tile"):
			_melee_tile(node, at, w, motion)
			continue
		var enemy := node.is_in_group("enemies") and node.has_method("take_hit")
		var block := node.is_in_group("destructibles")
		var trap := node.is_in_group("trap_units") and node.has_method("take_hit")
		if not enemy and not block and not trap:
			continue
		_melee_struck[id] = true
		# b.damage = curDam * powerMult (charged swing or the 4th combo blow).
		var dealt := p._weapons_c._amount(w, false) * _melee_power
		var struck := float(p._Block.of(str(w.get("id", "")))) if block else dealt
		var kind := str(w.get("damage_type", "DAM_BLUNT"))
		if enemy:
			_melee_impact(p._ImpactFx.unit_material(node, kind), at, w, dealt)
			struck *= Progression.target_mult(node)
		p._Resistances.apply(node, struck, kind)
		# WClub: knockx = storona.X, knocky = -0.2, otbros = otbros * otbrosMult * powerMult.
		if enemy and node.has_method("otbros"):
			node.otbros(Vector2(_wep_side, -0.2), float(p._WeaponVis.fx(str(w.get("id", ""))).get("knock", 0)) * Progression.weapon_perk(w, "Knock", 1.0) * _melee_power)
		if node.has_method("apply_on_hit"):
			var stun := Progression.weapon_perk(w, "Stun", 0.0)
			if stun > 0.0:
				p._roll_on_hit(node, "stun", stun, 1.0, int(round(dealt)))
			else:
				p._roll_on_hit(node, str(w.get("dop_effect", "")), float(w.get("dop_damage", 0.0)), float(w.get("dop_chance", 1.0)), int(round(dealt)))
		_melee_crash(w, motion)

## Bullet.run on a solid tile: popadalo, sound, crash, then Location.hitTile with char_destroy.
func _melee_tile(wall: Node, at: Vector2, w: Dictionary, motion: Vector2) -> void:
	if _melee_tile_hit:
		return
	var rect: Rect2 = wall.call("decal_rect")
	if rect.has_area():
		at = at.clamp(rect.position, rect.end - Vector2(0.01, 0.01))
	if _mtip_of(w) == 0 and Vector2i(floori(at.x / 40.0), floori(at.y / 40.0)) != _melee_cel_tile:
		return
	_melee_tile_hit = true
	var id := str(w.get("id", ""))
	_melee_impact(p._ImpactFx.surface_of(wall), at, w, p._weapons_c._amount(w, false) * _melee_power)
	_melee_crash(w, motion)
	wall.call("hit_tile", at, p._Block.of(id), str(w.get("damage_type", "DAM_BLUNT")), int(p._WeaponVis.fx(id).get("tipdec", 0)))

## Bullet.run with crack (weapons.xml: only mont): the box under the cursor
## (loc.celObj) takes Box.udarBullet(b, 1) = damage(destroy) where the blade
## passes. Only a locked container (bulPlayer) takes it.
func _crack_crate(at: Vector2, w: Dictionary, motion: Vector2) -> void:
	var id := str(w.get("id", ""))
	if id.get_slice("^", 0) != "mont":
		return
	var cursor := p._cursor_world()
	for props in p.get_tree().get_nodes_in_group("land_props"):
		var crates: Variant = props.get("_loot")
		if not (crates is Array) or not props.has_method("break_crate"):
			continue
		for crate in crates:
			if not is_instance_valid(crate) or _melee_struck.has(crate.get_instance_id()):
				continue
			var rect: Rect2 = props.call("_crate_rect", crate)
			if not rect.has_point(cursor) or not rect.has_point(at):
				continue
			_melee_struck[crate.get_instance_id()] = true
			if props.break_crate(crate, float(p._Block.of(id))):
				var mat := int(str(p._LandRegistry.obj(str(crate.get_meta("id", ""))).get("mat", "3")))
				_melee_impact(mat, at, w, p._weapons_c._amount(w, false) * _melee_power)
				_melee_crash(w, motion)
			return

func _melee_impact(mat: int, at: Vector2, w: Dictionary, dealt: float) -> void:
	var id := str(w.get("id", ""))
	var fx := p._WeaponVis.fx(id)
	var tip := int(fx.get("tipdec", 0))
	p._ImpactFx.popadalo(p.get_tree(), at, mat, tip, dealt, str(fx.get("flare", "")))
	p._ImpactFx.sound(mat, str(w.get("damage_type", "DAM_BLUNT")), id, tip)

func _melee_crash(w: Dictionary, motion: Vector2) -> void:
	# WClub.crash: 1 wear per blow plus the ammo's increasedWear, then the kickback shake.
	var id := str(w.get("id", ""))
	if Condition and Condition.has_method("_wear_weapon"):
		Condition.call("_wear_weapon", id, 1.0 + float(Condition.call("_extra_wear", id)))
	var knock := float(p._WeaponVis.fx(id).get("knock", 0)) * Progression.weapon_perk(w, "Knock", 1.0)
	if knock > 5.0 and motion != Vector2.ZERO and CamShake != null:
		Fx.shake(knock, p.global_position, {"x": knock * motion.x, "y": knock * motion.y, "source": p})
	if _mtip_of(w) == 2 or motion == Vector2.ZERO:
		_melee_quake = Vector2(Rng.randf(&"fx"), Rng.randf(&"fx")) * knock * 2.0
	else:
		_melee_quake = -motion * knock

func _solid_stop(from: Vector2, to: Vector2) -> Vector2:
	var space := p.get_world_2d().direct_space_state
	if space == null:
		return to
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.collide_with_areas = false
	query.exclude = [p.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return to
	return hit.position

## The carried weapon's grip stays on the near side of walls, and a blade that
## would reach into one backs off along its own axis.
func _keep_out_of_walls(grip: Vector2, rot: float, length: float, chest: Vector2) -> Vector2:
	var p := _solid_stop(chest, grip)
	if p != grip:
		p += (chest - p).normalized() * 2.0
	var dir := Vector2(cos(rot), sin(rot))
	var tip := p + dir * length
	var hit := _solid_stop(p, tip)
	if hit != tip:
		var back := p - dir * (hit.distance_to(tip) + 2.0)
		if _solid_stop(chest, back) == back:
			p = back
	return p

func _raised_clear(at_y: float) -> bool:
	return _solid_stop(Vector2(p.global_position.x, at_y + 40.0), Vector2(p.global_position.x, at_y)) == Vector2(p.global_position.x, at_y)

func _tick_weapon_raise(delta: float, up: bool) -> void:
	# weapUp: stay and keyBeUp for more than 10 ticks of t_up.
	weapon_raised = false
	if p.is_on_floor() and up and not p._climbing and not p._move._levitating:
		_up_for += Sim.frame_steps
		weapon_raised = _up_for > 10
	elif not up:
		_up_for = 0

