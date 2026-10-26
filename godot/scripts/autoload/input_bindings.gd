extends Node

## Rebindable actions, saved at user://controls.cfg. Each action has a
## keyboard/mouse side and a gamepad side (buttons and triggers); left-stick
## axes stay on the movement actions and are not rebound.
## Labels are the original key names (text_*.xml <key>).
##
## Default layout (Phase 7). Keyboard is the original Ctr.as keyXML, plus
## Enter/right mouse alternates; the pad side is the port's:
##   move / climb / crouch  WASD             left stick only
##   jump, levitate         Space            A
##   shoot                  left mouse       RT
##   melee                  F                RB
##   telekinesis            Q, right mouse   LT
##   magic_attack           T                D-pad Left
##   cast_spell             C                D-pad Right
##   grenade (keyGrenad)    G                LB
##   interact               E                X
##   reload / pet_command   R / U            Y tap / Y hold
##   weapon_next / prev     wheel up / down  D-pad Up / Down tap
##   weapon_wheel           -                D-pad Up hold
##   spell_wheel            -                D-pad Down hold
##   sats                   V, middle mouse  B
##   sprint                 Shift            L3
##   pip_toggle / pause     Tab / Esc        Back / Start
##   quick_heal / quick_mana H / B            R3 tap / R3 hold
##   armor_ability          N                Share
##   crack (keyCrack)       Y key            Y tap when a rune or lockpick applies
##   dash (keyDash)         Shift twice      L3 twice (PadGestures, sprint double tap)
## Keyboard-only originals, pad side unbound:
## use_item (keyItem, P), item_next / item_prev (] / [),
## look (keyLook, ;), zoom (keyZoom, '), fullscreen (keyFull, Enter),
## and the PipBuck pages including pip_quest (keyQuest, J).
## A pad button bound to both actions of a PadGestures pair is a tap / hold.

signal changed

const _UserDir := preload("res://scripts/user_dir.gd")
static var PATH := _UserDir.settings("controls.cfg")
## Files saved before this layout keep the old pad map; they are dropped once.
const LAYOUT := 8
const _Pip := preload("res://scripts/pipbuck.gd")
const _Gestures := preload("res://scripts/autoload/pad_gestures.gd")
const ACTIONS: PackedStringArray = [
	"move_left", "move_right", "aim_up", "aim_down", "jump", "sprint", "dash", "shoot", "melee",
	"magic_attack", "cast_spell", "grenade", "reload", "telekinesis", "interact", "crack",
	"weapon_prev", "weapon_next", "weapon_wheel", "spell_wheel",
	"pip_toggle", "sats", "pet_command", "use_item", "item_next", "item_prev",
	"quick_heal", "quick_mana", "armor_ability", "look", "zoom", "fullscreen", "pause",
	"weapon_1", "weapon_2", "weapon_3", "weapon_4", "weapon_5", "weapon_6",
	"weapon_7", "weapon_8", "weapon_9", "weapon_10", "weapon_11", "weapon_12",
]
const KEY_NAMES := {
	"move_left": "keyLeft", "move_right": "keyRight", "aim_up": "keyBeUp", "aim_down": "keySit",
	"jump": "keyJump", "sprint": "keyRun", "dash": "keyDash", "shoot": "keyAttack", "melee": "keyPunch",
	"magic_attack": "keyMagic", "cast_spell": "keyDef", "grenade": "keyGrenad", "reload": "keyReload",
	"telekinesis": "keyTele", "interact": "keyAction", "crack": "keyCrack", "weapon_prev": "keyScrUp",
	"weapon_next": "keyScrDown", "pip_toggle": "keyPip", "sats": "keySats",
	"pet_command": "keyPet", "use_item": "keyItem", "item_next": "keyItemNext", "item_prev": "keyItemPrev",
	"quick_heal": "keyPot", "quick_mana": "keyMana", "armor_ability": "keyArmor",
	"look": "keyLook", "zoom": "keyZoom", "fullscreen": "keyFull",
	"weapon_1": "keyWeapon1", "weapon_2": "keyWeapon2", "weapon_3": "keyWeapon3",
	"weapon_4": "keyWeapon4", "weapon_5": "keyWeapon5", "weapon_6": "keyWeapon6",
	"weapon_7": "keyWeapon7", "weapon_8": "keyWeapon8", "weapon_9": "keyWeapon9",
	"weapon_10": "keyWeapon10", "weapon_11": "keyWeapon11", "weapon_12": "keyWeapon12",
}
## Events added to actions project.godot does not define (or lacks them):
## "k" physical key, "m" mouse button, "j" pad button, "a" trigger axis.
const EXTRA := {
	"telekinesis": [["k", KEY_Q], ["m", MOUSE_BUTTON_RIGHT], ["a", JOY_AXIS_TRIGGER_LEFT]],
	"magic_attack": [["k", KEY_T], ["j", JOY_BUTTON_DPAD_LEFT]],
	"sats": [["k", KEY_V], ["m", MOUSE_BUTTON_MIDDLE], ["j", JOY_BUTTON_B]],
	"grenade": [["k", KEY_G], ["j", JOY_BUTTON_LEFT_SHOULDER]],
	"weapon_wheel": [["j", JOY_BUTTON_DPAD_UP]],
	"spell_wheel": [["j", JOY_BUTTON_DPAD_DOWN]],
	"dash": [],
	"crack": [["k", KEY_Y]],
	"use_item": [["k", KEY_P]],
	"item_next": [["k", KEY_BRACKETRIGHT]],
	"item_prev": [["k", KEY_BRACKETLEFT]],
	"quick_heal": [["k", KEY_H], ["j", JOY_BUTTON_RIGHT_STICK]],
	"quick_mana": [["k", KEY_B], ["j", JOY_BUTTON_RIGHT_STICK]],
	"armor_ability": [["k", KEY_N], ["j", JOY_BUTTON_MISC1]],
	"look": [["k", KEY_SEMICOLON]],
	"zoom": [["k", KEY_APOSTROPHE]],
	"fullscreen": [["k", KEY_ENTER]],
}
const _Fav := preload("res://scripts/autoload/favorites.gd")
const STICK_ACTIONS: PackedStringArray = ["move_left", "move_right", "aim_up", "aim_down"]

var gestures: Node
var _defaults: Dictionary = {}
## action -> pad button events taken out of the InputMap for PadGestures.
var _shared: Dictionary = {}


func _ready() -> void:
	gestures = _Gestures.new()
	gestures.name = "PadGestures"
	add_child(gestures)
	_ensure_extra()
	_Pip.ensure_actions()
	_Fav.ensure_actions()
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		var saved: Array[InputEvent] = []
		for event in InputMap.action_get_events(action):
			saved.append(event.duplicate())
		_defaults[action] = saved
	_load()
	apply_deadzone()
	_share()


func _ensure_extra() -> void:
	for action: String in EXTRA:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		for spec: Array in EXTRA[action]:
			var event := _make(str(spec[0]), int(spec[1]))
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


func _make(kind: String, value: int) -> InputEvent:
	match kind:
		"k":
			var key := InputEventKey.new()
			key.physical_keycode = value as Key
			return key
		"m":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = value as MouseButton
			return mouse
		"a":
			var motion := InputEventJoypadMotion.new()
			motion.axis = value as JoyAxis
			motion.axis_value = 1.0
			return motion
	var joy := InputEventJoypadButton.new()
	joy.button_index = value as JoyButton
	return joy


func label_for(action: String) -> String:
	if KEY_NAMES.has(action):
		return OriginalLines.key(KEY_NAMES[action])
	return Locale.t("act_" + action, action)


## All bound events, including pad buttons PadGestures currently drives.
func events_of(action: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	if InputMap.has_action(action):
		out.append_array(InputMap.action_get_events(action))
	for event: InputEvent in _shared.get(action, []):
		out.append(event)
	return out


## True when this event is the hold half of a shared tap / hold button.
func is_hold_event(action: String, event: InputEvent) -> bool:
	if not event is InputEventJoypadButton or not _shared.has(action):
		return false
	return gestures.hold_action((event as InputEventJoypadButton).button_index) == action


## Bound inputs of one side, " / " joined, or the "not set" word.
func binding_text(action: String, pad: bool = false) -> String:
	var parts: PackedStringArray = []
	for event in events_of(action):
		if _is_pad(event) != pad:
			continue
		var text := event_text(event)
		if text != "" and is_hold_event(action, event):
			text = "%s (%s)" % [text, OriginalLines.gui("hold")]
		if text != "":
			parts.append(text)
	if parts.is_empty():
		return Locale.t("unbound")
	return " / ".join(parts)


func event_text(event: InputEvent) -> String:
	return Prompts.event_label(event)


## A key replaces keys, a mouse button replaces mouse buttons, and a pad
## button or trigger replaces the pad buttons and triggers. Stick axes stay.
func set_binding(action: String, event: InputEvent) -> void:
	_unshare()
	var kept: Array[InputEvent] = []
	var pad := _is_pad(event)
	for existing in InputMap.action_get_events(action):
		if pad and _is_pad(existing) and not _is_stick(existing):
			continue
		if event is InputEventKey and existing is InputEventKey:
			continue
		if event is InputEventMouseButton and existing is InputEventMouseButton:
			continue
		kept.append(existing)
	InputMap.action_erase_events(action)
	for existing in kept:
		InputMap.action_add_event(action, existing)
	InputMap.action_add_event(action, _clean(event))
	_save()
	_share()
	changed.emit()


## Ctr keyObj a1 / a2: the keyboard and mouse events in order, two cells.
func kb_events(action: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for event in events_of(action):
		if not _is_pad(event):
			out.append(event)
	return out


## PipPageOpt.transOk: writes the edited key cells of many actions at once.
## edits: action -> [a1, a2], null for an empty cell. Pad events stay.
func set_kb(edits: Dictionary) -> void:
	_unshare()
	for action: String in edits:
		var pad: Array[InputEvent] = []
		for existing in InputMap.action_get_events(action):
			if _is_pad(existing):
				pad.append(existing)
		InputMap.action_erase_events(action)
		for e: Variant in edits[action]:
			if e is InputEvent:
				InputMap.action_add_event(action, _clean(e as InputEvent))
		for e in pad:
			InputMap.action_add_event(action, e)
	_save()
	_share()
	changed.emit()


## Drops the keyboard/mouse side (or the pad buttons and triggers).
func clear_binding(action: String, pad: bool) -> void:
	_unshare()
	var kept: Array[InputEvent] = []
	for existing in InputMap.action_get_events(action):
		if _is_pad(existing) == pad and not _is_stick(existing):
			continue
		kept.append(existing)
	InputMap.action_erase_events(action)
	for existing in kept:
		InputMap.action_add_event(action, existing)
	_save()
	_share()
	changed.emit()


func reset_defaults() -> void:
	_unshare()
	for action in ACTIONS:
		InputMap.action_erase_events(action)
		for event in _defaults[action]:
			InputMap.action_add_event(action, event.duplicate())
	_save()
	_share()
	UiSettings.set_stick_deadzone(0.35)
	UiSettings.set_aim_sensitivity(1.0)
	UiSettings.set_aim_assist(true)
	UiSettings.set_assist_pull(1.0)
	UiSettings.set_assist_slow(0.25)
	apply_deadzone()
	changed.emit()


func apply_deadzone() -> void:
	var dz := UiSettings.stick_deadzone()
	for action in STICK_ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, dz)


## Moves each pad button bound to both actions of a PadGestures pair out of
## the InputMap and hands it to PadGestures.
func _share() -> void:
	_unshare()
	var map := {}
	for i in _Gestures.PAIRS.size():
		var pair: Array = _Gestures.PAIRS[i]
		var tap := str(pair[0])
		var hold := str(pair[1])
		if not InputMap.has_action(tap) or not InputMap.has_action(hold):
			continue
		for event in InputMap.action_get_events(tap):
			if not event is InputEventJoypadButton:
				continue
			var button := (event as InputEventJoypadButton).button_index as int
			if map.has(button):
				continue
			var twin := _pad_button(hold, button)
			if twin == null:
				continue
			map[button] = i
			InputMap.action_erase_event(tap, event)
			InputMap.action_erase_event(hold, twin)
			_shared[tap] = (_shared.get(tap, []) as Array) + [event]
			_shared[hold] = (_shared.get(hold, []) as Array) + [twin]
	gestures.set_buttons(map)


func _unshare() -> void:
	for action: String in _shared:
		for event: InputEvent in _shared[action]:
			InputMap.action_add_event(action, event)
	_shared.clear()
	if gestures != null:
		gestures.set_buttons({})


func _pad_button(action: String, button: int) -> InputEvent:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return event
	return null


func _is_pad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


func _is_stick(event: InputEvent) -> bool:
	if not event is InputEventJoypadMotion:
		return false
	var axis := (event as InputEventJoypadMotion).axis
	return axis != JOY_AXIS_TRIGGER_LEFT and axis != JOY_AXIS_TRIGGER_RIGHT


func _clean(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key := InputEventKey.new()
		key.physical_keycode = (event as InputEventKey).physical_keycode
		if key.physical_keycode == 0:
			key.keycode = (event as InputEventKey).keycode
		return key
	if event is InputEventJoypadButton:
		var joy := InputEventJoypadButton.new()
		joy.button_index = (event as InputEventJoypadButton).button_index
		return joy
	if event is InputEventMouseButton:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = (event as InputEventMouseButton).button_index
		return mouse
	if event is InputEventJoypadMotion:
		var motion := InputEventJoypadMotion.new()
		motion.axis = (event as InputEventJoypadMotion).axis
		motion.axis_value = 1.0 if (event as InputEventJoypadMotion).axis_value >= 0.0 else -1.0
		return motion
	return event


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "layout", LAYOUT)
	for action in ACTIONS:
		var parts: PackedStringArray = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				parts.append("key:%d" % (event as InputEventKey).physical_keycode)
			elif event is InputEventJoypadButton:
				parts.append("joy:%d" % (event as InputEventJoypadButton).button_index)
			elif event is InputEventMouseButton:
				parts.append("mouse:%d" % (event as InputEventMouseButton).button_index)
			elif event is InputEventJoypadMotion:
				var motion := event as InputEventJoypadMotion
				parts.append("axis:%d:%d" % [int(motion.axis), -1 if motion.axis_value < 0.0 else 1])
		cfg.set_value("input", action, ",".join(parts))
	cfg.save(PATH)


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	if int(cfg.get_value("meta", "layout", 0)) < LAYOUT:
		_save()
		return
	for action in ACTIONS:
		if not cfg.has_section_key("input", action):
			continue
		var spec := str(cfg.get_value("input", action))
		InputMap.action_erase_events(action)
		for part in spec.split(",", false):
			var event := _parse(part, action)
			if event != null:
				InputMap.action_add_event(action, event)


func _parse(spec: String, action: String) -> InputEvent:
	var bits := spec.split(":", false)
	if bits.size() < 2:
		return null
	var value := int(bits[1])
	match bits[0]:
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = value as Key
			return key
		"joy":
			var joy := InputEventJoypadButton.new()
			joy.button_index = value as JoyButton
			return joy
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = value as MouseButton
			return mouse
		"axis":
			var motion := InputEventJoypadMotion.new()
			motion.axis = value as JoyAxis
			motion.axis_value = 1.0
			if bits.size() > 2:
				motion.axis_value = -1.0 if int(bits[2]) < 0 else 1.0
			else:
				for event in _defaults.get(action, []):
					if event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == motion.axis:
						motion.axis_value = (event as InputEventJoypadMotion).axis_value
			return motion
	return null
