extends UnitBrain

## UnitScythe: a spectral blade that passes through walls. A free one flies at where
## the player was, speeding up 5% a tick, and dies leaving the room; a bound one
## circles its summoner 200 px out. Both start cutting after 60 ticks.

const BIND_RAD := 200.0
const BIND_KOEF := 0.05

var napr := -1.0
var dr := 0.0
var t := 0
var skor := 1.5
var bind: Node2D = null
var bind_n := 0
var origin := Vector2.ZERO
var alpha := 0.0


func configure() -> void:
	brake = accel / 2.0
	flips_sprite = false
	u.set("_can_lift", false)
	u.set("_flying", true)


func ready() -> void:
	u.collision_mask = 0
	u.set("_detect_delay", 0.0)
	origin = room_origin()
	if u.has_meta("bind") and u.get_meta("bind") is Node2D:
		bind = u.get_meta("bind")
	bind_n = int(u.get_meta("bind_n", 0))
	var p := player_node()
	if p != null:
		var d := p.global_position - u.global_position
		napr = atan2(d.x, d.y)
	u.anim.position = Vector2(0.0, -body().y * 0.5)


func forces() -> void:
	pass


func move_body() -> void:
	if bind != null:
		if not is_instance_valid(bind) or bool(bind.get("_dead")):
			u.call("_begin_death")
			return
		var bc: Vector2 = bind.global_position - Vector2(0.0, float(bind.get("body_size").y) * 0.5)
		var a := t * BIND_KOEF + TAU * bind_n / 6.0
		u.global_position = bc - Vector2(sin(a), cos(a)) * BIND_RAD + Vector2(0.0, body().y * 0.5)
		return
	u.global_position += vel * u.get_physics_process_delta_time() * TPS
	var rel := u.global_position - origin
	if rel.x <= 0.0 or rel.y <= 0.0 or rel.x >= 48 * 40 or rel.y >= 25 * 40:
		u.call("_begin_death")


func after_move(_pushed: Vector2) -> void:
	pass


func control() -> void:
	t += 1
	if bind == null:
		skor *= 1.05
		vel = Vector2(sin(napr), cos(napr)) * skor
	if t > 60:
		att_korp(player_node())


func animate() -> void:
	if dr < 30.0:
		dr += 0.5
	u.anim.rotation += deg_to_rad(dr)
	alpha = minf(1.0, alpha + 0.05)
	u.anim.modulate.a = alpha
	anim("stay")
