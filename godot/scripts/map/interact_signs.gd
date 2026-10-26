extends RefCounted
## Interact.sign: an object with sign > 0 (map attr sign or the script command
## sign) emits the sign<N> particle every 30 ticks while helpMess is on, until
## its main action (actOsn) clears it.

const PERIOD := 30
const _ImpMess := preload("res://scripts/imp_mess.gd")
const _UnitFx := preload("res://scripts/units/unit_fx.gd")

var _nodes: Array = []
var _acc := 0.0


func set_sign(node: Node, sign: int) -> void:
	if node == null:
		return
	node.set_meta("sign", sign)
	if sign > 0 and not _nodes.has(node):
		_nodes.append(node)
		node.set_meta("t_sign", 0)


func clear(node: Node) -> void:
	if node != null and node.has_meta("sign"):
		node.set_meta("sign", 0)


## point: Callable(node) -> Vector2, the object's centre.
func tick(tree: SceneTree, delta: float, point: Callable) -> void:
	if _nodes.is_empty():
		return
	_acc += delta * 30.0
	while _acc >= 1.0:
		_acc -= 1.0
		var help := _ImpMess.help_on()
		for i in range(_nodes.size() - 1, -1, -1):
			var node: Node = _nodes[i]
			if not is_instance_valid(node) or int(node.get_meta("sign", 0)) <= 0:
				_nodes.remove_at(i)
				continue
			var t := int(node.get_meta("t_sign", 0))
			if t <= 0:
				t = PERIOD
				if help:
					_UnitFx.emit(tree, "sign%d" % int(node.get_meta("sign", 1)), point.call(node))
			node.set_meta("t_sign", t - 1)
