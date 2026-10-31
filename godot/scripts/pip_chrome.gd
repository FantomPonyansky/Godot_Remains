extends RefCounted

## Shared PipBuck screen colors and one-step menu navigation.
## Left-stick ui_* events are joypad motion, so they must be edged like a d-pad.
## PipPage text is #00FF99 on dark green; the names stay for the callers.

const AMBER := Color("00ff99")
const AMBER_DIM := Color("8affd0")
const SCREEN := Color(0.012, 0.05, 0.028, 1)
const FRAME := "res://assets/portraits/pipbuck.png"


static func ui_pressed(event: InputEvent, action: String) -> bool:
	if not event.is_action_pressed(action):
		return false
	if event is InputEventJoypadMotion:
		return Input.is_action_just_pressed(action)
	return true


static func build_screen(parent: Node) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(0, 0, 0, 0.62)
	root.add_child(dim)
	var device := AspectRatioContainer.new()
	device.set_anchors_preset(Control.PRESET_FULL_RECT)
	device.ratio = 1.7256
	device.stretch_mode = AspectRatioContainer.STRETCH_FIT
	device.alignment_horizontal = 1
	device.alignment_vertical = 1
	device.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(device)
	var frame_root := Control.new()
	frame_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	device.add_child(frame_root)
	var frame := TextureRect.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(FRAME):
		frame.texture = load(FRAME)
	frame_root.add_child(frame)
	var screen := Control.new()
	screen.anchor_left = 0.2055
	screen.anchor_top = 0.1739
	screen.anchor_right = 0.8163
	screen.anchor_bottom = 0.8271
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_root.add_child(screen)
	var crt := ColorRect.new()
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt.color = SCREEN
	screen.add_child(crt)
	return screen


