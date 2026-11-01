extends Node2D

## A Location object whose behaviour is not ported yet. It keeps the plan
## row: objs.xml id, category, resolved unit id, placed attributes and the
## attached scripts, so script commands can target it by uid later.
## Groups: land_objects and land_<category>.

const _ObjArt := preload("res://scripts/map/obj_art.gd")
const _PS := preload("res://scripts/prop_state.gd")
const _UNITS := "res://assets/sprites/sheets/units/"

var eid := ""
var kind: StringName = &"prop"
var authority: bool = true
var faction := 0
var _fields_live := false
var _field_set: Dictionary = {}
var lock := 0.0
var dead := false
var usable := true
var spent := false
var opened := false
var box_hp := 0.0
var vis_state := ""
var mine := 0
var hackable := false
var locktip := 1
var lock_hp := 10.0
var lock_level := 0
var lock_att := -100
var mine_tip := 3
var allact := ""
var allid := ""
var once := 0
var act_time := 0
var lock_key := ""
var keyloss := 0
var fun := ""
var sec := false
var user_action := ""
var hold_use := false
var touched := false
var box_open := false
var close_at := 0
var blocks_sight := false
var prize_locked := false

var cat := ""
var data: Dictionary = {}


func setup(row: Dictionary) -> void:
	data = row
	cat = str(row.get("cat", ""))
	name = "%s_%s" % [cat, str(row.get("id", ""))]
	var feet: Array = row.get("feet", [0, 0])
	position = Vector2(float(feet[0]), float(feet[1]))
	add_to_group("land_objects")
	add_to_group("land_" + cat)
	var room: Array = row.get("room", [0, 0])
	set_meta("room_x", int(room[0]))
	set_meta("room_y", int(room[1]))
	set_meta("id", str(row.get("id", "")))
	set_meta("uid", str(row.get("uid", "")))
	var id := str(row.get("id", ""))
	if _ObjArt.has(id):
		var art := _ObjArt.sprite(id, maxi(_ObjArt.label_frame(id, "close"), 1))
		art.z_index = -1
		add_child(art)
		_ObjArt.shade(art, id)
		return
	if _unit_still(str(row.get("unit_id", ""))):
		return
	var size := Vector2(float(row.get("w", 0)), float(row.get("h", 0)))
	if size.x < 1.0 or size.y < 1.0:
		return
	var poly := Polygon2D.new()
	poly.color = Color(0.55, 0.55, 0.6, 0.35)
	poly.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y), Vector2(size.x * 0.5, -size.y),
		Vector2(size.x * 0.5, 0), Vector2(-size.x * 0.5, 0),
	])
	poly.z_index = -1
	add_child(poly)


## A unit that is not run here (the home stable's player-fraction turrets) still
## shows its stay pose: its rig held there, or its packed sheet and each part's first frame.
func _unit_still(unit_id: String) -> bool:
	if unit_id == "":
		return false
	var rig := _ObjArt.rig_still(unit_id)
	if rig != null:
		add_child(rig)
		return true
	var stills := _ObjArt.unit_still(_UNITS, unit_id)
	for s in stills:
		add_child(s)
	return not stills.is_empty()


func scripts() -> Dictionary:
	return data.get("scripts", {})


func _ready() -> void:
	_PS.absorb(self)


func snapshot() -> Dictionary:
	return _PS.record(self)


func restore(d: Dictionary) -> void:
	_PS.apply_fields(self, d)


func land_record() -> Dictionary:
	return snapshot()


func apply_land(d: Dictionary) -> void:
	restore(d)
