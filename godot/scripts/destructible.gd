class_name Destructible
extends StaticBody2D

## required_type empty means any damage type can break this body.
@export var hp: int = 40
@export var required_type: String = ""
@export var sight_transparency: float = 0.0


func _ready() -> void:
	add_to_group("destructibles")
	collision_layer = 1
	collision_mask = 0
	set_meta("sight_transparency", sight_transparency)
	if not has_meta("blocks_sight"):
		set_meta("blocks_sight", sight_transparency < 0.99)


func take_hit(amount: int = 0, type: String = "") -> void:
	if required_type != "" and type != required_type:
		return
	if amount <= 0:
		return
	hp -= amount
	if hp <= 0:
		queue_free()
