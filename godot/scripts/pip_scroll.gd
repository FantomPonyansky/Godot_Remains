extends Control

## visPipOptItem scr: the horizontal ScrollBar of a volume row, 0..100.
## The arrows step by 1 and a track click jumps the thumb there.

signal moved(value: int)

const GREEN := Color("00ff99")
const DARK := Color(0.0, 0.12, 0.08, 0.85)
const ARROW := 12.0
const THUMB := 14.0

var value := 0
var _drag := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func set_value(v: int) -> void:
	value = clampi(v, 0, 100)
	queue_redraw()


func _draw() -> void:
	var h := size.y
	var track := Rect2(ARROW, h * 0.5 - 3.0, size.x - ARROW * 2.0, 6.0)
	draw_rect(track, DARK)
	draw_rect(track, GREEN.darkened(0.45), false, 1.0)
	for side in 2:
		var box := Rect2(0.0 if side == 0 else size.x - ARROW, 1.0, ARROW, h - 2.0)
		draw_rect(box, DARK)
		draw_rect(box, GREEN, false, 1.0)
		var cx := box.get_center().x
		var cy := box.get_center().y
		var d := -1.0 if side == 0 else 1.0
		draw_colored_polygon(PackedVector2Array([Vector2(cx + 2.0 * d, cy), Vector2(cx - 2.0 * d, cy - 3.0), Vector2(cx - 2.0 * d, cy + 3.0)]), GREEN)
	var x := track.position.x + (track.size.x - THUMB) * float(value) / 100.0
	var thumb := Rect2(x, 2.0, THUMB, h - 4.0)
	draw_rect(thumb, DARK)
	draw_rect(thumb, GREEN, false, 1.0)
	draw_line(Vector2(thumb.get_center().x - 3.0, thumb.get_center().y), Vector2(thumb.get_center().x + 3.0, thumb.get_center().y), GREEN, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		_drag = mb.pressed
		if mb.pressed:
			if mb.position.x < ARROW:
				_put(value - 1)
			elif mb.position.x > size.x - ARROW:
				_put(value + 1)
			else:
				_track(mb.position.x)
		accept_event()
	elif event is InputEventMouseMotion and _drag:
		_track((event as InputEventMouseMotion).position.x)
		accept_event()


func _track(px: float) -> void:
	var span := size.x - ARROW * 2.0 - THUMB
	_put(int(round((px - ARROW - THUMB * 0.5) / span * 100.0)))


func _put(v: int) -> void:
	v = clampi(v, 0, 100)
	if v == value:
		return
	set_value(v)
	moved.emit(value)
