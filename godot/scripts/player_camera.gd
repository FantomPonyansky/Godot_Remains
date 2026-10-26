extends Camera2D

## Port camera (PORT_RULES): the player moves freely inside a circle of
## FREE_ZONE screen heights around the view centre; past its edge the view
## catches up at CATCH_UP per second of the overshoot, so the farther out,
## the faster. Offsets (look-ahead, Camera.showOn) still ride on top.

const FREE_ZONE := 1.0 / 6.0
const HARD_LIMIT := 0.4
const CATCH_UP := 4.0
const SNAP_JUMP := 400.0

var _last_target := Vector2.INF


func _ready() -> void:
	top_level = true
	position_smoothing_enabled = false
	snap()


func snap() -> void:
	var host := get_parent() as Node2D
	if host == null:
		return
	global_position = host.global_position
	_last_target = host.global_position
	_hold_in_limits()
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var host := get_parent() as Node2D
	if host == null:
		return
	var target := host.global_position
	if _last_target == Vector2.INF or target.distance_to(_last_target) > SNAP_JUMP:
		snap()
		return
	_last_target = target
	var view_h := get_viewport_rect().size.y / maxf(zoom.y, 0.01)
	var to := target - global_position
	var dist := to.length()
	var free := view_h * FREE_ZONE
	if dist <= free:
		_hold_in_limits()
		return
	var dir := to / dist
	var over := dist - free
	global_position += dir * over * minf(1.0, CATCH_UP * delta)
	var hard := view_h * HARD_LIMIT
	if target.distance_to(global_position) > hard:
		global_position = target - dir * hard
	_hold_in_limits()


## The view stops at the limits (map borders, a back room); the centre stops
## with it, so walking back moves the view at once.
func _hold_in_limits() -> void:
	var half := get_viewport_rect().size * 0.5 / Vector2(maxf(zoom.x, 0.01), maxf(zoom.y, 0.01))
	var lo := Vector2(limit_left, limit_top) + half
	var hi := Vector2(limit_right, limit_bottom) - half
	var at := global_position
	at.x = clampf(at.x, lo.x, hi.x) if lo.x <= hi.x else (lo.x + hi.x) * 0.5
	at.y = clampf(at.y, lo.y, hi.y) if lo.y <= hi.y else (lo.y + hi.y) * 0.5
	global_position = at
