extends "res://scripts/rig/other/player_rig.gd"
## OTHER's player rig as the port's pony body (`pony_puppet.gd` drives it). The
## PipBuck shows only once it is on the leg (Inventory.leg_pip, the stable grant).

var pip_shown := true


func _sync_pipbuck() -> void:
	super()
	if pip_shown:
		return
	for bone_name in ["pip1", "pip2"]:
		var bone: Node2D = _bones.get(bone_name)
		if bone:
			bone.visible = false
