extends StaticBody2D

## A begin-land button or explosive. Bullets call take_hit. The land actor node listens.

signal triggered

var hp: int = 1
var breaks: bool = false


func take_hit(amount: int = 1, _type: String = "") -> void:
	if breaks:
		hp -= amount
		if hp > 0:
			return
	triggered.emit()
	if breaks:
		queue_free()
