extends Node

## Prints PipInfo.info_str for a pistol, a magic weapon, two suits,
## two medicines, one ammo stack, a grenade and the memory orb.

func _ready() -> void:
	var info: GDScript = load("res://scripts/pip_info.gd")
	var cases: Array = [
		["weapon", "p10mm"],
		["weapon", "mbul"],
		["armor", "kombu"],
		["armor", "antirad"],
		["item", "antidote"],
		["item", "pot1"],
		["a", "p9"],
		["e", "grenade"],
		["e", "sphera"],
		["item", "sphera"],
	]
	for row in cases:
		var text: String = info.call("info_str", row[0], row[1])
		print("PIPINFO " + str(row[0]) + " " + str(row[1]) + " :: " + text.replace("\n", " | "))
	get_tree().quit()
