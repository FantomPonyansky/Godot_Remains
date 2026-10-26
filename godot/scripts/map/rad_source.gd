extends Node

## Obj.ggModum on a radioactive box (objs.xml rad, radrad, radtip): each tick the
## player inside radrad takes rad * (radrad - dist) / radrad. radtip 0 goes into
## drad; 1 (gas) and 2 (pink cloud) build ddam1/ddam2, paid every 31 ticks / 30.

const TPS := 30.0
const _Registry := preload("res://scripts/map/land_registry.gd")
const GAS := ["", "DAM_VENOM", "DAM_PINKCLOUD"]

var rad := 0.0
var radrad := 250.0
var radtip := 0
var _acc := 0.0
var _gas := 0.0
var _t := 0


static func attach(node: Node, id: String) -> void:
	if not node is Node2D or id == "":
		return
	var info := _Registry.obj(id)
	var r := str(info.get("rad", "0")).to_float()
	if r <= 0.0:
		return
	var src: Node = (load("res://scripts/map/rad_source.gd") as Script).new()
	src.name = "RadSource"
	src.set("rad", r)
	if info.has("radrad"):
		src.set("radrad", str(info.radrad).to_float())
	src.set("radtip", str(info.get("radtip", "0")).to_int())
	node.add_child(src)


func _physics_process(delta: float) -> void:
	_acc += delta * TPS
	while _acc >= 1.0:
		_acc -= 1.0
		_step()


func _step() -> void:
	var host := get_parent() as Node2D
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if host == null or player == null or GameState.is_dead():
		return
	_t += 1
	var d2 := _center(host).distance_squared_to(_center(player))
	if d2 < radrad * radrad:
		var koef := (radrad - sqrt(d2)) / radrad
		if radtip == 0:
			GameState.rad_exposure(rad * koef)
		elif radtip < GAS.size():
			_gas += rad * (koef * 4.0 if koef < 0.25 else 1.0)
	if _t > 30:
		_t = 0
		if _gas > 0.0:
			GameState.apply_damage_f(_gas / 30.0, GAS[radtip], true)
			_gas = 0.0


func _center(node: Node2D) -> Vector2:
	if node.has_meta("size") and node.get_meta("size") is Vector2:
		return node.global_position + (node.get_meta("size") as Vector2) * 0.5
	for child in node.get_children():
		var cs := child as CollisionShape2D
		if cs != null and cs.shape != null:
			return cs.global_position
	return node.global_position + Vector2(0.0, -20.0)
