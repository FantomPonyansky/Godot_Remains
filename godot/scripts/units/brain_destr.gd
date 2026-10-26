extends UnitBrain

## UnitDestr tr 1 (the pylon, visualStolp): a boss target with no AI. It hums while
## standing. noDestr: destroyed it stays as a wreck (osn frame 2) that throws
## an explw blast every 10 ticks; its die script still runs.

var wrecked := false
var t_part := 10


func configure() -> void:
	if str(u.get_meta("turn", "")) != "":
		storona = 1.0 if float(u.get_meta("turn")) > 0.0 else -1.0
	else:
		storona = 1.0 if rnd() else -1.0
	u.set("fixed_post", true)
	u.set("_can_lift", false)


func on_die() -> bool:
	if not (tr == 1 or id == "destr1"):
		return false
	if wrecked:
		return true
	wrecked = true
	sound(str(row.get("snd", {}).get("die", "")))
	var host := u.get_tree().get_first_node_in_group("land_props")
	if host != null and host.has_method("run_actions"):
		host.run_actions(u.get("die_actions"))
	GameState.enemy_defeated(int(u.get("points")))
	u.hp = 0
	u.collision_layer = 0
	u.remove_from_group("enemies")
	return true


func control() -> void:
	if not (tr == 1 or id == "destr1"):
		return
	t_part -= 1
	if t_part == 0:
		t_part = 10
	var b := body()
	var at := u.global_position + Vector2((randf() - 0.5) * b.x, -randf() * b.y)
	if not wrecked:
		emit_part("lift", at)
	elif t_part == 3:
		emit_part("explw", at)


func forces() -> void:
	vel = Vector2.ZERO


func move_body() -> void:
	pass


func after_move(_pushed: Vector2) -> void:
	vel = Vector2.ZERO


func animate() -> void:
	anim("die" if wrecked else "stay")
