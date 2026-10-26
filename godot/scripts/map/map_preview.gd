extends Control

const DungeonGenScript = preload("res://scripts/map/dungeon_gen.gd")
const SCALE := 3

@onready var _layout: Control = $Layout
@onready var _caption: Label = $Caption


func _ready() -> void:
	var layout: Dictionary = DungeonGenScript.generate()
	if layout.has("error"):
		_caption.text = str(layout.error)
		print("DungeonGen error: %s" % str(layout.error))
		return
	var counts: Dictionary = layout.counts
	_caption.text = "land=%s %sx%s  fixed=%s random=%s  passages=%s" % [
		str(layout.land_id),
		str(layout.width),
		str(layout.height),
		str(counts.fixed),
		str(counts.random),
		str(layout.link_count),
	]
	_paint(layout)
	print("DungeonGen land=%s grid=%sx%s cells=%d fixed=%s random=%s links=%s" % [
		str(layout.land_id),
		str(layout.width),
		str(layout.height),
		layout.cells.size(),
		str(counts.fixed),
		str(counts.random),
		str(layout.link_count),
	])


func _paint(layout: Dictionary) -> void:
	var room_w := int(layout.room_tiles_x)
	var room_h := int(layout.room_tiles_y)
	var origin_x := int(layout.min_x)
	var origin_y := int(layout.min_y)
	var symbols: Dictionary = layout.quest_symbols
	for cell in layout.cells:
		var ox := (int(cell.x) - origin_x) * room_w * SCALE
		var oy := (int(cell.y) - origin_y) * room_h * SCALE
		var y := 0
		for row in cell.tiles:
			var line := str(row)
			var x := 0
			while x < line.length():
				var ch := line[x]
				var end := x + 1
				while end < line.length() and line[end] == ch:
					end += 1
				var rect := ColorRect.new()
				rect.position = Vector2(ox + x * SCALE, oy + y * SCALE)
				rect.size = Vector2((end - x) * SCALE, SCALE)
				rect.color = _color(str(cell.kind), ch, symbols)
				rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_layout.add_child(rect)
				x = end
			y += 1


func _color(kind: String, ch: String, symbols: Dictionary) -> Color:
	if kind == "quest":
		if ch == "_":
			return Color(0.07, 0.16, 0.1)
		var info = symbols.get(ch, {})
		if info is Dictionary and str(info.get("name", "")) == "Reinforced concrete":
			return Color(0.82, 0.82, 0.78)
		return Color(0.62, 0.45, 0.18)
	if ch == "2":
		return Color(0.25, 0.75, 0.86)
	if ch == "1":
		return Color(0.4, 0.38, 0.36)
	return Color(0.13, 0.14, 0.16)
