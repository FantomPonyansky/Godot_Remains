class_name Resistances
extends Node

## Damage type -> multiplier. 1 = normal, 0.5 resists, 1.5 weak, 0 immune.
## Missing types count as 1. Values come from E_Resistances (DAM_PIERCE, DAM_BURN, ...).

@export var multipliers: Dictionary = {}


func _ready() -> void:
	multipliers = multipliers.duplicate(true)


func multiplier_for(damage_type: String) -> float:
	if multipliers.has(damage_type):
		return float(multipliers[damage_type])
	return 1.0


static func of(target: Node) -> Resistances:
	if target == null:
		return null
	var child := target.get_node_or_null("Resistances")
	if child is Resistances:
		return child
	return null


## Scales amount by the target's resistance, then calls take_hit.
## take_hit still owns i-frames. Destructibles keep the raw type instead of a multiplier.
static func apply(target: Node, amount: float, damage_type: String) -> int:
	return apply_hit(target, HitInfo.make(amount, damage_type))


## Same as apply. Copies source, knock and contact onto the scaled hit.
## A non-destructible is called back with tip cleared and resisted set, which
## is the old take_hit(dealt, "").
static func apply_hit(target: Node, hit: HitInfo) -> int:
	if target == null or not is_instance_valid(target) or hit == null:
		return 0
	var passed := hit.dup()
	if target.is_in_group("destructibles"):
		var raw := int(round(hit.amount))
		passed.amount = raw
		passed.resisted = true
		if target.has_method("take_hit"):
			target.take_hit(passed)
		return raw
	var mult := 1.0
	var comp := of(target)
	if comp:
		mult = comp.multiplier_for(hit.tip)
	var dealt := int(round(hit.amount * mult))
	if dealt <= 0 or not target.has_method("take_hit"):
		return 0
	passed.amount = dealt
	passed.tip = ""
	passed.resisted = true
	passed.from_bullet = false
	target.take_hit(passed)
	return dealt
