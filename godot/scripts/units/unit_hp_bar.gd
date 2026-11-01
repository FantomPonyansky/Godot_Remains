extends Node2D

## Unit.hpbar / visDetails: a bar over a unit once it is hurt, its armour is
## worn, or it is a hero; hidden while invisible or dead. Drawn, not the hpBar
## clip: the fill shrinks from both sides to the centre and goes green, yellow,
## red as hp falls (port look, PORT_RULES "Enemies"). A thinner armour bar
## sits under it. A child of the unit, so the fog hides it with the unit.

const W := 40.0
const H := 4.0
const ARMOR_H := 2.0
const LIFT := 16.0

var _unit: Node2D
var _armor_max := 0.0
var _shown := -1.0
var _armor_shown := -1.0


func _init(unit: Node2D) -> void:
	_unit = unit
	name = "HpBar"
	z_as_relative = false
	z_index = 15
	visible = false


func _process(_delta: float) -> void:
	if not is_instance_valid(_unit):
		return
	var hp := float(_unit.get("hp"))
	var max_hp := maxf(1.0, float(_unit.get("max_hp")))
	var armor := float(_unit.get("_armor_hp"))
	if armor > _armor_max:
		_armor_max = armor
	var has_armor := float(_unit.get("_armor_qual")) > 0.0 and _armor_max > 0.0
	var hero := int(_unit.get_meta("hero", 0)) > 0
	var show := hp > 0.0 and not bool(_unit.get("_dead")) and not bool(_unit.get("_invis")) \
			and (hp < max_hp or hero or (has_armor and armor < _armor_max))
	visible = show
	if not show:
		return
	var size: Vector2 = _unit.get("body_size")
	position = Vector2(0.0, -size.y - LIFT)
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var armor_ratio := clampf(armor / _armor_max, 0.0, 1.0) if has_armor else -1.0
	if ratio != _shown or armor_ratio != _armor_shown:
		_shown = ratio
		_armor_shown = armor_ratio
		queue_redraw()


func _draw() -> void:
	var back := Rect2(-W * 0.5 - 1.0, -1.0, W + 2.0, H + 2.0)
	if _armor_shown >= 0.0:
		back.size.y += ARMOR_H + 1.0
	draw_rect(back, Color(0, 0, 0, 0.7))
	var fill := W * _shown
	var col := Color(minf(1.0, 2.0 * (1.0 - _shown)), minf(1.0, 2.0 * _shown), 0.0)
	draw_rect(Rect2(-fill * 0.5, 0.0, fill, H), col)
	if _armor_shown >= 0.0:
		var af := W * _armor_shown
		draw_rect(Rect2(-af * 0.5, H + 1.0, af, ARMOR_H), Color(0.55, 0.75, 1.0))
