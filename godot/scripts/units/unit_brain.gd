class_name UnitBrain
extends RefCounted

## The control() / forces() / animate() of one original Unit* class, run on the
## enemy body at the original 30 ticks per second. Velocities are px/tick and
## distances are original pixels, so the AS3 numbers carry over unchanged.

const TPS := 30.0
const DDY := 1.0
const MAXDY := 20.0
const MAX_SPOK := 30
const TILE := 40.0
const NO_CELL := Vector2i(-99999, -99999)
const NEUJAZ_MS := 667
const MANIFEST := "res://assets/sprites/sheets/units/manifest.json"
const _Bullet := preload("res://scenes/bullet.tscn")
const _RoomFlags := preload("res://scripts/map/room_flags.gd")
const _WeaponVis := preload("res://scripts/weapon_vis.gd")
const _UnitWater := preload("res://scripts/map/unit_water.gd")
const _UnitMassa := preload("res://scripts/unit_massa.gd")

static var _manifest: Dictionary = {}
static var _manifest_loaded := false

var u: CharacterBody2D
var _dry_cell := NO_CELL
var row: Dictionary = {}
var id := ""
var tr := 0
var vel := Vector2.ZERO
var storona := -1.0
var ai_state := 0
var ai_tch := 0
## The host's _sense raises this on a sighting and lowers it on each failed look.
var ai_spok: int:
	get:
		return int(u.get("ai_spok"))
	set(v):
		u.set("ai_spok", v)
var max_spok := MAX_SPOK
var guns: Array[UnitGun] = []
var weapon_dy := 0.0
var cel := Vector2.ZERO
var cel_unit: Node2D = null
var cel_dx := 0.0
var cel_dy := 0.0
var stay := false
var turn_x := 0.0
var turn_y := 0.0
var is_fly := false
var is_plav := false
## Unit.inWater: swimming, or wading with the lower quarter of the body in water.
var wet := false
var ddy_plav := 0.0
var walk := 0.0
var max_speed := 10.0
var walk_speed := 10.0
var run_speed := 10.0
var accel := 5.0
var brake := 1.0
var jumpdy := 15.0
var levitaccel := 1.6
var knocked := 1.0
var elast := 0.0
var dam := 0.0
var tip := "DAM_PIERCE"
var shok := 0
var shithp := 0.0
var shit_armor := 20.0
var throu := false
## Unit.destroy: the tile hit dealt when it rams a wall.
var destroy := 0.0
var no_flip := false
var flips_sprite := true
var ticks := 0
var level := 0
## Unit.timerDie: a killed unit stays in sost 2 this many ticks before it dies.
var timer_die := 0
var dying := false
var _die_now := false
var _shake_base := Vector2.ZERO
## Unit.sndRunOn: the <snd run> hum plays while the player is within 800.
var snd_run_on := false
## Runs outside the player's room and its neighbours (a sky arena spans three).
var always_active := false
## Unit.control keeps running while telekinesis holds the body (levit); the
## brains that react to being held set this.
var acts_held := false


func setup(host: CharacterBody2D, data: Dictionary) -> void:
	u = host
	row = data
	id = str(host.get("_species_id"))
	tr = int(host.get_meta("tr", 0))
	level = int(host.get_meta("level", 0))
	var mv: Dictionary = row.get("move", {})
	max_speed = float(mv.get("speed", 10.0))
	walk_speed = max_speed
	run_speed = max_speed
	accel = float(mv.get("accel", 5.0))
	brake = float(mv.get("brake", 1.0))
	jumpdy = float(mv.get("jump", 15.0))
	levitaccel = float(mv.get("levitaccel", 1.6))
	knocked = float(mv.get("knocked", 1.0))
	ddy_plav = float(mv.get("float", 1.0))
	dam = float(row.get("damage", 0))
	tip = str(row.get("damage_type", "DAM_PIERCE"))
	storona = float(host.get("facing"))
	if storona == 0.0:
		storona = -1.0


## Before the body enters the tree, after the catalog stats.
func configure() -> void:
	pass


## After enemy._ready: groups, hp and the sprite are in place.
func start() -> void:
	var res: Node = u.get_node_or_null("Resistances")
	if res != null:
		var mult: Dictionary = res.get("multipliers")
		var vul: Dictionary = row.get("vulner", {})
		for k in vul.keys():
			mult[k] = float(vul[k])
		res.set("multipliers", mult)
	ready()


func ready() -> void:
	pass


## The vision cone direction (Unit.vAngle).
func v_angle() -> float:
	return 0.0 if storona >= 0.0 else PI


## Unit.vision for both calm and alert looks.
func set_vision(v: float) -> void:
	u.set("_calm_vision", v)
	u.set("_alert_vision", v)
	u.set("_vision", v)


## Unit.setWeaponPos: where the class's guns sit.
func weapon_pos() -> Vector2:
	return u.global_position + Vector2(0.0, weapon_dy)


## Weapon.vis of a gun with its own art (AllData `vweap`): drawn over the unit at the weapon
## point; the gun's bullets leave its `emit`. `skin` draws another weapon's art.
func make_gun_vis(g: UnitGun, skin := "") -> Sprite2D:
	var art := skin if skin != "" else g.id if g != null else ""
	if g == null or not _WeaponVis.has_art(art):
		return null
	g.vis_clip = _WeaponVis.clip(art)
	if g.vis_clip == null:
		return null
	var spr := Sprite2D.new()
	spr.name = "GunVis"
	spr.z_index = 1
	g.vis_clip.show(spr)
	u.add_child(spr)
	g.vis = spr
	g.vis_shots = g.shots
	return spr


## Weapon.animate for an owner with krep > 0 (robots): scaleX = storona, rotation = rot +
## 180° facing left; "shoot" plays on a shot, a gun with prep shows its spin-up frames.
func animate_gun_vis(g: UnitGun) -> void:
	if g == null or g.vis == null:
		return
	var c := g.vis_clip as _WeaponVis.Clip
	c.advance()
	if g.t_shoot > 0:
		g.t_shoot -= 1
	if g.shots != g.vis_shots:
		g.vis_shots = g.shots
		if g.t_shoot <= 1 and c.total > 1:
			c.goto_play("shoot")
			g.t_shoot = 3
	if g.prep > 0 and g.t_shoot <= 0:
		if g.t_prep < g.prep and g.t_prep > 1:
			c.goto_stop(g.t_prep)
		if g.t_prep >= g.prep and c.label("ready") > 0:
			c.goto_stop("ready")
		if g.t_prep <= 1 and g.t_reload == 0:
			c.goto_stop(1)
	c.show(g.vis)
	if g.floating:
		# krep 0: mirrored by the target's side, not the owner's facing.
		var at := g.origin()
		g.vis.global_position = at
		var fs := g.vis.scale.x
		if at.x > cel.x:
			fs = -1.0
		elif at.x < cel.x:
			fs = 1.0
		g.vis.scale = Vector2(fs, 1.0)
		g.vis.rotation = g.rot + (PI if fs < 0.0 else 0.0)
		return
	g.vis.global_position = weapon_pos()
	var s := 1.0 if storona >= 0.0 else -1.0
	g.vis.scale = Vector2(s, 1.0)
	g.vis.rotation = g.rot + (0.0 if s > 0.0 else PI)


## The host floats the held body; only control and the guns tick.
func held(delta: float) -> void:
	var dd := float(u.get("_detect_delay"))
	if dd > 0.0:
		u.set("_detect_delay", maxf(0.0, dd - delta))
	for _i in int(u.get("_frame_ticks")):
		ticks += 1
		if shok > 0:
			shok -= 1
		control()
		if not is_instance_valid(u) or bool(u.get("_dead")):
			return
		for g in guns:
			g.actions()


## The push the class's own control adds to dx / dy while held (px per tick).
func levit_pull(_vel: Vector2) -> Vector2:
	return Vector2.ZERO


func physics(delta: float) -> void:
	var player := player_node()
	if player != null:
		u.call("_tick_world_senses", player, delta)
	var dd := float(u.get("_detect_delay"))
	if dd > 0.0:
		u.set("_detect_delay", maxf(0.0, dd - delta))
	var st := float(u.get("_stun_t"))
	if st > 0.0:
		u.set("_stun_t", maxf(0.0, st - delta))
	var n := int(u.get("_frame_ticks"))
	if dying:
		_dying_ticks(n)
		return
	vel = u.velocity / TPS
	stay = u.is_on_floor()
	check_water()
	for _i in n:
		ticks += 1
		if shok > 0:
			shok -= 1
		control()
		if bool(u.get("_dead")) or not is_instance_valid(u):
			return
		for g in guns:
			g.actions()
		forces()
	if snd_run_on:
		run_hum()
	u.velocity = vel * TPS
	var pushed := u.velocity
	move_body()
	after_move(pushed)
	animate()
	if flips_sprite and is_instance_valid(u.anim):
		u.anim.flip_h = storona < 0.0
	u.set("facing", storona)


## Unit.checkWater against the room's water tiles. Rooms without water keep is_plav as set.
func check_water() -> void:
	# A room's water mask is fixed; a unit in a dry room skips the env lookup.
	var cell: Vector2i = _RoomFlags.cell_of(u.global_position)
	if cell == _dry_cell:
		return
	var mask: PackedByteArray = _RoomFlags.env_at(u.global_position).get("wmask", PackedByteArray())
	if mask.is_empty():
		_dry_cell = cell
		return
	_dry_cell = NO_CELL
	var box: Variant = u.get("body_size")
	var h := (box as Vector2).y if box is Vector2 else TILE
	var was := wet
	is_plav = _RoomFlags.water_at(u.global_position - Vector2(0, h * 0.75))
	wet = is_plav or (h > TILE and _RoomFlags.water_at(u.global_position - Vector2(0, h * 0.25)))
	if is_plav:
		stay = false
	if was != wet or wet:
		_UnitWater.splash(u.get_tree(), u.global_position, h, (box as Vector2).x if box is Vector2 else TILE,
			was, wet, is_plav, vel, _UnitMassa.massa(u), not dying)


## Unit.throu: platforms do not hold the unit while it is set.
func move_body() -> void:
	u.set_collision_mask_value(7, not throu)
	u.call("_commit_move")


## Unit.run collision results: turnX / turnY flags, stay, elastic bounce.
func after_move(pushed: Vector2) -> void:
	if destroy > 0.0 or float(row.get("massa", 0)) >= 50.0:
		destroy_walls(pushed / TPS)
	var got := u.velocity / TPS
	if u.is_on_wall() and absf(pushed.x) > 0.01:
		turn_x = -signf(pushed.x)
		got.x = -pushed.x / TPS * elast
	if u.is_on_ceiling() and pushed.y < 0.0:
		turn_y = 1.0
		got.y = -pushed.y / TPS * elast
	if is_fly and u.is_on_floor() and pushed.y > 0.0:
		turn_y = -1.0
		got.y = -pushed.y / TPS * elast
	vel = got
	stay = u.is_on_floor() and not is_fly


## Unit.destroyWall for every tile this move ran into (wall_span cells).
func destroy_walls(v: Vector2) -> void:
	for i in u.get_slide_collision_count():
		var col := u.get_slide_collision(i)
		var body := col.get_collider() as Node
		if body == null or not body.has_method("apply_blast"):
			continue
		var dir := -col.get_normal()
		var amount := destroy_amount(dir, v)
		if amount <= 0:
			continue
		var p := col.get_position() + dir * 4.0
		var cell := (p / TILE).floor() * TILE + Vector2(TILE, TILE) * 0.5
		body.call("apply_blast", amount, "", cell, TILE * 0.7)


## The tile hit for a move into a wall: a heavy fall stomps for 50, otherwise
## destroy when pushing in faster than 10.
func destroy_amount(dir: Vector2, v: Vector2) -> int:
	if is_plav or dying:
		return 0
	if dir.y > 0.5 and v.y > 15.0 and destroy < 50.0 and float(row.get("massa", 0)) >= 50.0:
		return 50
	if destroy > 0.0 and v.dot(dir) > 10.0:
		return int(destroy)
	return 0


func control() -> void:
	pass


## Unit.forces for a flyer and for a walker. Subclasses override like the class.
func forces() -> void:
	if is_plav:
		vel.y += DDY * ddy_plav
		vel *= 0.8
		return
	if is_fly:
		if vel.length_squared() > max_speed * max_speed:
			vel *= 0.7
		if absf(vel.x) < brake:
			vel.x = 0.0
		if absf(vel.y) < brake:
			vel.y = 0.0
		return
	if wet:
		vel.x *= 0.5
	var box: Variant = u.get("body_size")
	var g := _RoomFlags.gravity_at(u.global_position - Vector2(0, (box as Vector2).y * 0.25 if box is Vector2 else 10.0))
	if (g > 0.0 and vel.y < MAXDY * g) or (g < 0.0 and vel.y > MAXDY * g):
		vel.y += DDY * g
	if stay:
		if walk < 0.0:
			if vel.x < -max_speed:
				vel.x += brake
		elif walk > 0.0:
			if vel.x > max_speed:
				vel.x -= brake
		elif absf(vel.x) < brake:
			vel.x = 0.0
		elif vel.x > 0.0:
			vel.x -= brake
		else:
			vel.x += brake


func animate() -> void:
	pass


## Unit.damage before resistances. Returns what is left to apply.
func on_damage(amount: float, _type: String, _bullet: Node, tt: bool) -> float:
	if shithp > 0.0 and not tt:
		shithp = maxf(0.0, shithp - amount)
		return amount - shit_armor
	return amount


## True keeps the unit alive (a phase change instead of death). With timer_die set
## the first call starts sost 2 and the real death comes when it runs out.
func on_die() -> bool:
	if _die_now:
		return false
	if timer_die > 0:
		if not dying:
			dying = true
			vel = Vector2.ZERO
			u.velocity = Vector2.ZERO
			_shake_base = u.anim.position
			start_dying()
		return true
	return false


## Called once as sost 2 begins.
func start_dying() -> void:
	pass


## One sost 2 tick (Unit.animate while dying).
func dying_tick() -> void:
	pass


## setVisPos in sost 2: the sprite jitters harder as the timer runs down.
func dying_shake() -> void:
	var s := (150.0 - timer_die) / 15.0
	u.anim.position = _shake_base + Vector2((randf() - 0.5) * s, (randf() - 0.5) * s)


func _dying_ticks(n: int) -> void:
	u.velocity = Vector2.ZERO
	for _i in n:
		timer_die -= 1
		dying_tick()
		if timer_die <= 0:
			dying = false
			u.anim.position = _shake_base
			_die_now = true
			u.call("_begin_death")
			return
	dying_shake()


## After a phase change the next death runs its own timer again.
func revive_from_dying(next_timer: int) -> void:
	_die_now = false
	dying = false
	timer_die = next_timer


## Unit.dopTest: false lets a bullet pass through.
func dop_test(_bullet: Node) -> bool:
	return true


## Extra Unit.dropLoot work after the loot table.
func drop_loot() -> void:
	pass


## Unit.die (sposob 0): the <snd die> sound, then the class's expl().
func died() -> void:
	sound(str(row.get("snd", {}).get("die", "")))
	expl()


## A class's otbros override: a bullet with knockback hit the unit.
func on_knock() -> void:
	pass


## Unit.expl: the parts a class throws when it is destroyed.
func expl() -> void:
	pass


## Unit.sound / Sound.ps.
func sound(sid: String, vol: float = 1.0) -> void:
	UnitFx.snd(sid, vol)


## Unit.newPart: parts at the body centre.
func new_part(pid: String, kol: int = 1, frame: int = 0) -> void:
	UnitFx.emit(u.get_tree(), pid, center(), {"kol": kol, "frame": frame})


## Emitter.emit at a point.
func emit_part(pid: String, at: Vector2, param: Dictionary = {}) -> void:
	UnitFx.emit(u.get_tree(), pid, at, param)


## Unit.sndRunPlay.
func run_hum() -> void:
	var sid := str(row.get("snd", {}).get("run", ""))
	if sid != "":
		UnitFx.hum(u.get_tree(), sid, UnitFx.hum_volume(sqrt(dist2_to_player())))


## Script command (Unit.command). off/on stop and start control.
func command(_com: String, _val: String = "") -> void:
	pass


## Guns point back at the brain; the host breaks that cycle when it is freed.
func release() -> void:
	for g in guns:
		g.b = null
	guns.clear()


# ---------------------------------------------------------------- senses

func player_node() -> Node2D:
	var p: Variant = u.get("_player")
	if p is Node2D and is_instance_valid(p):
		return p
	var found := u.get_tree().get_first_node_in_group("player") as Node2D
	u.set("_player", found)
	return found


## Unit.findCel through the enemy's look and listen. A sighting aims at the
## player; a sound aims at where it came from.
func find_cel(_over: bool = false) -> bool:
	var player := player_node()
	if player == null:
		cel_unit = null
		return false
	var spok_before := int(u.get("ai_spok"))
	u.call("_sense")
	if bool(u.get("_track_player")):
		var pr: Variant = u.call("_prior_target") if bool(u.get("_on_prior")) else null
		set_cel(pr if pr is Node2D else player)
		return true
	cel_unit = null
	if int(u.get("ai_spok")) == MAX_SPOK - 1 and spok_before != MAX_SPOK - 1:
		cel = u.get("_goal")
		return true
	return false


func set_cel(node: Node2D, at: Variant = null) -> void:
	if node != null:
		cel_unit = node
		cel = center_of(node)
	else:
		cel_unit = null
		if at is Vector2:
			cel = at


## Unit.setCel on the player starts the unit's combat music (sndMusic).
func targets_player() -> bool:
	return cel_unit != null and is_instance_valid(cel_unit) and cel_unit == player_node()


func center_of(node: Node2D) -> Vector2:
	return u.call("_body_center", node)


func feet() -> Vector2:
	return u.global_position


func body() -> Vector2:
	return u.get("body_size")


func center() -> Vector2:
	return u.global_position + Vector2(0.0, -body().y * 0.5)


func dist2_to_player() -> float:
	var p := player_node()
	if p == null:
		return INF
	return center().distance_squared_to(center_of(p))


func enemy_act() -> bool:
	return player_node() != null and not bool(u.get("_friendly"))


## loc.getAbsTile(p).collision: a solid wall or floor tile at the point.
func solid_at(p: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.collision_mask = 1
	q.exclude = [u.get_rid()]
	return not u.get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


## Unit.shX1 / shX2: no floor under the leading edge on side dir.
func ledge(dir: float) -> bool:
	var x := u.global_position.x + dir * (body().x * 0.5 + 4.0)
	return not solid_at(Vector2(x, u.global_position.y + 6.0)) and not solid_at(Vector2(x, u.global_position.y + 20.0))


func rnd(p: float = 0.5) -> bool:
	return randf() < p


func norma(v: Vector2, len: float) -> Vector2:
	var l := v.length()
	if l < 0.0001:
		return Vector2.ZERO
	return v * (len / l)


func stunned() -> bool:
	return float(u.get("_stun_t")) > 0.0


## Unit.budilo: alarm allies of the same fraction.
func budilo(rad: float = 500.0) -> void:
	u.call("_budilo", rad)


# ---------------------------------------------------------------- attacks

## Unit.attKorp: the boxes overlap and the target is not still reeling.
func att_korp(target: Node2D, mult: float = 1.0) -> bool:
	if target == null or not is_instance_valid(target) or bool(u.get("_dead")):
		return false
	if not boxes_touch(target):
		return false
	var now := Time.get_ticks_msec()
	if int(target.get_meta("neujaz_until", 0)) > now:
		return false
	target.set_meta("neujaz_until", now + NEUJAZ_MS)
	var sila := randf() * 0.4 + 0.8
	var amount := int(round(dam * sila * mult))
	if amount > 0 and target.has_method("take_hit"):
		target.take_hit(amount, tip)
	return true


func boxes_touch(target: Node2D, grow: float = 0.0) -> bool:
	var a := Rect2(u.global_position - Vector2(body().x * 0.5, body().y), body()).grow(grow)
	var size: Vector2 = u.call("_body_size", target)
	var feet_t: Vector2 = u.call("_feet", target)
	var b := Rect2(feet_t - Vector2(size.x * 0.5, size.y), size)
	return a.intersects(b)


## Unit.getXmlWeapon: one of the units.xml weapons, weighted by ch.
func xml_gun() -> UnitGun:
	# Unit.getXmlWeapon: in list order, skip `f` (the class's own extra weapon) and take
	# the first that passes its `ch` roll.
	for wv: Dictionary in row.get("weapons", []):
		if bool(wv.get("f", false)):
			continue
		if randf() < float(wv.get("ch", 1.0)):
			var g := gun(str(wv.get("id", "")))
			if g != null:
				return g
	return null


## A class weapon (Unit.currentWeapon / dopWeapon) that ticks with the brain.
func gun(wid: String) -> UnitGun:
	var w: Dictionary = u.call("_weapon_row", wid)
	if w.is_empty():
		return null
	var g := UnitGun.new(self, w)
	guns.append(g)
	return g


## loc.createUnit: a new enemy at the feet point, already awake when alert is set.
func spawn_unit(uid: String, at: Vector2, metas: Dictionary = {}, alert := true) -> CharacterBody2D:
	var packed := load("res://scenes/enemy.tscn") as PackedScene
	var host := u.get_tree().current_scene
	if packed == null or host == null:
		return null
	var node := packed.instantiate() as CharacterBody2D
	node.set_meta("unit_id", uid)
	for k in metas.keys():
		node.set_meta(k, metas[k])
	node.position = at
	host.add_child(node)
	node.global_position = at
	if alert and node.has_method("_become_alert"):
		var p := player_node()
		node.call("_become_alert", p.global_position if p != null else at)
	return node


## Unit.explosion at the feet: a blast with no projectile.
func explode(damage: float, dtype: String, radius: float, at: Variant = null) -> void:
	if radius <= 0.0 or damage <= 0.0:
		return
	var host := u.get_tree().current_scene
	if host == null:
		return
	var b := _Bullet.instantiate() as Area2D
	b.from_player = false
	b.fraction = int(u.get("fraction"))
	b.damage = maxi(1, int(round(damage)))
	b.damage_type = dtype
	b.blast_radius = radius
	b.explode_on_timeout = true
	b.use_velocity = true
	b.velocity = Vector2.ZERO
	b.speed = 0.0
	b.lifetime = 0.02
	b.style = "grenade"
	b.weapon_id = id
	host.add_child(b)
	b.global_position = (at as Vector2) if at is Vector2 else u.global_position + Vector2(0.0, -3.0)


func hurt_player_radius(radius: float, amount: float, dtype: String) -> void:
	var p := player_node()
	if p == null or amount <= 0.0:
		return
	if center().distance_to(center_of(p)) <= radius and p.has_method("take_hit"):
		p.take_hit(int(round(amount)), dtype)


# ---------------------------------------------------------------- sprites

func anim(clip: String) -> void:
	u.call("_play_anim", clip)


func anim_frame(clip: String, frame: int) -> void:
	if not is_instance_valid(u.anim) or u.anim.sprite_frames == null:
		return
	if not u.anim.sprite_frames.has_animation(clip):
		return
	if u.anim.animation != clip:
		u.anim.play(clip)
		u.set("_current_anim", clip)
	u.anim.pause()
	u.anim.frame = clampi(frame, 0, u.anim.sprite_frames.get_frame_count(clip) - 1)


## vis.osn.rotation: turn the sprite about the body centre.
func tilt(deg: float) -> void:
	var r := deg_to_rad(deg)
	var c := Vector2(0.0, -body().y * 0.5)
	u.anim.rotation = r
	u.anim.position = c - c.rotated(r)


func has_clip(clip: String) -> bool:
	return u.call("_has_clip", clip)


## Another packed symbol (a shield bubble) drawn on top of the unit at its origin.
func make_overlay(key: String, at: Vector2, scale: float = 1.0) -> AnimatedSprite2D:
	var entry := vis_of(key)
	if entry.is_empty():
		return null
	var tex := load("res://assets/sprites/sheets/units/%s" % str(entry.get("sheet", ""))) as Texture2D
	if tex == null:
		return null
	var node := AnimatedSprite2D.new()
	node.name = key.capitalize()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.sprite_frames = frames_of(tex, entry, entry.get("clips", {}))
	node.centered = false
	var anchor: Array = entry.get("anchor", [0, 0])
	node.offset = -Vector2(float(anchor[0]), float(anchor[1]))
	node.position = at
	node.scale = Vector2(scale, scale)
	node.visible = false
	u.add_child(node)
	return node


## The world point of the room's top-left tile (loc coordinates 0, 0).
func room_origin() -> Vector2:
	var w := 48
	var h := 25
	var tile := 40
	var lp := u.get_tree().get_first_node_in_group("land_props")
	if lp != null and lp.get_script() != null:
		var c: Dictionary = (lp.get_script() as Script).get_script_constant_map()
		w = int(c.get("ROOM_W", w))
		h = int(c.get("ROOM_H", h))
		tile = int(c.get("TILE", tile))
	var at := u.global_position
	return Vector2(floor(at.x / float(w * tile)) * w * tile, floor(at.y / float(h * tile)) * h * tile)


## Game.globalDif, 0..4.
func global_dif() -> int:
	return GameState.difficulty()


func vis_entry() -> Dictionary:
	return vis_of(str(row.get("vis", "")))


static func vis_of(key: String) -> Dictionary:
	if key == "":
		return {}
	if not _manifest_loaded:
		_manifest_loaded = true
		if FileAccess.file_exists(MANIFEST):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
			if parsed is Dictionary:
				_manifest = parsed
	return _manifest.get(key, {})


## SpriteFrames over a packed unit sheet: frame i is cell i in row-major order.
static func frames_of(tex: Texture2D, entry: Dictionary, clips: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var cell: Array = entry.get("cell", [1, 1])
	var cw := int(cell[0])
	var ch := int(cell[1])
	var cols := maxi(1, int(entry.get("cols", 1)))
	var atlas_cache := {}
	for clip_v in clips.keys():
		var clip := str(clip_v)
		var data: Dictionary = clips[clip_v]
		frames.add_animation(clip)
		frames.set_animation_speed(clip, float(data.get("speed", TPS)))
		frames.set_animation_loop(clip, bool(data.get("loop", true)))
		for idx_v in data.get("frames", []):
			var idx := int(idx_v)
			var at: AtlasTexture = atlas_cache.get(idx)
			if at == null:
				at = AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2((idx % cols) * cw, (idx / cols) * ch, cw, ch)
				atlas_cache[idx] = at
			frames.add_frame(clip, at)
	return frames
