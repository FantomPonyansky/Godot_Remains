extends AnimatableBody2D

## A shelf box (platform2 / platform3) and its Interact.move from a <move> kid:
## dx / dy in tiles from where it was placed, tstay ticks standing at each end,
## tmove ticks travelling, on = moving from the start.
## moveSt: 0 stands, 1 goes to the end, 2 back to the start, 3 to the other
## end, 4 shuttles. Commands (scripts, allact): stop, move, pop, move1-3.

const TPS := 30.0
const TILE := 40.0
const LIP := 10.0
const ART := "res://assets/sprites/props/"
const MOVE_SND := "res://assets/sfx/move.mp3"
const STOP_AT := 5.5
const _Flags := preload("res://scripts/map/room_flags.gd")

var beg := Vector2.ZERO
var end := Vector2.ZERO
var t_stay := 10.0
var t_mov := 100.0
var move_st := 0
var is_move := false
var _t := 0.0
var _dt := 1.0
var _moving := false
var _snd: AudioStreamPlayer


func setup(row: Dictionary) -> void:
	var feet: Array = row.get("feet", [0, 0])
	beg = Vector2(float(feet[0]), float(feet[1]))
	end = beg
	position = beg
	collision_layer = 64
	collision_mask = 0
	sync_to_physics = true
	set_meta("blocks_sight", false)
	set_meta("sight_transparency", 1.0)
	set_meta("id", str(row.get("id", "")))
	set_meta("uid", str(row.get("uid", "")))
	var attrs: Dictionary = row.get("attrs", {})
	if attrs.has("allid"):
		set_meta("allid", str(attrs.allid))
	var room: Array = row.get("room", [0, 0])
	set_meta("room_x", int(room[0]))
	set_meta("room_y", int(room[1]))
	var w := float(row.get("w", 120.0))
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(w, LIP)
	shape.shape = box
	shape.position = Vector2(0, -float(row.get("h", TILE)) + LIP * 0.5)
	shape.one_way_collision = true
	shape.one_way_collision_margin = 8.0
	add_child(shape)
	_add_art(str(row.get("id", "")))
	var mv: Dictionary = row.get("move", {})
	if mv.is_empty():
		return
	is_move = true
	end = beg + Vector2(_num(mv.get("dx"), 0.0), _num(mv.get("dy"), 0.0)) * TILE
	t_stay = _num(mv.get("tstay"), t_stay)
	t_mov = maxf(_num(mv.get("tmove"), t_mov), 1.0)
	if mv.has("on"):
		move_st = 4


## Interact.command: stop, move, pop, move1, move2, move3. True when handled.
func script_command(act: String, _val: String = "") -> bool:
	if not is_move:
		return false
	match act:
		"stop":
			move_st = 0
		"move":
			move_st = 4
		"pop":
			move_st = 4 if move_st == 0 else 0
		"move1", "move2", "move3":
			move_to(int(act.substr(4)))
		_:
			return false
	return true


## Interact.moveTo.
func move_to(n: int) -> void:
	move_st = n
	var at_start := _t >= 0.0 and _t < t_stay
	var at_end := _t >= t_stay + t_mov and _t < t_stay + t_mov + t_stay
	match n:
		1:
			if at_start:
				_t = t_stay
			if at_end:
				move_st = 0
		2:
			if at_start:
				move_st = 0
			if at_end:
				_t = t_stay + t_mov + t_stay
		3:
			if at_start:
				_t = t_stay
			if at_end:
				_t = t_stay + t_mov + t_stay


## land_memory: moveSt and the move timer, so a switched lift stays where it was left.
func memory_state() -> Dictionary:
	if not is_move:
		return {}
	return {"st": move_st, "t": _t}


func load_memory(state: Dictionary) -> void:
	if not is_move:
		return
	move_st = int(state.get("st", move_st))
	_t = float(state.get("t", _t))
	position = _at()
	_moving = false


func _physics_process(delta: float) -> void:
	if not is_move or move_st <= 0:
		return
	var k := delta * TPS
	if _dt < 1.0:
		_dt = minf(_dt + 0.1 * k, 1.0)
	var was := _moving
	position = _at()
	if was != _moving:
		_sound(_moving)
	_t += _dt * k
	if _t >= (t_stay + t_mov) * 2.0:
		_t = 0.0


## Interact.sound: "move" from the start when it sets off, from 5.5 s (the stop
## tail) when it halts; the step only runs in the player's room.
func _sound(start: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or _Flags.cell_of(player.global_position) != Vector2i(int(get_meta("room_x", 0)), int(get_meta("room_y", 0))):
		return
	if _snd == null:
		_snd = AudioStreamPlayer.new()
		_snd.stream = load(MOVE_SND) as AudioStream
		add_child(_snd)
	if _snd.stream == null:
		return
	_snd.stop()
	_snd.play(0.0 if start else minf(STOP_AT, _snd.stream.get_length()))


## Interact.move: where the box is at _t, and the stop rules of moveSt 1-3.
func _at() -> Vector2:
	var f := 0.0
	var cycle := (t_stay + t_mov) * 2.0
	if _t < t_stay:
		_moving = false
		if move_st == 2 or move_st == 3:
			move_st = 0
	elif _t < t_stay + t_mov:
		_moving = true
		f = (_t - t_stay) / t_mov
	elif _t < t_stay + t_mov + t_stay:
		_moving = false
		f = 1.0
		if move_st == 1 or move_st == 3:
			move_st = 0
	elif _t < cycle:
		_moving = true
		f = (cycle - _t) / t_mov
	return beg + (end - beg) * f


func _add_art(id: String) -> void:
	var path := ART + id + ".png"
	if not ResourceLoader.exists(path):
		return
	var spr := Sprite2D.new()
	spr.texture = load(path) as Texture2D
	spr.centered = false
	var anchors: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART + "platform_anchors.json"))
	var a: Array = (anchors as Dictionary).get(id, [60, 40]) if anchors is Dictionary else [60, 40]
	spr.offset = -Vector2(float(a[0]), float(a[1]))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)


static func _num(v: Variant, fallback: float) -> float:
	if v == null or not str(v).is_valid_float():
		return fallback
	return float(str(v))
