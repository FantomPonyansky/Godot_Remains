extends Node

## Shared focus and navigation for every menu-like screen (port extra; the
## original is mouse and keyboard only).
## A screen registers its root once with add_screen(). It is active while the
## root is visible in the tree; the most recently shown one is on top.
## On the active screen:
## - left stick and held d-pad step focus like the arrow keys, with repeat;
## - LB / RB call opts.tabs(step);
## - LT / RT and PgUp / PgDn jump a page in the focused ScrollContainer;
## - ui_cancel (Esc, B) calls opts.back;
## - focus that is lost, hidden, or wandered into another registered screen
##   goes back to the last good control or to opts.default.
## Screens' own _input runs first, so a screen can still eat any of these.

const REPEAT_DELAY := 0.4
const REPEAT_RATE := 0.11
const TRIGGER_ON := 0.6
const DPAD := {
	JOY_BUTTON_DPAD_UP: Vector2i.UP, JOY_BUTTON_DPAD_DOWN: Vector2i.DOWN,
	JOY_BUTTON_DPAD_LEFT: Vector2i.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2i.RIGHT,
}

var _screens: Array[Dictionary] = []
var _order := 0
var _active: Control
var _last_focus: Control
var _stick := Vector2.ZERO
var _dir := Vector2i.ZERO
var _dir_from_stick := false
var _repeat_left := 0.0
var _triggers: Dictionary = {}
## Right stick moves the mouse on a screen; A then clicks where it points.
const CURSOR_SPEED := 1.3
const WHEEL_STEP := 40.0
var _rstick := Vector2.ZERO
var _cursor_mode := false
## Process frame of the last stick warp; Prompts keeps pad glyphs for that motion.
var warped_frame := -10
## Where the stick cursor points. Gamescope (Steam Deck game mode) ignores
## warp_mouse, so hover and clicks go to this point and it is drawn here.
var _vpos := Vector2(-1.0, -1.0)
var _soft: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_smooth_ui)


## The project default filter is nearest for the world art. Glyphs sit at fractional
## positions, so nearest sampling steps their edges; Flash drew text and UI smoothed.
## Each UI root (a Control not under another Control) that inherits its filter draws linear.
func _smooth_ui(node: Node) -> void:
	if node is Control and not node.get_parent() is Control:
		var item := node as Control
		if item.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## opts: default (Control or Callable -> Control), back (Callable),
## tabs (Callable(step: int)), page (Callable(step: int)) to replace the
## ScrollContainer jump.
func add_screen(root: Control, opts: Dictionary = {}) -> void:
	if root == null:
		return
	var entry := _entry(root)
	if not entry.is_empty():
		entry["opts"] = opts
		return
	_order += 1
	_screens.append({"root": root, "opts": opts, "order": _order})
	root.visibility_changed.connect(_on_visibility.bind(root))
	root.tree_exiting.connect(remove_screen.bind(root))
	if root.is_inside_tree() and root.is_visible_in_tree():
		_on_visibility(root)


func remove_screen(root: Control) -> void:
	for i in range(_screens.size() - 1, -1, -1):
		if _screens[i]["root"] == root:
			_screens.remove_at(i)
	if root != null and is_instance_valid(root):
		if root.visibility_changed.is_connected(_on_visibility):
			root.visibility_changed.disconnect(_on_visibility)
		if root.tree_exiting.is_connected(remove_screen):
			root.tree_exiting.disconnect(remove_screen)


func active_screen() -> Control:
	var best: Control = null
	var best_order := -1
	for entry in _screens:
		var root: Variant = entry["root"]
		if not is_instance_valid(root):
			continue
		var control := root as Control
		if not control.is_inside_tree() or not control.is_visible_in_tree():
			continue
		if int(entry["order"]) > best_order:
			best_order = int(entry["order"])
			best = control
	return best


func is_active(root: Control) -> bool:
	return root != null and active_screen() == root


## Moves focus to opts.default, else the first focusable control.
func focus_default(root: Control = null) -> void:
	if root == null:
		root = active_screen()
	if root == null or not is_instance_valid(root):
		return
	var target := _default_of(root)
	if target != null:
		target.grab_focus()
		_last_focus = target


## Chains controls top to bottom (wrapping) and pins left/right to themselves.
func link_column(controls: Array, wrap := true, pin_sides := true) -> void:
	var live: Array[Control] = []
	for c in controls:
		if c is Control and is_instance_valid(c) and (c as Control).focus_mode != Control.FOCUS_NONE:
			live.append(c)
	var n := live.size()
	for i in n:
		var c := live[i]
		var above: Control = live[i - 1] if i > 0 else (live[n - 1] if wrap else c)
		var below: Control = live[i + 1] if i + 1 < n else (live[0] if wrap else c)
		c.focus_neighbor_top = c.get_path_to(above)
		c.focus_neighbor_bottom = c.get_path_to(below)
		c.focus_previous = c.get_path_to(above)
		c.focus_next = c.get_path_to(below)
		if pin_sides and not c is Range:
			c.focus_neighbor_left = c.get_path()
			c.focus_neighbor_right = c.get_path()


func focusables(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	_collect(root, out)
	return out


func _input(event: InputEvent) -> void:
	var top := active_screen()
	if top == null:
		_dir = Vector2i.ZERO
		return
	var opts: Dictionary = _entry(top).get("opts", {})
	if event is InputEventMouseButton and event.pressed:
		var wheel := (event as InputEventMouseButton).button_index
		if wheel == MOUSE_BUTTON_WHEEL_UP or wheel == MOUSE_BUTTON_WHEEL_DOWN:
			var at := top.get_global_transform() * (top.make_input_local(event) as InputEventMouse).position
			var under := _text_scroll(top, true, at)
			if under != null:
				var k := maxf((event as InputEventMouseButton).factor, 1.0)
				_scroll_by(under, (WHEEL_STEP if wheel == MOUSE_BUTTON_WHEEL_DOWN else -WHEEL_STEP) * k)
				get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		match motion.axis:
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				_on_stick(motion)
			JOY_AXIS_RIGHT_X:
				_rstick.x = motion.axis_value
			JOY_AXIS_RIGHT_Y:
				_rstick.y = motion.axis_value
			JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT:
				var down := motion.axis_value >= TRIGGER_ON
				var was := bool(_triggers.get(motion.axis, false))
				_triggers[motion.axis] = down
				if down and not was:
					_page(top, opts, -1 if motion.axis == JOY_AXIS_TRIGGER_LEFT else 1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton:
		var pad := event as InputEventJoypadButton
		if pad.button_index == JOY_BUTTON_A and _cursor_mode:
			get_viewport().set_input_as_handled()
			_click(pad.pressed)
			return
		if DPAD.has(pad.button_index):
			if pad.pressed:
				_cursor_mode = false
				_dir = DPAD[pad.button_index]
				_dir_from_stick = false
				_repeat_left = REPEAT_DELAY
				if _scroll_dir(top, _dir):
					get_viewport().set_input_as_handled()
			elif not _dir_from_stick and _dir == DPAD[pad.button_index]:
				_dir = Vector2i.ZERO
			return
		if pad.button_index == JOY_BUTTON_LEFT_SHOULDER or pad.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			if pad.pressed and opts.has("tabs"):
				(opts["tabs"] as Callable).call(-1 if pad.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed:
		var key := (event as InputEventKey).keycode
		if key == KEY_PAGEUP or key == KEY_PAGEDOWN:
			_page(top, opts, -1 if key == KEY_PAGEUP else 1)
			get_viewport().set_input_as_handled()
			return
	if opts.has("back") and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		(opts["back"] as Callable).call()


func _process(delta: float) -> void:
	var top := active_screen()
	if _soft != null and _soft.visible and (top == null or not _cursor_mode):
		_soft.visible = false
	if top != _active:
		_active = top
		_last_focus = null
		if top != null:
			_keep_focus(top, true)
		else:
			var owner := get_viewport().gui_get_focus_owner()
			if owner != null and not owner.is_visible_in_tree():
				get_viewport().gui_release_focus()
	if top == null:
		return
	_keep_focus(top, false)
	_move_cursor(delta)
	if _dir != Vector2i.ZERO:
		_repeat_left -= delta
		if _repeat_left <= 0.0:
			_repeat_left = REPEAT_RATE
			_push_dir(_dir)


func _on_stick(motion: InputEventJoypadMotion) -> void:
	if motion.axis == JOY_AXIS_LEFT_X:
		_stick.x = motion.axis_value
	else:
		_stick.y = motion.axis_value
	var cut := maxf(0.5, UiSettings.stick_deadzone())
	var dir := Vector2i.ZERO
	if absf(_stick.x) >= cut or absf(_stick.y) >= cut:
		if absf(_stick.x) > absf(_stick.y):
			dir = Vector2i(int(signf(_stick.x)), 0)
		else:
			dir = Vector2i(0, int(signf(_stick.y)))
	if dir == Vector2i.ZERO:
		if _dir_from_stick:
			_dir = Vector2i.ZERO
		return
	if dir == _dir and _dir_from_stick:
		return
	_cursor_mode = false
	_dir = dir
	_dir_from_stick = true
	_repeat_left = REPEAT_DELAY
	call_deferred("_push_dir", dir)


func _push_dir(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO or active_screen() == null:
		return
	if not _dir_from_stick and _scroll_dir(active_screen(), dir):
		return
	var ev := InputEventAction.new()
	match dir:
		Vector2i.UP:
			ev.action = "ui_up"
		Vector2i.DOWN:
			ev.action = "ui_down"
		Vector2i.LEFT:
			ev.action = "ui_left"
		_:
			ev.action = "ui_right"
	ev.pressed = true
	get_viewport().push_input(ev)


## D-pad up/down scrolls a text box when focus has nowhere to go that way.
## Lists keep moving focus; their ScrollContainer follows it.
func _scroll_dir(top: Control, dir: Vector2i) -> bool:
	if dir.y == 0:
		return false
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and top.is_ancestor_of(owner):
		var next := owner.find_valid_focus_neighbor(SIDE_BOTTOM if dir.y > 0 else SIDE_TOP)
		if next != null and next != owner:
			return false
	var target := _text_scroll(top, false)
	if target == null:
		return false
	_scroll_by(target, WHEEL_STEP * float(dir.y))
	return true


## A text box on top that can scroll: a ScrollContainer or RichTextLabel with
## its bar showing. Under the mouse when at_mouse, else the one under the
## mouse or the tallest. Pad scrolling skips containers that hold focusables.
func _text_scroll(top: Control, at_mouse: bool, mouse := Vector2.INF) -> Control:
	var found: Array[Control] = []
	_collect_scrolls(top, found)
	if mouse == Vector2.INF:
		mouse = top.get_global_mouse_position()
	var best: Control = null
	for c in found:
		if c.get_global_rect().has_point(mouse):
			best = c
	if best != null or at_mouse:
		return best
	for c in found:
		if c is ScrollContainer and not focusables(c).is_empty():
			continue
		if best == null or c.size.y > best.size.y:
			best = c
	return best


func _collect_scrolls(node: Node, out: Array[Control]) -> void:
	for child in node.get_children():
		if not child is Control:
			continue
		var c := child as Control
		if not c.is_visible_in_tree():
			continue
		if c is ScrollContainer and (c as ScrollContainer).get_v_scroll_bar().visible:
			out.append(c)
		elif c is RichTextLabel and (c as RichTextLabel).scroll_active and (c as RichTextLabel).get_v_scroll_bar().visible:
			out.append(c)
		_collect_scrolls(c, out)


func _scroll_by(target: Control, amount: float) -> void:
	if target is ScrollContainer:
		(target as ScrollContainer).scroll_vertical += int(amount)
	elif target is RichTextLabel:
		var bar := (target as RichTextLabel).get_v_scroll_bar()
		bar.value = clampf(bar.value + amount, bar.min_value, bar.max_value)


func _move_cursor(delta: float) -> void:
	var dead := maxf(0.2, UiSettings.stick_deadzone())
	var strength := _rstick.length()
	if strength < dead:
		return
	var vp := get_viewport()
	var rect := vp.get_visible_rect()
	var k := (minf(strength, 1.0) - dead) / (1.0 - dead)
	var from := _vpos if _cursor_mode and _vpos.x >= 0.0 else vp.get_mouse_position()
	var pos := from + _rstick.normalized() * k * k * rect.size.y * CURSOR_SPEED * delta
	pos = pos.clamp(rect.position, rect.end - Vector2.ONE)
	warped_frame = Engine.get_process_frames()
	vp.warp_mouse(pos)
	_vpos = pos
	_cursor_mode = true
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.set_meta("ui_nav_click", true)
	vp.push_input.call_deferred(ev, true)
	if _gamescope():
		_soft_cursor().position = pos
		_soft.visible = true


static func _gamescope() -> bool:
	return OS.has_environment("SteamDeck") or OS.has_environment("GAMESCOPE_WAYLAND_DISPLAY")


func _soft_cursor() -> Control:
	if _soft == null or not is_instance_valid(_soft):
		var layer := CanvasLayer.new()
		layer.layer = 128
		add_child(layer)
		_soft = Control.new()
		_soft.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_soft.draw.connect(func() -> void:
			var arrow := PackedVector2Array([Vector2(0, 0), Vector2(0, 17), Vector2(4.5, 13), Vector2(8, 20), Vector2(10.5, 19), Vector2(7, 12), Vector2(12.5, 12)])
			_soft.draw_colored_polygon(arrow, Color.WHITE)
			_soft.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color.BLACK, 1.0))
		layer.add_child(_soft)
	return _soft


func _click(down: bool) -> void:
	var vp := get_viewport()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	ev.position = _vpos if _cursor_mode and _vpos.x >= 0.0 else vp.get_mouse_position()
	ev.global_position = ev.position
	ev.set_meta("ui_nav_click", true)
	vp.push_input.call_deferred(ev, true)


func _page(top: Control, opts: Dictionary, step: int) -> void:
	if opts.has("page"):
		(opts["page"] as Callable).call(step)
		return
	var owner := get_viewport().gui_get_focus_owner()
	var scroll: ScrollContainer = null
	var node: Node = owner
	while node != null and node != top.get_parent():
		if node is ScrollContainer:
			scroll = node
			break
		node = node.get_parent()
	if scroll == null:
		scroll = _first_scroll(top)
	if scroll == null:
		return
	var list := focusables(scroll)
	if list.is_empty():
		scroll.scroll_vertical += int(float(step) * scroll.size.y * 0.9)
		return
	var at := list.find(owner)
	if at < 0:
		at = 0 if step > 0 else list.size() - 1
		list[at].grab_focus()
		return
	var row_h := maxf(1.0, list[at].size.y + 4.0)
	var per := maxi(1, int(scroll.size.y / row_h) - 1)
	var next := clampi(at + step * per, 0, list.size() - 1)
	list[next].grab_focus()
	scroll.ensure_control_visible(list[next])


func _keep_focus(top: Control, opened: bool) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	var good := owner != null and owner.is_visible_in_tree() and (owner == top or top.is_ancestor_of(owner))
	if good:
		_last_focus = owner
		return
	# A control outside every registered screen (debug console line) keeps focus.
	if owner != null and owner.is_visible_in_tree() and not opened and not _in_any_screen(owner):
		return
	if _last_focus != null and is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree() \
			and _can_focus(_last_focus) and top.is_ancestor_of(_last_focus):
		_last_focus.grab_focus()
		return
	focus_default(top)


func _default_of(root: Control) -> Control:
	var opts: Dictionary = _entry(root).get("opts", {})
	var want: Variant = opts.get("default")
	if want is Callable:
		want = (want as Callable).call()
	if want is Control and is_instance_valid(want):
		var control := want as Control
		if control.is_visible_in_tree() and _can_focus(control):
			return control
	var list := focusables(root)
	return list[0] if not list.is_empty() else null


## FOCUS_ACCESSIBILITY (rich text, labels) takes focus only under a screen reader.
func _can_focus(control: Control) -> bool:
	return control.focus_mode != Control.FOCUS_NONE and control.focus_mode != Control.FOCUS_ACCESSIBILITY


func _collect(node: Node, out: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if not control.is_visible_in_tree():
				continue
			if _can_focus(control):
				out.append(control)
		_collect(child, out)


func _first_scroll(node: Node) -> ScrollContainer:
	for child in node.get_children():
		if child is ScrollContainer and (child as Control).is_visible_in_tree():
			return child
		var found := _first_scroll(child)
		if found != null:
			return found
	return null


func _in_any_screen(control: Control) -> bool:
	for entry in _screens:
		var root: Variant = entry["root"]
		if is_instance_valid(root) and ((root as Control) == control or (root as Control).is_ancestor_of(control)):
			return true
	return false


func _on_visibility(root: Control) -> void:
	if not is_instance_valid(root) or not root.is_visible_in_tree():
		return
	var entry := _entry(root)
	if entry.is_empty():
		return
	_order += 1
	entry["order"] = _order


func _entry(root: Control) -> Dictionary:
	for entry in _screens:
		if entry["root"] == root:
			return entry
	return {}
