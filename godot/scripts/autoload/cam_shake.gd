extends Node

## World.quake / Camera.calc: an impulse offsets the view, then each tick it flips
## sign and shrinks to 0.5-0.8 of itself (80% of ticks), snapping to 0 under 1 px.
## The offset is clamped to 20 px a side. Location.earthQuake keeps the strongest
## quake for its ticks; units read Fx.quake_left() to toss whoever stands on the floor.

const LIMIT := 20.0

## Camera.otryv lean from keyLook (scripts/quick_keys.gd), added to the shake.
var look := Vector2.ZERO
var _q := Vector2.ZERO
var _left := 0
var _power := 0.0


## Location.earthQuake(n): a quake of amount n lasting ticks.
func add(amount: float, ticks: int) -> void:
	if ticks > _left or amount > _power:
		_left = maxi(_left, ticks)
		_power = maxf(_power, amount)
		quake(amount, amount * 0.25)


## World.quake(x, y): one impulse. A sky room never shakes.
func quake(x: float, y: float) -> void:
	var player := Run.local_player()
	if player != null and player.get("sky_mode") == true:
		return
	if not UiSettings.quake_cam():
		return
	_q.x = clampf(_q.x + x, -LIMIT, LIMIT)
	_q.y = clampf(_q.y + y, -LIMIT, LIMIT)


func quake_left() -> int:
	return _left


func _ready() -> void:
	Sim.register(Sim.Phase.PRESENTATION, _sim_tick)
	if not Fx.shaken.is_connected(_on_fx_shake):
		Fx.shaken.connect(_on_fx_shake)
	Fx.bind_quake(quake_left)


func _on_fx_shake(amount: float, _at: Vector2, opts: Dictionary, _eid: String, _local: bool) -> void:
	if opts.has("ticks"):
		add(amount, int(opts.ticks))
	else:
		quake(float(opts.get("x", 0.0)), float(opts.get("y", 0.0)))


func _exit_tree() -> void:
	Sim.unregister(_sim_tick)


func _process(_delta: float) -> void:
	_apply()


func _sim_tick() -> void:
	if Sim.paused():
		return
	_tick()
	_apply()


func _apply() -> void:
	var cam := Run.camera()
	if cam != null:
		cam.offset = _q + look


func _tick() -> void:
	if _left > 0:
		_left -= 1
		if _left == 0:
			_power = 0.0
	for axis in 2:
		if _q[axis] != 0.0:
			if Rng.randf(&"fx") > 0.2:
				_q[axis] *= -Rng.randf_range(&"fx", 0.5, 0.8)
			if absf(_q[axis]) < 1.0:
				_q[axis] = 0.0
