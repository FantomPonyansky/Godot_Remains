extends Node

## World.quake / Camera.calc: an impulse offsets the view, then each tick it flips
## sign and shrinks to 0.5-0.8 of itself (80% of ticks), snapping to 0 under 1 px.
## The offset is clamped to 20 px a side. Location.earthQuake keeps the strongest
## quake for its ticks; units read quake_left() to toss whoever stands on the floor.

const TPS := 30.0
const LIMIT := 20.0

## Camera.otryv lean from keyLook (scripts/quick_keys.gd), added to the shake.
var look := Vector2.ZERO
var _q := Vector2.ZERO
var _left := 0
var _power := 0.0
var _acc := 0.0


## Location.earthQuake(n): a quake of amount n lasting ticks.
func add(amount: float, ticks: int) -> void:
	if ticks > _left or amount > _power:
		_left = maxi(_left, ticks)
		_power = maxf(_power, amount)
		quake(amount, amount * 0.25)


## World.quake(x, y): one impulse. A sky room never shakes.
func quake(x: float, y: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.get("sky_mode") == true:
		return
	if not UiSettings.quake_cam():
		return
	_q.x = clampf(_q.x + x, -LIMIT, LIMIT)
	_q.y = clampf(_q.y + y, -LIMIT, LIMIT)


func quake_left() -> int:
	return _left


func _process(delta: float) -> void:
	_acc += delta
	var step := 1.0 / TPS
	while _acc >= step:
		_acc -= step
		_tick()
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		cam.offset = _q + look


func _tick() -> void:
	if _left > 0:
		_left -= 1
		if _left == 0:
			_power = 0.0
	for axis in 2:
		if _q[axis] != 0.0:
			if randf() > 0.2:
				_q[axis] *= -randf_range(0.5, 0.8)
			if absf(_q[axis]) < 1.0:
				_q[axis] = 0.0
