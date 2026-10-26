extends Node

## Box molnDam / molnPeriod (objs.xml moln, period; the placed phase starts
## moln_t): every period ticks attMoln strikes each living unit whose box
## overlaps this one (Unit.udarBox: damage(molnDam, DAM_ELECTRIC)) and the
## clip plays from its 'moln' label. Box.step only runs in the active room.

const TPS := 30.0
const _ObjArt := preload("res://scripts/map/obj_art.gd")
const _Flags := preload("res://scripts/map/room_flags.gd")

var dam := 0.0
var period := 60
var moln_t := 0
var key := ""
## Box boundingBox from the box coordinates (bottom centre).
var rect := Rect2()
var _acc := 0.0
var _anim := 0


## Adds the trap to a stand-in when the objs.xml row has moln.
static func attach(host: Node2D, id: String, info: Dictionary, attrs: Dictionary) -> Node:
	var d := float(str(info.get("moln", "0")))
	if d <= 0.0:
		return null
	var trap: Node = load("res://scripts/map/moln_trap.gd").new()
	trap.name = "Moln"
	trap.set("dam", d)
	trap.set("period", maxi(int(str(info.get("period", "60"))), 1))
	trap.set("moln_t", int(str(attrs.get("phase", "0"))))
	trap.set("key", id)
	var size := _ObjArt.size(id)
	var w := float(str(info.get("scx", size.x if size.x > 0.0 else 40.0)))
	var h := float(str(info.get("scy", size.y if size.y > 0.0 else 40.0)))
	trap.set("rect", Rect2(-w * 0.5, -h, w, h))
	host.add_child(trap)
	return trap


func _physics_process(delta: float) -> void:
	var host := get_parent() as Node2D
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if host == null or player == null:
		return
	if _Flags.cell_of(player.global_position) != Vector2i(int(host.get_meta("room_x", 0)), int(host.get_meta("room_y", 0))):
		return
	_acc += delta * TPS
	while _acc >= 1.0:
		_acc -= 1.0
		_tick(host)


func _tick(host: Node2D) -> void:
	if _anim > 0:
		_anim += 1
		var last := _ObjArt.frames(key)
		if _anim > last:
			_anim = 0
		_show(host, maxi(_anim, maxi(_ObjArt.label_frame(key, "close"), 1)))
	moln_t += 1
	if moln_t < period:
		return
	moln_t = 0
	_strike(host)
	_anim = _ObjArt.label_frame(key, "moln")
	if _anim > 0:
		_show(host, _anim)


func _show(host: Node2D, frame: int) -> void:
	var art := host.get_node_or_null("Visual") as Sprite2D
	if art != null:
		art.texture = _ObjArt.texture(key, frame)


func _strike(host: Node2D) -> void:
	var box := Rect2(host.global_position + rect.position, rect.size)
	for unit in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemies"):
		if not unit is Node2D or not unit.has_method("take_hit") or unit.get("_dead") == true:
			continue
		if box.intersects(unit_rect(unit as Node2D)):
			unit.call("take_hit", int(dam), "DAM_ELECTRIC")


## A unit's boundingBox: body_size (player.gd BODY_SIZE for the player) above its feet.
static func unit_rect(unit: Node2D) -> Rect2:
	var size: Variant = unit.get("body_size")
	if unit.is_in_group("player"):
		size = Vector2(50, 78)
	var s: Vector2 = size if size is Vector2 else Vector2(40, 40)
	return Rect2(unit.global_position + Vector2(-s.x * 0.5, -s.y), s)
