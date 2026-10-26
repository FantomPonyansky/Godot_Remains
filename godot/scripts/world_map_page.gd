extends Control

## PipPageInfo world map (page2 3). visPipWMap (pfe.swf 834) sits at page
## 17,80: the 550×550 map bitmap and one marker per land (833: zad 803 back,
## sim 829 icon by land id, sign 832 blink). A marker shows once the land is
## visited or opened; it is half alpha when checkTravel refuses it.
## In travel mode (map table, base room) A on a marker selects it (zad frame 2)
## and the PipBuck OK button (pip trans) leaves. Otherwise the map only shows.

signal target_changed(id: String)

const Registry := preload("res://scripts/map/land_registry.gd")
const _ImpMess := preload("res://scripts/imp_mess.gd")
const ART := "res://assets/sprites/ui/world_map/"
const MAP_AT := Vector2(17, 80)
const MAP_SIZE := Vector2(550, 550)
## Sprite bounds at scale 1 (frames were exported at zoom 2).
const ZAD := 42.0
const SIM := 40.0
const SIGN_AT := Vector2(-59.4, -59.35)
const SIGN_FRAMES := 40
## visPipWMap placements: x, y, scale.
const MARKS := {
	"begin": [66.05, 469.15, 1.0],
	"surf": [144.05, 429.15, 1.0],
	"rbl": [278.05, 359.15, 1.0],
	"random_plant": [164.9, 330.0, 1.25],
	"nio": [110.0, 325.0, 1.0],
	"raiders": [389.1, 429.15, 1.0],
	"random_sewer": [409.1, 484.2, 1.0],
	"random_stable": [454.1, 424.15, 1.25],
	"random_mane": [454.1, 220.0, 1.25],
	"bunker": [355.0, 171.95, 1.0],
	"random_canter": [111.05, 85.0, 1.25],
	"core": [508.1, 419.15, 1.0],
	"garages": [243.1, 273.0, 1.0],
	"mtn": [511.1, 215.0, 1.0],
	"covert": [110.0, 200.0, 1.0],
	"src": [209.9, 131.95, 1.0],
	"minst": [58.05, 80.0, 1.0],
	"random_encl": [310.0, 48.25, 1.25],
	"random_mbase": [270.05, 194.0, 1.0],
	"workshop": [60.0, 325.0, 1.0],
	"hql": [497.1, 341.15, 1.0],
	"post": [305.0, 101.05, 1.0],
	"comm": [363.0, 43.25, 1.0],
	"stable_pi": [300.05, 487.2, 1.0],
	"art": [330.0, 225.0, 1.0],
}
const GREEN := Color("00ff99")
const LIGHT := Color("8affd0")

var target := ""
var font: Font
var _marks: Dictionary = {}
var _signs: Array[TextureRect] = []
var _sign_frame := 1
var _acc := 0.0
var _title: Label
var _info: RichTextLabel
var _shown_id := ""

static var _tex: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(900, 700)
	var map := TextureRect.new()
	map.texture = _load("map.png")
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.position = MAP_AT
	map.size = MAP_SIZE
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map)
	_title = _label(Vector2(630.95, 87), 281, 20, GREEN)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = false
	_info.scroll_active = true
	_info.position = Vector2(625.95, 162.05)
	_info.size = Vector2(284, 471)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		_info.add_theme_font_override("normal_font", font)
	_info.add_theme_font_size_override("normal_font_size", 14)
	_info.add_theme_color_override("default_color", GREEN)
	add_child(_info)
	for id: String in MARKS:
		_add_mark(id)
	if target != "" and not _marks.has(target):
		target = ""
	_paint_target()


func first_focus() -> Control:
	if target != "" and _marks.has(target):
		return _marks[target]
	for id: String in ["rbl", Travel.cur_land_id]:
		if _marks.has(id):
			return _marks[id]
	for id: String in MARKS:
		if _marks.has(id):
			return _marks[id]
	return null


func marks() -> Dictionary:
	return _marks


func _add_mark(id: String) -> void:
	if not Travel.lands.has(id):
		return
	var act: Dictionary = Travel.land_act(id)
	var visited := bool(act.get("visited", false))
	var access := bool(act.get("access", false))
	if not visited and not access:
		return
	var spec: Array = MARKS[id]
	var k := float(spec[2])
	var side := ZAD * k
	var b := Button.new()
	b.name = id
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.position = MAP_AT + Vector2(float(spec[0]), float(spec[1])) - Vector2(side, side) * 0.5
	b.size = Vector2(side, side)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = LIGHT
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("focus", focus)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, empty)
	var zad := _rect("zad1.png", Vector2.ZERO, Vector2(side, side))
	zad.name = "Zad"
	b.add_child(zad)
	var sim := _rect("sim_%s.png" % id, Vector2((ZAD - SIM) * 0.5 * k, (ZAD - SIM) * 0.5 * k), Vector2(SIM, SIM) * k)
	b.add_child(sim)
	if not Travel.check_travel(id):
		b.modulate.a = 0.5
	if _ImpMess.help_on() and not visited and access:
		var sign := _rect("sign/1.png", Vector2(side, side) * 0.5 + SIGN_AT * k, Vector2(118.8, 118.75) * k)
		sign.name = "Sign"
		b.add_child(sign)
		_signs.append(sign)
	b.focus_entered.connect(_show_info.bind(id))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.pressed.connect(_click.bind(id))
	add_child(b)
	_marks[id] = b


func _process(delta: float) -> void:
	if _signs.is_empty():
		return
	_acc += delta * 30.0
	var ticks := int(_acc)
	if ticks <= 0:
		return
	_acc -= float(ticks)
	_sign_frame = (_sign_frame - 1 + ticks) % SIGN_FRAMES + 1
	var tex := _load("sign/%d.png" % _sign_frame)
	for sign in _signs:
		sign.texture = tex


## PipPageInfo.itemClick.
func _click(id: String) -> void:
	if Travel.no_act():
		_notice(OriginalLines.info("noAct"))
		return
	if not Travel.map_travel():
		return
	if Travel.check_travel(id):
		target = id
	else:
		target = ""
		_notice(OriginalLines.info("noTravel"))
	_paint_target()
	SfxBank.play("ui_click")
	target_changed.emit(target)


## PipPageInfo.transOk.
func travel_ok() -> bool:
	if Travel.no_act():
		_notice(OriginalLines.info("noAct"))
		return false
	if not Travel.map_travel() or target == "" or not Travel.lands.has(target):
		return false
	Travel.begin_mission(target)
	return true


func _paint_target() -> void:
	for id: String in _marks:
		var zad := (_marks[id] as Control).get_node("Zad") as TextureRect
		zad.texture = _load("zad2.png" if id == target else "zad1.png")


## PipPageInfo.statInfo.
func _show_info(id: String) -> void:
	if id == _shown_id:
		return
	_shown_id = id
	var act: Dictionary = Travel.land_act(id)
	var info := Registry.land(id)
	_title.text = OriginalLines.text("map", id)
	var s := OriginalLines.desc("map", id)
	var tip := str(info.get("tip", ""))
	if bool(act.get("visited", false)):
		if bool(act.get("passed", false)):
			s += "\n\n[color=#ff9900]%s[/color]" % OriginalLines.pip("ls2")
		elif tip == "base":
			s += "\n\n[color=#ff9900]%s[/color]" % OriginalLines.pip("ls4")
		elif tip == "rnd":
			s += "\n\n[color=#ffff33]%s: %d[/color]" % [OriginalLines.pip("ls3"), int(act.get("st", 0)) + 1]
	else:
		s += "\n\n[color=#33ccff]%s[/color]" % OriginalLines.pip("ls1")
	if tip == "rnd":
		var probs: Array = info.get("probs", [])
		if not probs.is_empty():
			var closed := 0
			for row_v in probs:
				if Travel.trigger("prob_" + str((row_v as Dictionary).get("id", ""))) != null:
					closed += 1
			var line := "%s: %d/%d" % [OriginalLines.pip("kolProb"), closed, probs.size()]
			s += "\n" + (line if closed >= probs.size() else "[color=#ffff33]%s[/color]" % line)
	var dif := Registry.float_of(info.get("dif"), 0.0)
	var level := int(Progression.level)
	if dif > 0.0:
		var rec := "%s %d" % [OriginalLines.pip("recLevel"), int(round(dif))]
		s += "\n\n" + ("[color=#ff3333]%s[/color]" % rec if float(level) < dif else rec)
	if dif > float(level):
		s += "\n\n" + OriginalLines.pip("wrLevel")
	_info.text = s.replace("[br]", "\n")


func _notice(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_notice"):
		hud.show_notice(text)


func _label(at: Vector2, width: float, font_size: int, color: Color) -> Label:
	var l := Label.new()
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = at
	l.size = Vector2(width, font_size + 6)
	add_child(l)
	return l


func _rect(file: String, at: Vector2, rect_size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _load(file)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.position = at
	r.size = rect_size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _load(file: String) -> Texture2D:
	if not _tex.has(file):
		var path := ART + file
		_tex[file] = load(path) if ResourceLoader.exists(path) else null
	return _tex[file]
