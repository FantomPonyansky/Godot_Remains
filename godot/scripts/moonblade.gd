extends CharacterBody2D

## Pet moon from units.xml and UnitPet. No weapon, so it rams (attKorp).
## HP moonHP 70 × spellPower. Damage moonDam 15 × spellPower, then × (0.8–1.2).
## tipdam 1 is DAM_CUT. Follows 120px behind and 80px above the caster.
## Charges at run 15 px/tick inside 400px. Body hits wait neujazMax (20) ticks.

const FOLLOW_SPEED := 7.0 * 30.0
const CHARGE_SPEED := 15.0 * 30.0
const SIGHT := 400.0
const RECOVER := 15.0 / 30.0
const HIT_GAP := 20.0 / 30.0

var hp: float = 70.0
var max_hp: float = 70.0
var blade_damage: float = 15.0
var caster: Node2D
var _recover: float = 0.0
var _hit_until: Dictionary = {}
var _charging: bool = false
var _visual: Polygon2D


func _ready() -> void:
	add_to_group("moonblade")
	collision_layer = 2
	collision_mask = 1
	z_index = 3


func setup(owner: Node2D, pet_hp: float, pet_damage: float) -> void:
	caster = owner
	max_hp = pet_hp
	hp = pet_hp
	blade_damage = pet_damage
	var shape_node := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(38, 38)
	shape_node.shape = box
	shape_node.position = Vector2(0, -19)
	add_child(shape_node)
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(0, -28),
		Vector2(10, -8),
		Vector2(0, 8),
		Vector2(-10, -8),
	])
	_visual.color = Color(0.75, 0.9, 1.0, 0.9)
	_visual.position = Vector2(0, -19)
	add_child(_visual)


func heal_full() -> void:
	hp = max_hp


func take_hit(amount: int = 15, type: String = "") -> void:
	if type != "":
		var resistances := preload("res://scripts/resistances.gd")
		resistances.apply(self, float(amount), type)
		return
	hp -= amount
	if hp <= 0.0:
		queue_free()


func _physics_process(delta: float) -> void:
	if caster == null or not is_instance_valid(caster):
		queue_free()
		return
	if GameState.paused:
		return
	_recover = maxf(0.0, _recover - delta)
	var aim := _follow_point()
	_charging = false
	var foe := _nearest_foe()
	if foe != null and _recover <= 0.0:
		aim = foe.global_position + Vector2(0, -28)
		_charging = true
	var speed := CHARGE_SPEED if _charging else FOLLOW_SPEED
	var delta_to := aim - global_position
	if delta_to.length() > 8.0:
		velocity = delta_to.normalized() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if _charging and foe != null:
		_try_hit(foe)
	if _visual:
		var spin := 30.0 if _charging else 3.0
		_visual.rotation += deg_to_rad(spin) * 30.0 * delta


func _follow_point() -> Vector2:
	var face := 1.0
	if "facing" in caster:
		face = float(caster.facing)
	# UnitPet.getFlyPoint: 120px opposite facing, 80px above the feet.
	return caster.global_position + Vector2(-face * 120.0, -80.0)


func _nearest_foe() -> Node2D:
	var best: Node2D = null
	var best_d := SIGHT
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is Node2D or not is_instance_valid(node):
			continue
		var body := node as Node2D
		var dist := global_position.distance_to(body.global_position)
		if dist < best_d:
			best_d = dist
			best = body
	return best


func _try_hit(foe: Node2D) -> void:
	var reach := global_position.distance_to(foe.global_position)
	if reach > 42.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var key := foe.get_instance_id()
	if float(_hit_until.get(key, 0.0)) > now:
		return
	_hit_until[key] = now + HIT_GAP
	_recover = RECOVER
	var sila := randf() * 0.4 + 0.8
	var dealt := blade_damage * sila
	if foe.has_method("take_hit"):
		foe.take_hit(maxi(1, int(round(dealt))), "DAM_CUT")
		SfxBank.play("hit")
	# attKorp then damages the pet for 2% as internal. Round stays under 1 at base dam.
	hp -= blade_damage * 0.02
	if hp <= 0.0:
		queue_free()
