class_name UnitGun
extends RefCounted

## Weapon.actions / attack / shoot for a class weapon held by a UnitBrain:
## the barrel turns at drot toward the target (or forceRot), and shots leave
## along the barrel. Times are ticks.

const _WeaponVis := preload("res://scripts/weapon_vis.gd")
const SIXTH := PI / 6.0
const FIVE_SIXTH := PI * 5.0 / 6.0

var b: UnitBrain
var w: Dictionary
var id := ""
var rot := 0.0
var force_rot := 0.0
var find_cel := true
var fixed_to_owner := false
var drot := 0.0
var drot_mult := 1.0
var fix_rot := 0
var rapid := 1
var dkol := 0
var prep := 0
var cap := 0
var rounds := 0
var rashod := 1
var reload := 0
var reload_mult := 1.0
var recharg := 0
var auto := false
var length := 0.0
var t_attack := 0
var t_prep := 0
var t_reload := 0
var t_rech := 0
var ready := false
var is_shoot := false
var shots := 0
## Weapon.vis drawn by the brain (UnitBrain.make_gun_vis), its clip, the shots it has shown,
## and the frames left on its "shoot" clip.
var vis: Sprite2D
var vis_clip: RefCounted
var vis_shots := 0
var t_shoot := 0
var floating := false


func _init(brain: UnitBrain, row: Dictionary) -> void:
	b = brain
	w = row
	id = str(row.get("id", ""))
	rapid = maxi(1, int(row.get("rapid", 1)))
	dkol = int(row.get("burst", 0))
	prep = int(row.get("prep", 0))
	cap = int(row.get("mag", 0))
	rounds = cap
	rashod = maxi(1, int(row.get("ammo_per_shot", 1)))
	reload = int(row.get("reload", 0))
	recharg = int(row.get("recharg", 0))
	auto = bool(row.get("auto", false))
	length = float(row.get("length", 0.0))
	# weapons.xml gives drot in degrees per tick.
	drot = deg_to_rad(float(row.get("drot", 0.0)))
	rot = 0.0 if b.storona >= 0.0 else PI


## Where the gun is. Weapon.actions with krep 0 eases it to weaponX / weaponY by 1/5 a
## tick; the port keeps it on the mount (PORT_RULES.md, boss guns).
func origin() -> Vector2:
	return b.weapon_pos()


func actions() -> void:
	var at := origin()
	var rot2 := force_rot
	if find_cel:
		if fixed_to_owner:
			rot2 = atan2(b.cel.y - at.y, absf(b.cel.x - at.x) * b.storona)
		else:
			rot2 = atan2(b.cel.y - at.y, b.cel.x - at.x)
	ready = false
	var step := drot * drot_mult
	if step <= 0.0:
		rot = rot2
		ready = true
	else:
		var diff := absf(rot - rot2)
		if diff > PI:
			if diff > TAU - step:
				rot = rot2
				ready = true
			elif rot > rot2:
				rot += step
			else:
				rot -= step
		else:
			if rot2 - rot > step:
				rot += step
			elif rot2 - rot < -step:
				rot -= step
			else:
				rot = rot2
				ready = true
		if rot > PI:
			rot -= TAU
		if rot < -PI:
			rot += TAU
	match fix_rot:
		1:
			if rot < -SIXTH and rot > -PI * 0.5:
				rot = -SIXTH
			if rot > -FIVE_SIXTH and rot <= -PI * 0.5:
				rot = -FIVE_SIXTH
		2:
			rot = clampf(rot, -SIXTH, SIXTH)
		3:
			if rot > 0.0 and rot < FIVE_SIXTH:
				rot = FIVE_SIXTH
			if rot <= 0.0 and rot > -FIVE_SIXTH:
				rot = -FIVE_SIXTH
	if (dkol <= 0 and t_attack == rapid) or (dkol > 0 and t_attack > rapid and t_attack % rapid == 0):
		shoot()
	if t_attack > 0:
		t_attack -= 1
	if t_prep > 0:
		t_prep -= 1
	if recharg > 0 and rounds < cap and t_attack == 0:
		t_rech -= 1
		if t_rech <= 0:
			rounds += 1
			t_rech = recharg
	if t_attack == 0 and t_reload > 0:
		t_reload -= 1
		if t_reload == 10:
			rounds = cap


func attack(wait_ready: bool = false) -> bool:
	if wait_ready and not ready:
		return false
	if cap > 0 and rounds < rashod:
		init_reload()
		return false
	if t_prep < prep + 10:
		t_prep += 2
	if t_prep >= prep and t_attack <= 0 and t_reload <= 0:
		t_attack = rapid if dkol <= 0 else rapid * (dkol + 1)
		if cap == 1:
			init_reload()
	return true


func init_reload() -> void:
	if cap <= 0 or recharg > 0 or t_reload > 0:
		return
	t_reload = int(round(reload * reload_mult)) + 10


func dir() -> Vector2:
	return Vector2.from_angle(rot)


func shoot() -> void:
	if cap > 0 and rounds < rashod:
		return
	if cap > 0:
		rounds -= rashod
		if rounds < rashod:
			init_reload()
	var at := origin()
	var start := at + dir() * minf(length, 40.0)
	# Weapon.getBulXY: from the vis clip's `emit` point.
	if vis != null and vis.is_visible_in_tree():
		start = vis.to_global(_WeaponVis.emit(id))
	start = _clear(at, start)
	var reach := maxf(at.distance_to(b.cel), 60.0) if find_cel else 200.0
	var target := start + dir() * reach
	var n := maxi(1, int(w.get("pellets", 1)))
	var spread := float(w.get("spread", 0.0))
	for _i in n:
		b.u.call("_launch_one", start, target, w, bool(b.u.get("_friendly")), false, spread, 0.0)
	is_shoot = true
	shots += 1


func _clear(from: Vector2, to: Vector2) -> Vector2:
	var space := b.u.get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
	ray.exclude = [b.u.get_rid()]
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return to
	return Vector2(hit["position"]) - (to - from).normalized() * 2.0
