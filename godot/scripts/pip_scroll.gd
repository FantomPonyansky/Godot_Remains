extends Control

## visPipOptItem scr: the horizontal ScrollBar of a volume row, 0..100.
## The arrows step by 1 and a track click jumps the thumb there. Drawn with
## the VScrollBar skins of the project theme turned a quarter (fl.controls
## ScrollBar direction horizontal is the vertical bar rotated).

signal moved(value: int)

const THUMB := 20.0

var value := 0
var _drag := false
var _hover := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_exited.connect(func() -> void:
		_hover = ""
		queue_redraw())


func set_value(v: int) -> void:
	value = clampi(v, 0, 100)
	queue_redraw()


## Arrow length along the bar: the decrement skin at the bar's thickness.
func _arrow() -> float:
	var tex := get_theme_icon("decrement", "VScrollBar")
	if tex == null or tex.get_width() <= 0:
		return size.y
	return size.y * float(tex.get_height()) / float(tex.get_width())


func _thumb_x() -> float:
	var a := _arrow()
	return a + (size.x - a * 2.0 - THUMB) * float(value) / 100.0


func _draw() -> void:
	# Vertical frame: u across (size.y wide), v along (size.x long), up = left.
	draw_set_transform(Vector2(0.0, size.y), -PI * 0.5)
	var w := size.y
	var l := size.x
	var a := _arrow()
	var track := get_theme_stylebox("scroll", "VScrollBar")
	if track != null:
		draw_style_box(track, Rect2(0.0, a, w, l - a * 2.0))
	var dec := get_theme_icon("decrement_pressed" if _drag and _hover == "dec" else ("decrement_highlight" if _hover == "dec" else "decrement"), "VScrollBar")
	var inc := get_theme_icon("increment_pressed" if _drag and _hover == "inc" else ("increment_highlight" if _hover == "inc" else "increment"), "VScrollBar")
	if dec != null:
		draw_texture_rect(dec, Rect2(0.0, 0.0, w, a), false)
	if inc != null:
		draw_texture_rect(inc, Rect2(0.0, l - a, w, a), false)
	var grab := "grabber_pressed" if _drag and _hover == "thumb" else ("grabber_highlight" if _hover == "thumb" else "grabber")
	var thumb := get_theme_stylebox(grab, "VScrollBar")
	if thumb != null:
		draw_style_box(thumb, Rect2(0.0, _thumb_x(), w, THUMB))
	draw_set_transform(Vector2.ZERO)


func _part(px: float) -> String:
	var a := _arrow()
	if px < a:
		return "dec"
	if px > size.x - a:
		return "inc"
	var tx := _thumb_x()
	return "thumb" if px >= tx and px <= tx + THUMB else "track"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		_drag = mb.pressed
		if mb.pressed:
			match _part(mb.position.x):
				"dec":
					_put(value - 1)
				"inc":
					_put(value + 1)
				_:
					_hover = "thumb"
					_track(mb.position.x)
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion:
		var px := (event as InputEventMouseMotion).position.x
		if _drag and _hover == "thumb":
			_track(px)
		else:
			var was := _hover
			_hover = _part(px)
			if _hover != was:
				queue_redraw()
		accept_event()


func _track(px: float) -> void:
	var a := _arrow()
	var span := size.x - a * 2.0 - THUMB
	_put(int(round((px - a - THUMB * 0.5) / span * 100.0)))


func _put(v: int) -> void:
	v = clampi(v, 0, 100)
	if v == value:
		return
	set_value(v)
	moved.emit(value)
