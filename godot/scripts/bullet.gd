extends Area2D

const _Resistances := preload("res://scripts/resistances.gd")
const _Proj := preload("res://scripts/projectile_vis.gd")
const _WeaponVis := preload("res://scripts/weapon_vis.gd")
const _ImpactFx := preload("res://scripts/impact_fx.gd")

const FRACTION_UNSET := -1
const F_PLAYER := 100
const F_MONSTER := 1
const F_RAIDER := 2
## Unit.friendlyExpl default.
const FRIENDLY_EXPL := 0.25
## Enemy and pet bodies (collision layer 3).
const ENEMY_LAYER := 4
## units.xml fraction. A child id such as raider1 keeps the parent's prefix.
const _SPECIES_FRACTION := {
	"thunderhead": 4,
	"robobrain": 4,
	"spritebot": 4,
	"hellhound": 4,
	"bossraider": 2,
	"bossencl": 4,
	"bossdron": 4,
	"bossultra": 4,
	"bossnecr": 2,
	"sentinel": 4,
	"triglaser": 4,
	"trigridge": 2,
	"trigplate": 2,
	"trigcans": 2,
	"damexpl": 2,
	"damshot": 2,
	"damgren": 2,
	"spectre": 0,
	"raider": 2,
	"slaver": 2,
	"zebra": 2,
	"ranger": 4,
	"protect": 4,
	"gutsy": 4,
	"roller": 4,
	"turret": 4,
	"encl": 4,
	"merc": 2,
	"vortex": 2,
	"dront": 4,
	"dron": 4,
	"eqd": 4,
	"msp": 4,
	"ttur": 4,
	"npc": 100,
	"vendor": 100,
	"doctor": 100,
	"captive": 100,
	"ponpon": 100,
}

const ROOM_PX := 1920.0
const OPEN_ROOMS := 6.0

@export var speed: float = 520.0
@export var damage: int = 20
@export var lifetime: float = 1.6

var direction: Vector2 = Vector2.RIGHT
var from_player: bool = true
## Shooter's Unit.fraction. -1 until the shot is fired. Unit.F_PLAYER is 100.
var fraction: int = -1
var damage_type: String = "DAM_PIERCE"
## weapons.json char_destroy. -1 until the shot is fired. Doors use this, not damage.
var block_damage: int = -1
var hitscan: bool = false
var blast_radius: float = 0.0
var style: String = "bullet"
var fall_accel: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var use_velocity: bool = false
var traveled: float = 0.0
var range_px: float = 0.0
var anti_px: float = 0.0
var miss_chance: float = 0.0
var explode_on_timeout: bool = false
var dop_effect: String = ""
var dop_damage: float = 0.0
var dop_chance: float = 1.0
## Bullet.pier: armor it ignores. char_pier plus the weapon perk's Pier.
var pier: float = 0.0
## Weapon.otbrosMult from the weapon perk's Knock.
var knock_mult: float = 1.0
## Bullet.desintegr: laser and plasma chance to burn a near-dead unit away.
var desintegr: float = 0.0
## weapons.json id. Empty until the shot is fired. Picks snd_shoot and visbul.
var weapon_id: String = ""
## spring 3 stops the clip on this pellet. 0 is the first frame.
var pellet_index: int = 0
## -1 plays this shot. 0 stays quiet. One positive key is shared by a volley.
var voice_key: int = -1
## PhisBullet (WThrow): flies through units and bounces off solid tiles only.
## bumc blows on the first tile, lip (throwtip 2) sticks, sensor (grenader)
## blows inside a live unit of another fraction.
var phis: bool = false
var bumc: bool = false
var lip: bool = false
var sensor: bool = false
var skok: float = 0.4
var tormoz: float = 0.6
var brake: float = 2.0

var _dead: bool = false
## E_WaterState: 0 unchecked, 1 in, 2 out.
var _in_water := 0
var _part_emit := true
var _skip: Array[RID] = []
var _shot: Dictionary = {}
var _beam := false
## Bullet.liv after a beam stops: 4 ticks, vis.alpha = liv * 0.25.
var _fade := 0.0
var _spring := 1
var _anim := false
var _anim_t := 0.0
var _frame_i := 0
var _origin := Vector2.ZERO
var _stay := false
var _prilip := false
## Bullet.targetObj when it is a Box: explosion() deals it destroy.
var _target_box: Node = null
static var _voiced := 0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	monitoring = false
	monitorable = false
	_ensure_fraction()
	if from_player:
		collision_layer = 8
		collision_mask = 69  # world + enemy + platforms
		add_to_group("player_bullets")
	else:
		collision_layer = 16
		collision_mask = 67  # world + player + platforms
		add_to_group("enemy_bullets")
	_dress_projectile()
	# The first drawn frame comes before the first physics step.
	var heading := velocity if use_velocity and velocity.length_squared() > 0.01 else direction
	if heading.length_squared() > 0.0001:
		rotation = heading.angle()
	# Layer 8 is a spell wall. The wall tests fraction and lets the caster's side through.
	set_collision_mask_value(8, true)
	if hitscan:
		sprite.visible = false
	# Fuses stop with the world (pause, Sats).
	get_tree().create_timer(lifetime, false).timeout.connect(_on_timeout)


func _on_timeout() -> void:
	if _dead or not is_inside_tree():
		return
	# Grenades, bombs, and flame keep their fuse. A straight shot does not
	# die in the air just because its timer ran out at a room line.
	if not _fuse_flight():
		return
	_dead = true
	if explode_on_timeout and blast_radius > 0.0:
		_explode(null)
	queue_free()


func _fuse_flight() -> bool:
	return explode_on_timeout or fall_accel != 0.0 or style == "flame"


func _range_limit() -> float:
	if range_px > 0.0:
		return range_px
	return ROOM_PX * OPEN_ROOMS


func _physics_process(delta: float) -> void:
	if _fade > 0.0:
		_fade -= delta * 30.0
		if _fade <= 0.0:
			queue_free()
			return
		sprite.modulate.a = minf(1.0, ceilf(_fade) * 0.25)
		_fit_sprite(delta)
		return
	if _dead:
		return
	_ensure_fraction()
	if not hitscan and not _fuse_flight() and traveled >= _range_limit() and traveled > 0.0:
		_finish_flight()
		return
	if hitscan:
		_hitscan()
		_dead = true
		queue_free()
		return
	if phis:
		_phis_step(delta)
		return
	if fall_accel != 0.0:
		velocity.y += fall_accel * delta
		use_velocity = true
	var step := direction.normalized() * speed * delta
	if use_velocity:
		step = velocity * delta
		if step.length_squared() > 0.01:
			direction = step.normalized()
	if step.length_squared() < 0.01:
		rotation = direction.angle()
		_fit_sprite(delta)
		return
	traveled += step.length()
	var next := global_position + step
	if _water_check(next):
		global_position = next
		if blast_radius > 0.0:
			_explode(null)
		else:
			_ImpactFx.popadalo(get_tree(), next, _ImpactFx.NONE, _tip(), float(damage), "")
		_dead = true
		queue_free()
		return
	var space := get_world_2d().direct_space_state
	var guard := 0
	while guard < 128:
		guard += 1
		var query := PhysicsRayQueryParameters2D.create(global_position, next, collision_mask)
		query.collide_with_areas = false
		query.hit_from_inside = false
		query.exclude = _skip
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			global_position = next
			rotation = direction.angle()
			_fit_sprite(delta)
			return
		if _shot_passes(hit):
			_exclude_hit(hit)
			continue
		global_position = hit.position
		if not _impact(hit.collider):
			global_position += direction.normalized() * 6.0
			_fit_sprite(delta)
			return
		rotation = direction.angle()
		_fit_sprite(delta)
		_finish_flight()
		return
	global_position = next
	rotation = direction.angle()
	_fit_sprite(delta)


func _finish_flight() -> void:
	_dead = true
	if _beam and sprite.visible and sprite.texture != null:
		_fade = 4.0
		return
	queue_free()


## Bullet.run water pass: physical shots splash 'kap' crossing the surface,
## burn/laser/plasma/shock/acid shots boil off in 'steam' and stop.
func _water_check(at: Vector2) -> bool:
	var wet := RoomFlags.in_water(at)
	var physical := damage_type in ["DAM_PIERCE", "DAM_BLUNT", "DAM_CUT"]
	if _part_emit and physical and _in_water != 0 and wet != (_in_water == 1):
		var d := direction.normalized() * (-10.0 if wet else 10.0)
		UnitFx.emit(get_tree(), "kap", at, {"dx": d.x, "dy": d.y, "kol": randi_range(0, 3) + int(damage / 5.0)})
		_ImpactFx.hit_sound("hit_water", 0.5, weapon_id, _tip())
		_part_emit = false
	_in_water = 1 if wet else 2
	if wet and damage_type in ["DAM_BURN", "DAM_LASER", "DAM_PLASMA", "DAM_ELECTRIC", "DAM_ACID"]:
		if _part_emit:
			UnitFx.emit(get_tree(), "steam", at)
		return true
	return false


func _hitscan() -> void:
	var start := global_position
	var origin := start
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var end := origin + dir * _range_limit()
	var space := get_world_2d().direct_space_state
	var tip := end
	var guard := 0
	while guard < 512:
		guard += 1
		var query := PhysicsRayQueryParameters2D.create(origin, end, collision_mask)
		query.collide_with_areas = false
		query.hit_from_inside = false
		query.exclude = _skip
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			tip = end
			break
		tip = hit.position
		if _shot_passes(hit):
			_exclude_hit(hit)
			origin = tip + dir * 0.5
			continue
		global_position = tip
		_impact(hit.collider)
		break
	_stamp_tracer(start, tip)


## PhisBullet.step and run, in px/s: ddy 1 px/tick, stay brakes 2 px/tick.
func _phis_step(delta: float) -> void:
	var tps := 30.0
	velocity.y += fall_accel * delta
	if _stay:
		if velocity.x > tps:
			velocity.x -= brake * tps * tps * delta
		elif velocity.x < -tps:
			velocity.x += brake * tps * tps * delta
		else:
			velocity.x = 0.0
	if lip and not _prilip and from_player and _stick_to_box():
		velocity = Vector2.ZERO
	if not _prilip:
		var space := get_world_2d().direct_space_state
		var motion := velocity * delta
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, 1)
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			global_position += motion
			if absf(velocity.y) > 0.01:
				_stay = false
		else:
			var n: Vector2 = hit.normal
			global_position = (hit.position as Vector2) + n
			if bumc:
				_phis_blow()
				return
			if lip:
				_prilip = true
				velocity = Vector2.ZERO
			elif absf(n.x) > absf(n.y):
				velocity.x = absf(velocity.x * skok) * signf(n.x)
			elif n.y < 0.0:
				if velocity.y > 2.0 * tps:
					velocity.y = -absf(velocity.y * skok)
					velocity.x *= tormoz
				else:
					velocity.y = 0.0
					_stay = true
			else:
				velocity.y = absf(velocity.y * skok)
		rotation += deg_to_rad(velocity.x / tps) * delta * tps
	if sensor and _sensor_hit():
		_phis_blow()
		return
	_fit_sprite(delta)


func _stick_to_box() -> bool:
	var props := get_tree().get_first_node_in_group("land_props")
	var player := get_tree().get_first_node_in_group("player")
	if props == null or player == null or not props.has_method("sticky_box") or not player.has_method("_cursor_world"):
		return false
	_target_box = props.call("sticky_box", global_position, player.call("_cursor_world"))
	_prilip = _target_box != null
	return _prilip


func _phis_blow() -> void:
	_dead = true
	if blast_radius > 0.0:
		_explode(null)
	queue_free()


## PhisBullet.sensor: any live unit of another fraction whose box holds the grenade.
func _sensor_hit() -> bool:
	var group := "enemies" if from_player else "player"
	for node in get_tree().get_nodes_in_group(group):
		if not node is Node2D or not is_instance_valid(node):
			continue
		var unit := node as Node2D
		if bool(unit.get("_dead")) or bool(unit.get("_downed")) or not unit.is_visible_in_tree():
			continue
		if from_player and node.is_in_group("pets"):
			continue
		var size: Variant = unit.get("body_size")
		var box := Vector2(48, 56) if not size is Vector2 else size as Vector2
		if Rect2(unit.global_position - Vector2(box.x * 0.5, box.y), box).has_point(global_position):
			return true
	return false


## Bullet.otbros with knockx/knocky: the flight direction, or for a blast
## fragment (t / rasst) / (1 + 4 * rasst / er), er = radius + target width.
func _knock_unit(node: Node) -> void:
	if not node.has_method("otbros") or not node is Node2D:
		return
	var power := float(_WeaponVis.fx(weapon_id).get("knock", 0)) * knock_mult if weapon_id != "" else 0.0
	if power <= 0.0:
		return
	var dir := (velocity if use_velocity and velocity.length_squared() > 0.01 else direction).normalized()
	if blast_radius > 0.0:
		# Bullet.explBullet: no knockx / knocky where the room has levitoff.
		if not RoomFlags.allows("levit", global_position):
			return
		var body := node as Node2D
		var size: Variant = body.get("body_size")
		var box := Vector2(48, 56) if not size is Vector2 else size as Vector2
		var t := body.global_position - Vector2(0.0, box.y * 0.5) - global_position
		var rasst := maxf(t.length(), 1.0)
		var er := blast_radius + box.x
		if rasst >= er:
			return
		dir = t / rasst / (1.0 + 4.0 * rasst / er)
	node.otbros(dir, power)


## Bullet.explBlast reaches the player too: a player blast does damage * pers.autoExpl
## (friendly 0.25), walls shield, and the fragment's knock is capped at 10.
func _self_blast() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or blast_radius <= 0.0:
		return
	var box: Rect2 = player.call("_aim_rect", player) if player.has_method("_aim_rect") else Rect2(player.global_position - Vector2(20, 60), Vector2(40, 60))
	var t := box.get_center() - global_position
	var rasst := maxf(t.length(), 1.0)
	var er := blast_radius + box.size.x
	if rasst >= er:
		return
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, box.get_center(), 1)
	if not space.intersect_ray(query).is_empty():
		return
	var dealt := float(damage) * randf_range(0.7, 1.3)
	if rasst > er * 0.5:
		dealt *= 2.0 - rasst * 2.0 / er
	dealt *= Progression.pers("autoExpl", 1.0)
	if dealt <= 0.0:
		return
	var power := float(_WeaponVis.fx(weapon_id).get("knock", 0)) * knock_mult if weapon_id != "" else 0.0
	var knock := (t / rasst / (1.0 + 4.0 * rasst / er)) * power
	# levitoff zeroes knockx / knocky; player.take_hit reads Vector2.ZERO as "use the contact knock".
	if not RoomFlags.allows("levit", global_position):
		knock = Vector2(0.0, 1e-6)
	player.set("_hit_knock", knock)
	_Resistances.apply(player, dealt, damage_type)
	player.set("_hit_knock", Vector2.ZERO)


## Unit.udarBullet: dexter 0 is always hit; otherwise accuracy / (dexter + 0.05). -1 skips dodge.
func _connects(dex: float = -1.0) -> bool:
	if miss_chance > 0.0 and randf() < miss_chance:
		return false
	if range_px <= 0.0 or dex == 0.0:
		return true
	var dist := maxf(traveled, 1.0)
	var acc := range_px / dist
	if anti_px > 0.0 and dist < anti_px:
		acc = dist / anti_px * 0.75 + 0.25
	if dex > 0.0:
		acc /= dex + 0.05
	if acc >= 1.0:
		return true
	return randf() < acc


func _dexter_of(body: Object) -> float:
	if body is Node and (body as Node).is_in_group("player") and body.has_method("dexter_now"):
		return float(body.call("dexter_now"))
	if body is Node and (body as Node).is_in_group("enemies"):
		var value: Variant = (body as Node).get("dexter")
		if value is float or value is int:
			return float(value)
	return -1.0


func _impact(body: Object) -> bool:
	if body is Node and (body as Node).is_in_group("magic_barriers"):
		var wall := body as Node
		if _wall_passes(wall):
			_exclude_body(wall)
			return false
		if wall.has_method("absorb"):
			wall.absorb(float(damage))
		if blast_radius > 0.0:
			_explode(null)
		return true
	# Unit.dopTest: some units let most bullets through (the thunderhead).
	var passes: bool = body is Node and (body as Node).has_method("dop_test") and not (body as Node).call("dop_test", self)
	if passes or (body is Node and _is_unit(body as Node) and not _connects(_dexter_of(body))):
		if body is CollisionObject2D:
			_skip.append((body as CollisionObject2D).get_rid())
		return false
	if blast_radius > 0.0:
		_explode(body)
		if body is Node:
			_roll_status(body as Node)
		return true
	_play_impact(body)
	if body is Node:
		var node := body as Node
		if node.has_method("hit_tile"):
			# The ray stops on the face. Bullet.run finds the tile a step inside it.
			node.hit_tile(global_position + direction.normalized() * 3.0, _block_amount(), damage_type, _tip())
		elif node.is_in_group("destructibles") or _is_unit(node) or (from_player and node.is_in_group("trap_units")) or node.is_in_group("actdam"):
			_strike(node, float(damage), false)
			_roll_status(node)
	return true


## Doors take char_destroy. Units take health damage, and blasts fall off past half the radius.
## Bullet.explDestroy applies destroy once to every tile in the disk, with no falloff.
## A wall span applies that disk itself. A single hit records where it landed.
func _strike(node: Node, health: float, soften: bool) -> void:
	if blast_radius > 0.0 and node.has_method("apply_blast"):
		node.apply_blast(_block_amount(), damage_type, global_position, blast_radius, _tip())
		return
	var dealt := health
	if node.is_in_group("destructibles"):
		node.set_meta("hit_at", global_position)
		dealt = float(_block_amount())
	elif soften and blast_radius > 0.0 and node is Node2D:
		var gap := global_position.distance_to((node as Node2D).global_position)
		if gap > blast_radius * 0.5:
			dealt *= maxf(0.0, 2.0 - gap * 2.0 / blast_radius)
	if not node.is_in_group("destructibles") and node.has_method("hit_by_bullet"):
		# Bullet.explBlast: an enemy blast on its own fraction does friendlyExpl (0.25).
		if blast_radius > 0.0 and not from_player and node.is_in_group("enemies"):
			var side: Variant = node.get("fraction")
			if (side is int or side is float) and int(side) == fraction and fraction != F_PLAYER:
				dealt *= FRIENDLY_EXPL
		node.hit_by_bullet(self, dealt, blast_radius > 0.0)
		_knock_unit(node)
		return
	# knop2 (actdam) and charges (trap_units) only have take_hit; Resistances
	# does nothing on them, so shots and the detonator blast never fired them.
	if node.has_method("take_hit") and (node.is_in_group("actdam") or node.is_in_group("trap_units")):
		node.take_hit(maxi(1, int(round(dealt))), damage_type)
		return
	_Resistances.apply(node, dealt, damage_type)


func _block_amount() -> int:
	if damage_type == "DAM_EMP":
		return 0
	if block_damage >= 0:
		return block_damage
	return 10


func _roll_status(node: Node) -> void:
	if dop_effect == "" or dop_chance <= 0.0 or not node.has_method("apply_on_hit"):
		return
	if dop_chance < 1.0 and randf() >= dop_chance:
		return
	node.apply_on_hit(dop_effect, dop_damage, damage)


func _explode(direct_body: Object = null) -> void:
	var destroy := float(_block_amount())
	if destroy > 0.0:
		var props := get_tree().get_first_node_in_group("land_props")
		if props:
			if blast_radius > 0.0 and props.has_method("blast_boxes"):
				props.call("blast_boxes", global_position, blast_radius, destroy)
			elif is_instance_valid(_target_box) and props.has_method("damage_box"):
				props.call("damage_box", _target_box, destroy)
	_flash_disk(global_position, blast_radius, Color(1.0, 0.42, 0.08, 0.45))
	preload("res://scripts/expl_fx.gd").vis(get_tree(), global_position, damage_type, weapon_id, RoomFlags.in_water(global_position))
	_quake()
	var hits: Array[Node] = []
	var seen := {}
	if direct_body is Node:
		var direct := direct_body as Node
		_play_impact(direct)
		if _blast_target(direct):
			hits.append(direct)
			seen[direct.get_instance_id()] = true
	# Units first, then world. Wall tiles must not fill the unit query.
	# Bullet.explBlast hits every unit in the room; enemy blasts reach enemies and pets too.
	var unit_mask := collision_mask & ~1
	if not from_player:
		unit_mask |= ENEMY_LAYER
	_gather_blast(hits, seen, unit_mask, 32)
	_gather_blast(hits, seen, 1, 256)
	# explDestroy walks tiles in the disk; a physics miss (layer, same-frame
	# spawn) would skip walls, so also take every destructible span.
	_gather_blast_walls(hits, seen)
	for node in hits:
		var soften := node != direct_body
		if soften and from_player and node.is_in_group("enemies"):
			SfxBank.play("hit")
		elif soften and node.is_in_group("destructibles"):
			SfxBank.play(_surface_clip(node))
		_strike(node, float(damage), soften)
	if from_player:
		_self_blast()


func _blast_target(node: Node) -> bool:
	if not from_player and (node.is_in_group("enemies") or node.is_in_group("allies")):
		return node.has_method("take_hit")
	return node.has_method("apply_blast") or node.is_in_group("destructibles") or node.is_in_group("trap_units") or node.is_in_group("actdam") or _is_unit(node)


func _gather_blast(hits: Array[Node], seen: Dictionary, mask: int, limit: int) -> void:
	if mask == 0 or limit < 1:
		return
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = blast_radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = mask
	params.collide_with_areas = false
	params.collide_with_bodies = true
	for result in space.intersect_shape(params, limit):
		var collider: Object = result.collider
		if not collider is Node:
			continue
		var node := collider as Node
		var id := node.get_instance_id()
		if seen.has(id) or not _blast_target(node):
			continue
		seen[id] = true
		hits.append(node)


func _gather_blast_walls(hits: Array[Node], seen: Dictionary) -> void:
	if blast_radius <= 0.0 or _block_amount() <= 0 or not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group("destructibles"):
		if not is_instance_valid(node) or not node.has_method("apply_blast"):
			continue
		var id := node.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		hits.append(node)


## Bullet.popadalo, then Bullet.sound for the material it struck. A blast's own
## popadalo is the explosion.
func _play_impact(body: Object) -> void:
	var mat := _material_of(body)
	var tip := _tip()
	if blast_radius <= 0.0:
		var flare_id := str(_WeaponVis.fx(weapon_id).get("flare", "")) if weapon_id != "" else ""
		_ImpactFx.popadalo(get_tree(), global_position, mat, tip, float(damage), flare_id)
	_ImpactFx.sound(mat, damage_type, weapon_id, tip)


## Bullet.explVis: a shot with knockback shakes the view when it blows.
func _quake() -> void:
	var knock := float(_WeaponVis.fx(weapon_id).get("knock", 0)) * knock_mult if weapon_id != "" else 0.0
	if knock > 0.0 and CamShake != null:
		CamShake.quake(randf_range(-4.0, 4.0) * knock, knock * 0.8)


func _tip() -> int:
	if weapon_id == "":
		return 0
	return int(_WeaponVis.fx(weapon_id).get("tipdec", 0))


func _material_of(body: Object) -> int:
	if body is Node and _is_unit(body as Node):
		return _ImpactFx.unit_material(body as Node, damage_type)
	return _ImpactFx.surface_of(body)


func _surface_clip(body: Object) -> String:
	if body is Node:
		var node := body as Node
		var label := node.name.to_lower() + " " + str(node.get_meta("surface", "")).to_lower()
		if "metal" in label or "grate" in label:
			return "hit_metal"
	return "hit_concrete"


func _is_unit(node: Node) -> bool:
	if from_player and node.is_in_group("enemies"):
		return node.has_method("take_hit")
	if not from_player and (node.is_in_group("player") or node.is_in_group("moonblade") or node.is_in_group("pets")):
		return node.has_method("take_hit")
	return false


func _ensure_fraction() -> void:
	if fraction >= 0:
		return
	if from_player:
		fraction = F_PLAYER
		return
	var shooter := _nearest_shooter()
	if shooter != null and _marked_friendly(shooter):
		fraction = F_PLAYER
		return
	if shooter != null:
		var owned := _explicit_fraction(shooter)
		if owned > 0:
			fraction = owned
			return
		fraction = _fraction_for_species(_species_id(shooter))
		return
	fraction = F_RAIDER


func _nearest_shooter() -> Node:
	var best: Node = null
	var best_d := 24.0
	for group_name in ["enemies", "pets", "pet", "friendly", "moonblade"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if not node is Node2D:
				continue
			var dist := global_position.distance_to(_muzzle_point(node as Node2D))
			if dist < best_d - 0.01:
				best_d = dist
				best = node
			elif best != null and absf(dist - best_d) <= 0.01 and _marked_friendly(node) and not _marked_friendly(best):
				best = node
	return best


func _muzzle_point(node: Node2D) -> Vector2:
	var muzzle := node.get_node_or_null("Muzzle") as Node2D
	if muzzle != null:
		return muzzle.global_position
	if node.has_method("get_muzzle_global"):
		var at: Variant = node.call("get_muzzle_global")
		if at is Vector2:
			return at
	return node.global_position


func _marked_friendly(node: Node) -> bool:
	if node.is_in_group("friendly") or node.is_in_group("pets") or node.is_in_group("pet") or node.is_in_group("moonblade"):
		return true
	if node.has_meta("friendly") and bool(node.get_meta("friendly")):
		return true
	var flag: Variant = node.get("friendly")
	return flag is bool and flag


func _explicit_fraction(node: Node) -> int:
	if node.has_meta("fraction"):
		return int(node.get_meta("fraction"))
	var value: Variant = node.get("fraction")
	if value is int or value is float:
		return int(value)
	return FRACTION_UNSET


func _species_id(node: Node) -> String:
	for key in ["unit_id", "species", "cid"]:
		if not node.has_meta(key):
			continue
		var raw := str(node.get_meta(key)).strip_edges().to_lower()
		if raw != "" and raw != "enemy":
			return raw
	for group_name in node.get_groups():
		var label := str(group_name).to_lower()
		if label in ["enemies", "enemy", "pets", "pet", "friendly", "moonblade"]:
			continue
		return label
	var base := String(node.name).to_lower()
	var at := base.find("@")
	if at > 0:
		base = base.substr(0, at)
	return base


func _fraction_for_species(id: String) -> int:
	var key := id.strip_edges().to_lower()
	if key == "":
		return F_RAIDER
	if _SPECIES_FRACTION.has(key):
		return int(_SPECIES_FRACTION[key])
	var best := ""
	for prefix in _SPECIES_FRACTION.keys():
		var name := str(prefix)
		if key.begins_with(name) and name.length() > best.length():
			best = name
	if best != "":
		return int(_SPECIES_FRACTION[best])
	return F_MONSTER


## A ray hits every StaticBody on the mask, including one-way lips.
## Tile collision 1 is a sealed floor or wall: the body cannot fall through it,
## and the shot stops. Collision 0 platforms and slopes are not sealed. The
## body drops through them and walks through them, so the shot does too.
## A destroyed wall has already left the world layer.
func _shot_passes(hit: Dictionary) -> bool:
	if _wall_passes(hit.get("collider")):
		return true
	return _floor_passes(hit.get("collider"))


func _floor_passes(body: Object) -> bool:
	if not body is Node:
		return false
	var node := body as Node
	var parent := node.get_parent()
	var pname := str(parent.name) if parent != null else ""
	if pname == "Platforms" or pname == "Slopes":
		return true
	if not body is CollisionObject2D:
		return false
	return _shape_is_one_way(body as CollisionObject2D)


func _shape_is_one_way(body: CollisionObject2D) -> bool:
	for child in body.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).one_way_collision:
			return true
	return false


func _wall_passes(body: Object) -> bool:
	_ensure_fraction()
	if not body is Node:
		return false
	var wall := body as Node
	if not wall.is_in_group("magic_barriers"):
		return false
	return wall.has_method("passes_fraction") and wall.passes_fraction(fraction)


func _exclude_hit(hit: Dictionary) -> void:
	var raw: Variant = hit.get("rid", RID())
	if raw is RID:
		var rid: RID = raw
		if rid.is_valid() and not _skip.has(rid):
			_skip.append(rid)
			return
	_exclude_body(hit.get("collider", null))


func _exclude_body(body: Object) -> void:
	if body is CollisionObject2D:
		var rid := (body as CollisionObject2D).get_rid()
		if rid.is_valid() and not _skip.has(rid):
			_skip.append(rid)


func _dress_projectile() -> void:
	_origin = global_position
	_shot = _Proj.lookup(weapon_id)
	_shot = _Proj.alicorn_bullet(_shot, from_player, ScriptsEngine != null and ScriptsEngine.alicorn)
	if _shot.is_empty():
		if from_player:
			_apply_style()
		else:
			sprite.modulate = Color(1.0, 0.45, 0.35)
		return
	sprite.modulate = Color.WHITE
	_spring = int(_shot.get("spring", 1))
	_beam = _Proj.is_beam(_shot) and _spring >= 2
	# vis.play() loops, and a beam's laser child always plays. spring 3 stops on the pellet frame instead.
	_anim = (bool(_shot.get("anim", false)) or _beam) and _spring != 3
	if str(_shot.get("blend", "")) == "add":
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = mat
	else:
		sprite.material = null
	_frame_i = pellet_index if _spring == 3 else 0
	if not _Proj.show_frame(sprite, _shot, _frame_i):
		if from_player:
			_apply_style()
		else:
			sprite.modulate = Color(1.0, 0.45, 0.35)
	else:
		_apply_stretch()
	_announce()


## Sound.ps(sndShoot) uses volume 1. A volley shares voice_key so pellets do not stack.
func _announce() -> void:
	if voice_key == 0 or _shot.is_empty():
		return
	var snd := str(_shot.get("sound", ""))
	if snd == "":
		return
	if voice_key > 0:
		if _voiced == voice_key:
			return
		_voiced = voice_key
	SfxBank.play(snd, float(_shot.get("volume", 1.0)))


## spring 1 and vel > 100 stretches the tracer. A laser child stretches with distance.
func _apply_stretch() -> void:
	if _beam:
		sprite.scale = Vector2(0.02, 1.0)
		return
	var base := _Proj.RAINBOW_SCALE if str(_shot.get("symbol", "")) == "visualRainbow" else 1.0
	if _spring != 1:
		sprite.scale = Vector2(base, base)
		return
	var vel := speed / 30.0
	if use_velocity:
		vel = velocity.length() / 30.0
	if vel > 100.0:
		sprite.scale = Vector2(vel * 0.01, 1.0) * base
	else:
		sprite.scale = Vector2(base, base)


func _fit_sprite(delta: float) -> void:
	if _shot.is_empty() or sprite.texture == null:
		return
	if _beam:
		var dist := _origin.distance_to(global_position)
		sprite.scale = Vector2(maxf(dist * 0.01, 0.02), 1.0)
	if not _anim:
		return
	_anim_t += delta
	var count := _Proj.frame_count(_shot)
	if count <= 1:
		return
	var idx := int(_anim_t * 30.0) % count
	if idx == _frame_i:
		return
	_frame_i = idx
	_Proj.show_frame(sprite, _shot, idx)


func _stamp_tracer(start: Vector2, tip: Vector2) -> void:
	if _shot.is_empty() or sprite.texture == null:
		_flash(start, tip, Color(1.0, 0.28, 0.18))
		return
	var host := get_tree().current_scene
	if host == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.centered = false
	ghost.offset = sprite.offset
	ghost.texture_filter = sprite.texture_filter
	ghost.material = sprite.material
	ghost.modulate = sprite.modulate
	var dir := tip - start
	ghost.rotation = dir.angle() if dir.length_squared() > 0.01 else direction.angle()
	if _beam:
		ghost.scale = Vector2(maxf(start.distance_to(tip) * 0.01, 0.02), 1.0)
	else:
		ghost.scale = sprite.scale
	host.add_child(ghost)
	ghost.global_position = tip
	get_tree().create_timer(0.06).timeout.connect(ghost.queue_free)


func _apply_style() -> void:
	match style:
		"laser":
			sprite.modulate = Color(1.0, 0.25, 0.18)
			sprite.scale = Vector2(1.8, 0.35)
		"flame":
			sprite.modulate = Color(1.0, 0.48, 0.1)
			sprite.scale = Vector2(1.5, 1.5)
		"plasma":
			sprite.modulate = Color(0.35, 1.0, 0.48)
			sprite.scale = Vector2(1.35, 1.35)
		"fireball":
			sprite.modulate = Color(1.0, 0.32, 0.05)
			sprite.scale = Vector2(2.1, 2.1)
		"pellet":
			sprite.scale = Vector2(0.65, 0.65)
		_:
			sprite.modulate = Color(0.95, 0.88, 0.55)


func _flash(from: Vector2, to: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = color
	var host := get_tree().current_scene
	if host == null:
		return
	line.points = PackedVector2Array([host.to_local(from), host.to_local(to)])
	host.add_child(line)
	get_tree().create_timer(0.06).timeout.connect(line.queue_free)


func _flash_disk(at: Vector2, radius: float, color: Color) -> void:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		var angle := TAU * float(i) / 12.0
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	poly.polygon = pts
	poly.color = color
	var host := get_tree().current_scene
	if host == null:
		return
	poly.position = host.to_local(at)
	host.add_child(poly)
	get_tree().create_timer(0.16).timeout.connect(poly.queue_free)
