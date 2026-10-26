extends UnitBrain

## UnitBloatEmitter: while it sees a target it hatches a unit every 100 ticks, five alive
## at most, and five more spill out when it is destroyed. The ant nest (eant) hatches ants
## 40 px above its feet. The bloatsprite nest (ebloat) hatches bloats at its feet: bloat0
## on an easy land, a random kind from Location.randomCid('bloat') from land difficulty 4.

const ANTS := ["ant1", "ant2", "ant3"]
const MAX_CHILD := 5
const Registry := preload("res://scripts/map/land_registry.gd")

var emit_t := 0
var children: Array = []
var emit_id := "bloat"


func configure() -> void:
	flips_sprite = false
	u.set("fixed_post", true)
	emit_id = "ant" if id == "eant" else "bloat"


func forces() -> void:
	vel = Vector2.ZERO


func move_body() -> void:
	pass


func after_move(_pushed: Vector2) -> void:
	vel = Vector2.ZERO


func _land() -> Dictionary:
	return Registry.land(Travel.cur_land_id)


## Location.randomCid('bloat').
func _bloat_tr() -> int:
	var land := _land()
	var dif := float(Registry.int_of(land.get("dif"), 0))
	if Registry.int_of(land.get("biom"), 0) == 5:
		return int(randf() * 3.0 + 4.0)
	if dif >= 10.0:
		return int(randf() * 5.0)
	if dif >= 4.0:
		return int(randf() * 4.0)
	if dif >= 2.0:
		return int(randf() * 3.0)
	return 0


func emit(count_child: bool) -> void:
	var un: Node
	if emit_id == "ant":
		un = spawn_unit(ANTS[randi() % ANTS.size()], u.global_position + Vector2(0.0, -40.0))
	else:
		var tr_b := 0
		if float(Registry.int_of(_land().get("dif"), 0)) > 3.0:
			tr_b = _bloat_tr()
		un = spawn_unit("bloat%d" % tr_b, u.global_position)
	if un != null and count_child:
		children.append(un)


func expl() -> void:
	new_part("schep" if emit_id == "ant" else "shmatok", 16, 2)


func drop_loot() -> void:
	for _i in 5:
		emit(false)


func control() -> void:
	if not enemy_act():
		return
	if ai_tch > 0:
		ai_tch -= 1
	if ai_tch == 0:
		ai_tch = 10
		ai_state = 2 if find_cel() else 1
	children = children.filter(func(c: Variant) -> bool: return is_instance_valid(c) and not bool((c as Node).get("_dead")))
	if emit_t > 0:
		emit_t -= 1
	elif ai_state == 2 and children.size() < MAX_CHILD:
		emit(true)
		emit_t = 100
	if cel_unit != null:
		att_korp(cel_unit)


func animate() -> void:
	anim("stay")
