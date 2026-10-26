extends Sprite2D

## A visualPlayer child clip (shit, cryst, inh) driven like a MovieClip at 30 fps.
## Frame numbers are 1-based as in the swf. stops: frames that call stop(); -1 is the last frame.

var _frames: Array = []
var _fr := 1
var _acc := 0.0
var _playing := false
var stops: Array = []


static func make(key: String, at: Vector2, size: float = 1.0, stop_at: Array = []) -> Sprite2D:
	var clip := (load("res://scripts/fx_clip.gd") as GDScript).new() as Sprite2D
	clip.set("stops", stop_at)
	clip.call("_load", key)
	clip.position = at
	clip.scale = Vector2(size, size)
	clip.visible = false
	clip.centered = false
	clip.set_meta("no_tele_glow", true)
	return clip


func _load(key: String) -> void:
	var entry := UnitBrain.vis_of(key)
	var tex := load("res://assets/sprites/sheets/units/" + str(entry.get("sheet", ""))) as Texture2D if not entry.is_empty() else null
	if tex == null:
		return
	var cell: Array = entry.cell
	var anchor: Array = entry.get("anchor", [0, 0])
	var cols := maxi(1, int(entry.get("cols", 1)))
	for idx_v in entry.clips.stay.frames:
		var idx := int(idx_v)
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((idx % cols) * float(cell[0]), (idx / cols) * float(cell[1]), float(cell[0]), float(cell[1]))
		_frames.append(at)
	offset = -Vector2(float(anchor[0]), float(anchor[1]))


func play_from(frame: int) -> void:
	visible = true
	_playing = true
	_acc = 0.0
	_show(frame)


func frame() -> int:
	return _fr


func _show(frame: int) -> void:
	if _frames.is_empty():
		return
	_fr = clampi(frame, 1, _frames.size())
	texture = _frames[_fr - 1]
	if stops.has(_fr) or (stops.has(-1) and _fr == _frames.size()):
		_playing = false


func _process(delta: float) -> void:
	if not visible or not _playing:
		return
	_acc += delta * 30.0
	while _acc >= 1.0 and _playing:
		_acc -= 1.0
		_show(_fr + 1 if _fr < _frames.size() else 1)
