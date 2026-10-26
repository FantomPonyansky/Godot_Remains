extends Node

## Button prompts for the last-used device. Keyboard and mouse show the bound
## key; a gamepad shows a bracketed label ([A], [LB], [LT] ...). The original
## has no gamepad support and no glyph art, so labels are text.
## The device flips on a key, mouse button, deliberate mouse move, pad button
## or a stick/trigger push. Small mouse nudges while on a pad are ignored.

signal device_changed(pad: bool)

const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓",
	JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →",
	JOY_BUTTON_MISC1: "Share",
}
## Hint ids for UI controls that are not InputMap actions: [keyboard, pad].
const UI := {
	"accept": ["Enter", "A"],
	"back": ["Esc", "B"],
	"alt": ["@rmb", "X"],
	"tabs": ["", "LB]/[RB"],
	"pages": ["PgUp]/[PgDn", "LT]/[RT"],
	"move": ["↑↓", "D-pad"],
	"adjust": ["←→", "←→"],
	"fav": ["", "Y"],
}
const PAD_ACTIVE := 0.5
const MOUSE_WAKE := 24.0
const MOUSE_DECAY := 90.0

var pad := false
var _wake := 0.0
var _last_motion := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.has_meta("ui_nav_click"):
		return
	if event is InputEventKey:
		if event.pressed:
			_set_pad(false)
	elif event is InputEventMouseButton:
		if event.pressed:
			_set_pad(false)
	elif event is InputEventMouseMotion:
		accept_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventJoypadButton:
		if event.pressed:
			_set_pad(true)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if _axis_on(motion.axis, motion.axis_value, PAD_ACTIVE):
			_set_pad(true)


func _process(delta: float) -> void:
	_wake = maxf(0.0, _wake - MOUSE_DECAY * delta)
	# Screens may consume pad events before this autoload sees them.
	if not pad and _pad_held():
		_set_pad(true)


## True when this mouse motion should count. While a pad was last used, a
## nudge under MOUSE_WAKE px is dropped; a real move switches to the mouse.
func accept_mouse_motion(motion: InputEventMouseMotion) -> bool:
	var id := motion.get_instance_id()
	if id == _last_motion:
		return not pad
	_last_motion = id
	if not pad:
		return true
	if Engine.get_process_frames() - UiNav.warped_frame <= 2:
		return true
	_wake += motion.relative.length()
	if _wake < MOUSE_WAKE:
		return false
	_set_pad(false)
	return true


## "[E]" / "[A]" for an InputMap action on the current device. Falls back to
## the other device when nothing is bound for this one.
func action(name: String) -> String:
	var text := action_plain(name)
	return "[%s]" % text if text != "" else ""


func action_plain(name: String) -> String:
	if not InputMap.has_action(name):
		return ""
	var mine := ""
	var other := ""
	var stick := ""
	for event in InputBindings.events_of(name):
		var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
		var text := event_label(event)
		if text == "":
			continue
		if is_pad and event is InputEventJoypadMotion and not _is_trigger(event as InputEventJoypadMotion):
			if stick == "":
				stick = text
			continue
		if InputBindings.is_hold_event(name, event):
			text = "%s (%s)" % [text, OriginalLines.gui("hold")]
		if is_pad == pad:
			if mine == "":
				mine = text
		elif other == "":
			other = text
	if mine == "" and pad and stick != "":
		return stick
	return mine if mine != "" else other


## Hint label for a UI control id (accept, back, alt, tabs, pages, move,
## adjust). Empty when the current device has no such control.
func ui(id: String) -> String:
	var pair: Array = UI.get(id, ["", ""])
	var text := str(pair[1] if pad else pair[0])
	if text.begins_with("@"):
		text = OriginalLines.key(text.substr(1))
	return "[%s]" % text if text != "" else ""


## "[A] text   [B] text". Each pair is [ui id or action name, text].
func hint(pairs: Array) -> String:
	var parts: PackedStringArray = []
	for pair_v in pairs:
		var pair: Array = pair_v
		var id := str(pair[0])
		var glyph := ui(id) if UI.has(id) else action(id)
		if glyph != "":
			parts.append("%s %s" % [glyph, str(pair[1])])
	return "   ".join(parts)


## Plain device label for one event: "E", "Space", "LB", "LT", "lmb".
func event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		return OS.get_keycode_string(code)
	if event is InputEventJoypadButton:
		return pad_button_name((event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return pad_axis_name(motion.axis, motion.axis_value)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return OriginalLines.key("lmb")
			MOUSE_BUTTON_RIGHT:
				return OriginalLines.key("rmb")
			MOUSE_BUTTON_MIDDLE:
				return OriginalLines.key("mmb")
			MOUSE_BUTTON_WHEEL_UP:
				return OriginalLines.key("scru")
			MOUSE_BUTTON_WHEEL_DOWN:
				return OriginalLines.key("scrd")
		return "Mouse %d" % int((event as InputEventMouseButton).button_index)
	return ""


func pad_button_name(index: int) -> String:
	return str(PAD_NAMES.get(index, "Pad %d" % index))


func pad_axis_name(axis: int, value: float = 1.0) -> String:
	match axis:
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
		JOY_AXIS_LEFT_X:
			return "L ←" if value < 0.0 else "L →"
		JOY_AXIS_LEFT_Y:
			return "L ↑" if value < 0.0 else "L ↓"
		JOY_AXIS_RIGHT_X:
			return "R ←" if value < 0.0 else "R →"
		JOY_AXIS_RIGHT_Y:
			return "R ↑" if value < 0.0 else "R ↓"
	return "Axis %d" % axis


func _is_trigger(motion: InputEventJoypadMotion) -> bool:
	return motion.axis == JOY_AXIS_TRIGGER_LEFT or motion.axis == JOY_AXIS_TRIGGER_RIGHT


func _set_pad(on: bool) -> void:
	if on:
		_wake = 0.0
	if pad == on:
		return
	pad = on
	device_changed.emit(pad)


func _pad_held() -> bool:
	for device in Input.get_connected_joypads():
		for button in 16:
			if Input.is_joy_button_pressed(device, button as JoyButton):
				return true
		for axis in 6:
			if _axis_on(axis, Input.get_joy_axis(device, axis as JoyAxis), 0.6):
				return true
	return false


## Some drivers report an idle trigger as -1, so a trigger only counts pressed.
static func _axis_on(axis: int, value: float, limit: float) -> bool:
	if axis == JOY_AXIS_TRIGGER_LEFT or axis == JOY_AXIS_TRIGGER_RIGHT:
		return value >= limit
	return absf(value) >= limit
